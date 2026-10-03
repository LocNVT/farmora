extends GutTest

## Verifies Game.sell_product()/sell_all() per docs/ARCHITECTURE.md
## Section 13.1/10.4's transaction order: debounce, refusal codes, the
## mutation + signal set on success. Swaps Game.clock for a FakeClock so
## the 300ms ActionGuard "sell" lock is deterministic.
##
## Uses Game.catalog (the real data/balance.json): egg 5 coins, milk 12,
## pork 30. Market bonus reads BuildingRules.sell_bonus_percent() --
## before_each() seeds the Market at level 1 (0% bonus) by default via
## StateFactory; individual tests override to a higher level to prove
## the retrofit.

var _fake_clock: FakeClock
var _real_clock: GameClock
var _real_save_io: SaveFileIO
var _save_dir: String

func before_each() -> void:
	_real_clock = Game.clock
	_fake_clock = FakeClock.new()
	Game.clock = _fake_clock
	Game._guard = ActionGuard.new()  # fresh lock state per test -- Game is a singleton, so the real guard persists across tests otherwise
	Game.state = StateFactory.game_state_with([], 5, 0, 0, 1)
	Game.state.inventory.add("egg", 12)
	Game.state.inventory.add("milk", 1)
	Game.state.inventory.add("pork", 0)

	# sell_product/sell_all save SYNCHRONOUSLY through SaveService
	# (ARCHITECTURE.md Section 10.4) -- SaveService is also a singleton,
	# so each test gets its own throwaway save directory and persistence
	# is reset to a clean, enabled state in before_each/disabled again in
	# after_each, matching Phase 6's leaked-autoload-state postmortem.
	_save_dir = "user://test_saves/sell_" + str(Time.get_ticks_usec())
	_real_save_io = SaveFileIO.new(_save_dir)
	SaveService.io = _real_save_io
	SaveService.persistence_enabled = true
	SaveService.configure(func() -> Dictionary: return SaveCodec.encode(Game.state), Game.catalog)
	SaveService._autosave_timer.stop()
	SaveService._retry_timer.stop()
	SaveService._retry_index = 0

	watch_signals(Game)

func after_each() -> void:
	Game.clock = _real_clock
	SaveService.persistence_enabled = false
	SaveService._autosave_timer.stop()
	SaveService._retry_timer.stop()
	SaveService._retry_index = 0
	SaveService.io = SaveFileIO.new()
	for filename: String in [
		SaveFileIO.MAIN_FILENAME, SaveFileIO.TMP_FILENAME,
		SaveFileIO.BACKUP_FILENAME, SaveFileIO.DAMAGED_FILENAME,
	]:
		var path: String = _save_dir.path_join(filename)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(_save_dir)

func test_sell_product_succeeds_and_mutates_state() -> void:
	var result: ActionResult = Game.sell_product("egg")
	assert_true(result.ok())
	assert_eq(Game.state.player.coins, 60)
	assert_eq(Game.state.inventory.get_qty("egg"), 0)

func test_sell_product_sells_the_whole_stack_not_a_partial_amount() -> void:
	Game.sell_product("egg")
	assert_eq(Game.state.inventory.get_qty("egg"), 0, "sell_product sells the ENTIRE stack (UI_SPEC Section 8.1/9), not a partial quantity")

func test_sell_product_emits_the_full_signal_set_on_success() -> void:
	Game.sell_product("egg")
	assert_signal_emitted(Game, "coins_changed")
	assert_signal_emitted_with_parameters(Game, "bag_changed", ["egg", 0, 12])
	assert_signal_emitted_with_parameters(Game, "products_sold", [{"egg": 12}, 60])
	assert_signal_emitted(Game, "state_changed")

func test_sell_product_refuses_nothing_to_sell_for_a_zero_quantity_product() -> void:
	var result: ActionResult = Game.sell_product("pork")
	assert_eq(result.code, ActionResult.Code.NOTHING_TO_SELL)
	assert_eq(Game.state.player.coins, 0)
	assert_signal_not_emitted(Game, "products_sold")

func test_sell_product_refuses_nothing_to_sell_for_an_unknown_product() -> void:
	var result: ActionResult = Game.sell_product("gem")
	assert_eq(result.code, ActionResult.Code.NOTHING_TO_SELL)

func test_sell_all_succeeds_and_sells_every_nonzero_product() -> void:
	var result: ActionResult = Game.sell_all()
	assert_true(result.ok())
	# 12*5 (egg) + 1*12 (milk) = 72, no bonus.
	assert_eq(Game.state.player.coins, 72)
	assert_eq(Game.state.inventory.get_qty("egg"), 0)
	assert_eq(Game.state.inventory.get_qty("milk"), 0)
	assert_eq(Game.state.inventory.get_qty("pork"), 0)

func test_sell_all_emits_the_full_signal_set_on_success() -> void:
	Game.sell_all()
	assert_signal_emitted(Game, "coins_changed")
	assert_signal_emitted(Game, "bag_changed")
	assert_signal_emitted_with_parameters(Game, "products_sold", [{"egg": 12, "milk": 1}, 72])
	assert_signal_emitted(Game, "state_changed")

func test_sell_all_emits_bag_changed_once_per_sold_product_with_its_own_quantities() -> void:
	# Codex Phase 5 review F-01: the previous test only checked that
	# bag_changed fired at all, not that each of the TWO emissions
	# (egg, milk) carries that product's own before/after quantity, not
	# a stale or shared value from the other product.
	Game.sell_all()
	assert_signal_emit_count(Game, "bag_changed", 2, "sell_all should emit bag_changed once per nonzero product sold (egg, milk) -- pork is 0 and must not emit")
	assert_signal_emitted_with_parameters(Game, "bag_changed", ["egg", 0, 12], 0)
	assert_signal_emitted_with_parameters(Game, "bag_changed", ["milk", 0, 1], 1)

func test_sell_all_refuses_nothing_to_sell_on_an_empty_bag() -> void:
	Game.state.inventory.remove("egg", 12)
	Game.state.inventory.remove("milk", 1)
	var result: ActionResult = Game.sell_all()
	assert_eq(result.code, ActionResult.Code.NOTHING_TO_SELL)
	assert_eq(Game.state.player.coins, 0)

func test_second_sell_within_debounce_window_is_refused_and_emits_nothing() -> void:
	Game.sell_product("egg")
	clear_signal_watcher()
	watch_signals(Game)
	var result: ActionResult = Game.sell_product("milk")
	assert_eq(result.code, ActionResult.Code.DEBOUNCED)
	assert_signal_not_emitted(Game, "products_sold")
	assert_eq(Game.state.inventory.get_qty("milk"), 1, "The debounced sell must not have touched milk")

func test_sell_is_allowed_again_after_the_lock_window_elapses() -> void:
	Game.sell_product("egg")
	_fake_clock.advance(300)
	var result: ActionResult = Game.sell_product("milk")
	assert_true(result.ok())

func test_a_refused_sell_does_not_consume_the_debounce_lock() -> void:
	Game.state.inventory.remove("egg", 12)  # egg now 0 -> NOTHING_TO_SELL
	Game.sell_product("egg")
	var result: ActionResult = Game.sell_product("milk")  # same mono tick -- must not be DEBOUNCED
	assert_true(result.ok())

func test_sell_and_buy_do_not_share_a_debounce_key() -> void:
	# "sell" and "purchase" are documented as SEPARATE ActionGuard keys
	# (ARCHITECTURE.md Section 10.4) -- a sale must not lock out a buy.
	Game.state.player.coins = 200
	Game.sell_product("egg")
	var result: ActionResult = Game.buy_feed_pack()
	assert_true(result.ok(), "buy_feed_pack should not be blocked by sell_product's own 'sell' key commit")

func test_full_loop_buy_feed_collect_sell() -> void:
	# End-to-end integration: buy a chicken, feed it, let production
	# complete via FakeClock, collect the egg, then sell it. Reset the
	# bag to zero first -- before_each() seeds 12 eggs/1 milk for the
	# OTHER sell tests in this file, which this full-loop test doesn't
	# want as a baseline.
	Game.state.inventory.remove("egg", 12)
	Game.state.inventory.remove("milk", 1)
	Game.state.player.coins = 200
	Game.state.player.feed = 5
	var buy_result: ActionResult = Game.buy_animal("chicken")
	assert_true(buy_result.ok())
	var animal_id: String = buy_result.data.get("animal_id")

	_fake_clock.advance(301)  # clear the shared "purchase"/debounce window
	var feed_result: ActionResult = Game.feed_animal(animal_id)
	assert_true(feed_result.ok())

	# Chicken cycle is 180s (cycleMinutes 3); hunger was just refilled to
	# 100 by the feed above, so it stays fed for the whole advance.
	_fake_clock.advance(180 * 1000)
	Game._advance_to(_fake_clock.now_ms())
	var animal: AnimalInstance = Game.state.farm.get_animal(animal_id)
	assert_almost_eq(animal.progress, 1.0, 0.01, "Precondition: the chicken should be READY after one full cycle")

	var collect_result: ActionResult = Game.collect(animal_id)
	assert_true(collect_result.ok())
	assert_eq(Game.state.inventory.get_qty("egg"), 1)

	_fake_clock.advance(301)  # clear the shared debounce window again
	var sell_result: ActionResult = Game.sell_product("egg")
	assert_true(sell_result.ok())
	assert_eq(Game.state.inventory.get_qty("egg"), 0)
	# 200 (start) - 100 (chicken) - 25 (feed pack NOT bought, only feed_animal spent 1 feed) + 5 (egg sale)
	assert_eq(Game.state.player.coins, 105, "200 - 100 (chicken) + 5 (egg sale) = 105")

func test_sell_product_applies_the_market_buildings_sell_bonus() -> void:
	# Live market L2 bonus is 5%. 12 eggs * 5 coins = 60; +5% = 63.0 exactly.
	Game.state.farm.buildings = [StateFactory.building("market", 2)]
	var result: ActionResult = Game.sell_product("egg")
	assert_true(result.ok())
	assert_eq(Game.state.player.coins, 63)

func test_sell_all_applies_the_market_buildings_sell_bonus_to_the_grand_total() -> void:
	# 12*5 (egg) + 1*12 (milk) = 72 grand total; L3 bonus is 10% -> 79.2 -> 79.
	Game.state.farm.buildings = [StateFactory.building("market", 3)]
	var result: ActionResult = Game.sell_all()
	assert_true(result.ok())
	assert_eq(Game.state.player.coins, 79)

func test_sell_product_success_saves_synchronously_via_save_service() -> void:
	# ARCHITECTURE.md Section 10.4: sell_product saves SYNCHRONOUSLY --
	# the save file must exist immediately after the call returns, no
	# waiting for the 2s autosave debounce.
	var result: ActionResult = Game.sell_product("egg")
	assert_true(result.ok())
	assert_true(FileAccess.file_exists(_save_dir.path_join(SaveFileIO.MAIN_FILENAME)), "sell_product should have written the save file synchronously, before returning")

func test_sell_all_success_saves_synchronously_via_save_service() -> void:
	var result: ActionResult = Game.sell_all()
	assert_true(result.ok())
	assert_true(FileAccess.file_exists(_save_dir.path_join(SaveFileIO.MAIN_FILENAME)), "sell_all should have written the save file synchronously, before returning")

func test_sell_product_with_a_forced_save_failure_returns_save_failed_and_rolls_back() -> void:
	var failing := FailingSaveFileIO.new(_save_dir)
	failing.fail_write = true
	SaveService.io = failing

	var result: ActionResult = Game.sell_product("egg")

	assert_eq(result.code, ActionResult.Code.SAVE_FAILED)
	assert_eq(Game.state.player.coins, 0, "Coins must be rolled back to the pre-sale value")
	assert_eq(Game.state.inventory.get_qty("egg"), 12, "Inventory must be rolled back to the pre-sale value")
	assert_signal_not_emitted(Game, "coins_changed")
	assert_signal_not_emitted(Game, "bag_changed")
	assert_signal_not_emitted(Game, "products_sold")
	assert_signal_not_emitted(Game, "state_changed")

func test_sell_all_with_a_forced_save_failure_returns_save_failed_and_rolls_back() -> void:
	var failing := FailingSaveFileIO.new(_save_dir)
	failing.fail_write = true
	SaveService.io = failing

	var result: ActionResult = Game.sell_all()

	assert_eq(result.code, ActionResult.Code.SAVE_FAILED)
	assert_eq(Game.state.player.coins, 0, "Coins must be rolled back to the pre-sale value")
	assert_eq(Game.state.inventory.get_qty("egg"), 12, "Inventory must be rolled back to the pre-sale value")
	assert_eq(Game.state.inventory.get_qty("milk"), 1, "Inventory must be rolled back to the pre-sale value")
	assert_signal_not_emitted(Game, "coins_changed")
	assert_signal_not_emitted(Game, "bag_changed")
	assert_signal_not_emitted(Game, "products_sold")
	assert_signal_not_emitted(Game, "state_changed")

func test_sell_product_failure_still_lets_save_service_emit_save_failed_and_schedule_a_retry() -> void:
	# The Phase 7 planning note: Game does not need to do anything extra
	# for the retry schedule -- SaveService's own save_now() failure
	# handling (emit save_failed, start the retry timer) already ran by
	# the time sell_product returns SAVE_FAILED.
	var failing := FailingSaveFileIO.new(_save_dir)
	failing.fail_write = true
	SaveService.io = failing
	watch_signals(SaveService)

	Game.sell_product("egg")

	assert_signal_emitted_with_parameters(SaveService, "save_failed", [false])
	assert_false(SaveService._retry_timer.is_stopped(), "A failed synchronous save should have started SaveService's own retry schedule")
