class_name GameClock
extends RefCounted

## Real-time clock source for UI-level debounce timing (docs/
## ARCHITECTURE.md Section 10.4: "ActionGuard ... uses GameClock.mono_ms()
## (Time.get_ticks_msec())"). Phase 3 scope only: `mono_ms()`, a
## monotonic, non-persistent millisecond counter -- correctly distinct
## from CLAUDE.md Section 8's "time-based systems must use timestamps"
## rule, since this never touches saved/persistent state, only a
## same-session double-tap guard.
##
## `now_ms()` (UTC wall-clock time) is the simulation clock Production/
## Offline progression read -- added in Phase 4, since that is the
## first phase whose persistent state (hunger/happiness/progress)
## advances with elapsed wall-clock time (CLAUDE.md Section 8).
##
## A plain, non-virtual function (not RefCounted-abstract) so tests can
## subclass it (FakeClock extends GameClock) and override mono_ms()/
## now_ms() for deterministic tests.

func mono_ms() -> int:
	return Time.get_ticks_msec()

## UTC wall-clock milliseconds since the epoch -- the only source of
## elapsed time Game._advance_to() may read (docs/ARCHITECTURE.md
## Section 1: "the elapsed seconds always come from two clock
## readings"). Distinct from mono_ms(): this one persists meaningfully
## across app restarts (today's session must see time that passed while
## the app was closed), which Time.get_ticks_msec() never does.
func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
