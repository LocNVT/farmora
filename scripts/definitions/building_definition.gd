class_name BuildingDefinition
extends RefCounted

## Static, read-only building definition per docs/ARCHITECTURE.md
## Section 7.2. Parsed once by GameCatalog from data/balance.json's
## "buildings" block; never mutated after construction.

enum Kind { HOUSING, FEED_STORAGE, MARKET }

var id: String = ""
var kind: Kind = Kind.HOUSING
var starts_built: bool = true    # GDD Section 6's OPEN default: all five exist at L1 from first launch
var levels: Array[UpgradeDefinition] = []   # index 0 = level 1

## The raw "kind" string as parsed, kept so GameCatalog.validate() can
## report a genuinely unrecognized kind as a problem (the enum fallback
## in _kind_from_string() silently maps anything unknown to HOUSING,
## which would otherwise hide a balance.json typo).
var raw_kind: String = ""

func max_level() -> int:
	return levels.size()

func level_def(level: int) -> UpgradeDefinition:
	return levels[level - 1]

## Returns Kind.HOUSING as a tolerant fallback for an unrecognized kind
## string -- GameCatalog.validate() is what reports this as a real
## problem; this function never crashes on bad data.
static func _kind_from_string(kind_name: String) -> Kind:
	match kind_name:
		"housing":
			return Kind.HOUSING
		"feed_storage":
			return Kind.FEED_STORAGE
		"market":
			return Kind.MARKET
		_:
			return Kind.HOUSING

static func from_dict(building_id: String, data: Dictionary) -> BuildingDefinition:
	var def := BuildingDefinition.new()
	def.id = building_id
	def.raw_kind = String(data.get("kind", "housing"))
	def.kind = _kind_from_string(def.raw_kind)
	def.starts_built = bool(data.get("startsBuilt", true))

	var levels_data: Array = data.get("levels", [])
	var levels: Array[UpgradeDefinition] = []
	for i: int in levels_data.size():
		levels.append(UpgradeDefinition.from_dict(i + 1, levels_data[i]))
	def.levels = levels

	return def
