class_name LoadResult
extends RefCounted

## The result of SaveService.load_game(), per docs/ARCHITECTURE.md Section
## 11.5's Load order table: "SaveService.load_game() returns LoadResult
## {status, state, source}". Reuses DecodeResult.Status directly (NO_SAVE/
## OK/DAMAGED/TOO_NEW already cover every case load_game() needs -- no
## separate enum). `source` records which candidate file produced `state`
## ("" when there is none), the same enum + plain-data + static `of()`
## shape as ActionResult/DecodeResult.

var status: DecodeResult.Status = DecodeResult.Status.NO_SAVE
var state: GameState = null  # non-null only when status == OK
var source: String = ""      # "" | "main" | "tmp" | "backup"

static func of(result_status: DecodeResult.Status, result_state: GameState = null, result_source: String = "") -> LoadResult:
	var result := LoadResult.new()
	result.status = result_status
	result.state = result_state
	result.source = result_source
	return result
