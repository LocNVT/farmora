class_name BuildingInstance
extends RefCounted

## Runtime building state per docs/ARCHITECTURE.md Section 8.1/10.1:
## "BuildingInstance { id: String, level: int, extra }". Refers to its
## definition by string id only (`id` doubles as the BuildingDefinition
## id in the MVP -- ARCHITECTURE.md Section 8.1: "Building ids are the
## definition ids in the MVP"), never by object reference (CLAUDE.md
## Section 7).
##
## `extra` holds unknown JSON keys, preserved and written back unchanged
## (GDD Section 9/10). `to_dict`/`from_dict` are the save-shaped
## encoding, per ARCHITECTURE.md Section 8.1's save table: one entry in
## the save's `buildings` array per instance.

var id: String = ""
var level: int = 1
var extra: Dictionary = {}

func to_dict() -> Dictionary:
	var result: Dictionary = {
		"id": id,
		"level": level,
	}
	for key: String in extra.keys():
		if not result.has(key):
			result[key] = extra[key]
	return result

## Tolerant: missing keys get defaults; unknown keys go into `extra`
## (docs/ARCHITECTURE.md Section 8.3). Validation (types, ranges) is not
## this method's job -- that belongs to SaveCodec.
static func from_dict(data: Dictionary) -> BuildingInstance:
	var instance := BuildingInstance.new()
	var known_keys: PackedStringArray = ["id", "level"]

	instance.id = String(data.get("id", ""))
	instance.level = int(data.get("level", 1))

	var extra: Dictionary = {}
	for key: String in data.keys():
		if not known_keys.has(key):
			extra[key] = data[key]
	instance.extra = extra

	return instance
