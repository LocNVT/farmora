extends GutTest

## Verifies EconomyRules per docs/ARCHITECTURE.md Section 10.4/19's test
## table ("Economy calculations: prices, missing coins, sale total with
## Market bonus and rounding, sell all, feed pack vs storage cap (OPEN
## switch), unlock level") against the fixture catalog (chicken 100/L1,
## pig 600/L3, cow 1500/L5, feedPack 10 feed for 25 coins, chicken_coop
## capacity 4/8/12, feed_storage 100/250/500, market bonus 0%/5%/10%).
##
## check_buy_animal()/check_buy_feed_pack() take `state: GameState` (not
## just PlayerState) since Phase 6 -- they need `state.farm` to reach
## BuildingRules.is_full()/feed_capacity().

var _catalog: GameCatalog

func before_each() -> void:
	_catalog = StateFactory.fixture_catalog()

func _state(coins: int, level: int = 1, animals: Array[AnimalInstance] = [], building_levels: Dictionary = {}, feed: int = 0) -> GameState:
	return StateFactory.game_state_with(animals, feed, 0, coins, level, building_levels)

func test_missing_coins_is_zero_when_affordable() -> void:
	assert_eq(EconomyRules.missing_coins(100, 100), 0)
	assert_eq(EconomyRules.missing_coins(150, 100), 0)

func test_missing_coins_returns_the_shortfall() -> void:
	assert_eq(EconomyRules.missing_coins(60, 100), 40)

func test_check_buy_animal_ok_when_affordable_and_unlocked() -> void:
	var state := _state(100, 1)
	var result: ActionResult = EconomyRules.check_buy_animal(state, "chicken", _catalog)
	assert_true(result.ok())

func test_check_buy_animal_allows_exactly_enough_coins() -> void:
	var state := _state(100, 1)
	assert_true(EconomyRules.check_buy_animal(state, "chicken", _catalog).ok())

func test_check_buy_animal_refuses_not_enough_coins_with_the_shortfall() -> void:
	var state := _state(60, 1)
	var result: ActionResult = EconomyRules.check_buy_animal(state, "chicken", _catalog)
	assert_false(result.ok())
	assert_eq(result.code, ActionResult.Code.NOT_ENOUGH_COINS)
	assert_eq(result.missing, 40)

func test_check_buy_animal_refuses_locked_by_level() -> void:
	var state := _state(10000, 1)  # plenty of coins, but pig needs level 3
	var result: ActionResult = EconomyRules.check_buy_animal(state, "pig", _catalog)
	assert_false(result.ok())
	assert_eq(result.code, ActionResult.Code.LOCKED_BY_LEVEL)

func test_check_buy_animal_prioritizes_locked_by_level_over_not_enough_coins() -> void:
	var state := _state(0, 1)  # neither affordable nor unlocked
	var result: ActionResult = EconomyRules.check_buy_animal(state, "pig", _catalog)
	assert_eq(result.code, ActionResult.Code.LOCKED_BY_LEVEL)

func test_check_buy_animal_allows_a_higher_level_animal_once_unlocked() -> void:
	var state := _state(10000, 3)
	assert_true(EconomyRules.check_buy_animal(state, "pig", _catalog).ok())

func test_check_buy_animal_refuses_unknown_species() -> void:
	var state := _state(10000, 10)
	var result: ActionResult = EconomyRules.check_buy_animal(state, "dragon", _catalog)
	assert_eq(result.code, ActionResult.Code.UNKNOWN_ID)

func test_check_buy_animal_refuses_building_full() -> void:
	var animals: Array[AnimalInstance] = [
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a2"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a3"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a4"}),
	]  # L1 capacity is 4
	var state := _state(10000, 1, animals)
	var result: ActionResult = EconomyRules.check_buy_animal(state, "chicken", _catalog)
	assert_eq(result.code, ActionResult.Code.BUILDING_FULL)

func test_check_buy_animal_allows_buying_after_an_upgrade_raises_capacity() -> void:
	var animals: Array[AnimalInstance] = [
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a2"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a3"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a4"}),
	]
	var state := _state(10000, 1, animals, {"chicken_coop": 2})  # L2 capacity is 8
	assert_true(EconomyRules.check_buy_animal(state, "chicken", _catalog).ok())

func test_check_buy_animal_prioritizes_building_full_over_not_enough_coins() -> void:
	var animals: Array[AnimalInstance] = [
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a2"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a3"}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a4"}),
	]
	var state := _state(0, 1, animals)  # full AND unaffordable
	var result: ActionResult = EconomyRules.check_buy_animal(state, "chicken", _catalog)
	assert_eq(result.code, ActionResult.Code.BUILDING_FULL)

func test_check_buy_feed_pack_ok_when_affordable() -> void:
	var state := _state(25)
	assert_true(EconomyRules.check_buy_feed_pack(state, _catalog).ok())

func test_check_buy_feed_pack_refuses_not_enough_coins_with_the_shortfall() -> void:
	var state := _state(10)
	var result: ActionResult = EconomyRules.check_buy_feed_pack(state, _catalog)
	assert_false(result.ok())
	assert_eq(result.code, ActionResult.Code.NOT_ENOUGH_COINS)
	assert_eq(result.missing, 15)

func test_check_buy_feed_pack_refuses_storage_full_when_the_whole_pack_would_overflow() -> void:
	# refuseOverflowingFeedPack=true (fixture default): L1 cap is 100.
	# feed 95 + feedPackFeed 10 = 105 > 100 -> refuse the WHOLE pack.
	var state := _state(100, 1, [], {}, 95)
	var result: ActionResult = EconomyRules.check_buy_feed_pack(state, _catalog)
	assert_eq(result.code, ActionResult.Code.STORAGE_FULL)

func test_check_buy_feed_pack_allows_a_pack_that_exactly_fills_the_cap() -> void:
	var state := _state(100, 1, [], {}, 90)  # 90 + 10 = 100, exactly the cap
	assert_true(EconomyRules.check_buy_feed_pack(state, _catalog).ok())

func test_check_buy_feed_pack_allows_more_after_a_storage_upgrade() -> void:
	var state := _state(100, 1, [], {"feed_storage": 2}, 95)  # L2 cap 250
	assert_true(EconomyRules.check_buy_feed_pack(state, _catalog).ok())

func test_check_buy_feed_pack_prioritizes_not_enough_coins_over_storage_full() -> void:
	var state := _state(0, 1, [], {}, 95)  # unaffordable AND would overflow
	var result: ActionResult = EconomyRules.check_buy_feed_pack(state, _catalog)
	assert_eq(result.code, ActionResult.Code.NOT_ENOUGH_COINS)

func test_sale_total_with_no_bonus() -> void:
	assert_eq(EconomyRules.sale_total(5, 12, 0.0), 60)

func test_sale_total_applies_market_bonus_and_rounds_half_up() -> void:
	# 5 coins * 12 eggs = 60; +5% = 63.0 exactly.
	assert_eq(EconomyRules.sale_total(5, 12, 5.0), 63)
	# 5 * 13 = 65; +10% = 71.5 -> rounds up to 72 (half up).
	assert_eq(EconomyRules.sale_total(5, 13, 10.0), 72)

func test_sale_total_rounds_the_total_not_each_item() -> void:
	# unit price 3, qty 3 -> 9 total; +5% = 9.45 -> rounds to 9, not 10
	# (which per-item rounding of 3*1.05=3.15->3 each, times 3, would
	# also give 9 here -- use a case where per-item rounding would
	# differ: unit price 1, qty 3, bonus 50% -> total 1.5*3=4.5 rounds
	# to 5; per-item would round each 1*1.5=1.5 -> 2, times 3 = 6).
	assert_eq(EconomyRules.sale_total(1, 3, 50.0), 5, "Rounding the TOTAL (4.5 -> 5) should differ from rounding each item (1.5 -> 2, times 3 = 6)")

func test_sell_all_total_sums_every_product_in_the_bag() -> void:
	var inv := InventoryState.new()
	inv.add("egg", 12)
	inv.add("milk", 1)
	# 5*12 + 12*1 = 72, no bonus.
	assert_eq(EconomyRules.sell_all_total(inv, _catalog, 0.0), 72)

func test_sell_all_total_ignores_zero_quantity_products() -> void:
	var inv := InventoryState.new()
	inv.add("egg", 10)
	inv.add("milk", 0)
	inv.add("pork", 0)
	assert_eq(EconomyRules.sell_all_total(inv, _catalog, 0.0), 50)

func test_sell_all_total_is_zero_for_an_empty_bag() -> void:
	var inv := InventoryState.new()
	assert_eq(EconomyRules.sell_all_total(inv, _catalog, 0.0), 0)

func test_sell_all_total_applies_the_bonus_to_the_grand_total() -> void:
	var inv := InventoryState.new()
	inv.add("egg", 12)  # 60
	inv.add("milk", 1)  # 12
	# grand total 72, +10% = 79.2 -> rounds to 79.
	assert_eq(EconomyRules.sell_all_total(inv, _catalog, 10.0), 79)

func test_offline_coin_value_is_zero_for_an_empty_dictionary() -> void:
	assert_eq(EconomyRules.offline_coin_value({}, _catalog, 0.0), 0)

func test_offline_coin_value_ignores_zero_quantity_entries() -> void:
	assert_eq(EconomyRules.offline_coin_value({"egg": 0, "milk": 3}, _catalog, 0.0), 36)

func test_offline_coin_value_matches_sell_all_total_for_the_same_quantities() -> void:
	var inv := InventoryState.new()
	inv.add("egg", 12)
	inv.add("milk", 1)
	var via_sell_all: int = EconomyRules.sell_all_total(inv, _catalog, 10.0)
	var via_offline: int = EconomyRules.offline_coin_value({"egg": 12, "milk": 1}, _catalog, 10.0)
	assert_eq(via_offline, via_sell_all)

func test_offline_coin_value_applies_the_bonus_and_rounds_the_grand_total() -> void:
	# 12 eggs (60) + 1 milk (12) = 72, +10% = 79.2 -> rounds to 79.
	assert_eq(EconomyRules.offline_coin_value({"egg": 12, "milk": 1}, _catalog, 10.0), 79)
