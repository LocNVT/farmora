extends GutTest

## Verifies Game._advance_to()'s Phase 8 extension end-to-end: the 8h
## cap, backwards-clock handling, is_return/OfflineReport emission, and
## split invariance against the online SimTick path. Per docs/GDD.md
## Section 9 and docs/ARCHITECTURE.md Section 12.

var _real_clock: GameClock
var _fake_clock: FakeClock

func before_each() -> void:
	_real_clock = Game.clock
	_fake_clock = FakeClock.new()
	Game.clock = _fake_clock
	watch_signals(Game)

func after_each() -> void:
	Game.clock = _real_clock
	if is_instance_valid(Game._sim_tick):
		Game._sim_tick.stop()

func _seed_session(animals: Array[AnimalInstance], last_seen_ms: int) -> void:
	var fresh: GameState = StateFactory.game_state_with(animals, 999, last_seen_ms)
	Game.state = fresh

func test_24_hour_gap_is_applied_as_8_hours_and_marked_capped() -> void:
	var cap_ms: int = Game.catalog.offline.cap_ms()
	_fake_clock.set_now_ms(0)
	_seed_session([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})], 0)
	_fake_clock.set_now_ms(24 * 3600000)

	var report: OfflineReport = Game._advance_to(_fake_clock.now_ms(), true)

	assert_eq(report.elapsed_ms, cap_ms)
	assert_true(report.capped)
	assert_eq(Game.state.last_seen_ms, 24 * 3600000, "last_seen_ms should advance to the real now, even though production was capped")

func test_backwards_clock_applies_zero_elapsed_and_rebases_last_seen() -> void:
	_fake_clock.set_now_ms(100000)
	_seed_session([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 50.0})], 100000)
	_fake_clock.set_now_ms(10000)  # clock moved backwards

	var report: OfflineReport = Game._advance_to(_fake_clock.now_ms(), true)

	assert_eq(report.elapsed_ms, 0)
	assert_eq(Game.state.last_seen_ms, 10000, "a backwards clock should still rebase last_seen_ms to now, per ARCHITECTURE.md Section 12.1")
	assert_almost_eq(Game.state.farm.get_animal("a1").hunger, 50.0, 0.01, "zero elapsed time means no hunger decay")

func test_is_return_false_does_not_emit_offline_progress_applied() -> void:
	_fake_clock.set_now_ms(0)
	_seed_session([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})], 0)
	_fake_clock.set_now_ms(3600000)

	Game._advance_to(_fake_clock.now_ms(), false)

	assert_signal_not_emitted(Game, "offline_progress_applied")

func test_is_return_true_emits_offline_progress_applied_with_the_report() -> void:
	_fake_clock.set_now_ms(0)
	_seed_session([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})], 0)
	_fake_clock.set_now_ms(3600000)

	var report: OfflineReport = Game._advance_to(_fake_clock.now_ms(), true)

	assert_signal_emitted_with_parameters(Game, "offline_progress_applied", [report])

func test_hungry_animal_produces_nothing_while_away() -> void:
	_fake_clock.set_now_ms(0)
	_seed_session([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 0.0})], 0)
	_fake_clock.set_now_ms(3600000)

	var report: OfflineReport = Game._advance_to(_fake_clock.now_ms(), true)

	assert_true(report.products.is_empty(), "GDD Section 9: no free production for a hungry animal")
	assert_true(report.ready_animal_ids.is_empty())

func test_an_animal_already_ready_before_leaving_is_not_counted_as_produced() -> void:
	_fake_clock.set_now_ms(0)
	_seed_session([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0, "progress": 1.0})], 0)
	_fake_clock.set_now_ms(3600000)

	var report: OfflineReport = Game._advance_to(_fake_clock.now_ms(), true)

	assert_true(report.products.is_empty(), "an animal that was already READY when the player left produced nothing new while away")

func test_a_fed_animal_that_completes_is_reported() -> void:
	# chicken's cycle_seconds is short in the fixture catalog; a 1h
	# window with full hunger should complete at least one cycle.
	_fake_clock.set_now_ms(0)
	_seed_session([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})], 0)
	_fake_clock.set_now_ms(3600000)

	var report: OfflineReport = Game._advance_to(_fake_clock.now_ms(), true)

	assert_eq(report.products.get("egg"), 1)
	assert_true(report.ready_animal_ids.has("a1"))

func test_one_shot_advance_matches_many_one_second_advances_mid_window() -> void:
	# Split invariance (ARCHITECTURE.md Section 14): advancing N seconds
	# in one call must match the same elapsed time applied as repeated
	# small ticks, confirming the offline path and the online SimTick
	# path are genuinely the same code, not two implementations that
	# happen to agree. Codex review (Phase 8): the original version of
	# this test used a 2h window with a cow (6 min cycle, hunger decays
	# to 0 in 100 min) -- both paths saturate at progress=1.0/hunger=0.0
	# well before the window ends, so the assertion could pass even with
	# a real mid-window divergence between the two paths, since both
	# just converge to the same clamped endpoint regardless. Fixed by
	# choosing a window short enough that hunger/progress stay STRICTLY
	# mid-range (never hit 0 or clamp at 1.0) in both runs, so an actual
	# per-tick discrepancy would show up as a real, unmasked difference.
	var one_shot_animal := StateFactory.animal("cow", "cow_barn", {"id": "one_shot", "hunger": 100.0})
	var ticked_animal := StateFactory.animal("cow", "cow_barn", {"id": "ticked", "hunger": 100.0})
	var window_ms: int = 2 * 60000  # 2 min: well under the cow's 6 min cycle and the 100 min hunger-to-zero time

	_fake_clock.set_now_ms(0)
	_seed_session([one_shot_animal], 0)
	_fake_clock.set_now_ms(window_ms)
	Game._advance_to(_fake_clock.now_ms(), true)
	var one_shot_progress: float = Game.state.farm.get_animal("one_shot").progress
	var one_shot_hunger: float = Game.state.farm.get_animal("one_shot").hunger
	assert_true(one_shot_hunger > 0.0 and one_shot_hunger < 100.0, "test setup must keep hunger strictly mid-range, not saturated")
	assert_true(one_shot_progress > 0.0 and one_shot_progress < 1.0, "test setup must keep progress strictly mid-range, not clamped at READY")

	_fake_clock.set_now_ms(0)
	_seed_session([ticked_animal], 0)
	for i in range(window_ms / 1000):
		_fake_clock.advance(1000)
		Game._advance_to(_fake_clock.now_ms(), false)
	var ticked_progress: float = Game.state.farm.get_animal("ticked").progress
	var ticked_hunger: float = Game.state.farm.get_animal("ticked").hunger

	assert_almost_eq(one_shot_progress, ticked_progress, 0.001)
	assert_almost_eq(one_shot_hunger, ticked_hunger, 0.001)

func test_save_snapshot_encodes_last_seen_at_the_advance_time() -> void:
	_fake_clock.set_now_ms(0)
	_seed_session([], 0)
	_fake_clock.set_now_ms(5000)

	var snapshot: Dictionary = Game._save_snapshot()

	assert_eq(int(snapshot.get("lastSeen")), 5000)
