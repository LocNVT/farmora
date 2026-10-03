class_name OfflineRules
extends RefCounted

## Offline progression math per docs/GDD.md Section 9 / docs/
## ARCHITECTURE.md Section 12.1. Pure static functions only -- no
## autoloads, no clock, no nodes (CLAUDE.md Section 11), same as every
## other *Rules class. `Game._advance_to()` is the only production
## caller; it owns applying the result to real state and emitting
## signals, which this file deliberately does not know about.

## GDD Section 9 rules 1-2: the elapsed time to simulate, capped at
## `cap_ms` (an 8 h cap in the live catalog), and zero if the clock went
## backwards. `Game._advance_to()` still re-bases `last_seen_ms = now_ms`
## in that case (ARCHITECTURE.md Section 12.1: "Otherwise a moved-back
## clock would freeze production until real time caught up").
static func elapsed_ms(now_ms: int, last_seen_ms: int, cap_ms: int) -> int:
	if now_ms < last_seen_ms:
		return 0
	return mini(now_ms - last_seen_ms, cap_ms)

## GDD Section 9 rule 4's "more than 5 minutes" -- strictly greater than
## the configured threshold, not inclusive.
static func exceeds_modal_threshold(elapsed_ms: int, catalog: GameCatalog) -> bool:
	return elapsed_ms > catalog.offline.reward_modal_min_ms()

## GDD Section 9 rule 4: show the modal only when the elapsed window
## exceeds the threshold AND something was actually produced. A long
## absence with nothing produced (every animal was hungry) skips the
## modal entirely, same as a short return.
static func should_show_modal(report: OfflineReport, catalog: GameCatalog) -> bool:
	return exceeds_modal_threshold(report.elapsed_ms, catalog) and not report.products.is_empty()
