class_name BuildingRules
extends RefCounted

## Buildings per docs/ARCHITECTURE.md Section 10.2 / GDD Section 6. Pure
## static functions over (state, definitions) only -- no autoloads, no
## clock, no nodes (CLAUDE.md Section 11), same as
## StatusRules/FeedingRules/ProductionRules/EconomyRules. `Game.
## buy_animal`/`buy_feed_pack`/`sell_product`/`sell_all`/
## `upgrade_building` are the only production callers.
##
## A missing BuildingInstance (should not happen in real play --
## new_game_state() always creates one for every starts_built catalog
## building) is treated as a safe, inert programmer-error fallback,
## never a crash (ARCHITECTURE.md Section 18): capacity()/
## feed_capacity() return 0, is_full() returns true,
## production_multiplier()/sell_bonus_percent() return the neutral
## values (1.0 / 0.0).

static func housed_count(farm: FarmState, building_id: String) -> int:
	var count := 0
	for a: AnimalInstance in farm.animals:
		if a.building_id == building_id:
			count += 1
	return count

static func capacity(farm: FarmState, building_id: String, c: GameCatalog) -> int:
	var instance: BuildingInstance = farm.get_building(building_id)
	var definition: BuildingDefinition = c.building(building_id)
	if instance == null or definition == null:
		return 0
	return definition.level_def(instance.level).capacity

static func is_full(farm: FarmState, building_id: String, c: GameCatalog) -> bool:
	var instance: BuildingInstance = farm.get_building(building_id)
	if instance == null:
		return true
	return housed_count(farm, building_id) >= capacity(farm, building_id, c)

static func production_multiplier(farm: FarmState, building_id: String, c: GameCatalog) -> float:
	var instance: BuildingInstance = farm.get_building(building_id)
	var definition: BuildingDefinition = c.building(building_id)
	if instance == null or definition == null:
		return 1.0
	return definition.level_def(instance.level).production_multiplier

## From the one FEED_STORAGE building (ARCHITECTURE.md Section 7.2:
## "exactly one FEED_STORAGE... building" is enforced by
## GameCatalog.validate()).
static func feed_capacity(farm: FarmState, c: GameCatalog) -> int:
	var definition: BuildingDefinition = c.building_of_kind(BuildingDefinition.Kind.FEED_STORAGE)
	if definition == null:
		return 0
	var instance: BuildingInstance = farm.get_building(definition.id)
	if instance == null:
		return 0
	return definition.level_def(instance.level).feed_capacity

## From the one MARKET building.
static func sell_bonus_percent(farm: FarmState, c: GameCatalog) -> float:
	var definition: BuildingDefinition = c.building_of_kind(BuildingDefinition.Kind.MARKET)
	if definition == null:
		return 0.0
	var instance: BuildingInstance = farm.get_building(definition.id)
	if instance == null:
		return 0.0
	return definition.level_def(instance.level).sell_bonus_percent

static func is_max_level(b: BuildingInstance, c: GameCatalog) -> bool:
	var definition: BuildingDefinition = c.building(b.id)
	if definition == null:
		return true
	return b.level >= definition.max_level()

## Null at max level -- the "do we show an Upgrade button at all"
## question (GDD Section 6: "Max level (L3): the Upgrade button is
## hidden").
static func next_upgrade(b: BuildingInstance, c: GameCatalog) -> UpgradeDefinition:
	if is_max_level(b, c):
		return null
	var definition: BuildingDefinition = c.building(b.id)
	return definition.level_def(b.level + 1)

## Refusal checks only, in priority order: unknown building, then
## MAX_LEVEL, then NOT_ENOUGH_COINS. GDD Section 6: "Upgrade requires
## coins only. No other requirement." Returns
## ActionResult.of(Code.OK) when upgrading is allowed.
static func check_upgrade(state: GameState, building_id: String, c: GameCatalog) -> ActionResult:
	var instance: BuildingInstance = state.farm.get_building(building_id)
	if instance == null:
		return ActionResult.of(ActionResult.Code.UNKNOWN_ID)
	if is_max_level(instance, c):
		return ActionResult.of(ActionResult.Code.MAX_LEVEL)
	var cost: int = next_upgrade(instance, c).cost
	var missing: int = EconomyRules.missing_coins(state.player.coins, cost)
	if missing > 0:
		var result := ActionResult.of(ActionResult.Code.NOT_ENOUGH_COINS)
		result.missing = missing
		return result
	return ActionResult.of(ActionResult.Code.OK)
