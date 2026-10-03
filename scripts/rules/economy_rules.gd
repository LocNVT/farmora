class_name EconomyRules
extends RefCounted

## Economy per docs/ARCHITECTURE.md Section 10.4 / GDD Section 7. Pure
## static functions over (state, definitions) only -- no autoloads, no
## clock, no nodes (CLAUDE.md Section 11), same as
## StatusRules/FeedingRules/ProductionRules/BuildingRules. `Game.
## buy_animal`/`buy_feed_pack`/`sell_product`/`sell_all`/
## `upgrade_building` are the only production callers; they own the
## ActionGuard/GameClock wiring and signal emission this file
## deliberately does not know about.
##
## `check_buy_animal()`/`check_buy_feed_pack()` take `state: GameState`
## (not just `PlayerState`), matching ARCHITECTURE.md Section 10.4's own
## documented signatures -- Phase 5's narrower `PlayerState`-only
## signature was the interim shape before `BuildingRules.is_full`/
## `feed_capacity` (which need `state.farm`) existed to check against.

static func missing_coins(coins: int, cost: int) -> int:
	return maxi(0, cost - coins)

## Refusal checks only, in priority order: unknown species, then
## LOCKED_BY_LEVEL (GDD Section 8 / ARCHITECTURE.md Section 23 item 9:
## the player must have reached the species' unlock_level), then
## BUILDING_FULL (the species' housing building is at capacity -- GDD
## Section 6: "A building at capacity blocks buying another animal for
## it"), then NOT_ENOUGH_COINS. Matches ARCHITECTURE.md Section 10.4's
## documented priority order exactly. Returns ActionResult.of(Code.OK)
## when buying is allowed.
static func check_buy_animal(state: GameState, species: String, catalog: GameCatalog) -> ActionResult:
	var definition: AnimalDefinition = catalog.animal(species)
	if definition == null:
		return ActionResult.of(ActionResult.Code.UNKNOWN_ID)
	if state.player.level < definition.unlock_level:
		return ActionResult.of(ActionResult.Code.LOCKED_BY_LEVEL)
	if BuildingRules.is_full(state.farm, definition.housing_building_id, catalog):
		return ActionResult.of(ActionResult.Code.BUILDING_FULL)
	var missing: int = missing_coins(state.player.coins, definition.price)
	if missing > 0:
		var result := ActionResult.of(ActionResult.Code.NOT_ENOUGH_COINS)
		result.missing = missing
		return result
	return ActionResult.of(ActionResult.Code.OK)

## Refusal checks only, in priority order: NOT_ENOUGH_COINS, then
## STORAGE_FULL. GDD Section 6's OPEN default (the project's built
## behavior): "a pack that would partially overflow is refused (not
## partially applied)" when `economy.refuse_overflowing_feed_pack` is
## true -- i.e. refuse the WHOLE pack if `feed + feed_pack_feed >
## feed_capacity`, checked before anything is applied. When the switch
## is false, only refuse once feed has already reached the cap (Game
## then clamps the applied amount to the cap, so GDD Section 6's
## "cannot be held" still holds even without the whole-pack refusal).
static func check_buy_feed_pack(state: GameState, catalog: GameCatalog) -> ActionResult:
	var missing: int = missing_coins(state.player.coins, catalog.economy.feed_pack_price)
	if missing > 0:
		var result := ActionResult.of(ActionResult.Code.NOT_ENOUGH_COINS)
		result.missing = missing
		return result
	var cap: int = BuildingRules.feed_capacity(state.farm, catalog)
	if catalog.economy.refuse_overflowing_feed_pack:
		if state.player.feed + catalog.economy.feed_pack_feed > cap:
			return ActionResult.of(ActionResult.Code.STORAGE_FULL)
	elif state.player.feed >= cap:
		return ActionResult.of(ActionResult.Code.STORAGE_FULL)
	return ActionResult.of(ActionResult.Code.OK)

## The coin total for selling `qty` units at `unit_price`, after the
## Market building's sell bonus (a percentage, from
## `BuildingRules.sell_bonus_percent`), rounded HALF UP on the TOTAL
## (GDD Section 7's OPEN recommendation: "round the total, not each
## item, to the nearest whole coin, half up").
static func sale_total(unit_price: int, qty: int, bonus_percent: float) -> int:
	var raw: float = float(unit_price * qty) * (1.0 + bonus_percent / 100.0)
	return int(floor(raw + 0.5))

## The coin total for selling the ENTIRE bag at once (Sell all), summed
## per product then rounded once on the grand total -- not per-product
## -- matching GDD Section 7's "round the total" rule applied to the
## whole operation.
static func sell_all_total(bag: InventoryState, catalog: GameCatalog, bonus_percent: float) -> int:
	var raw_total: float = 0.0
	for product_id: String in catalog.product_ids():
		var qty: int = bag.get_qty(product_id)
		if qty <= 0:
			continue
		var unit_price: int = catalog.product(product_id).sell_price
		raw_total += float(unit_price * qty)
	raw_total *= 1.0 + bonus_percent / 100.0
	return int(floor(raw_total + 0.5))

## The "coins" row on the Offline Reward report (ARCHITECTURE.md Section
## 12.3: "computed with EconomyRules.offline_coin_value() as information
## only" -- the GDD Section 9 OPEN item's built default is display-only;
## `collect_offline_reward()` never credits this). Takes a plain
## `product_id -> qty` Dictionary (an OfflineReport's own `products`
## field, not an InventoryState) since the report tallies products
## produced during the offline window, not the player's whole bag.
## Shares `sell_all_total`'s "round the total once, half up" rule.
static func offline_coin_value(products: Dictionary, catalog: GameCatalog, bonus_percent: float) -> int:
	var raw_total: float = 0.0
	for product_id: String in products.keys():
		var qty: int = int(products[product_id])
		if qty <= 0:
			continue
		var unit_price: int = catalog.product(product_id).sell_price
		raw_total += float(unit_price * qty)
	raw_total *= 1.0 + bonus_percent / 100.0
	return int(floor(raw_total + 0.5))
