extends GutTest

## Verifies ProductionRules.advance_animal() per docs/ARCHITECTURE.md
## Section 14's "the only simulation math" and its test table (Section
## 19): fed progress, hunger running out mid-interval, starving makes
## no progress, pause at 1.0, one meal ~= 50 minutes of production, and
## split invariance (1 big dt == many small dt's). Building multipliers
## and the tutorial boost are Phase 6/unassigned-tutorial concerns --
## not tested here, since Params.cycle_seconds is the only knob this
## class reads (docs/PROGRESS.md "Phase 4" plan item 3).

func _params(cycle_seconds: float, hunger_decay_per_minute: float = 0.0, happiness_decay_per_minute: float = 0.0, pause_when_ready: bool = true) -> ProductionRules.Params:
	var p := ProductionRules.Params.new()
	p.cycle_seconds = cycle_seconds
	p.hunger_decay_per_second = hunger_decay_per_minute / 60.0
	p.happiness_decay_per_second = happiness_decay_per_minute / 60.0
	p.pause_when_ready = pause_when_ready
	return p

func _animal(hunger: float, progress: float = 0.0, happiness: float = 100.0) -> AnimalInstance:
	return StateFactory.animal("chicken", "chicken_coop", {"hunger": hunger, "progress": progress, "happiness": happiness})

func test_zero_dt_does_nothing() -> void:
	var a := _animal(50.0, 0.5)
	var completed: int = ProductionRules.advance_animal(a, 0.0, _params(100.0))
	assert_eq(completed, 0)
	assert_almost_eq(a.progress, 0.5, 0.0001)

func test_negative_dt_does_nothing() -> void:
	# Codex Phase 4 review F-02: the implementation has an explicit
	# `if dt <= 0.0: return 0` guard, but the old test name claimed to
	# cover "zero_or_negative" while only exercising dt == 0.0.
	var a := _animal(50.0, 0.5, 80.0)
	var completed: int = ProductionRules.advance_animal(a, -5.0, _params(100.0, 10.0, 10.0))
	assert_eq(completed, 0)
	assert_almost_eq(a.progress, 0.5, 0.0001, "A negative dt must not advance progress")
	assert_almost_eq(a.hunger, 50.0, 0.0001, "A negative dt must not decay hunger")
	assert_almost_eq(a.happiness, 80.0, 0.0001, "A negative dt must not decay happiness")

func test_fed_animal_gains_progress_proportional_to_dt() -> void:
	var a := _animal(100.0, 0.0)
	# cycle 100s, hunger never runs out (no decay configured) -> 10s = 0.1 progress.
	ProductionRules.advance_animal(a, 10.0, _params(100.0))
	assert_almost_eq(a.progress, 0.1, 0.0001)

func test_hunger_running_out_mid_interval_only_advances_progress_for_the_fed_portion() -> void:
	# hunger 30, decay 60/min = 1/s -> fed for exactly 30s of a 60s interval.
	var a := _animal(30.0, 0.0)
	ProductionRules.advance_animal(a, 60.0, _params(100.0, 60.0))
	assert_almost_eq(a.progress, 0.3, 0.0001, "Only the 30s the animal had food should count toward the 100s cycle")
	assert_almost_eq(a.hunger, 0.0, 0.0001)

func test_starving_animal_makes_no_progress_however_long_it_waits() -> void:
	var a := _animal(0.0, 0.0)
	ProductionRules.advance_animal(a, 99999.0, _params(100.0, 60.0))
	assert_almost_eq(a.progress, 0.0, 0.0001)

func test_hunger_and_happiness_decay_on_wall_time_regardless_of_feeding_state() -> void:
	var a := _animal(100.0, 0.0, 100.0)
	ProductionRules.advance_animal(a, 60.0, _params(100.0, 30.0, 10.0))
	assert_almost_eq(a.hunger, 70.0, 0.0001)
	assert_almost_eq(a.happiness, 90.0, 0.0001)

func test_hunger_never_goes_below_zero() -> void:
	var a := _animal(10.0, 0.0)
	ProductionRules.advance_animal(a, 60.0, _params(100.0, 60.0))
	assert_almost_eq(a.hunger, 0.0, 0.0001)

func test_happiness_never_goes_below_zero() -> void:
	var a := _animal(100.0, 0.0, 5.0)
	ProductionRules.advance_animal(a, 60.0, _params(100.0, 0.0, 60.0))
	assert_almost_eq(a.happiness, 0.0, 0.0001)

func test_progress_pauses_at_one_and_returns_one_completion() -> void:
	var a := _animal(100.0, 0.95)
	var completed: int = ProductionRules.advance_animal(a, 10.0, _params(100.0))
	assert_eq(completed, 1)
	assert_almost_eq(a.progress, 1.0, 0.0001)

func test_progress_already_at_one_stays_paused_and_returns_zero_when_pause_when_ready_is_true() -> void:
	var a := _animal(100.0, 1.0)
	var completed: int = ProductionRules.advance_animal(a, 60.0, _params(100.0))
	assert_eq(completed, 0)
	assert_almost_eq(a.progress, 1.0, 0.0001, "A paused-at-ready animal should not accumulate progress past 1.0")

func test_one_meal_gives_about_fifty_minutes_of_production() -> void:
	# GDD Section 4 clarification: +50 hunger ~= 50 minutes of production
	# at hungerDecayPerMinute=1. A 60-minute cycle should be exactly 50%
	# complete after exactly 50 minutes of fed time.
	var a := _animal(50.0, 0.0)
	ProductionRules.advance_animal(a, 50.0 * 60.0, _params(60.0 * 60.0, 1.0))
	assert_almost_eq(a.progress, 50.0 / 60.0, 0.0001)

func test_split_invariance_one_big_step_matches_many_small_steps() -> void:
	var total_seconds: float = 8.0 * 3600.0  # 8 hours
	var one_big_step := _animal(80.0, 0.0)
	ProductionRules.advance_animal(one_big_step, total_seconds, _params(500.0, 1.0))

	var many_small_steps := _animal(80.0, 0.0)
	var elapsed: float = 0.0
	while elapsed < total_seconds:
		ProductionRules.advance_animal(many_small_steps, 1.0, _params(500.0, 1.0))
		elapsed += 1.0

	assert_almost_eq(one_big_step.progress, many_small_steps.progress, 0.001)
	assert_almost_eq(one_big_step.hunger, many_small_steps.hunger, 0.001)

func test_split_invariance_holds_for_random_splits_too() -> void:
	var total_seconds: float = 3600.0
	var baseline := _animal(80.0, 0.0)
	ProductionRules.advance_animal(baseline, total_seconds, _params(500.0, 1.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var split := _animal(80.0, 0.0)
	var remaining: float = total_seconds
	while remaining > 0.0:
		var step: float = minf(remaining, rng.randf_range(0.1, 50.0))
		ProductionRules.advance_animal(split, step, _params(500.0, 1.0))
		remaining -= step

	assert_almost_eq(baseline.progress, split.progress, 0.001)
	assert_almost_eq(baseline.hunger, split.hunger, 0.001)

func test_check_collect_refuses_when_progress_is_below_one() -> void:
	var a := _animal(100.0, 0.99)
	var result: ActionResult = ProductionRules.check_collect(a)
	assert_false(result.ok())
	assert_eq(result.code, ActionResult.Code.NOT_READY)

func test_check_collect_ok_when_progress_is_exactly_one() -> void:
	var a := _animal(100.0, 1.0)
	assert_true(ProductionRules.check_collect(a).ok())

func test_apply_collect_adds_the_animals_product_to_the_inventory() -> void:
	var catalog: GameCatalog = StateFactory.fixture_catalog()
	var inv := InventoryState.new()
	var a := _animal(100.0, 1.0)  # chicken -> egg
	ProductionRules.apply_collect(a, inv, catalog)
	assert_eq(inv.get_qty("egg"), 1)

func test_apply_collect_returns_the_collected_product_id() -> void:
	var catalog: GameCatalog = StateFactory.fixture_catalog()
	var inv := InventoryState.new()
	var a := _animal(100.0, 1.0)
	var product_id: String = ProductionRules.apply_collect(a, inv, catalog)
	assert_eq(product_id, "egg")

func test_apply_collect_resets_progress_to_zero() -> void:
	var catalog: GameCatalog = StateFactory.fixture_catalog()
	var inv := InventoryState.new()
	var a := _animal(100.0, 1.0)
	ProductionRules.apply_collect(a, inv, catalog)
	assert_almost_eq(a.progress, 0.0, 0.0001)

func test_apply_collect_raises_happiness_by_gain_on_collect() -> void:
	var catalog: GameCatalog = StateFactory.fixture_catalog()  # gainOnCollect = 15
	var inv := InventoryState.new()
	var a := _animal(100.0, 1.0, 50.0)
	ProductionRules.apply_collect(a, inv, catalog)
	assert_almost_eq(a.happiness, 65.0, 0.0001)

func test_apply_collect_clamps_happiness_at_100() -> void:
	var catalog: GameCatalog = StateFactory.fixture_catalog()
	var inv := InventoryState.new()
	var a := _animal(100.0, 1.0, 95.0)
	ProductionRules.apply_collect(a, inv, catalog)
	assert_almost_eq(a.happiness, 100.0, 0.0001)

func test_apply_collect_accumulates_across_multiple_animals_of_the_same_species() -> void:
	var catalog: GameCatalog = StateFactory.fixture_catalog()
	var inv := InventoryState.new()
	ProductionRules.apply_collect(_animal(100.0, 1.0), inv, catalog)
	ProductionRules.apply_collect(_animal(100.0, 1.0), inv, catalog)
	assert_eq(inv.get_qty("egg"), 2)
