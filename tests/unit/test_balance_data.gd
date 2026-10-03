extends GutTest

## Confirms the LIVE data/balance.json (not the frozen fixture) loads
## and validates cleanly, per docs/ARCHITECTURE.md Section 7.4's
## requirement that the shipped file is checked the same way the
## fixture is. This is the test that would fail if balance.json were
## ever hand-edited into an inconsistent state.

func test_live_balance_file_loads() -> void:
	var catalog: GameCatalog = GameCatalog.load_from_file("res://data/balance.json")
	assert_not_null(catalog, "data/balance.json should load without error")

func test_live_balance_file_validates_cleanly() -> void:
	var catalog: GameCatalog = GameCatalog.load_from_file("res://data/balance.json")
	var problems: PackedStringArray = catalog.validate()
	assert_eq(problems.size(), 0, "data/balance.json should validate with no problems: " + str(problems))

func test_live_file_has_all_three_mvp_animals_and_products() -> void:
	var catalog: GameCatalog = GameCatalog.load_from_file("res://data/balance.json")
	assert_eq(catalog.animal_ids().size(), 3)
	assert_eq(catalog.product_ids().size(), 3)
