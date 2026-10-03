class_name ProductionRules
extends RefCounted

## Production per docs/ARCHITECTURE.md Section 14 ("the only simulation
## math") / GDD Section 4. Pure static functions over (state,
## definitions) only -- no autoloads, no clock, no nodes (CLAUDE.md
## Section 11), same as StatusRules/FeedingRules. `Game._advance_to` is
## the only production caller; it owns the two-clock-reading elapsed
## time this file has no clock to compute itself.

## Per-animal advancement parameters, built fresh each call by
## `Game._production_params_for()`. `cycle_seconds` is the catalog's
## base value directly in Phase 4 -- no building-multiplier division
## yet (Phase 6: `BuildingRules.production_multiplier` divides it
## there, not here; this class's signature never changes) and no
## tutorial-boost substitution yet (unassigned tutorial work).
class Params:
	var cycle_seconds: float = 1.0
	var hunger_decay_per_second: float = 0.0
	var happiness_decay_per_second: float = 0.0
	var pause_when_ready: bool = true

## Advances one animal by `dt` seconds. Returns the number of products
## completed (0 or 1 when paused-at-ready). Exact order per
## ARCHITECTURE.md Section 14:
## 1. fed_time = the portion of dt during which hunger > 0.
## 2. hunger/happiness decay on wall time regardless of feeding state.
## 3. progress advances only during fed_time, paused at 1.0 (one stored
##    product) when pause_when_ready is true.
##
## Guaranteed properties (each covered by a test): split invariance
## (one big dt == many small dt's summing to the same total, within
## float epsilon); an animal at hunger 0 gains no progress no matter
## how long it waits; one meal (+50 hunger) gives ~50 minutes of
## production at hungerDecayPerMinute=1.
static func advance_animal(a: AnimalInstance, dt: float, p: Params) -> int:
	if dt <= 0.0:
		return 0

	var fed_time: float = dt
	if p.hunger_decay_per_second > 0.0:
		fed_time = clampf(a.hunger / p.hunger_decay_per_second, 0.0, dt)
	elif a.hunger <= 0.0:
		fed_time = 0.0

	a.hunger = maxf(0.0, a.hunger - p.hunger_decay_per_second * dt)
	a.happiness = maxf(0.0, a.happiness - p.happiness_decay_per_second * dt)

	if p.pause_when_ready and a.progress >= 1.0:
		return 0

	a.progress += fed_time / p.cycle_seconds
	if a.progress >= 1.0:
		if p.pause_when_ready:
			a.progress = 1.0
			return 1
		var done := int(floor(a.progress))
		a.progress -= done
		return done

	return 0

## Refusal check only: an animal whose progress has not reached 1.0 has
## nothing to collect. Returns ActionResult.of(Code.OK) when collecting
## is allowed -- same check_*/apply_* split as FeedingRules.
static func check_collect(a: AnimalInstance) -> ActionResult:
	if a.progress < 1.0:
		return ActionResult.of(ActionResult.Code.NOT_READY)
	return ActionResult.of(ActionResult.Code.OK)

## Applies one collect's effect: the animal's product moves into the
## bag, progress resets to 0, happiness rises by gain_on_collect
## (clamped to 100). Returns the product id collected, so the caller
## can emit `product_collected(animal_id, product_id, amount)` without
## looking the species up a second time. Callers must have already
## confirmed check_collect() returned OK -- this function does not
## re-validate, same division of responsibility as FeedingRules.apply_meal.
static func apply_collect(a: AnimalInstance, inventory: InventoryState, catalog: GameCatalog) -> String:
	var product_id: String = catalog.animal(a.species).product_id
	inventory.add(product_id, 1)
	a.progress = 0.0
	a.happiness = minf(100.0, a.happiness + catalog.happiness.gain_on_collect)
	return product_id
