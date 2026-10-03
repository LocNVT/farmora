extends GutTest

## Verifies Game.feed_animal() per docs/ARCHITECTURE.md Section 17's
## "Feed an animal" data flow: debounce, refusal codes, the mutation +
## signal set on success. Swaps Game.clock for a FakeClock so the 300ms
## ActionGuard lock is deterministic (tests/helpers/fake_clock.gd).
##
## Uses Game.catalog (the real data/balance.json), not the fixture --
## Game.feed_animal always reads its own catalog, so a test catalog
## swap would not be testing production wiring. happiness.gainOnFeed is
## therefore the live file's placeholder-inert 0 (see docs/PROGRESS.md
## "Phase 3" owner flag); test_feeding_rules.gd already exercises the
## non-zero gain-and-clamp path against the fixture catalog directly.

var _fake_clock: FakeClock
var _real_clock: GameClock

func before_each() -> void:
	_real_clock = Game.clock
	_fake_clock = FakeClock.new()
	Game.clock = _fake_clock
	Game._guard = ActionGuard.new()  # fresh lock state per test -- Game is a singleton, so the real guard persists across tests otherwise
	Game.state = StateFactory.game_state_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 40.0, "happiness": 60.0})], 5)
	SaveService._autosave_timer.stop()  # SaveService is also a singleton -- a left-running debounce timer leaks into later tests
	SaveService.persistence_enabled = true
	watch_signals(Game)

func after_each() -> void:
	Game.clock = _real_clock
	SaveService._autosave_timer.stop()
	SaveService.persistence_enabled = false

func test_feed_animal_returns_unknown_id_for_a_missing_animal() -> void:
	var result: ActionResult = Game.feed_animal("does_not_exist")
	assert_eq(result.code, ActionResult.Code.UNKNOWN_ID)

func test_feed_animal_succeeds_and_mutates_state() -> void:
	var result: ActionResult = Game.feed_animal("a1")
	assert_true(result.ok())
	assert_eq(Game.state.player.feed, 4)
	var a: AnimalInstance = Game.state.farm.get_animal("a1")
	assert_almost_eq(a.hunger, 90.0, 0.01)
	assert_almost_eq(a.happiness, 60.0 + Game.catalog.happiness.gain_on_feed, 0.01)

func test_feed_animal_emits_the_full_signal_set_on_success() -> void:
	Game.feed_animal("a1")
	assert_signal_emitted(Game, "feed_changed")
	assert_signal_emitted(Game, "animal_fed")
	assert_signal_emitted(Game, "animal_changed")
	assert_signal_emitted(Game, "state_changed")

func test_feed_animal_emits_animal_fed_with_the_correct_id() -> void:
	Game.feed_animal("a1")
	assert_signal_emitted_with_parameters(Game, "animal_fed", ["a1"])

func test_second_feed_within_debounce_window_is_refused_and_emits_nothing() -> void:
	Game.feed_animal("a1")
	clear_signal_watcher()  # reset signal history after the first (real) feed
	watch_signals(Game)
	var result: ActionResult = Game.feed_animal("a1")
	assert_eq(result.code, ActionResult.Code.DEBOUNCED)
	assert_signal_not_emitted(Game, "animal_fed")
	assert_signal_not_emitted(Game, "state_changed")

func test_feed_is_allowed_again_after_the_lock_window_elapses() -> void:
	Game.feed_animal("a1")
	_fake_clock.advance(300)
	var result: ActionResult = Game.feed_animal("a1")
	assert_true(result.ok())

func test_debounce_window_is_read_from_the_catalog_not_hardcoded() -> void:
	# Regression test for a real Codex finding (Phase 3 review F-01):
	# Game.feed_animal() used to pass a hardcoded FEED_LOCK_MS=300
	# constant to ActionGuard, ignoring catalog.feeding.debounce_ms
	# entirely -- a balance.json tuning change would have had no effect.
	# Proven here by configuring a DIFFERENT window (1000ms) and
	# confirming the lock actually follows it: still locked at +300ms,
	# but free again at +1000ms.
	var saved_catalog: GameCatalog = Game.catalog
	Game.catalog = StateFactory.fixture_catalog()
	Game.catalog.feeding.debounce_ms = 1000

	Game.feed_animal("a1")
	_fake_clock.advance(300)
	var still_locked: ActionResult = Game.feed_animal("a1")
	assert_eq(still_locked.code, ActionResult.Code.DEBOUNCED, "300ms should still be inside a configured 1000ms lock")

	_fake_clock.advance(700)  # total 1000ms since the first feed
	var now_allowed: ActionResult = Game.feed_animal("a1")
	assert_true(now_allowed.ok(), "1000ms should clear a configured 1000ms lock")

	Game.catalog = saved_catalog

func test_feed_animal_refuses_not_enough_feed_without_mutating_state() -> void:
	Game.state.player.feed = 0
	var result: ActionResult = Game.feed_animal("a1")
	assert_eq(result.code, ActionResult.Code.NOT_ENOUGH_FEED)
	assert_eq(Game.state.player.feed, 0)
	assert_signal_not_emitted(Game, "animal_changed")

func test_feed_animal_refuses_hunger_full_without_mutating_state() -> void:
	Game.state.farm.get_animal("a1").hunger = 100.0
	var result: ActionResult = Game.feed_animal("a1")
	assert_eq(result.code, ActionResult.Code.HUNGER_FULL)
	assert_eq(Game.state.player.feed, 5)
	assert_signal_not_emitted(Game, "animal_changed")

func test_a_refused_feed_does_not_consume_the_debounce_lock() -> void:
	Game.state.player.feed = 0
	Game.feed_animal("a1")  # refused: NOT_ENOUGH_FEED
	Game.state.player.feed = 5
	var result: ActionResult = Game.feed_animal("a1")  # same mono tick -- must not be DEBOUNCED
	assert_true(result.ok())

func test_feed_animal_advances_production_before_mutating() -> void:
	# ARCHITECTURE.md Section 14: "Order matters... every command calls
	# _advance_to(now) before it mutates." Proven here by advancing the
	# clock first, then feeding: the hunger decay for that elapsed time
	# must already be applied BEFORE apply_meal's +50 is added, not
	# skipped or applied after.
	Game.state.last_seen_ms = 0
	_fake_clock.set_now_ms(60000)  # 60s elapsed, hungerDecayPerMinute=1 (live catalog) -> -1 hunger
	Game.feed_animal("a1")  # starts at hunger 40.0 (before_each)
	var a: AnimalInstance = Game.state.farm.get_animal("a1")
	assert_almost_eq(a.hunger, 89.0, 0.01, "40 - 1 (60s decay) + 50 (meal) = 89, proving decay applied before the meal")

func test_feed_animal_emits_simulation_ticked() -> void:
	Game.feed_animal("a1")
	assert_signal_emitted(Game, "simulation_ticked", "_advance_to is called by every command, so simulation_ticked should fire even outside the SimTick timer")

func test_feed_animal_success_triggers_save_services_autosave_debounce() -> void:
	# ARCHITECTURE.md Section 11.6: every successful command calls
	# SaveService.request_autosave(), which starts its 2s debounce timer.
	# Checking the timer is running is a deterministic proxy for "was
	# called" without waiting out the real 2s delay.
	var result: ActionResult = Game.feed_animal("a1")
	assert_true(result.ok())
	assert_false(SaveService._autosave_timer.is_stopped(), "A successful feed_animal should start SaveService's autosave debounce timer")

func test_collect_success_triggers_save_services_autosave_debounce() -> void:
	Game.state.farm.get_animal("a1").progress = 1.0
	var result: ActionResult = Game.collect("a1")
	assert_true(result.ok())
	assert_false(SaveService._autosave_timer.is_stopped(), "A successful collect should start SaveService's autosave debounce timer")

func test_collect_returns_unknown_id_for_a_missing_animal() -> void:
	var result: ActionResult = Game.collect("does_not_exist")
	assert_eq(result.code, ActionResult.Code.UNKNOWN_ID)

func test_collect_refuses_not_ready_when_progress_is_below_one() -> void:
	var result: ActionResult = Game.collect("a1")  # progress 0.0 (before_each default)
	assert_eq(result.code, ActionResult.Code.NOT_READY)

func test_collect_succeeds_and_mutates_state() -> void:
	Game.state.farm.get_animal("a1").progress = 1.0
	var result: ActionResult = Game.collect("a1")
	assert_true(result.ok())
	assert_eq(Game.state.inventory.get_qty("egg"), 1)
	assert_almost_eq(Game.state.farm.get_animal("a1").progress, 0.0, 0.0001)

func test_collect_emits_the_full_signal_set_on_success() -> void:
	Game.state.farm.get_animal("a1").progress = 1.0
	Game.collect("a1")
	assert_signal_emitted_with_parameters(Game, "product_collected", ["a1", "egg", 1])
	assert_signal_emitted(Game, "animal_changed")
	assert_signal_emitted(Game, "state_changed")

func test_collect_refusal_emits_no_signals() -> void:
	Game.collect("a1")  # progress 0.0 -> NOT_READY
	assert_signal_not_emitted(Game, "product_collected")
	assert_signal_not_emitted(Game, "animal_changed")
	assert_signal_not_emitted(Game, "state_changed")

func test_a_second_collect_refuses_not_ready_without_a_debounce() -> void:
	# docs/PROGRESS.md "Phase 4" plan item 5: no ActionGuard on collect
	# -- a repeat attempt refuses on its own via NOT_READY, since
	# progress already reset to 0 after the first collect.
	Game.state.farm.get_animal("a1").progress = 1.0
	Game.collect("a1")
	var second: ActionResult = Game.collect("a1")
	assert_eq(second.code, ActionResult.Code.NOT_READY)

func test_feed_animal_emits_animal_status_changed_when_hunger_crosses_the_threshold() -> void:
	# fixture/live hungryBelow=30; before_each's "a1" starts at hunger
	# 40.0 (not HUNGRY). Starve it below 30 via elapsed time, then feed
	# it -- the feed should both clear HUNGRY and emit the transition.
	Game.state.farm.get_animal("a1").hunger = 20.0  # already HUNGRY
	var result: ActionResult = Game.feed_animal("a1")
	assert_true(result.ok())
	# assert_signal_emitted_with_parameters's 3rd positional arg is an
	# emission INDEX, not a message (docs/PROGRESS.md "Phase 1" note) --
	# use the plain assert plus a separate comment for intent instead.
	assert_signal_emitted_with_parameters(Game, "animal_status_changed", ["a1", 0])

func test_feed_animal_emits_no_status_change_when_flags_do_not_cross_a_threshold() -> void:
	# "a1" starts at hunger 40.0 (already not-HUNGRY, well above the 30
	# threshold) and happiness 60.0 (well above low_happiness_below).
	# Feeding it raises hunger further but crosses no flag boundary.
	Game.feed_animal("a1")
	assert_signal_not_emitted(Game, "animal_status_changed")

func test_collect_emits_animal_status_changed_when_ready_flag_clears() -> void:
	Game.state.farm.get_animal("a1").progress = 1.0  # READY
	Game.collect("a1")
	assert_signal_emitted(Game, "animal_status_changed", "Collecting a READY animal should clear its READY flag and emit the transition")

func test_advance_to_advances_multiple_animals_independently_in_one_call() -> void:
	# Codex Phase 4 review F-02: _advance_to() loops over every animal
	# in state.farm.animals, but no test previously proved two animals
	# with DIFFERENT starting values both advance correctly from a
	# single call, rather than (for example) only the first one in the
	# array being touched.
	Game.state.farm.animals = [
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0, "progress": 0.0}),
		StateFactory.animal("pig", "pig_pen", {"id": "a2", "hunger": 100.0, "progress": 0.5}),
	]
	Game.state.last_seen_ms = 0
	_fake_clock.set_now_ms(60000)  # 60s elapsed, hungerDecayPerMinute=1 (live catalog) -> -1 hunger each
	Game.feed_animal("a1")  # any command's own _advance_to(now) call advances BOTH animals

	var a1: AnimalInstance = Game.state.farm.get_animal("a1")
	var a2: AnimalInstance = Game.state.farm.get_animal("a2")
	# a1 was fed (hunger 100 -> 99 decay -> +50 meal, clamped to 100) --
	# just confirm it was touched by the shared decay, not re-deriving
	# the full feed math already covered elsewhere.
	assert_almost_eq(a1.hunger, 100.0, 0.01)
	# a2 received ONLY the 60s decay (no command targeted it) -- proves
	# the loop inside _advance_to touched an animal that was not the
	# command's own target.
	assert_almost_eq(a2.hunger, 99.0, 0.01, "A second, untargeted animal should still be advanced by the same _advance_to call")
	assert_almost_eq(a2.progress, 0.5 + (60.0 / 600.0), 0.001, "a2's progress should advance using its OWN cycle_seconds (pig: 600s), independent of a1")

func test_production_speed_scales_with_the_housing_buildings_level() -> void:
	# ARCHITECTURE.md Section 14: "cycle = cycle_seconds /
	# BuildingRules.production_multiplier(...)". Live chicken_coop L2
	# multiplier is 1.25, so the same elapsed time should yield 25% more
	# progress than at L1.
	Game.state.farm.animals = [StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0, "progress": 0.0})]
	Game.state.farm.buildings = [StateFactory.building("chicken_coop", 2)]
	Game.state.last_seen_ms = 0
	_fake_clock.set_now_ms(18000)  # 18s elapsed, chicken cycle 180s at L1 -> 0.1 progress at L1

	Game.feed_animal("a1")  # any command's own _advance_to(now) call advances production

	var a1: AnimalInstance = Game.state.farm.get_animal("a1")
	# 180s / 1.25 = 144s effective cycle; 18s / 144s = 0.125 progress.
	assert_almost_eq(a1.progress, 0.125, 0.001, "L2's 1.25x multiplier should give 25% more progress than L1 over the same elapsed time")

func test_an_upgrade_does_not_retroactively_speed_up_already_elapsed_time() -> void:
	# _advance_to() always runs BEFORE a command's own mutation
	# (ARCHITECTURE.md Section 14: "Order matters"), so upgrading a
	# building and then immediately advancing must use the NEW
	# multiplier only for time elapsed AFTER the upgrade, never for the
	# window that was already simulated at the old level.
	Game.state.farm.animals = [StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0, "progress": 0.0})]
	Game.state.farm.buildings = [StateFactory.building("chicken_coop", 1)]
	Game.state.last_seen_ms = 0
	_fake_clock.set_now_ms(18000)  # 18s at L1 (cycle 180s) -> 0.1 progress
	Game._advance_to(_fake_clock.now_ms())
	var a1: AnimalInstance = Game.state.farm.get_animal("a1")
	assert_almost_eq(a1.progress, 0.1, 0.001, "Precondition: 18s at L1 should give exactly 0.1 progress")

	# Now upgrade (simulated directly on state, since Game.upgrade_building
	# does not exist until Task 6) and advance another 18s.
	Game.state.farm.buildings[0].level = 2
	_fake_clock.advance(18000)
	Game._advance_to(_fake_clock.now_ms())
	# The FIRST 18s already produced 0.1 progress at L1 and must not be
	# re-simulated at L2; only the SECOND 18s uses the 1.25x multiplier.
	assert_almost_eq(a1.progress, 0.1 + 0.125, 0.001, "Only time elapsed AFTER the upgrade should use the new multiplier")
