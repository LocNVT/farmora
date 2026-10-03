extends GutTest

## Boots the real main.tscn and asserts it reaches a stable state without
## errors, per docs/ARCHITECTURE.md Section 19's one specified
## integration test. As of Phase 7, Main._ready() runs the real boot
## decision tree against SaveService.load_game() instead of the old
## Phase 2-6 "always fresh" seam (docs/PROGRESS.md "Phase 2 — Animals"),
## so these tests point SaveService.io at a throwaway directory BEFORE
## instantiating main.tscn to control which of the three boot branches
## (OK / NO_SAVE / DAMAGED-TOO_NEW) is exercised.

var _save_dir: String
var _real_save_io: SaveFileIO
var _main: Node

func before_each() -> void:
	_save_dir = "user://test_saves/main_boot_" + str(Time.get_ticks_usec())
	_real_save_io = SaveFileIO.new(_save_dir)
	SaveService.io = _real_save_io
	SaveService.persistence_enabled = false
	SaveService._autosave_timer.stop()
	SaveService._retry_timer.stop()
	SaveService._retry_index = 0

func after_each() -> void:
	# Main._ready() calls Game.begin_session(), which starts the real
	# SimTick Timer on the Game singleton -- it must not keep running
	# into later tests (Game outlives this scene across the whole suite).
	if is_instance_valid(Game._sim_tick):
		Game._sim_tick.stop()
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

func _instantiate_main() -> Node:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child_autofree(main)
	return main

func test_main_instantiates_without_error() -> void:
	_main = _instantiate_main()
	assert_not_null(_main)
	assert_true(is_instance_valid(_main))

func test_farm_world_is_present() -> void:
	_main = _instantiate_main()
	var farm_world: Node = _main.get_node_or_null("FarmWorld")
	assert_not_null(farm_world, "main.tscn should contain FarmWorld (docs/ARCHITECTURE.md Section 4.1)")
	assert_true(farm_world is FarmWorld, "The FarmWorld child should be an instance of the FarmWorld class")

func test_main_does_not_own_farm_world_internals() -> void:
	# Main owns application-level composition only; it must not reach
	# into FarmWorld's children directly (docs/PROGRESS.md Phase 1 Task 2
	# composition rule). This is a structural check: Main's script has no
	# @onready references into FarmWorld's named children.
	_main = _instantiate_main()
	var main_script: Script = _main.get_script()
	var source: String = main_script.source_code
	assert_false(source.contains("%Backdrop"), "Main should not reference FarmWorld's internal nodes directly")
	assert_false(source.contains("%BuildingSlots"), "Main should not reference FarmWorld's internal nodes directly")

func test_main_boot_leaves_a_sane_window_state() -> void:
	_main = _instantiate_main()
	var window := _main.get_window()
	assert_not_null(window, "Main scene should have a valid window after _ready()")
	var css := window.content_scale_size
	assert_true(css.x >= 0 and css.y >= 0, "Window content_scale_size should not be negative after _ready(); got " + str(css))

func test_boot_with_no_save_starts_a_fresh_session_and_enables_persistence() -> void:
	# NO_SAVE branch: the throwaway save dir is empty.
	_main = _instantiate_main()
	assert_not_null(Game.state, "Main._ready() should have called Game.begin_session()")
	assert_eq(Game.state.farm.animals.size(), 0, "A fresh NO_SAVE session starts with an empty farm")
	assert_true(SaveService.persistence_enabled, "NO_SAVE boots straight into saving -- no Play-gate in this no-UI scope")

func test_boot_with_a_valid_save_loads_it_and_enables_persistence() -> void:
	# OK branch: write a real save via SaveCodec/SaveFileIO before boot.
	var seeded := Game.new_game_state()
	seeded.player.coins = 777
	var json_text: String = JSON.stringify(SaveCodec.encode(seeded))
	_real_save_io.write_atomic(json_text)

	_main = _instantiate_main()
	assert_not_null(Game.state)
	assert_eq(Game.state.player.coins, 777, "A valid save's wallet should be loaded, not a fresh session's")
	assert_true(SaveService.persistence_enabled, "A clean OK boot should save normally going forward")

func test_boot_with_a_damaged_save_starts_fresh_in_memory_only_and_leaves_persistence_disabled() -> void:
	# DAMAGED branch: unparseable JSON as the only candidate (no backup).
	var file: FileAccess = FileAccess.open(_save_dir.path_join(SaveFileIO.MAIN_FILENAME), FileAccess.WRITE)
	file.store_string("{ not valid json")
	file.close()

	_main = _instantiate_main()
	assert_push_error("Main: save is DAMAGED -- starting a fresh in-memory session; the save file is left untouched")
	assert_not_null(Game.state, "A damaged save should still start a playable in-memory session")
	assert_eq(Game.state.farm.animals.size(), 0, "The in-memory fallback session is a fresh one")
	assert_false(SaveService.persistence_enabled, "A damaged save must never be silently overwritten by autosave")
	assert_true(FileAccess.file_exists(_save_dir.path_join(SaveFileIO.MAIN_FILENAME)), "The damaged file itself must be left untouched, not quarantined automatically")

func test_boot_with_a_too_new_save_starts_fresh_in_memory_only_and_leaves_persistence_disabled() -> void:
	var too_new: Dictionary = {
		"version": 99, "lastSeen": 0, "tutorialStep": 0,
		"wallet": {"coins": 0, "feed": 0, "xp": 0, "level": 1},
		"bag": {}, "buildings": [], "animals": [], "settings": {},
	}
	_real_save_io.write_atomic(JSON.stringify(too_new))

	_main = _instantiate_main()
	assert_push_error("Main: save is TOO_NEW -- starting a fresh in-memory session; the save file is left untouched")
	assert_not_null(Game.state)
	assert_false(SaveService.persistence_enabled, "A TOO_NEW save must never be overwritten")
	assert_true(FileAccess.file_exists(_save_dir.path_join(SaveFileIO.MAIN_FILENAME)), "The too-new file itself must be left untouched")

func test_app_backgrounded_notification_triggers_a_synchronous_save() -> void:
	_main = _instantiate_main()
	Game.state.player.coins = 42

	_main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)

	var result: LoadResult = SaveService.load_game()
	assert_eq(result.status, DecodeResult.Status.OK)
	assert_eq(result.state.player.coins, 42, "Backgrounding should synchronously save the current state")

func test_boot_with_a_qualifying_offline_window_holds_a_pending_report() -> void:
	# OK branch with a stale lastSeen: a fed chicken housed 3h ago should
	# complete at least one cycle during boot's own begin_session(now, true).
	var seeded := Game.new_game_state()
	seeded.farm.animals = [StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})]
	seeded.last_seen_ms = Time.get_unix_time_from_system() * 1000.0 - 3 * 3600000
	_real_save_io.write_atomic(JSON.stringify(SaveCodec.encode(seeded)))

	_main = _instantiate_main()

	assert_not_null(_main.pending_offline_report, "a qualifying offline window should be held for the not-yet-built modal")
	assert_true(_main.pending_offline_report.ready_animal_ids.has("a1"))

func test_boot_with_a_recent_lastseen_does_not_hold_a_pending_report() -> void:
	var seeded := Game.new_game_state()
	seeded.last_seen_ms = Time.get_unix_time_from_system() * 1000.0 - 1000  # 1s ago
	_real_save_io.write_atomic(JSON.stringify(SaveCodec.encode(seeded)))

	_main = _instantiate_main()

	assert_null(_main.pending_offline_report)

func test_boot_with_no_save_does_not_hold_a_pending_report() -> void:
	_main = _instantiate_main()
	assert_null(_main.pending_offline_report)

func test_app_resumed_notification_after_a_qualifying_gap_holds_a_pending_report() -> void:
	_main = _instantiate_main()
	Game.state.farm.animals = [StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})]
	Game.state.last_seen_ms = Game.clock.now_ms() - 3 * 3600000

	_main._notification(NOTIFICATION_APPLICATION_RESUMED)

	assert_not_null(_main.pending_offline_report)
	assert_true(_main.pending_offline_report.ready_animal_ids.has("a1"))

func test_app_resumed_notification_with_no_further_gap_does_not_overwrite_a_pending_report_with_an_empty_one() -> void:
	_main = _instantiate_main()
	Game.state.farm.animals = [StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})]
	Game.state.last_seen_ms = Game.clock.now_ms() - 3 * 3600000
	_main._notification(NOTIFICATION_APPLICATION_RESUMED)
	var first_report: OfflineReport = _main.pending_offline_report

	_main._notification(NOTIFICATION_APPLICATION_RESUMED)  # no further gap

	assert_eq(_main.pending_offline_report, first_report, "a second resume with nothing new to report must not clobber the still-pending one")
