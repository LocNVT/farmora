class_name AnimalInstance
extends RefCounted

## Runtime animal state per docs/ARCHITECTURE.md Section 8.1/9.1 (GDD
## Section 9 save sketch, GDD Section 4 state table). Refers to its
## definition by string id only (`species`), never by object reference
## (CLAUDE.md Section 7).
##
## Floats are used for hunger/happiness/health/progress so time-based
## decay (a later phase) is exact between saves; the UI rounds for
## display.

var id: String = ""
var species: String = ""            # e.g. "chicken" -- looked up in GameCatalog, never stored as a reference
var name: String = ""
var building_id: String = ""        # the BuildingInstance this animal is housed in
var hunger: float = 0.0             # 0-100, 100 = fully fed
var happiness: float = 0.0          # 0-100
var health: float = 100.0           # 0-100; constant 100 in the MVP (GDD Section 4)
var progress: float = 0.0           # 0.0-1.0; production progress toward the next product
var extra: Dictionary = {}          # unknown JSON keys, preserved and written back unchanged (GDD Section 9/10)

func to_dict() -> Dictionary:
	var result: Dictionary = {
		"id": id,
		"species": species,
		"name": name,
		"buildingId": building_id,
		"hunger": hunger,
		"happiness": happiness,
		"health": health,
		"progress": progress,
	}
	for key: String in extra.keys():
		if not result.has(key):
			result[key] = extra[key]
	return result

## Tolerant: missing keys get defaults; unknown keys go into `extra`
## (docs/ARCHITECTURE.md Section 8.3). Validation (types, ranges) is not
## this method's job -- that belongs to SaveCodec, a later phase.
static func from_dict(data: Dictionary) -> AnimalInstance:
	var instance := AnimalInstance.new()
	var known_keys: PackedStringArray = ["id", "species", "name", "buildingId", "hunger", "happiness", "health", "progress"]

	instance.id = String(data.get("id", ""))
	instance.species = String(data.get("species", ""))
	instance.name = String(data.get("name", ""))
	instance.building_id = String(data.get("buildingId", ""))
	instance.hunger = float(data.get("hunger", 0.0))
	instance.happiness = float(data.get("happiness", 0.0))
	instance.health = float(data.get("health", 100.0))
	instance.progress = float(data.get("progress", 0.0))

	var extra: Dictionary = {}
	for key: String in data.keys():
		if not known_keys.has(key):
			extra[key] = data[key]
	instance.extra = extra

	return instance
