extends GutTest

## Verifies the Game autoload's thin Phase 2 slice: catalog loads at
## _ready(), new_game_state() starts empty, begin_session() sets state
## and emits state_loaded. Per docs/ARCHITECTURE.md Section 5's
## dependency rule, this never assigns Game.state directly -- only
## through begin_session(), same as production code must.

func before_each() -> void:
	watch_signals(Game)

func test_game_catalog_is_loaded_after_ready() -> void:
	assert_not_null(Game.catalog, "Game.catalog should be loaded by _ready()")
	assert_eq(Game.catalog.animal_ids().size(), 3)

func test_new_game_state_starts_with_zero_animals() -> void:
	var state: GameState = Game.new_game_state()
	assert_eq(state.farm.animals.size(), 0, "GDD Section 2/8: a fresh game starts with no animals")

func test_new_game_state_seeds_feed_from_catalog_start() -> void:
	var state: GameState = Game.new_game_state()
	assert_eq(state.player.feed, Game.catalog.start.feed, "A fresh game's starting feed should come from balance.json's start group")

func test_new_game_state_seeds_zero_inventory_for_every_catalog_product() -> void:
	var state: GameState = Game.new_game_state()
	for product_id: String in Game.catalog.product_ids():
		assert_eq(state.inventory.get_qty(product_id), 0, "Product '%s' should start at 0, not be missing" % product_id)

func test_new_game_state_seeds_coins_from_catalog_start() -> void:
	var state: GameState = Game.new_game_state()
	assert_eq(state.player.coins, Game.catalog.start.coins, "A fresh game's starting coins should come from balance.json's start group")

func test_new_game_state_seeds_level_from_catalog_start() -> void:
	var state: GameState = Game.new_game_state()
	assert_eq(state.player.level, Game.catalog.start.level, "A fresh game's starting level should come from balance.json's start group")

func test_new_game_state_creates_a_level_1_instance_for_every_starts_built_building() -> void:
	var state: GameState = Game.new_game_state()
	for building_id: String in Game.catalog.building_ids():
		if Game.catalog.building(building_id).starts_built:
			var instance: BuildingInstance = state.farm.get_building(building_id)
			assert_not_null(instance, "Building '%s' should exist at session start" % building_id)
			assert_eq(instance.level, 1)

func test_new_game_state_creates_exactly_five_buildings() -> void:
	# GDD Section 6: "Six buildings. Farm is the world itself ... The
	# other five have three levels" -- all five start_built, per the
	# live/fixture balance.json.
	var state: GameState = Game.new_game_state()
	assert_eq(state.farm.buildings.size(), 5)

func test_new_game_state_stamps_last_seen_ms_to_now() -> void:
	var before: int = Game.clock.now_ms()
	var state: GameState = Game.new_game_state()
	var after: int = Game.clock.now_ms()
	assert_true(state.last_seen_ms >= before and state.last_seen_ms <= after, "A fresh game's last_seen_ms should be stamped to roughly now, not left at 0")

func test_begin_session_sets_state_and_emits_state_loaded() -> void:
	var fresh: GameState = Game.new_game_state()
	Game.begin_session(fresh)
	assert_eq(Game.state, fresh)
	assert_signal_emitted(Game, "state_loaded")
	Game._sim_tick.stop()  # Game is a singleton -- a left-running SimTick leaks into every later test

func test_begin_session_starts_the_sim_tick_timer() -> void:
	# ARCHITECTURE.md Section 13.1: "A child Timer 'SimTick' ...
	# autostart only once a session begins." _sim_tick is created in
	# _ready() but must not be running before a session exists.
	Game._sim_tick.stop()
	Game.begin_session(Game.new_game_state())
	assert_false(Game._sim_tick.is_stopped(), "begin_session() should start the SimTick timer")
	Game._sim_tick.stop()  # don't leave it running into later tests

func test_begin_session_advances_to_now_so_a_held_state_is_not_stale() -> void:
	var fresh: GameState = Game.new_game_state()
	fresh.farm.animals = [StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})]
	fresh.last_seen_ms = Game.clock.now_ms() - 60000  # 60s "ago"
	Game.begin_session(fresh)
	assert_almost_eq(Game.state.farm.get_animal("a1").hunger, 99.0, 0.5, "begin_session should advance production for the elapsed time before anything else reads the state")
	Game._sim_tick.stop()

func test_begin_session_emits_offline_progress_applied_as_a_return() -> void:
	# ARCHITECTURE.md Section 12.2: "Launch with a save... is_return = true".
	var fresh: GameState = Game.new_game_state()
	fresh.last_seen_ms = Game.clock.now_ms() - 3600000  # 1h "ago"
	Game.begin_session(fresh)
	assert_signal_emitted(Game, "offline_progress_applied")
	Game._sim_tick.stop()

func test_on_app_resumed_does_nothing_when_no_session_has_started() -> void:
	var saved_state: GameState = Game.state
	Game.state = null
	Game.on_app_resumed()  # must not crash
	assert_null(Game.state, "on_app_resumed() must not create a session on its own")
	Game.state = saved_state

func test_on_app_resumed_after_a_qualifying_gap_emits_offline_progress_applied() -> void:
	var fresh: GameState = Game.new_game_state()
	Game.begin_session(fresh)
	Game.state.last_seen_ms = Game.clock.now_ms() - 600000  # 10 min "ago"
	clear_signal_watcher()  # discard begin_session's own return emission before re-watching
	watch_signals(Game)

	Game.on_app_resumed()

	assert_signal_emitted(Game, "offline_progress_applied")
	Game._sim_tick.stop()

func test_on_app_resumed_called_again_immediately_does_not_qualify_for_a_second_modal() -> void:
	# offline_progress_applied itself always fires on a return
	# (ARCHITECTURE.md Section 12.2's own pseudocode: "if is_return:
	# offline_progress_applied.emit(report)", unconditionally) -- it is
	# should_show_modal() that decides whether THAT report is worth
	# displaying. A second resume right away has no further gap to
	# report, so its report must not qualify for a modal.
	var fresh: GameState = Game.new_game_state()
	Game.begin_session(fresh)
	Game.state.last_seen_ms = Game.clock.now_ms() - 600000
	Game.on_app_resumed()
	clear_signal_watcher()  # discard the FIRST on_app_resumed's own emission before re-watching
	watch_signals(Game)

	Game.on_app_resumed()  # no further gap

	var emitted: Array = get_signal_parameters(Game, "offline_progress_applied")
	assert_not_null(emitted, "on_app_resumed always emits, per Section 12.2's pseudocode")
	var report: OfflineReport = emitted[0]
	assert_false(OfflineRules.should_show_modal(report, Game.catalog), "a second resume right away should never qualify for a modal")
	Game._sim_tick.stop()

func test_sim_tick_with_a_normal_1s_gap_does_not_emit_offline_progress_applied() -> void:
	Game.begin_session(Game.new_game_state())
	Game.state.last_seen_ms = Game.clock.now_ms()  # as if the last tick/command just ran
	clear_signal_watcher()  # discard begin_session's own return emission before re-watching
	watch_signals(Game)
	Game._on_sim_tick_timeout()
	assert_signal_not_emitted(Game, "offline_progress_applied")
	Game._sim_tick.stop()

func test_sim_tick_with_a_gap_exceeding_the_modal_threshold_emits_offline_progress_applied() -> void:
	Game.begin_session(Game.new_game_state())
	Game.state.last_seen_ms = Game.clock.now_ms() - 600000  # 10 min "ago"
	clear_signal_watcher()  # discard begin_session's own return emission before re-watching
	watch_signals(Game)
	Game._on_sim_tick_timeout()
	assert_signal_emitted(Game, "offline_progress_applied")
	Game._sim_tick.stop()

func test_sim_tick_with_a_backwards_clock_does_not_emit_offline_progress_applied() -> void:
	Game.begin_session(Game.new_game_state())
	Game.state.last_seen_ms = Game.clock.now_ms() + 600000  # 10 min "in the future"
	clear_signal_watcher()  # discard begin_session's own return emission before re-watching
	watch_signals(Game)
	Game._on_sim_tick_timeout()
	assert_signal_not_emitted(Game, "offline_progress_applied")
	Game._sim_tick.stop()
