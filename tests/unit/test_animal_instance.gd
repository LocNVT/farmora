extends GutTest

## Verifies AnimalInstance's defaults, dict round-trip, and unknown-key
## preservation (docs/ARCHITECTURE.md Section 8.1/8.3), plus FarmState's
## get_animal lookup.

func test_defaults_on_a_bare_instance() -> void:
	var a := AnimalInstance.new()
	assert_eq(a.id, "")
	assert_eq(a.species, "")
	assert_eq(a.hunger, 0.0)
	assert_eq(a.happiness, 0.0)
	assert_eq(a.health, 100.0)
	assert_eq(a.progress, 0.0)

func test_from_dict_reads_known_fields() -> void:
	var a := AnimalInstance.from_dict({
		"id": "a_1", "species": "chicken", "name": "Pip", "buildingId": "chicken_coop",
		"hunger": 75.0, "happiness": 90.0, "health": 100.0, "progress": 0.5,
	})
	assert_eq(a.id, "a_1")
	assert_eq(a.species, "chicken")
	assert_eq(a.name, "Pip")
	assert_eq(a.building_id, "chicken_coop")
	assert_eq(a.hunger, 75.0)
	assert_eq(a.happiness, 90.0)
	assert_eq(a.progress, 0.5)

func test_from_dict_tolerates_missing_keys_with_defaults() -> void:
	var a := AnimalInstance.from_dict({"id": "a_2", "species": "cow"})
	assert_eq(a.hunger, 0.0)
	assert_eq(a.happiness, 0.0)
	assert_eq(a.health, 100.0)
	assert_eq(a.progress, 0.0)
	assert_eq(a.building_id, "")

func test_unknown_keys_preserved_in_extra() -> void:
	var a := AnimalInstance.from_dict({
		"id": "a_3", "species": "pig", "futureTraitField": "golden", "rarity": 5,
	})
	assert_eq(a.extra.get("futureTraitField"), "golden")
	assert_eq(a.extra.get("rarity"), 5)

func test_to_dict_round_trip_is_lossless() -> void:
	var original := AnimalInstance.from_dict({
		"id": "a_4", "species": "chicken", "name": "Mimi", "buildingId": "chicken_coop",
		"hunger": 42.0, "happiness": 88.0, "health": 100.0, "progress": 0.75,
		"futureField": "kept",
	})
	var round_tripped := AnimalInstance.from_dict(original.to_dict())
	assert_eq(round_tripped.id, original.id)
	assert_eq(round_tripped.species, original.species)
	assert_eq(round_tripped.name, original.name)
	assert_eq(round_tripped.building_id, original.building_id)
	assert_eq(round_tripped.hunger, original.hunger)
	assert_eq(round_tripped.happiness, original.happiness)
	assert_eq(round_tripped.progress, original.progress)
	assert_eq(round_tripped.extra.get("futureField"), "kept")

func test_to_dict_uses_the_buildingId_json_key() -> void:
	var a := AnimalInstance.from_dict({"id": "a_5", "species": "pig", "buildingId": "pig_pen"})
	var d: Dictionary = a.to_dict()
	assert_true(d.has("buildingId"), "to_dict() should use the GDD Section 9 'buildingId' key, not 'building_id'")
	assert_eq(d["buildingId"], "pig_pen")

func test_farm_state_get_animal_finds_a_match() -> void:
	var farm := FarmState.new()
	var a := AnimalInstance.from_dict({"id": "a_6", "species": "chicken"})
	farm.animals = [a]
	assert_eq(farm.get_animal("a_6"), a)

func test_farm_state_get_animal_returns_null_on_miss() -> void:
	var farm := FarmState.new()
	assert_null(farm.get_animal("nonexistent"))

func test_game_state_has_an_empty_farm_by_default() -> void:
	var state := GameState.new()
	assert_not_null(state.farm)
	assert_eq(state.farm.animals.size(), 0)
