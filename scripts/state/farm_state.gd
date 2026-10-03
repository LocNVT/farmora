class_name FarmState
extends RefCounted

## Runtime farm state per docs/ARCHITECTURE.md Section 8.1. Holds
## animal instances and building instances, plus
## `unrecognized_buildings`/`unrecognized_animals`: raw Dictionary
## entries from a loaded save whose id/species was not found in the
## catalog -- kept and written back unchanged, never simulated or
## shown (GDD Section 9/10's "preserve unknown fields" extended to
## whole unrecognized entries, not just unknown keys on a known entry).
## Populated by `SaveCodec.decode()` (which has the catalog to check
## against), not by this class's own `from_dict`-equivalent -- FarmState
## maps to TWO save keys (`buildings`, `animals`), so its encoding lives
## in `to_buildings_array()`/`to_animals_array()` rather than one
## `to_dict()`.

var animals: Array[AnimalInstance] = []
var buildings: Array[BuildingInstance] = []
var unrecognized_buildings: Array[Dictionary] = []
var unrecognized_animals: Array[Dictionary] = []

func get_animal(animal_id: String) -> AnimalInstance:
	for a: AnimalInstance in animals:
		if a.id == animal_id:
			return a
	return null

func get_building(building_id: String) -> BuildingInstance:
	for b: BuildingInstance in buildings:
		if b.id == building_id:
			return b
	return null

## The save's `buildings` array: one encoded entry per known
## BuildingInstance, plus every unrecognized entry preserved unchanged.
func to_buildings_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for b: BuildingInstance in buildings:
		result.append(b.to_dict())
	for entry: Dictionary in unrecognized_buildings:
		result.append(entry)
	return result

## The save's `animals` array: one encoded entry per known
## AnimalInstance, plus every unrecognized entry preserved unchanged.
func to_animals_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for a: AnimalInstance in animals:
		result.append(a.to_dict())
	for entry: Dictionary in unrecognized_animals:
		result.append(entry)
	return result
