class_name StateFactory
extends RefCounted

## Builds GameStates and catalogs for tests, per docs/ARCHITECTURE.md
## Section 19 ("tests/helpers/state_factory.gd: builds GameStates for
## tests"). Never used by production code -- only by test files.

static func fixture_catalog() -> GameCatalog:
	return GameCatalog.load_from_file("res://tests/fixtures/balance_fixture.json")

## Builds one AnimalInstance with sensible defaults, overridable via
## `overrides` (any AnimalInstance field name -> value).
static func animal(species: String, building_id: String, overrides: Dictionary = {}) -> AnimalInstance:
	var data: Dictionary = {
		"id": overrides.get("id", "test_%s_%s" % [species, building_id]),
		"species": species,
		"name": overrides.get("name", species.capitalize()),
		"buildingId": building_id,
		"hunger": overrides.get("hunger", 100.0),
		"happiness": overrides.get("happiness", 100.0),
		"health": overrides.get("health", 100.0),
		"progress": overrides.get("progress", 0.0),
	}
	return AnimalInstance.from_dict(data)

## Builds one BuildingInstance, defaulting to level 1.
static func building(building_id: String, level: int = 1) -> BuildingInstance:
	var instance := BuildingInstance.new()
	instance.id = building_id
	instance.level = level
	return instance

## Default buildings for game_state_with(): all 5 MVP buildings at
## level 1 (matching Game.new_game_state()'s real starting-buildings
## behavior), overridable per-building via `levels` (building id ->
## level). Most tests don't care about building state at all; this
## keeps their existing calls working unchanged while still giving
## BuildingRules a real building to read instead of defaulting to the
## "missing instance" fallback.
static func _default_buildings(levels: Dictionary = {}) -> Array[BuildingInstance]:
	var ids: PackedStringArray = ["chicken_coop", "cow_barn", "pig_pen", "feed_storage", "market"]
	var result: Array[BuildingInstance] = []
	for id: String in ids:
		result.append(building(id, int(levels.get(id, 1))))
	return result

static func game_state_with(animals: Array[AnimalInstance], feed: int = 0, last_seen_ms: int = 0, coins: int = 0, level: int = 1, building_levels: Dictionary = {}) -> GameState:
	var state := GameState.new()
	state.farm.animals = animals
	state.farm.buildings = _default_buildings(building_levels)
	state.player.feed = feed
	state.last_seen_ms = last_seen_ms
	state.player.coins = coins
	state.player.level = level
	return state
