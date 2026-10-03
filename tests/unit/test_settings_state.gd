extends GutTest

## Verifies SettingsState's defaults and to_dict()/from_dict() round
## trip, per docs/ARCHITECTURE.md Section 8.1's save table.

func test_defaults_match_the_documented_values() -> void:
	var state := SettingsState.new()
	assert_true(state.sound)
	assert_true(state.music)
	assert_true(state.vibration)
	assert_false(state.reminders, "GDD Section 9: reminders defaults to off")
	assert_eq(state.language, "en")

func test_to_dict_round_trips_through_from_dict() -> void:
	var state := SettingsState.new()
	state.sound = false
	state.reminders = true
	state.language = "fr"
	var restored := SettingsState.from_dict(state.to_dict())
	assert_eq(restored.sound, false)
	assert_eq(restored.music, true)
	assert_eq(restored.reminders, true)
	assert_eq(restored.language, "fr")

func test_from_dict_preserves_unknown_keys_in_extra() -> void:
	var state := SettingsState.from_dict({"sound": true, "futureField": "x"})
	assert_eq(state.extra, {"futureField": "x"})

func test_to_dict_writes_back_extra_unchanged() -> void:
	var state := SettingsState.from_dict({"futureField": 42})
	var encoded: Dictionary = state.to_dict()
	assert_eq(encoded.get("futureField"), 42)

func test_from_dict_tolerates_missing_keys_with_defaults() -> void:
	var state := SettingsState.from_dict({})
	assert_true(state.sound)
	assert_false(state.reminders)
	assert_eq(state.language, "en")
