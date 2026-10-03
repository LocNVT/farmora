extends GutTest

## Verifies SaveService's autosave debounce, synchronous save, retry
## schedule, and load_game() candidate-selection policy per docs/
## ARCHITECTURE.md Section 11.5/11.6. SaveService is an autoload
## singleton (same as Game), so every test carefully resets its mutable
## state (`io`, `persistence_enabled`, both timers) in before_each/
## after_each -- Phase 6's postmortem (docs/PROGRESS.md) found that a
## Timer left running by one test leaks into and corrupts a later,
## unrelated test in this exact codebase.

var _dir: String
var _real_io: SaveFileIO
var _catalog: GameCatalog
var _state: GameState

func before_each() -> void:
	_dir = "user://test_saves/save_service_" + str(Time.get_ticks_usec())
	_real_io = SaveFileIO.new(_dir)
	SaveService.io = _real_io
	SaveService.persistence_enabled = false
	SaveService._autosave_timer.stop()
	SaveService._retry_timer.stop()
	SaveService._retry_index = 0

	_catalog = StateFactory.fixture_catalog()
	_state = StateFactory.game_state_with([], 5, 0, 150, 1)
	SaveService.configure(_snapshot, _catalog)

func after_each() -> void:
	SaveService._autosave_timer.stop()
	SaveService._retry_timer.stop()
	SaveService._retry_index = 0
	SaveService.persistence_enabled = false
	SaveService.io = SaveFileIO.new()  # back to the real default dir, never test_saves

	for filename: String in [
		SaveFileIO.MAIN_FILENAME, SaveFileIO.TMP_FILENAME,
		SaveFileIO.BACKUP_FILENAME, SaveFileIO.DAMAGED_FILENAME,
	]:
		var path: String = _dir.path_join(filename)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(_dir)

func _snapshot() -> Dictionary:
	return SaveCodec.encode(_state)

func _main_path() -> String:
	return _dir.path_join(SaveFileIO.MAIN_FILENAME)

func _write_raw(filename: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(_dir.path_join(filename), FileAccess.WRITE)
	file.store_string(text)
	file.close()

# --- save_now() ---------------------------------------------------------

func test_save_now_with_persistence_disabled_is_a_no_op_returning_true() -> void:
	SaveService.persistence_enabled = false
	var ok: bool = SaveService.save_now()
	assert_true(ok)
	assert_false(FileAccess.file_exists(_main_path()), "A disabled SaveService must never write a file")

func test_save_now_writes_a_real_file_and_returns_true_when_enabled() -> void:
	SaveService.persistence_enabled = true
	var ok: bool = SaveService.save_now()
	assert_true(ok)
	assert_true(FileAccess.file_exists(_main_path()))

func test_save_now_emits_save_succeeded_with_manual_false_by_default() -> void:
	SaveService.persistence_enabled = true
	watch_signals(SaveService)
	SaveService.save_now()
	assert_signal_emitted_with_parameters(SaveService, "save_succeeded", [false])

func test_save_now_true_emits_save_succeeded_with_manual_true() -> void:
	SaveService.persistence_enabled = true
	watch_signals(SaveService)
	SaveService.save_now(true)
	assert_signal_emitted_with_parameters(SaveService, "save_succeeded", [true])

func test_save_now_with_failing_io_returns_false_emits_save_failed_and_does_not_crash() -> void:
	var failing := FailingSaveFileIO.new(_dir)
	failing.fail_write = true
	SaveService.io = failing
	SaveService.persistence_enabled = true
	watch_signals(SaveService)

	var ok: bool = SaveService.save_now()

	assert_false(ok)
	assert_signal_emitted_with_parameters(SaveService, "save_failed", [false])

# --- request_autosave() -------------------------------------------------

func test_request_autosave_with_persistence_disabled_does_not_start_the_timer() -> void:
	SaveService.persistence_enabled = false
	SaveService.request_autosave()
	assert_true(SaveService._autosave_timer.is_stopped(), "request_autosave() must do nothing while persistence is disabled")

func test_request_autosave_starts_the_debounce_timer() -> void:
	SaveService.persistence_enabled = true
	SaveService.request_autosave()
	assert_false(SaveService._autosave_timer.is_stopped())
	assert_almost_eq(SaveService._autosave_timer.wait_time, 2.0, 0.01)

func test_request_autosave_called_twice_does_not_restart_the_timer() -> void:
	# The debounce contract (ARCHITECTURE.md Section 11.6) is "starts the
	# 2s timer only if not already running" -- proven deterministically by
	# checking the timer did not reset its time_left, instead of
	# literally waiting out 2 real seconds.
	SaveService.persistence_enabled = true
	SaveService.request_autosave()
	var time_left_after_first: float = SaveService._autosave_timer.time_left
	SaveService.request_autosave()
	var time_left_after_second: float = SaveService._autosave_timer.time_left
	assert_almost_eq(time_left_after_first, time_left_after_second, 0.05, "A second request_autosave() while already running must not restart the timer")

# --- load_game() ---------------------------------------------------------

func test_load_game_on_empty_dir_returns_no_save() -> void:
	var result: LoadResult = SaveService.load_game()
	assert_eq(result.status, DecodeResult.Status.NO_SAVE)
	assert_null(result.state)

func test_load_game_after_successful_save_now_returns_ok_from_main() -> void:
	_state.player.coins = 321
	SaveService.persistence_enabled = true
	SaveService.save_now()

	var result: LoadResult = SaveService.load_game()
	assert_eq(result.status, DecodeResult.Status.OK)
	assert_eq(result.source, "main")
	assert_not_null(result.state)
	assert_eq(result.state.player.coins, 321, "The loaded state should round-trip the saved coins value")

func test_load_game_emits_load_finished_with_the_same_result() -> void:
	watch_signals(SaveService)
	SaveService.load_game()
	assert_signal_emitted(SaveService, "load_finished")

func test_load_game_falls_back_to_backup_when_main_is_damaged() -> void:
	SaveService.persistence_enabled = true
	_state.player.coins = 999
	SaveService.save_now()  # valid main, becomes the backup on the next write
	_state.player.coins = 1
	SaveService.save_now()  # main now holds coins=1, backup holds coins=999

	_write_raw(SaveFileIO.MAIN_FILENAME, "{not valid json")  # corrupt main directly

	var result: LoadResult = SaveService.load_game()
	assert_eq(result.status, DecodeResult.Status.OK)
	assert_eq(result.source, "backup")
	assert_eq(result.state.player.coins, 999)

func test_load_game_returns_damaged_when_nothing_decodes() -> void:
	_write_raw(SaveFileIO.MAIN_FILENAME, "{not valid json")
	_write_raw(SaveFileIO.BACKUP_FILENAME, "also not valid")

	var result: LoadResult = SaveService.load_game()
	assert_eq(result.status, DecodeResult.Status.DAMAGED)
	assert_null(result.state)

# --- start_new_farm_after_damage() --------------------------------------

func test_start_new_farm_after_damage_quarantines_main_and_enables_persistence() -> void:
	_write_raw(SaveFileIO.MAIN_FILENAME, "{not valid json")
	SaveService.persistence_enabled = false

	SaveService.start_new_farm_after_damage()

	assert_false(FileAccess.file_exists(_main_path()), "The damaged main should be moved out of the way")
	assert_true(FileAccess.file_exists(_dir.path_join(SaveFileIO.DAMAGED_FILENAME)))
	assert_true(SaveService.persistence_enabled, "A fresh game should be able to save normally after quarantine")
