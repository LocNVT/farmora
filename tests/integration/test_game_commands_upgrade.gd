extends GutTest

## Verifies Game.upgrade_building() per docs/ARCHITECTURE.md Section
## 13.1/10.4's transaction order: debounce, refusal codes, the mutation
## + signal set on success. Swaps Game.clock for a FakeClock so the
## 300ms ActionGuard "purchase" lock is deterministic.
##
## Uses Game.catalog (the real data/balance.json): chicken_coop L2
## costs 500, L3 costs 1500.

var _fake_clock: FakeClock
var _real_clock: GameClock

func before_each() -> void:
	_real_clock = Game.clock
	_fake_clock = FakeClock.new()
	Game.clock = _fake_clock
	Game._guard = ActionGuard.new()  # fresh lock state per test -- Game is a singleton, so the real guard persists across tests otherwise
	Game.state = StateFactory.game_state_with([], 5, 0, 1000, 1)
	SaveService._autosave_timer.stop()  # SaveService is also a singleton -- a left-running debounce timer leaks into later tests
	SaveService.persistence_enabled = true
	watch_signals(Game)

func after_each() -> void:
	Game.clock = _real_clock
	SaveService._autosave_timer.stop()
	SaveService.persistence_enabled = false

func test_upgrade_building_succeeds_and_mutates_state() -> void:
	var result: ActionResult = Game.upgrade_building("chicken_coop")
	assert_true(result.ok())
	assert_eq(Game.state.player.coins, 500)  # 1000 - 500 (L2 cost)
	assert_eq(Game.state.farm.get_building("chicken_coop").level, 2)

func test_upgrade_building_emits_the_full_signal_set_on_success() -> void:
	Game.upgrade_building("chicken_coop")
	assert_signal_emitted(Game, "coins_changed")
	assert_signal_emitted_with_parameters(Game, "building_upgraded", ["chicken_coop", 2])
	assert_signal_emitted(Game, "state_changed")

func test_upgrade_building_refuses_unknown_building() -> void:
	var result: ActionResult = Game.upgrade_building("silo")
	assert_eq(result.code, ActionResult.Code.UNKNOWN_ID)
	assert_eq(Game.state.player.coins, 1000)

func test_upgrade_building_refuses_max_level_without_mutating_state() -> void:
	Game.state.farm.buildings = [StateFactory.building("chicken_coop", 3)]
	var result: ActionResult = Game.upgrade_building("chicken_coop")
	assert_eq(result.code, ActionResult.Code.MAX_LEVEL)
	assert_eq(Game.state.player.coins, 1000)
	assert_signal_not_emitted(Game, "building_upgraded")

func test_upgrade_building_refuses_not_enough_coins_with_the_shortfall() -> void:
	Game.state.player.coins = 100
	var result: ActionResult = Game.upgrade_building("chicken_coop")
	assert_eq(result.code, ActionResult.Code.NOT_ENOUGH_COINS)
	assert_eq(result.missing, 400)
	assert_eq(Game.state.player.coins, 100)
	assert_signal_not_emitted(Game, "building_upgraded")

func test_upgrading_twice_reaches_level_3() -> void:
	Game.state.player.coins = 3000  # enough for L2 (500) + L3 (1500)
	Game.upgrade_building("chicken_coop")
	_fake_clock.advance(301)
	var result: ActionResult = Game.upgrade_building("chicken_coop")
	assert_true(result.ok())
	assert_eq(Game.state.farm.get_building("chicken_coop").level, 3)
	assert_eq(Game.state.player.coins, 3000 - 500 - 1500, "coins should reflect both upgrade costs")

func test_upgrade_building_shares_the_purchase_debounce_key_with_buy_animal() -> void:
	# ARCHITECTURE.md Section 10.4 ADR-13: "buy animal, buy feed pack,
	# upgrade" all share one key, so a double tap cannot buy/upgrade two
	# different things.
	Game.upgrade_building("chicken_coop")
	var result: ActionResult = Game.buy_animal("chicken")
	assert_eq(result.code, ActionResult.Code.DEBOUNCED, "buy_animal should be locked out by upgrade_building's own purchase-key commit")

func test_second_upgrade_within_debounce_window_is_refused_and_emits_nothing() -> void:
	# Tap the SAME upgrade twice in a row (coins would allow it, but the
	# debounce lock must refuse the second tap regardless).
	Game.state.player.coins = 3000  # enough for two L2-cost taps, so DEBOUNCED is the only reason for refusal
	Game.upgrade_building("chicken_coop")
	clear_signal_watcher()
	watch_signals(Game)
	var result: ActionResult = Game.upgrade_building("chicken_coop")
	assert_eq(result.code, ActionResult.Code.DEBOUNCED)
	assert_signal_not_emitted(Game, "building_upgraded")
	assert_eq(Game.state.farm.get_building("chicken_coop").level, 2, "The debounced second upgrade must not have applied")

func test_upgrade_is_allowed_again_after_the_lock_window_elapses() -> void:
	Game.state.player.coins = 3000
	Game.upgrade_building("chicken_coop")
	_fake_clock.advance(300)
	var result: ActionResult = Game.upgrade_building("chicken_coop")
	assert_true(result.ok())

func test_a_refused_upgrade_does_not_consume_the_debounce_lock() -> void:
	Game.state.player.coins = 0
	Game.upgrade_building("chicken_coop")  # refused: NOT_ENOUGH_COINS
	Game.state.player.coins = 1000
	var result: ActionResult = Game.upgrade_building("chicken_coop")  # same mono tick -- must not be DEBOUNCED
	assert_true(result.ok())

func test_upgrade_building_advances_production_before_mutating() -> void:
	# ARCHITECTURE.md Section 14: "Order matters" -- every command calls
	# _advance_to(now) before it mutates.
	Game.state.farm.animals = [StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})]
	Game.state.last_seen_ms = 0
	_fake_clock.set_now_ms(60000)  # 60s elapsed, hungerDecayPerMinute=1 -> -1 hunger
	Game.upgrade_building("chicken_coop")
	var a1: AnimalInstance = Game.state.farm.get_animal("a1")
	assert_almost_eq(a1.hunger, 99.0, 0.01)

func test_upgrade_building_success_triggers_save_services_autosave_debounce() -> void:
	var result: ActionResult = Game.upgrade_building("chicken_coop")
	assert_true(result.ok())
	assert_false(SaveService._autosave_timer.is_stopped(), "A successful upgrade_building should start SaveService's autosave debounce timer")
