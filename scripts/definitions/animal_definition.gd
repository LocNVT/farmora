class_name AnimalDefinition
extends RefCounted

## Static, read-only animal definition per docs/ARCHITECTURE.md Section
## 7.2. Parsed once by GameCatalog from data/balance.json's "animals"
## block; never mutated after construction.

var id: String                      # e.g. "chicken"
var product_id: String              # e.g. "egg"
var price: int                      # coins
var unlock_level: int
var housing_building_id: String     # e.g. "chicken_coop"
var cycle_seconds: float            # base cycle at 100% speed, fed (GDD Section 4: minutes * 60)
var default_names: Array[String]    # OPEN (design): name pool, GDD Section 4

static func from_dict(animal_id: String, data: Dictionary) -> AnimalDefinition:
	var def := AnimalDefinition.new()
	def.id = animal_id
	def.product_id = String(data.get("product", ""))
	def.price = int(data.get("price", 0))
	def.unlock_level = int(data.get("unlockLevel", 1))
	def.housing_building_id = String(data.get("housing", ""))
	def.cycle_seconds = float(data.get("cycleMinutes", 0.0)) * 60.0
	var names: Array[String] = []
	for entry: Variant in data.get("defaultNames", []):
		names.append(String(entry))
	def.default_names = names
	return def
