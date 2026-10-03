class_name AmbientBudget
extends RefCounted

## Caps how many OPTIONAL ambient idle flourishes (peck/snout-wiggle/
## tail-swish-style per-species loops, plus backdrop cloud drift/grass
## sway) may be "in flight" across the whole farm at once, per Phase 9
## Task 9's approved interpretation (docs/DESIGN.md Section 9's ambient/
## idle principles): wandering, the product-bubble bob, and blinking are
## ALL exempt from this cap -- only the discretionary flourish loops
## count against it.
##
## Owned by FarmWorld as one shared instance (not per-AnimalView). A
## view asks for a slot before starting a flourish and releases it when
## the flourish ends/is interrupted; if no slot is free, that attempt is
## simply skipped (no error, no queueing) and the view tries again on
## its own next randomized interval.

const MAX_SLOTS := 2

var _used: int = 0

## Returns true and reserves one slot if the budget isn't exhausted;
## returns false (no state change) otherwise.
func request_slot() -> bool:
	if _used >= MAX_SLOTS:
		return false
	_used += 1
	return true

## Frees one slot, capped at 0 (never goes negative on a stray/duplicate
## release -- a caller that releases without a matching successful
## request_slot() must not corrupt the budget for everyone else).
func release_slot() -> void:
	_used = maxi(_used - 1, 0)

func used_slots() -> int:
	return _used

func available_slots() -> int:
	return MAX_SLOTS - _used
