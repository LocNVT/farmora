extends GutTest

## Verifies GameCatalog parsing of the frozen test fixture
## (tests/fixtures/balance_fixture.json, a copy of the real
## data/balance.json). Uses the fixture, not the live file, so tuning
## balance.json never breaks these tests (docs/ARCHITECTURE.md Section
## 7.4) -- test_balance_data.gd separately checks the live file.

var _catalog: GameCatalog

func before_each() -> void:
	_catalog = GameCatalog.load_from_file("res://tests/fixtures/balance_fixture.json")

func test_catalog_loads_from_fixture() -> void:
	assert_not_null(_catalog, "GameCatalog should load the fixture file")

func test_all_three_mvp_animals_parsed() -> void:
	var ids: Array[String] = _catalog.animal_ids()
	assert_true(ids.has("chicken"))
	assert_true(ids.has("pig"))
	assert_true(ids.has("cow"))
	assert_eq(ids.size(), 3)

func test_all_three_mvp_products_parsed() -> void:
	var ids: Array[String] = _catalog.product_ids()
	assert_true(ids.has("egg"))
	assert_true(ids.has("milk"))
	assert_true(ids.has("pork"))
	assert_eq(ids.size(), 3)

func test_chicken_definition_fields_match_gdd() -> void:
	var chicken: AnimalDefinition = _catalog.animal("chicken")
	assert_not_null(chicken)
	assert_eq(chicken.id, "chicken")
	assert_eq(chicken.product_id, "egg")
	assert_eq(chicken.price, 100)
	assert_eq(chicken.unlock_level, 1)
	assert_eq(chicken.housing_building_id, "chicken_coop")
	assert_eq(chicken.default_names, ["Mimi", "Pip"])

func test_cycle_minutes_converted_to_seconds() -> void:
	# GDD Section 4: Chicken 3 min, Pig 10 min, Cow 6 min cycle.
	assert_almost_eq(_catalog.animal("chicken").cycle_seconds, 180.0, 0.01)
	assert_almost_eq(_catalog.animal("pig").cycle_seconds, 600.0, 0.01)
	assert_almost_eq(_catalog.animal("cow").cycle_seconds, 360.0, 0.01)

func test_pig_and_cow_have_empty_default_names() -> void:
	assert_eq(_catalog.animal("pig").default_names.size(), 0)
	assert_eq(_catalog.animal("cow").default_names.size(), 0)

func test_product_sell_prices_match_gdd() -> void:
	# GDD Section 5: Egg 5, Milk 12, Pork 30.
	assert_eq(_catalog.product("egg").sell_price, 5)
	assert_eq(_catalog.product("milk").sell_price, 12)
	assert_eq(_catalog.product("pork").sell_price, 30)

func test_unknown_animal_id_returns_null() -> void:
	assert_null(_catalog.animal("dragon"))

func test_unknown_product_id_returns_null() -> void:
	assert_null(_catalog.product("gem"))

func test_status_thresholds_match_fixture() -> void:
	assert_almost_eq(_catalog.status.hungry_below, 30.0, 0.01)
	assert_almost_eq(_catalog.status.low_happiness_below, 30.0, 0.01)
	assert_almost_eq(_catalog.status.low_bar_below_percent, 30.0, 0.01)

func test_feeding_params_match_fixture() -> void:
	assert_eq(_catalog.feeding.feed_per_meal, 1)
	assert_almost_eq(_catalog.feeding.hunger_per_meal, 50.0, 0.01)
	assert_almost_eq(_catalog.feeding.hunger_decay_per_minute, 1.0, 0.01)
	assert_eq(_catalog.feeding.debounce_ms, 300)
	assert_true(_catalog.feeding.block_when_full)

func test_happiness_params_match_fixture() -> void:
	# Fixture deliberately sets non-zero gainOnFeed/gainOnCollect/
	# decayPerMinute so feeding-rules and production-rules tests
	# exercise the gain/decay/clamp paths; the live balance.json keeps
	# these at the GDD's placeholder-inert 0.
	assert_almost_eq(_catalog.happiness.gain_on_feed, 10.0, 0.01)
	assert_almost_eq(_catalog.happiness.gain_on_collect, 15.0, 0.01)
	assert_almost_eq(_catalog.happiness.decay_per_minute, 2.0, 0.01)

func test_start_params_match_fixture() -> void:
	assert_eq(_catalog.start.coins, 150)
	assert_eq(_catalog.start.feed, 5)
	assert_eq(_catalog.start.xp, 0)
	assert_eq(_catalog.start.level, 1)

func test_production_params_match_fixture() -> void:
	assert_true(_catalog.production.pause_when_ready)

func test_economy_params_match_fixture() -> void:
	assert_eq(_catalog.economy.purchase_lock_ms, 300)
	assert_eq(_catalog.economy.feed_pack_feed, 10)
	assert_eq(_catalog.economy.feed_pack_price, 25)
	assert_true(_catalog.economy.refuse_overflowing_feed_pack)

func test_all_five_mvp_buildings_parsed() -> void:
	var ids: Array[String] = _catalog.building_ids()
	assert_true(ids.has("chicken_coop"))
	assert_true(ids.has("cow_barn"))
	assert_true(ids.has("pig_pen"))
	assert_true(ids.has("feed_storage"))
	assert_true(ids.has("market"))
	assert_eq(ids.size(), 5)

func test_chicken_coop_definition_fields_match_gdd() -> void:
	var coop: BuildingDefinition = _catalog.building("chicken_coop")
	assert_not_null(coop)
	assert_eq(coop.id, "chicken_coop")
	assert_eq(coop.kind, BuildingDefinition.Kind.HOUSING)
	assert_true(coop.starts_built)
	assert_eq(coop.max_level(), 3)

func test_chicken_coop_levels_match_gdd() -> void:
	var coop: BuildingDefinition = _catalog.building("chicken_coop")
	assert_eq(coop.level_def(1).capacity, 4)
	assert_eq(coop.level_def(2).capacity, 8)
	assert_eq(coop.level_def(3).capacity, 12)
	assert_almost_eq(coop.level_def(1).production_multiplier, 1.0, 0.01)
	assert_almost_eq(coop.level_def(2).production_multiplier, 1.25, 0.01)
	assert_almost_eq(coop.level_def(3).production_multiplier, 1.5, 0.01)
	assert_eq(coop.level_def(1).cost, 0)
	assert_eq(coop.level_def(2).cost, 500)
	assert_eq(coop.level_def(3).cost, 1500)

func test_feed_storage_levels_match_gdd() -> void:
	var storage: BuildingDefinition = _catalog.building("feed_storage")
	assert_eq(storage.kind, BuildingDefinition.Kind.FEED_STORAGE)
	assert_eq(storage.level_def(1).feed_capacity, 100)
	assert_eq(storage.level_def(2).feed_capacity, 250)
	assert_eq(storage.level_def(3).feed_capacity, 500)

func test_market_levels_match_gdd() -> void:
	var market: BuildingDefinition = _catalog.building("market")
	assert_eq(market.kind, BuildingDefinition.Kind.MARKET)
	assert_almost_eq(market.level_def(1).sell_bonus_percent, 0.0, 0.01)
	assert_almost_eq(market.level_def(2).sell_bonus_percent, 5.0, 0.01)
	assert_almost_eq(market.level_def(3).sell_bonus_percent, 10.0, 0.01)

func test_building_of_kind_finds_the_feed_storage() -> void:
	var def: BuildingDefinition = _catalog.building_of_kind(BuildingDefinition.Kind.FEED_STORAGE)
	assert_not_null(def)
	assert_eq(def.id, "feed_storage")

func test_building_of_kind_finds_the_market() -> void:
	var def: BuildingDefinition = _catalog.building_of_kind(BuildingDefinition.Kind.MARKET)
	assert_not_null(def)
	assert_eq(def.id, "market")

func test_unknown_building_id_returns_null() -> void:
	assert_null(_catalog.building("silo"))

func test_new_animal_params_match_fixture() -> void:
	assert_almost_eq(_catalog.new_animal.hunger, 0.0, 0.01)
	assert_almost_eq(_catalog.new_animal.happiness, 100.0, 0.01)
	assert_almost_eq(_catalog.new_animal.health, 100.0, 0.01)

func test_offline_params_match_fixture() -> void:
	assert_almost_eq(_catalog.offline.cap_hours, 8.0, 0.01)
	assert_almost_eq(_catalog.offline.reward_modal_min_minutes, 5.0, 0.01)
	assert_eq(_catalog.offline.cap_ms(), 8 * 3600000)
	assert_eq(_catalog.offline.reward_modal_min_ms(), 5 * 60000)

func test_offline_params_default_when_the_group_is_missing() -> void:
	var catalog := GameCatalog.from_dict({"schema": 1})
	assert_almost_eq(catalog.offline.cap_hours, 8.0, 0.01)
	assert_almost_eq(catalog.offline.reward_modal_min_minutes, 5.0, 0.01)

func test_validate_reports_no_problems_on_the_fixture() -> void:
	var problems: PackedStringArray = _catalog.validate()
	assert_eq(problems.size(), 0, "Fixture should validate cleanly: " + str(problems))

func test_validate_catches_unknown_product_reference() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1,
		"products": {"egg": {"sellPrice": 5}},
		"animals": {"chicken": {"product": "nonexistent_product", "price": 100, "unlockLevel": 1, "housing": "chicken_coop", "cycleMinutes": 3}},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a dangling product reference")

func test_validate_catches_non_positive_cycle_seconds() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1,
		"products": {"egg": {"sellPrice": 5}},
		"animals": {"chicken": {"product": "egg", "price": 100, "unlockLevel": 1, "housing": "chicken_coop", "cycleMinutes": 0}},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a zero/negative cycle time")

func test_validate_catches_wrong_schema() -> void:
	var bad := GameCatalog.from_dict({"schema": 99, "products": {}, "animals": {}})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a schema mismatch")

func test_unknown_top_level_keys_are_ignored_not_errors() -> void:
	var catalog := GameCatalog.from_dict({
		"schema": 1,
		"products": {"egg": {"sellPrice": 5}},
		"animals": {},
		"buildings": {
			"feed_storage": {"kind": "feed_storage", "levels": [{"cost": 0}]},
			"market": {"kind": "market", "levels": [{"cost": 0}]},
		},
		"someFuturePhaseBlock": {"whatever": true},
	})
	assert_eq(catalog.validate().size(), 0, "Unparsed/unknown balance.json groups should not cause validation problems")

func test_validate_catches_zero_feed_per_meal() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"feeding": {"feedPerMeal": 0},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch feedPerMeal below 1")

func test_validate_catches_zero_hunger_per_meal() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"feeding": {"hungerPerMeal": 0},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch hungerPerMeal of 0")

func test_validate_catches_hunger_per_meal_above_100() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"feeding": {"hungerPerMeal": 150},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch hungerPerMeal above 100")

func test_validate_catches_negative_debounce_ms() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"feeding": {"debounceMs": -1},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a negative debounceMs")

func test_validate_catches_negative_hunger_decay() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"feeding": {"hungerDecayPerMinute": -1},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a negative hungerDecayPerMinute")

func test_validate_catches_negative_happiness_values() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"happiness": {"gainOnFeed": -1},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a negative happiness value")

func test_validate_catches_negative_start_feed() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"start": {"feed": -1},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a negative start.feed")

func test_validate_catches_negative_start_coins() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"start": {"coins": -1},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a negative start.coins")

func test_validate_catches_start_level_below_1() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"start": {"level": 0},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch start.level below 1")

func test_validate_catches_negative_purchase_lock_ms() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"economy": {"purchaseLockMs": -1},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a negative purchaseLockMs")

func test_validate_catches_zero_feed_pack_feed() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"economy": {"feedPack": {"feed": 0}},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch feedPack.feed below 1")

func test_validate_catches_negative_feed_pack_price() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"economy": {"feedPack": {"price": -1}},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a negative feedPack.price")

func test_validate_catches_new_animal_value_outside_0_100() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"newAnimal": {"happiness": 150},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a newAnimal value outside 0..100")

func test_validate_catches_non_positive_offline_cap_hours() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"offline": {"capHours": 0},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a non-positive offline.capHours")

func test_validate_catches_negative_offline_reward_modal_min_minutes() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1, "products": {}, "animals": {},
		"offline": {"rewardModalMinMinutes": -1},
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a negative offline.rewardModalMinMinutes")

## A minimal valid buildings block (one HOUSING, one FEED_STORAGE, one
## MARKET), shared by the building-validation tests below so each test
## only needs to break the ONE rule it is checking.
static func _valid_buildings() -> Dictionary:
	return {
		"coop": {"kind": "housing", "levels": [{"cost": 0, "capacity": 4, "productionMultiplier": 1.0}]},
		"feed_storage": {"kind": "feed_storage", "levels": [{"cost": 0, "feedCapacity": 100}]},
		"market": {"kind": "market", "levels": [{"cost": 0, "sellBonusPercent": 0}]},
	}

func test_validate_catches_animal_referencing_unknown_housing_building() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1,
		"products": {"egg": {"sellPrice": 5}},
		"animals": {"chicken": {"product": "egg", "price": 100, "unlockLevel": 1, "housing": "nonexistent_coop", "cycleMinutes": 3}},
		"buildings": _valid_buildings(),
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch an animal housed in an unknown building")

func test_validate_catches_animal_housed_in_a_non_housing_building() -> void:
	var bad := GameCatalog.from_dict({
		"schema": 1,
		"products": {"egg": {"sellPrice": 5}},
		"animals": {"chicken": {"product": "egg", "price": 100, "unlockLevel": 1, "housing": "market", "cycleMinutes": 3}},
		"buildings": _valid_buildings(),
	})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch an animal housed in a non-HOUSING building")

func test_validate_catches_a_building_with_no_levels() -> void:
	var buildings: Dictionary = _valid_buildings()
	buildings["coop"] = {"kind": "housing", "levels": []}
	var bad := GameCatalog.from_dict({"schema": 1, "products": {}, "animals": {}, "buildings": buildings})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a building with zero levels")

func test_validate_catches_a_negative_level_cost() -> void:
	var buildings: Dictionary = _valid_buildings()
	buildings["coop"]["levels"][0]["cost"] = -1
	var bad := GameCatalog.from_dict({"schema": 1, "products": {}, "animals": {}, "buildings": buildings})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a negative level cost")

func test_validate_catches_a_non_positive_production_multiplier_on_a_housing_building() -> void:
	var buildings: Dictionary = _valid_buildings()
	buildings["coop"]["levels"][0]["productionMultiplier"] = 0.0
	var bad := GameCatalog.from_dict({"schema": 1, "products": {}, "animals": {}, "buildings": buildings})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch a non-positive production_multiplier on a HOUSING building")

func test_validate_catches_an_unrecognized_building_kind() -> void:
	var buildings: Dictionary = _valid_buildings()
	buildings["coop"]["kind"] = "silo"
	var bad := GameCatalog.from_dict({"schema": 1, "products": {}, "animals": {}, "buildings": buildings})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch an unrecognized building kind")

func test_validate_catches_zero_feed_storage_buildings() -> void:
	var buildings: Dictionary = _valid_buildings()
	buildings.erase("feed_storage")
	var bad := GameCatalog.from_dict({"schema": 1, "products": {}, "animals": {}, "buildings": buildings})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch zero FEED_STORAGE buildings")

func test_validate_catches_zero_market_buildings() -> void:
	var buildings: Dictionary = _valid_buildings()
	buildings.erase("market")
	var bad := GameCatalog.from_dict({"schema": 1, "products": {}, "animals": {}, "buildings": buildings})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch zero MARKET buildings")

func test_validate_catches_two_market_buildings() -> void:
	var buildings: Dictionary = _valid_buildings()
	buildings["market2"] = {"kind": "market", "levels": [{"cost": 0, "sellBonusPercent": 0}]}
	var bad := GameCatalog.from_dict({"schema": 1, "products": {}, "animals": {}, "buildings": buildings})
	var problems: PackedStringArray = bad.validate()
	assert_true(problems.size() > 0, "validate() should catch two MARKET buildings")

func test_validate_reports_no_problems_with_a_valid_minimal_buildings_block() -> void:
	var catalog := GameCatalog.from_dict({"schema": 1, "products": {}, "animals": {}, "buildings": _valid_buildings()})
	assert_eq(catalog.validate().size(), 0, "A valid minimal buildings block should not raise any problems")
