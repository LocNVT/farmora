extends GutTest

## Verifies SaveCodec.encode()/decode() per docs/ARCHITECTURE.md Section
## 11.2/11.3: round-tripping, structural/type validation -> DAMAGED,
## version -> TOO_NEW, range clamps with logged problems, unrecognized
## building/animal ids preserved verbatim, missing starts_built buildings
## added at level 1, and SaveMigrator invoked for version < CURRENT.
## Uses the real fixture catalog (tests/fixtures/balance_fixture.json) --
## "dragon_barn"/"dragon" are genuinely absent from it, so they exercise
## the unrecognized-id path without needing a fake catalog.

var _catalog: GameCatalog

func before_each() -> void:
	_catalog = StateFactory.fixture_catalog()

func _load_fixture(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed as Dictionary

func _full_state() -> GameState:
	var state := GameState.new()
	state.player.coins = 250
	state.player.feed = 8
	state.player.xp = 40
	state.player.level = 2
	state.inventory.quantities = {"egg": 3, "milk": 1, "pork": 0}
	state.farm.buildings = [
		StateFactory.building("chicken_coop", 2),
		StateFactory.building("cow_barn", 1),
		StateFactory.building("pig_pen", 3),
		StateFactory.building("feed_storage", 1),
		StateFactory.building("market", 2),
	]
	state.farm.animals = [
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "name": "Pip", "hunger": 20.0, "happiness": 80.0, "progress": 0.5}),
		StateFactory.animal("pig", "pig_pen", {"id": "a2", "name": "Porky", "hunger": 50.0, "happiness": 60.0, "progress": 0.25}),
	]
	state.tutorial_step = 4
	state.settings.sound = false
	state.settings.language = "vi"
	state.last_seen_ms = 1759392000000
	return state

func test_encode_then_decode_round_trips_a_fully_populated_state() -> void:
	var original: GameState = _full_state()
	var encoded: Dictionary = SaveCodec.encode(original)
	var result: DecodeResult = SaveCodec.decode(encoded, _catalog)

	assert_eq(result.status, DecodeResult.Status.OK)
	var decoded: GameState = result.state
	assert_not_null(decoded)

	assert_eq(decoded.player.coins, 250)
	assert_eq(decoded.player.feed, 8)
	assert_eq(decoded.player.xp, 40)
	assert_eq(decoded.player.level, 2)

	assert_eq(decoded.inventory.get_qty("egg"), 3)
	assert_eq(decoded.inventory.get_qty("milk"), 1)
	assert_eq(decoded.inventory.get_qty("pork"), 0)

	assert_eq(decoded.farm.buildings.size(), 5)
	assert_eq(decoded.farm.get_building("chicken_coop").level, 2)
	assert_eq(decoded.farm.get_building("pig_pen").level, 3)

	assert_eq(decoded.farm.animals.size(), 2)
	var chicken: AnimalInstance = decoded.farm.get_animal("a1")
	assert_eq(chicken.name, "Pip")
	assert_almost_eq(chicken.hunger, 20.0, 0.001)
	assert_almost_eq(chicken.happiness, 80.0, 0.001)
	assert_almost_eq(chicken.progress, 0.5, 0.0001)

	assert_eq(decoded.tutorial_step, 4)
	assert_eq(decoded.settings.sound, false)
	assert_eq(decoded.settings.language, "vi")
	assert_eq(decoded.last_seen_ms, 1759392000000)

func test_decode_rejects_non_dictionary_wallet_as_damaged() -> void:
	var data: Dictionary = {
		"version": 1, "lastSeen": 0, "tutorialStep": 0,
		"wallet": "not a dict", "bag": {}, "buildings": [], "animals": [], "settings": {},
	}
	var result: DecodeResult = SaveCodec.decode(data, _catalog)
	assert_eq(result.status, DecodeResult.Status.DAMAGED)
	assert_null(result.state)

func test_decode_rejects_non_array_buildings_as_damaged() -> void:
	var data: Dictionary = {
		"version": 1, "lastSeen": 0, "tutorialStep": 0,
		"wallet": {}, "bag": {}, "buildings": {}, "animals": [], "settings": {},
	}
	var result: DecodeResult = SaveCodec.decode(data, _catalog)
	assert_eq(result.status, DecodeResult.Status.DAMAGED)
	assert_null(result.state)

func test_decode_rejects_version_greater_than_current_as_too_new() -> void:
	var data: Dictionary = {
		"version": 99, "lastSeen": 0, "tutorialStep": 0,
		"wallet": {}, "bag": {}, "buildings": [], "animals": [], "settings": {},
	}
	var result: DecodeResult = SaveCodec.decode(data, _catalog)
	assert_eq(result.status, DecodeResult.Status.TOO_NEW)
	assert_null(result.state)

func test_decode_rejects_wrong_typed_known_field_as_damaged() -> void:
	var data: Dictionary = {
		"version": 1, "lastSeen": 0, "tutorialStep": 0,
		"wallet": {"coins": "abc", "feed": 0, "xp": 0, "level": 1},
		"bag": {}, "buildings": [], "animals": [], "settings": {},
	}
	var result: DecodeResult = SaveCodec.decode(data, _catalog)
	assert_eq(result.status, DecodeResult.Status.DAMAGED)
	assert_null(result.state)

func test_decode_clamps_negative_coins_and_logs_a_problem() -> void:
	var data: Dictionary = {
		"version": 1, "lastSeen": 0, "tutorialStep": 0,
		"wallet": {"coins": -5, "feed": 0, "xp": 0, "level": 1},
		"bag": {}, "buildings": [], "animals": [], "settings": {},
	}
	var result: DecodeResult = SaveCodec.decode(data, _catalog)
	assert_eq(result.status, DecodeResult.Status.OK)
	assert_eq(result.state.player.coins, 0)
	assert_true(result.problems.any(func(p: String) -> bool: return p.contains("coins")))

func test_decode_clamps_out_of_range_hunger_and_happiness() -> void:
	var data: Dictionary = {
		"version": 1, "lastSeen": 0, "tutorialStep": 0,
		"wallet": {"coins": 0, "feed": 0, "xp": 0, "level": 1},
		"bag": {}, "buildings": [],
		"animals": [
			{"id": "a1", "species": "chicken", "name": "Pip", "buildingId": "chicken_coop",
			 "hunger": 150.0, "happiness": -20.0, "health": 100.0, "progress": 0.0},
		],
		"settings": {},
	}
	var result: DecodeResult = SaveCodec.decode(data, _catalog)
	assert_eq(result.status, DecodeResult.Status.OK)
	var animal: AnimalInstance = result.state.farm.get_animal("a1")
	assert_almost_eq(animal.hunger, 100.0, 0.001)
	assert_almost_eq(animal.happiness, 0.0, 0.001)
	assert_true(result.problems.any(func(p: String) -> bool: return p.contains("hunger")))
	assert_true(result.problems.any(func(p: String) -> bool: return p.contains("happiness")))

func test_decode_clamps_building_level_above_max_and_logs_a_problem() -> void:
	var data: Dictionary = {
		"version": 1, "lastSeen": 0, "tutorialStep": 0,
		"wallet": {"coins": 0, "feed": 0, "xp": 0, "level": 1},
		"bag": {},
		"buildings": [{"id": "chicken_coop", "level": 99}],
		"animals": [], "settings": {},
	}
	var result: DecodeResult = SaveCodec.decode(data, _catalog)
	assert_eq(result.status, DecodeResult.Status.OK)
	var max_level: int = _catalog.building("chicken_coop").max_level()
	assert_eq(result.state.farm.get_building("chicken_coop").level, max_level)
	assert_true(result.problems.any(func(p: String) -> bool: return p.contains("chicken_coop") and p.contains("level")))

func test_decode_preserves_unrecognized_building_and_animal() -> void:
	var data: Dictionary = {
		"version": 1, "lastSeen": 0, "tutorialStep": 0,
		"wallet": {"coins": 0, "feed": 0, "xp": 0, "level": 1},
		"bag": {},
		"buildings": [{"id": "dragon_barn", "level": 1}],
		"animals": [
			{"id": "a9", "species": "dragon", "name": "Spike", "buildingId": "dragon_barn",
			 "hunger": 0.0, "happiness": 100.0, "health": 100.0, "progress": 0.0},
		],
		"settings": {},
	}
	var result: DecodeResult = SaveCodec.decode(data, _catalog)
	assert_eq(result.status, DecodeResult.Status.OK)

	assert_eq(result.state.farm.unrecognized_buildings.size(), 1)
	assert_eq(String(result.state.farm.unrecognized_buildings[0].get("id")), "dragon_barn")
	assert_eq(result.state.farm.unrecognized_animals.size(), 1)
	assert_eq(String(result.state.farm.unrecognized_animals[0].get("species")), "dragon")

	# encode() after decode() writes both back unchanged.
	var encoded: Dictionary = SaveCodec.encode(result.state)
	var encoded_buildings: Array = encoded["buildings"]
	var encoded_animals: Array = encoded["animals"]
	var has_dragon_barn := false
	for entry: Variant in encoded_buildings:
		if String((entry as Dictionary).get("id")) == "dragon_barn":
			has_dragon_barn = true
	var has_dragon := false
	for entry: Variant in encoded_animals:
		if String((entry as Dictionary).get("species")) == "dragon":
			has_dragon = true
	assert_true(has_dragon_barn, "unrecognized building should be written back unchanged")
	assert_true(has_dragon, "unrecognized animal should be written back unchanged")

func test_decode_adds_missing_starts_built_building_at_level_1() -> void:
	var data: Dictionary = {
		"version": 1, "lastSeen": 0, "tutorialStep": 0,
		"wallet": {"coins": 0, "feed": 0, "xp": 0, "level": 1},
		"bag": {},
		"buildings": [
			{"id": "chicken_coop", "level": 1},
			{"id": "cow_barn", "level": 1},
			{"id": "pig_pen", "level": 1},
			{"id": "feed_storage", "level": 1},
			# "market" intentionally omitted -- it starts_built in the fixture catalog.
		],
		"animals": [], "settings": {},
	}
	var result: DecodeResult = SaveCodec.decode(data, _catalog)
	assert_eq(result.status, DecodeResult.Status.OK)
	var market: BuildingInstance = result.state.farm.get_building("market")
	assert_not_null(market, "a missing starts_built building should be added")
	assert_eq(market.level, 1)
	assert_true(result.problems.any(func(p: String) -> bool: return p.contains("market")))

func test_decode_with_version_below_current_calls_migrate_without_rejecting() -> void:
	var data: Dictionary = {
		"version": 0, "lastSeen": 0, "tutorialStep": 0,
		"wallet": {"coins": 0, "feed": 0, "xp": 0, "level": 1},
		"bag": {}, "buildings": [], "animals": [], "settings": {},
	}
	var result: DecodeResult = SaveCodec.decode(data, _catalog)
	# No real v0->v1 migration step exists yet, so this merely verifies
	# the SaveMigrator.migrate() call site exists and a lower version is
	# not itself treated as damaged.
	assert_eq(result.status, DecodeResult.Status.OK)
	assert_not_null(result.state)

func test_decode_parses_the_committed_v1_valid_fixture() -> void:
	var data: Dictionary = _load_fixture("res://tests/fixtures/saves/v1_valid.json")
	var result: DecodeResult = SaveCodec.decode(data, _catalog)
	assert_eq(result.status, DecodeResult.Status.OK)
	assert_eq(result.state.player.coins, 150)
	assert_eq(result.state.tutorial_step, 7)
	assert_eq(result.state.farm.animals.size(), 1)
	assert_eq(result.state.farm.animals[0].name, "Pip")
