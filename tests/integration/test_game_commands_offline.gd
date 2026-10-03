extends GutTest

## Verifies Game.collect_offline_reward() per docs/ARCHITECTURE.md
## Section 12.3: runs the normal per-animal collect logic for each
## ready_animal_ids entry (no debounce), credits the bag but never
## coins, saves synchronously, and tolerates a stale report.

var _save_dir: String
var _real_save_io: SaveFileIO
var _real_clock: GameClock
var _fake_clock: FakeClock

func before_each() -> void:
	_real_clock = Game.clock
	_fake_clock = FakeClock.new()
	Game.clock = _fake_clock
	Game.state = StateFactory.game_state_with([], 5, _fake_clock.now_ms(), 0, 1)

	_save_dir = "user://test_saves/offline_" + str(Time.get_ticks_usec())
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

func _ready_report(animal_ids: Array[String]) -> OfflineReport:
	var report := OfflineReport.new()
	report.ready_animal_ids = animal_ids
	return report

func test_collecting_a_ready_animal_credits_the_bag_and_resets_progress() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "progress": 1.0})
	Game.state.farm.animals.append(a)

	var result: ActionResult = Game.collect_offline_reward(_ready_report(["a1"]))

	assert_true(result.ok())
	assert_eq(Game.state.inventory.get_qty("egg"), 1)
	assert_almost_eq(a.progress, 0.0, 0.01)

func test_coins_are_never_credited_even_when_products_were_collected() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "progress": 1.0})
	Game.state.farm.animals.append(a)
	var coins_before: int = Game.state.player.coins

	Game.collect_offline_reward(_ready_report(["a1"]))

	assert_eq(Game.state.player.coins, coins_before, "GDD Section 9 rule 6: no coins are credited automatically")

func test_collecting_the_same_report_twice_only_credits_once() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "progress": 1.0})
	Game.state.farm.animals.append(a)
	var report: OfflineReport = _ready_report(["a1"])

	Game.collect_offline_reward(report)
	Game.collect_offline_reward(report)  # same report object, called again

	assert_eq(Game.state.inventory.get_qty("egg"), 1, "a second collect of the same already-collected animal should not double-credit")

func test_a_stale_unknown_animal_id_is_skipped_without_failing_the_batch() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "progress": 1.0})
	Game.state.farm.animals.append(a)

	var result: ActionResult = Game.collect_offline_reward(_ready_report(["a1", "does_not_exist"]))

	assert_true(result.ok())
	assert_eq(Game.state.inventory.get_qty("egg"), 1, "the real animal should still be collected")

func test_an_animal_not_actually_ready_is_skipped() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "progress": 0.2})
	Game.state.farm.animals.append(a)

	var result: ActionResult = Game.collect_offline_reward(_ready_report(["a1"]))

	assert_true(result.ok())
	assert_eq(Game.state.inventory.get_qty("egg"), 0)
	assert_almost_eq(a.progress, 0.2, 0.01, "a non-ready animal must not be mutated")

func test_the_save_is_on_disk_when_the_call_returns() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "progress": 1.0})
	Game.state.farm.animals.append(a)

	Game.collect_offline_reward(_ready_report(["a1"]))

	var loaded: LoadResult = SaveService.load_game()
	assert_eq(loaded.status, DecodeResult.Status.OK)
	assert_eq(loaded.state.inventory.get_qty("egg"), 1)

func test_a_save_failure_still_returns_ok_and_keeps_the_collected_products_in_memory() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "progress": 1.0})
	Game.state.farm.animals.append(a)

	var failing := FailingSaveFileIO.new(_save_dir)
	failing.fail_write = true
	SaveService.io = failing
	watch_signals(SaveService)

	var result: ActionResult = Game.collect_offline_reward(_ready_report(["a1"]))

	assert_true(result.ok(), "GDD Section 9 rule 7: play continues even if the save failed")
	assert_eq(Game.state.inventory.get_qty("egg"), 1, "a failed save must not roll back the in-memory collection -- there is nothing to roll back to")
	assert_signal_emitted_with_parameters(SaveService, "save_failed", [false])

func test_emits_the_full_signal_set_on_a_successful_collect() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "progress": 1.0})
	Game.state.farm.animals.append(a)

	Game.collect_offline_reward(_ready_report(["a1"]))

	assert_signal_emitted(Game, "product_collected")
	assert_signal_emitted(Game, "animal_changed")
	assert_signal_emitted(Game, "state_changed")

func test_an_empty_ready_list_does_not_save_or_emit_state_changed() -> void:
	Game.collect_offline_reward(_ready_report([]))
	assert_signal_not_emitted(Game, "state_changed")
	assert_false(FileAccess.file_exists(_save_dir.path_join(SaveFileIO.MAIN_FILENAME)), "nothing to collect should not write a save file")
