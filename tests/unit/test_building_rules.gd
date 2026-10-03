extends GutTest

## Verifies BuildingRules per docs/ARCHITECTURE.md Section 10.2/19's
## test table ("Capacity rules, upgrade calculations: housed count,
## full, next upgrade cost, max level, effects per level") against the
## fixture catalog's building levels (chicken_coop L1 capacity 4,
## L2 8, L3 12, multiplier 1.0/1.25/1.5; feed_storage L1 100, L2 250,
## L3 500; market L1 0%, L2 5%, L3 10%).

var _catalog: GameCatalog

func before_each() -> void:
	_catalog = StateFactory.fixture_catalog()

func _farm_with(animals: Array[AnimalInstance], building_levels: Dictionary = {}) -> FarmState:
	var farm := FarmState.new()
	farm.animals = animals
	for id: String in ["chicken_coop", "cow_barn", "pig_pen", "feed_storage", "market"]:
		farm.buildings.append(StateFactory.building(id, int(building_levels.get(id, 1))))
	return farm

func test_housed_count_counts_only_matching_building_id() -> void:
	var farm := _farm_with([
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a2"}),
		StateFactory.animal("pig", "pig_pen", {"id": "a3"}),
	])
	assert_eq(BuildingRules.housed_count(farm, "chicken_coop"), 2)
	assert_eq(BuildingRules.housed_count(farm, "pig_pen"), 1)
	assert_eq(BuildingRules.housed_count(farm, "cow_barn"), 0)

func test_capacity_reads_the_instances_own_level() -> void:
	var farm := _farm_with([])
	assert_eq(BuildingRules.capacity(farm, "chicken_coop", _catalog), 4)

func test_capacity_increases_after_an_upgrade() -> void:
	var farm := _farm_with([], {"chicken_coop": 2})
	assert_eq(BuildingRules.capacity(farm, "chicken_coop", _catalog), 8)

func test_is_full_false_when_under_capacity() -> void:
	var farm := _farm_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1"})])
	assert_false(BuildingRules.is_full(farm, "chicken_coop", _catalog))

func test_is_full_true_at_exactly_capacity() -> void:
	var farm := _farm_with([
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a2"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a3"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a4"}),
	])
	assert_true(BuildingRules.is_full(farm, "chicken_coop", _catalog))

func test_is_full_is_never_exceeded_by_capacity_at_a_higher_level() -> void:
	var farm := _farm_with([
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a2"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a3"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a4"}),
	], {"chicken_coop": 2})
	assert_false(BuildingRules.is_full(farm, "chicken_coop", _catalog), "4 animals should not be full at L2's capacity of 8")

func test_production_multiplier_at_level_1_is_1() -> void:
	var farm := _farm_with([])
	assert_almost_eq(BuildingRules.production_multiplier(farm, "chicken_coop", _catalog), 1.0, 0.01)

func test_production_multiplier_increases_per_level() -> void:
	var farm_l2 := _farm_with([], {"chicken_coop": 2})
	var farm_l3 := _farm_with([], {"chicken_coop": 3})
	assert_almost_eq(BuildingRules.production_multiplier(farm_l2, "chicken_coop", _catalog), 1.25, 0.01)
	assert_almost_eq(BuildingRules.production_multiplier(farm_l3, "chicken_coop", _catalog), 1.5, 0.01)

func test_feed_capacity_reads_the_feed_storage_buildings_own_level() -> void:
	var farm := _farm_with([])
	assert_eq(BuildingRules.feed_capacity(farm, _catalog), 100)

func test_feed_capacity_increases_after_an_upgrade() -> void:
	var farm := _farm_with([], {"feed_storage": 3})
	assert_eq(BuildingRules.feed_capacity(farm, _catalog), 500)

func test_sell_bonus_percent_is_zero_at_level_1() -> void:
	var farm := _farm_with([])
	assert_almost_eq(BuildingRules.sell_bonus_percent(farm, _catalog), 0.0, 0.01)

func test_sell_bonus_percent_increases_after_an_upgrade() -> void:
	var farm := _farm_with([], {"market": 2})
	assert_almost_eq(BuildingRules.sell_bonus_percent(farm, _catalog), 5.0, 0.01)

func test_is_max_level_false_below_max() -> void:
	var b := StateFactory.building("chicken_coop", 2)
	assert_false(BuildingRules.is_max_level(b, _catalog))

func test_is_max_level_true_at_max() -> void:
	var b := StateFactory.building("chicken_coop", 3)
	assert_true(BuildingRules.is_max_level(b, _catalog))

func test_next_upgrade_returns_the_next_levels_definition() -> void:
	var b := StateFactory.building("chicken_coop", 1)
	var upgrade: UpgradeDefinition = BuildingRules.next_upgrade(b, _catalog)
	assert_not_null(upgrade)
	assert_eq(upgrade.level, 2)
	assert_eq(upgrade.cost, 500)

func test_next_upgrade_is_null_at_max_level() -> void:
	var b := StateFactory.building("chicken_coop", 3)
	assert_null(BuildingRules.next_upgrade(b, _catalog))

func test_check_upgrade_ok_when_affordable() -> void:
	var state := StateFactory.game_state_with([], 0, 0, 500, 1)
	var result: ActionResult = BuildingRules.check_upgrade(state, "chicken_coop", _catalog)
	assert_true(result.ok())

func test_check_upgrade_refuses_unknown_building() -> void:
	var state := StateFactory.game_state_with([], 0, 0, 10000, 1)
	var result: ActionResult = BuildingRules.check_upgrade(state, "silo", _catalog)
	assert_eq(result.code, ActionResult.Code.UNKNOWN_ID)

func test_check_upgrade_refuses_max_level() -> void:
	var state := StateFactory.game_state_with([], 0, 0, 10000, 1, {"chicken_coop": 3})
	var result: ActionResult = BuildingRules.check_upgrade(state, "chicken_coop", _catalog)
	assert_eq(result.code, ActionResult.Code.MAX_LEVEL)

func test_check_upgrade_refuses_not_enough_coins_with_the_shortfall() -> void:
	var state := StateFactory.game_state_with([], 0, 0, 100, 1)
	var result: ActionResult = BuildingRules.check_upgrade(state, "chicken_coop", _catalog)
	assert_eq(result.code, ActionResult.Code.NOT_ENOUGH_COINS)
	assert_eq(result.missing, 400)  # L2 costs 500

func test_check_upgrade_prioritizes_max_level_over_not_enough_coins() -> void:
	var state := StateFactory.game_state_with([], 0, 0, 0, 1, {"chicken_coop": 3})
	var result: ActionResult = BuildingRules.check_upgrade(state, "chicken_coop", _catalog)
	assert_eq(result.code, ActionResult.Code.MAX_LEVEL)
