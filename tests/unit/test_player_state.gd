extends GutTest

## Verifies PlayerState's to_dict()/from_dict() round trip, per
## docs/ARCHITECTURE.md Section 8.1's save table ("wallet" group).

func test_to_dict_round_trips_through_from_dict() -> void:
	var state := PlayerState.new()
	state.coins = 150
	state.feed = 5
	state.xp = 42
	state.level = 3
	var restored := PlayerState.from_dict(state.to_dict())
	assert_eq(restored.coins, 150)
	assert_eq(restored.feed, 5)
	assert_eq(restored.xp, 42)
	assert_eq(restored.level, 3)

func test_from_dict_preserves_unknown_keys_in_extra() -> void:
	var state := PlayerState.from_dict({"coins": 10, "gems": 7})
	assert_eq(state.extra, {"gems": 7})

func test_to_dict_writes_back_extra_unchanged() -> void:
	var state := PlayerState.from_dict({"gems": 7})
	assert_eq(state.to_dict().get("gems"), 7)

func test_from_dict_tolerates_missing_keys_with_defaults() -> void:
	var state := PlayerState.from_dict({})
	assert_eq(state.coins, 0)
	assert_eq(state.feed, 0)
	assert_eq(state.xp, 0)
	assert_eq(state.level, 1)
