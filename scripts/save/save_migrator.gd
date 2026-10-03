class_name SaveMigrator
extends RefCounted

## Save schema migrations, per docs/ARCHITECTURE.md Section 11.4. Each
## step is a pure Dictionary -> Dictionary function keyed by the version
## it migrates FROM (e.g. step 1 takes a v1 save and returns a v2 save).
## None exist in MVP v1 -- STEPS stays empty until a v2 schema exists.
## A migration may only add or rename keys with defaults; it must never
## drop unknown keys, so `migrate()` always hands the step the exact
## Dictionary it received.

const STEPS: Dictionary = {}

static func migrate(d: Dictionary, steps: Dictionary = STEPS) -> Dictionary:
	# `steps` is overridable only so tests can exercise the loop with a
	# fake step of their own, without mutating the real (const) STEPS.
	var result: Dictionary = d.duplicate(true)
	var version: int = int(result.get("version", 0))
	while steps.has(version):
		var step: Callable = steps[version]
		result = step.call(result)
		version = int(result.get("version", version))
	return result
