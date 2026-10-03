class_name ActionGuard
extends RefCounted

## The 300 ms commit lock / debounce per docs/ARCHITECTURE.md Section
## 10.4: "ActionGuard.try_commit(key, now_mono_ms, lock_ms) -> bool ...
## uses GameClock.mono_ms() ... a real-time debounce, not persistent
## game time, so CLAUDE.md Section 8 is respected."
##
## Keys are independent: `try_commit("feed:a1", ...)` and
## `try_commit("feed:a2", ...)` never block each other (GDD Section 4's
## debounce is per-animal). A REFUSED attempt does not extend the lock
## -- only a successful commit starts a new lock_ms window.

var _last_commit_ms: Dictionary = {}  # String key -> int mono ms

func try_commit(key: String, now_mono_ms: int, lock_ms: int) -> bool:
	var last: Variant = _last_commit_ms.get(key)
	if last != null and now_mono_ms - int(last) < lock_ms:
		return false
	_last_commit_ms[key] = now_mono_ms
	return true
