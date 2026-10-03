class_name DecodeResult
extends RefCounted

## The result of SaveCodec.decode(), per docs/ARCHITECTURE.md Section
## 11.3: "{status, state, problems}". A separate top-level class (rather
## than nested in SaveCodec) so it can be used as a return type/static
## type annotation from any file, matching ActionResult's shape
## (core/action_result.gd): an enum + plain data fields + a static `of()`
## constructor.

enum Status { OK, NO_SAVE, DAMAGED, TOO_NEW }

var status: Status = Status.OK
var state: GameState = null       # non-null only when status == OK
var problems: Array[String] = []  # one short note per clamp/fixup performed during decode

static func of(result_status: Status, result_state: GameState = null, result_problems: Array[String] = []) -> DecodeResult:
	var result := DecodeResult.new()
	result.status = result_status
	result.state = result_state
	result.problems = result_problems
	return result
