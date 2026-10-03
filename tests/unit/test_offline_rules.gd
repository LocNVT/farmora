extends GutTest

## Verifies OfflineRules.elapsed_ms()/exceeds_modal_threshold()/
## should_show_modal() and OfflineReport.build(), per docs/GDD.md
## Section 9 rules 1-2-4 and docs/ARCHITECTURE.md Section 12.1/12.3.

var _catalog: GameCatalog

func before_each() -> void:
	_catalog = StateFactory.fixture_catalog()

# --- elapsed_ms() -----------------------------------------------------

func test_elapsed_ms_returns_the_normal_gap_under_the_cap() -> void:
	var cap: int = _catalog.offline.cap_ms()
	assert_eq(OfflineRules.elapsed_ms(10000, 4000, cap), 6000)

func test_elapsed_ms_caps_at_exactly_the_cap() -> void:
	var cap: int = _catalog.offline.cap_ms()
	assert_eq(OfflineRules.elapsed_ms(cap, 0, cap), cap)

func test_elapsed_ms_caps_a_gap_over_the_cap() -> void:
	var cap: int = _catalog.offline.cap_ms()
	assert_eq(OfflineRules.elapsed_ms(cap * 3, 0, cap), cap)

func test_elapsed_ms_returns_zero_when_the_clock_went_backwards() -> void:
	var cap: int = _catalog.offline.cap_ms()
	assert_eq(OfflineRules.elapsed_ms(1000, 5000, cap), 0)

func test_elapsed_ms_returns_zero_for_equal_timestamps() -> void:
	var cap: int = _catalog.offline.cap_ms()
	assert_eq(OfflineRules.elapsed_ms(5000, 5000, cap), 0)

# --- exceeds_modal_threshold() -----------------------------------------

func test_exceeds_modal_threshold_is_false_at_exactly_the_threshold() -> void:
	var threshold_ms: int = _catalog.offline.reward_modal_min_ms()
	assert_false(OfflineRules.exceeds_modal_threshold(threshold_ms, _catalog), "rule 4 is strictly more than 5 minutes")

func test_exceeds_modal_threshold_is_true_one_ms_over() -> void:
	var threshold_ms: int = _catalog.offline.reward_modal_min_ms()
	assert_true(OfflineRules.exceeds_modal_threshold(threshold_ms + 1, _catalog))

func test_exceeds_modal_threshold_is_false_under_the_threshold() -> void:
	assert_false(OfflineRules.exceeds_modal_threshold(1000, _catalog))

# --- should_show_modal() -----------------------------------------------

func test_should_show_modal_is_false_when_nothing_was_produced_even_after_a_long_absence() -> void:
	var report := OfflineReport.new()
	report.elapsed_ms = _catalog.offline.cap_ms()
	report.products = {}
	assert_false(OfflineRules.should_show_modal(report, _catalog))

func test_should_show_modal_is_false_when_production_happened_within_the_threshold() -> void:
	var report := OfflineReport.new()
	report.elapsed_ms = 1000
	report.products = {"egg": 1}
	assert_false(OfflineRules.should_show_modal(report, _catalog))

func test_should_show_modal_is_true_past_the_threshold_with_production() -> void:
	var report := OfflineReport.new()
	report.elapsed_ms = _catalog.offline.reward_modal_min_ms() + 1
	report.products = {"egg": 1}
	assert_true(OfflineRules.should_show_modal(report, _catalog))

# --- OfflineReport.build() ----------------------------------------------

func test_build_aggregates_products_across_multiple_animals_of_the_same_species() -> void:
	var state := StateFactory.game_state_with([
		StateFactory.animal("chicken", "chicken_coop", {"id": "c1"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "c2"}),
		StateFactory.animal("cow", "cow_barn", {"id": "c3"}),
	])
	var completed: Dictionary = {"c1": 1, "c2": 1, "c3": 1}
	var report := OfflineReport.build(completed, state, 3600000, false, _catalog)

	assert_eq(report.products.get("egg"), 2)
	assert_eq(report.products.get("milk"), 1)
	assert_eq(report.ready_animal_ids.size(), 3)
	assert_true(report.ready_animal_ids.has("c1"))
	assert_true(report.ready_animal_ids.has("c3"))

func test_build_excludes_animals_with_zero_completed_products() -> void:
	var state := StateFactory.game_state_with([
		StateFactory.animal("chicken", "chicken_coop", {"id": "c1"}),
	])
	var completed: Dictionary = {"c1": 0}
	var report := OfflineReport.build(completed, state, 1000, false, _catalog)

	assert_eq(report.ready_animal_ids.size(), 0)
	assert_true(report.products.is_empty())

func test_build_carries_elapsed_ms_and_capped_flag_through() -> void:
	var state := StateFactory.game_state_with([])
	var report := OfflineReport.build({}, state, 12345, true, _catalog)
	assert_eq(report.elapsed_ms, 12345)
	assert_true(report.capped)

func test_build_computes_coin_value_including_the_market_bonus() -> void:
	# Market at level 2 in the fixture grants a 5% sell bonus (mirrors
	# test_building_rules.gd's own fixture assumptions; confirmed
	# against data/balance.json/tests/fixtures/balance_fixture.json's
	# own "market" level-2 sellBonusPercent: 5 entry).
	#
	# Codex review (Phase 8): the original version of this test computed
	# its "expected" value by calling EconomyRules.offline_coin_value()
	# itself -- the very function build() internally calls -- so it only
	# proved build() passes its arguments through, never independently
	# verifying the bonus/rounding arithmetic (already covered on its
	# own in test_economy_rules.gd, but not from this call site). Fixed
	# by hand-computing the expected coins here instead: 1 egg at the
	# fixture's 5-coin sellPrice, +5% Market bonus = 5.25, rounds HALF UP
	# to 5 (EconomyRules' documented "round the total once" rule).
	var state := StateFactory.game_state_with(
		[StateFactory.animal("chicken", "chicken_coop", {"id": "c1"})],
		0, 0, 0, 1, {"market": 2}
	)
	var completed: Dictionary = {"c1": 1}
	var report := OfflineReport.build(completed, state, 1000, false, _catalog)

	assert_eq(report.coin_value, 5, "1 egg (5 coins) + 5%% Market bonus = 5.25, rounds to 5")
