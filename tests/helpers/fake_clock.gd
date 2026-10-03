class_name FakeClock
extends GameClock

## Deterministic clock for debounce tests (docs/ARCHITECTURE.md Section
## 19: "FakeClock extends GameClock"). Never used by production code.

var _mono_ms: int = 0
var _now_ms: int = 0

func mono_ms() -> int:
	return _mono_ms

func now_ms() -> int:
	return _now_ms

## Advances BOTH clocks together by `ms` -- mono_ms() and now_ms() are
## different clock sources in production (one resets per process, one
## doesn't), but nothing in this test double depends on them drifting
## apart, and a single advance() keeps every existing debounce test
## (Phase 3) working unchanged while also driving the new simulation
## tests (Phase 4).
func advance(ms: int) -> void:
	_mono_ms += ms
	_now_ms += ms

func set_mono_ms(value: int) -> void:
	_mono_ms = value

func set_now_ms(value: int) -> void:
	_now_ms = value
