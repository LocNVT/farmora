extends GutTest

## Verifies BuildingInstance's to_dict()/from_dict() round trip, per
## docs/ARCHITECTURE.md Section 8.1's save table.

func test_to_dict_round_trips_through_from_dict() -> void:
	var instance := BuildingInstance.new()
	instance.id = "chicken_coop"
	instance.level = 2
	var restored := BuildingInstance.from_dict(instance.to_dict())
	assert_eq(restored.id, "chicken_coop")
	assert_eq(restored.level, 2)

func test_from_dict_preserves_unknown_keys_in_extra() -> void:
	var instance := BuildingInstance.from_dict({"id": "market", "level": 1, "skin": "gold"})
	assert_eq(instance.extra, {"skin": "gold"})

func test_to_dict_writes_back_extra_unchanged() -> void:
	var instance := BuildingInstance.from_dict({"id": "market", "skin": "gold"})
	assert_eq(instance.to_dict().get("skin"), "gold")

func test_from_dict_tolerates_missing_keys_with_defaults() -> void:
	var instance := BuildingInstance.from_dict({})
	assert_eq(instance.id, "")
	assert_eq(instance.level, 1)
