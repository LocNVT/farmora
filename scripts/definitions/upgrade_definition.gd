class_name UpgradeDefinition
extends RefCounted

## Static, read-only building-level row per docs/ARCHITECTURE.md Section
## 7.2. One row of a BuildingDefinition.levels array (index 0 = level
## 1). Fields that do not apply to a building's kind stay at their
## neutral value (0 / 1.0) -- BuildingRules reads only the field for
## the building's own kind, never assumes an irrelevant field is
## meaningful.

var level: int = 1
var cost: int = 0                      # coins to reach this level from level-1 (0 for level 1)
var capacity: int = 0                  # housing kind only; 0 otherwise
var production_multiplier: float = 1.0 # housing kind only (1.0 / 1.25 / 1.5); 1.0 otherwise
var feed_capacity: int = 0             # feed_storage kind only; 0 otherwise
var sell_bonus_percent: float = 0.0    # market kind only (0 / 5 / 10); 0 otherwise

static func from_dict(level_number: int, data: Dictionary) -> UpgradeDefinition:
	var def := UpgradeDefinition.new()
	def.level = level_number
	def.cost = int(data.get("cost", 0))
	def.capacity = int(data.get("capacity", 0))
	def.production_multiplier = float(data.get("productionMultiplier", 1.0))
	def.feed_capacity = int(data.get("feedCapacity", 0))
	def.sell_bonus_percent = float(data.get("sellBonusPercent", 0.0))
	return def
