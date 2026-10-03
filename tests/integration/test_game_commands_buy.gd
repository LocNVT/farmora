extends GutTest

## Verifies Game.buy_animal()/buy_feed_pack() per docs/ARCHITECTURE.md
## Section 13.1/10.4's transaction order: debounce, refusal codes, the
## mutation + signal set on success. Swaps Game.clock for a FakeClock so
## the 300ms ActionGuard "purchase" lock is deterministic (same pattern
## as test_game_commands.gd).
##
## Uses Game.catalog (the real data/balance.json) -- Game.buy_animal
## always reads its own catalog, so a test catalog swap would not be
## testing production wiring. Chicken costs 100 coins (unlockLevel 1),
## pig 600 (unlockLevel 3), feed pack costs 25 coins for 10 feed.

var _fake_clock: FakeClock
var _real_clock: GameClock

func before_each() -> void:
	_real_clock = Game.clock
	_fake_clock = FakeClock.new()
	Game.clock = _fake_clock
	Game._guard = ActionGuard.new()  # fresh lock state per test -- Game is a singleton, so the real guard persists across tests otherwise
	Game.state = StateFactory.game_state_with([], 5, 0, 200, 1)  # feed=5, coins=200, level=1
	SaveService._autosave_timer.stop()  # SaveService is also a singleton -- a left-running debounce timer leaks into later tests
	SaveService.persistence_enabled = true
	watch_signals(Game)

func after_each() -> void:
	Game.clock = _real_clock
	SaveService._autosave_timer.stop()
	SaveService.persistence_enabled = false

func test_buy_animal_succeeds_and_mutates_state() -> void:
	var result: ActionResult = Game.buy_animal("chicken")
	assert_true(result.ok())
	assert_eq(Game.state.player.coins, 100)
	assert_eq(Game.state.farm.animals.size(), 1)

func test_buy_animal_houses_the_new_animal_at_the_species_definition_building() -> void:
	Game.buy_animal("chicken")
	var animal: AnimalInstance = Game.state.farm.animals[0]
	assert_eq(animal.building_id, "chicken_coop")

func test_buy_animal_applies_new_animal_starting_stats() -> void:
	Game.buy_animal("chicken")
	var animal: AnimalInstance = Game.state.farm.animals[0]
	assert_almost_eq(animal.hunger, Game.catalog.new_animal.hunger, 0.01)
	assert_almost_eq(animal.happiness, Game.catalog.new_animal.happiness, 0.01)
	assert_almost_eq(animal.health, Game.catalog.new_animal.health, 0.01)
	assert_almost_eq(animal.progress, 0.0, 0.0001)

func test_buy_animal_assigns_a_name_from_the_default_pool() -> void:
	Game.buy_animal("chicken")
	var animal: AnimalInstance = Game.state.farm.animals[0]
	assert_true(["Mimi", "Pip"].has(animal.name), "The new chicken's name should come from the catalog's defaultNames pool")

func test_buy_animal_gives_an_empty_name_when_the_pool_is_empty() -> void:
	Game.state.player.level = 3
	Game.state.player.coins = 1000
	Game.buy_animal("pig")  # pig has an empty defaultNames pool in balance.json
	var animal: AnimalInstance = Game.state.farm.animals[0]
	assert_eq(animal.name, "")

func test_buy_animal_result_data_carries_the_new_animal_id() -> void:
	var result: ActionResult = Game.buy_animal("chicken")
	var animal: AnimalInstance = Game.state.farm.animals[0]
	assert_eq(result.data.get("animal_id"), animal.id)

func test_buy_animal_emits_the_full_signal_set_on_success() -> void:
	Game.buy_animal("chicken")
	assert_signal_emitted(Game, "coins_changed")
	assert_signal_emitted(Game, "animal_added")
	assert_signal_emitted(Game, "state_changed")

func test_buy_animal_emits_animal_added_with_the_correct_id() -> void:
	Game.buy_animal("chicken")
	var animal: AnimalInstance = Game.state.farm.animals[0]
	assert_signal_emitted_with_parameters(Game, "animal_added", [animal.id])

func test_buy_animal_refuses_unknown_species() -> void:
	var result: ActionResult = Game.buy_animal("dragon")
	assert_eq(result.code, ActionResult.Code.UNKNOWN_ID)
	assert_eq(Game.state.farm.animals.size(), 0)

func test_buy_animal_refuses_locked_by_level_without_mutating_state() -> void:
	var result: ActionResult = Game.buy_animal("pig")  # needs level 3, player is level 1
	assert_eq(result.code, ActionResult.Code.LOCKED_BY_LEVEL)
	assert_eq(Game.state.player.coins, 200)
	assert_eq(Game.state.farm.animals.size(), 0)
	assert_signal_not_emitted(Game, "animal_added")

func test_buy_animal_refuses_not_enough_coins_without_mutating_state() -> void:
	Game.state.player.coins = 50
	var result: ActionResult = Game.buy_animal("chicken")
	assert_eq(result.code, ActionResult.Code.NOT_ENOUGH_COINS)
	assert_eq(result.missing, 50)
	assert_eq(Game.state.player.coins, 50)
	assert_eq(Game.state.farm.animals.size(), 0)

func test_second_buy_within_debounce_window_is_refused_and_emits_nothing() -> void:
	Game.buy_animal("chicken")
	clear_signal_watcher()
	watch_signals(Game)
	var result: ActionResult = Game.buy_animal("chicken")
	assert_eq(result.code, ActionResult.Code.DEBOUNCED)
	assert_signal_not_emitted(Game, "animal_added")
	assert_eq(Game.state.farm.animals.size(), 1, "The debounced second buy must not have added a second animal")

func test_buy_is_allowed_again_after_the_lock_window_elapses() -> void:
	Game.buy_animal("chicken")
	_fake_clock.advance(300)
	var result: ActionResult = Game.buy_animal("chicken")
	assert_true(result.ok())
	assert_eq(Game.state.farm.animals.size(), 2)

func test_a_refused_buy_does_not_consume_the_debounce_lock() -> void:
	Game.state.player.coins = 0
	Game.buy_animal("chicken")  # refused: NOT_ENOUGH_COINS
	Game.state.player.coins = 200
	var result: ActionResult = Game.buy_animal("chicken")  # same mono tick -- must not be DEBOUNCED
	assert_true(result.ok())

func test_buy_animal_and_buy_feed_pack_share_the_purchase_debounce_key() -> void:
	# ARCHITECTURE.md Section 10.4 ADR-13: "purchase" is shared by buy
	# animal, buy feed pack, and upgrade, so a double tap cannot buy two
	# different things.
	Game.buy_animal("chicken")
	var result: ActionResult = Game.buy_feed_pack()
	assert_eq(result.code, ActionResult.Code.DEBOUNCED, "buy_feed_pack should be locked out by buy_animal's own purchase-key commit")

func test_buy_feed_pack_succeeds_and_mutates_state() -> void:
	var result: ActionResult = Game.buy_feed_pack()
	assert_true(result.ok())
	assert_eq(Game.state.player.coins, 175)
	assert_eq(Game.state.player.feed, 15)

func test_buy_feed_pack_emits_the_full_signal_set_on_success() -> void:
	Game.buy_feed_pack()
	assert_signal_emitted(Game, "coins_changed")
	assert_signal_emitted(Game, "feed_changed")
	assert_signal_emitted_with_parameters(Game, "feed_bought", [10])
	assert_signal_emitted(Game, "state_changed")

func test_buy_feed_pack_refuses_not_enough_coins_without_mutating_state() -> void:
	Game.state.player.coins = 10
	var result: ActionResult = Game.buy_feed_pack()
	assert_eq(result.code, ActionResult.Code.NOT_ENOUGH_COINS)
	assert_eq(result.missing, 15)
	assert_eq(Game.state.player.coins, 10)
	assert_eq(Game.state.player.feed, 5)
	assert_signal_not_emitted(Game, "feed_bought")

func test_buy_feed_pack_emits_the_actual_amount_added_not_the_nominal_pack_size_on_partial_overflow() -> void:
	# Codex Phase 6 review F1: when refuse_overflowing_feed_pack is
	# false, a partially-overflowing pack is allowed through and the
	# applied feed is clamped to capacity -- feed_bought must report the
	# ACTUAL amount added (new_feed - old_feed), not the nominal
	# feed_pack_feed, which would overstate what really happened.
	var original_switch: bool = Game.catalog.economy.refuse_overflowing_feed_pack
	Game.catalog.economy.refuse_overflowing_feed_pack = false
	Game.state.player.feed = 95  # cap is 100 (L1 feed_storage); pack is 10 -> only 5 actually fit
	Game.buy_feed_pack()
	assert_eq(Game.state.player.feed, 100)
	assert_signal_emitted_with_parameters(Game, "feed_bought", [5])
	Game.catalog.economy.refuse_overflowing_feed_pack = original_switch

func test_buy_animal_advances_production_before_mutating() -> void:
	# ARCHITECTURE.md Section 14: "Order matters" -- every command calls
	# _advance_to(now) before it mutates. Proven here with an existing
	# animal in the farm: its hunger should already reflect the elapsed
	# decay by the time buy_animal returns.
	Game.state.farm.animals = [StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})]
	Game.state.last_seen_ms = 0
	_fake_clock.set_now_ms(60000)  # 60s elapsed, hungerDecayPerMinute=1 -> -1 hunger
	Game.buy_animal("chicken")
	var a1: AnimalInstance = Game.state.farm.get_animal("a1")
	assert_almost_eq(a1.hunger, 99.0, 0.01)

func test_buy_animal_success_triggers_save_services_autosave_debounce() -> void:
	var result: ActionResult = Game.buy_animal("chicken")
	assert_true(result.ok())
	assert_false(SaveService._autosave_timer.is_stopped(), "A successful buy_animal should start SaveService's autosave debounce timer")

func test_buy_feed_pack_success_triggers_save_services_autosave_debounce() -> void:
	var result: ActionResult = Game.buy_feed_pack()
	assert_true(result.ok())
	assert_false(SaveService._autosave_timer.is_stopped(), "A successful buy_feed_pack should start SaveService's autosave debounce timer")
