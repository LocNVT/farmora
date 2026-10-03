class_name ProductDefinition
extends RefCounted

## Static, read-only product definition per docs/ARCHITECTURE.md Section
## 7.2. Parsed once by GameCatalog from data/balance.json's "products"
## block; never mutated after construction (CLAUDE.md Section 7: static
## definitions and runtime state stay separate).

var id: String                 # e.g. "egg"
var sell_price: int             # coins per item, before Market bonus (GDD Section 5)

static func from_dict(product_id: String, data: Dictionary) -> ProductDefinition:
	var def := ProductDefinition.new()
	def.id = product_id
	def.sell_price = int(data.get("sellPrice", 0))
	return def
