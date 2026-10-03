class_name ActionResult
extends RefCounted

## The result of a Game command, per docs/ARCHITECTURE.md Section 13.2.
## Built at its final documented shape now (the full Code enum, not a
## Phase-3-only subset) -- an enum value with no current emitter costs
## nothing, and this avoids a breaking shape-change when a later phase
## adds the command that uses it (the same "build at final shape"
## approach Phase 2 used for AnimalDefinition's unused-until-later
## fields).

enum Code {
	OK, DEBOUNCED, NOT_ENOUGH_COINS, NOT_ENOUGH_FEED, HUNGER_FULL, NOT_READY,
	BUILDING_FULL, LOCKED_BY_LEVEL, STORAGE_FULL, MAX_LEVEL, NOTHING_TO_SELL,
	INVALID_NAME, UNKNOWN_ID, SAVE_FAILED,
}

var code: Code = Code.OK
var missing: int = 0            # e.g. coins missing, for "You need N more coins." (not used by Phase 3)
var data: Dictionary = {}       # e.g. {"animal_id": ...}

func ok() -> bool:
	return code == Code.OK

static func of(result_code: Code) -> ActionResult:
	var result := ActionResult.new()
	result.code = result_code
	return result
