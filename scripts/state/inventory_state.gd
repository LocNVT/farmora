class_name InventoryState
extends RefCounted

## Runtime inventory ("bag") per docs/ARCHITECTURE.md Section 8.1/10.2:
## "InventoryState <-> save 'bag'... quantities: Dictionary (product id
## -> int). Written with one key per catalog product, zero included."
##
## get_qty()/add() (Phase 4, for Game.collect() to have somewhere real
## to put a product -- GDD Section 5: "Products never expire or
## disappear") and remove() (Phase 5, for Game.sell_product()/
## sell_all()). to_dict()/from_dict() (Phase 7) serialize `quantities`
## as-is -- completeness (one key per catalog product) is
## Game.new_game_state()'s job when seeding a fresh bag, not this
## class's; an unrecognized key from an old save is kept, per
## ARCHITECTURE.md Section 10.3: "Unknown product keys are kept as they
## are" (there is no separate `extra` for InventoryState -- the whole
## dictionary IS the save-shaped data).

var quantities: Dictionary = {}  # String product id -> int, never negative

func get_qty(product_id: String) -> int:
	return int(quantities.get(product_id, 0))

func add(product_id: String, amount: int) -> void:
	quantities[product_id] = get_qty(product_id) + amount

## Removes `amount` of `product_id`, refusing (and making no change) if
## that would take the quantity below zero. Per docs/ARCHITECTURE.md
## Section 10.3: "remove(id, n) -> bool (refuses to go negative)".
func remove(product_id: String, amount: int) -> bool:
	if get_qty(product_id) < amount:
		return false
	quantities[product_id] = get_qty(product_id) - amount
	return true

func to_dict() -> Dictionary:
	return quantities.duplicate()

static func from_dict(data: Dictionary) -> InventoryState:
	var state := InventoryState.new()
	for product_id: String in data.keys():
		state.quantities[product_id] = int(data[product_id])
	return state
