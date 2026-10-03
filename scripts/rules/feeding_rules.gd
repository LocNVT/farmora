class_name FeedingRules
extends RefCounted

## Feeding rules per docs/ARCHITECTURE.md Section 17's "Feed an animal"
## data flow and Section 7's `balance.feeding`/`balance.happiness`
## groups (GDD Section 4). Pure static functions over (state,
## definitions) only -- no autoloads, no clock, no nodes (CLAUDE.md
## Section 11), same as StatusRules. `Game.feed_animal` is the only
## production caller; it owns the ActionGuard/GameClock wiring and
## signal emission that this file deliberately does not know about.

## The ActionGuard key for feeding one animal (ARCHITECTURE.md Section
## 17: `ActionGuard("feed:id")`).
static func debounce_key(animal_id: String) -> String:
	return "feed:%s" % animal_id

## Refusal checks only, in priority order: not enough feed, then (if
## balance.feeding.blockWhenFull) the animal is already at full hunger.
## Returns ActionResult.of(Code.OK) when feeding is allowed -- callers
## apply the ActionGuard debounce separately, since that is a
## real-time concern this pure function has no clock to perform.
static func check_feed(player: PlayerState, animal: AnimalInstance, catalog: GameCatalog) -> ActionResult:
	if player.feed < catalog.feeding.feed_per_meal:
		return ActionResult.of(ActionResult.Code.NOT_ENOUGH_FEED)
	if catalog.feeding.block_when_full and animal.hunger >= 100.0:
		return ActionResult.of(ActionResult.Code.HUNGER_FULL)
	return ActionResult.of(ActionResult.Code.OK)

## Applies one meal's effect, per ARCHITECTURE.md Section 17:
## `wallet.feed -= feedPerMeal ; hunger = min(100, hunger + hungerPerMeal)
## ; happiness = min(100, happiness + gainOnFeed)`. Callers must have
## already confirmed check_feed() returned OK -- this function does not
## re-validate, matching ProductionRules/StatusRules leaving refusal
## entirely to their check_*/flags() siblings.
static func apply_meal(player: PlayerState, animal: AnimalInstance, catalog: GameCatalog) -> void:
	player.feed -= catalog.feeding.feed_per_meal
	animal.hunger = minf(100.0, animal.hunger + catalog.feeding.hunger_per_meal)
	animal.happiness = minf(100.0, animal.happiness + catalog.happiness.gain_on_feed)
