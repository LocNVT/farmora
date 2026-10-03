extends GutTest

## Verifies SaveMigrator.migrate()'s version-stepping loop, per
## docs/ARCHITECTURE.md Section 11.4. SaveMigrator.STEPS is empty in
## MVP v1 (no real migration exists yet, and it is a `const` so a test
## cannot mutate it in place) -- so these tests exercise the loop via
## migrate()'s `steps` parameter, passing a fake v1 -> v2 step of their
## own. Production call sites always use the default (the real STEPS).

func _v1_to_v2(d: Dictionary) -> Dictionary:
	var result: Dictionary = d.duplicate(true)
	result["version"] = 2
	result["tutorialStep"] = result.get("tutorialStep", 0)
	return result

func _v2_to_v3(d: Dictionary) -> Dictionary:
	var result: Dictionary = d.duplicate(true)
	result["version"] = 3
	return result

func test_migrate_with_the_real_empty_steps_returns_the_input_unchanged() -> void:
	var input: Dictionary = {"version": 1, "wallet": {"coins": 5}}
	var result: Dictionary = SaveMigrator.migrate(input)
	assert_eq(result, input)

func test_migrate_does_not_mutate_the_input_dictionary() -> void:
	var steps: Dictionary = {1: Callable(self, "_v1_to_v2")}
	var input: Dictionary = {"version": 1}
	SaveMigrator.migrate(input, steps)
	assert_eq(input["version"], 1, "migrate() must not mutate the caller's Dictionary in place")

func test_migrate_applies_a_single_step_and_advances_the_version() -> void:
	var steps: Dictionary = {1: Callable(self, "_v1_to_v2")}
	var result: Dictionary = SaveMigrator.migrate({"version": 1}, steps)
	assert_eq(result["version"], 2)
	assert_eq(result["tutorialStep"], 0)

func test_migrate_loops_through_multiple_steps_until_no_step_remains() -> void:
	var steps: Dictionary = {
		1: Callable(self, "_v1_to_v2"),
		2: Callable(self, "_v2_to_v3"),
	}
	var result: Dictionary = SaveMigrator.migrate({"version": 1}, steps)
	assert_eq(result["version"], 3)

func test_migrate_preserves_unknown_keys_through_a_step() -> void:
	var steps: Dictionary = {1: Callable(self, "_v1_to_v2")}
	var result: Dictionary = SaveMigrator.migrate({"version": 1, "futureField": "x"}, steps)
	assert_eq(result.get("futureField"), "x", "A migration must never drop unknown keys")
