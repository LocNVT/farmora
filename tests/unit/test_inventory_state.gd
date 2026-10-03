extends GutTest

## Verifies InventoryState's get_qty()/add() (Phase 4), remove()
## (Phase 5), and to_dict()/from_dict() (Phase 7) per
## docs/ARCHITECTURE.md Section 8.1/10.3.

func test_get_qty_defaults_to_zero_for_an_unknown_product() -> void:
	var inv := InventoryState.new()
	assert_eq(inv.get_qty("egg"), 0)

func test_add_seeds_a_new_product_at_the_given_amount() -> void:
	var inv := InventoryState.new()
	inv.add("egg", 3)
	assert_eq(inv.get_qty("egg"), 3)

func test_add_accumulates_on_an_existing_product() -> void:
	var inv := InventoryState.new()
	inv.add("egg", 3)
	inv.add("egg", 2)
	assert_eq(inv.get_qty("egg"), 5)

func test_add_zero_seeds_the_product_without_changing_its_quantity() -> void:
	var inv := InventoryState.new()
	inv.add("egg", 0)
	assert_eq(inv.get_qty("egg"), 0)
	assert_true(inv.quantities.has("egg"), "add(0) should still create the key, per 'one key per catalog product, zero included'")

func test_different_products_are_independent() -> void:
	var inv := InventoryState.new()
	inv.add("egg", 5)
	inv.add("milk", 1)
	assert_eq(inv.get_qty("egg"), 5)
	assert_eq(inv.get_qty("milk"), 1)

func test_remove_succeeds_and_reduces_the_quantity() -> void:
	var inv := InventoryState.new()
	inv.add("egg", 5)
	var ok: bool = inv.remove("egg", 3)
	assert_true(ok)
	assert_eq(inv.get_qty("egg"), 2)

func test_remove_exactly_all_of_a_product_leaves_zero() -> void:
	var inv := InventoryState.new()
	inv.add("egg", 5)
	assert_true(inv.remove("egg", 5))
	assert_eq(inv.get_qty("egg"), 0)

func test_remove_refuses_to_go_negative() -> void:
	var inv := InventoryState.new()
	inv.add("egg", 2)
	var ok: bool = inv.remove("egg", 3)
	assert_false(ok)
	assert_eq(inv.get_qty("egg"), 2, "A refused remove must not change the quantity")

func test_remove_from_an_unseeded_product_refuses() -> void:
	var inv := InventoryState.new()
	var ok: bool = inv.remove("egg", 1)
	assert_false(ok)
	assert_eq(inv.get_qty("egg"), 0)

func test_to_dict_round_trips_through_from_dict() -> void:
	var inv := InventoryState.new()
	inv.add("egg", 12)
	inv.add("milk", 0)
	var restored := InventoryState.from_dict(inv.to_dict())
	assert_eq(restored.get_qty("egg"), 12)
	assert_eq(restored.get_qty("milk"), 0)

func test_from_dict_keeps_an_unrecognized_product_key_as_is() -> void:
	# ARCHITECTURE.md Section 10.3: "Unknown product keys are kept as
	# they are" -- no separate extra for InventoryState.
	var inv := InventoryState.from_dict({"egg": 5, "futureProduct": 3})
	assert_eq(inv.get_qty("futureProduct"), 3)
