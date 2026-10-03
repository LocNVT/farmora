extends GutTest

## Verifies SaveFileIO's atomic write/read-candidates/quarantine contract
## per docs/ARCHITECTURE.md Section 11.5. Each test uses a fresh throwaway
## directory under user://test_saves so tests never collide or depend on
## real save state, and after_each removes every known filename plus the
## directory itself.

var _io: SaveFileIO
var _dir: String

func before_each() -> void:
	_dir = "user://test_saves/save_file_io_" + str(Time.get_ticks_usec())
	_io = SaveFileIO.new(_dir)

func after_each() -> void:
	for filename: String in [
		SaveFileIO.MAIN_FILENAME, SaveFileIO.TMP_FILENAME,
		SaveFileIO.BACKUP_FILENAME, SaveFileIO.DAMAGED_FILENAME,
	]:
		var path: String = _dir.path_join(filename)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(_dir)

func test_write_atomic_on_fresh_dir_creates_main_and_round_trips_content() -> void:
	var json_text: String = JSON.stringify({"version": 1, "coins": 150})
	var err: Error = _io.write_atomic(json_text)
	assert_eq(err, OK)
	var main_path: String = _dir.path_join(SaveFileIO.MAIN_FILENAME)
	assert_true(FileAccess.file_exists(main_path))
	var file: FileAccess = FileAccess.open(main_path, FileAccess.READ)
	var read_text: String = file.get_as_text()
	file.close()
	assert_eq(read_text, json_text)

func test_write_atomic_called_twice_backs_up_the_first_writes_content() -> void:
	var first_text: String = JSON.stringify({"version": 1, "coins": 100})
	var second_text: String = JSON.stringify({"version": 1, "coins": 200})
	_io.write_atomic(first_text)
	_io.write_atomic(second_text)

	var backup_path: String = _dir.path_join(SaveFileIO.BACKUP_FILENAME)
	assert_true(FileAccess.file_exists(backup_path))
	var file: FileAccess = FileAccess.open(backup_path, FileAccess.READ)
	var backup_text: String = file.get_as_text()
	file.close()
	assert_eq(backup_text, first_text, "The backup should hold the FIRST write's content, not the second")

	var main_path: String = _dir.path_join(SaveFileIO.MAIN_FILENAME)
	var main_file: FileAccess = FileAccess.open(main_path, FileAccess.READ)
	var main_text: String = main_file.get_as_text()
	main_file.close()
	assert_eq(main_text, second_text, "Main should hold the SECOND write's content")

func test_write_atomic_round_trip_matches_its_own_json_validation_step() -> void:
	# write_atomic's documented contract (Section 11.5 step 2) reads its own
	# .tmp back and JSON.parse's it before promoting to main, stopping (and
	# leaving main untouched) if it does not parse. Since write_atomic's
	# input is always a json_text string produced by the caller (SaveCodec),
	# there is no way to feed it an unparseable intermediate .tmp from
	# outside -- this test instead confirms the positive side of that
	# contract: a valid write always produces a main file whose content is
	# valid, parseable JSON equal to the input.
	var json_text: String = JSON.stringify({"version": 1, "wallet": {"coins": 50}})
	var err: Error = _io.write_atomic(json_text)
	assert_eq(err, OK)
	var main_path: String = _dir.path_join(SaveFileIO.MAIN_FILENAME)
	var file: FileAccess = FileAccess.open(main_path, FileAccess.READ)
	var main_text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(main_text)
	assert_not_null(parsed, "Main's content must always be parseable JSON after a successful write_atomic")
	assert_eq(main_text, json_text, "write_atomic must leave main exactly equal to the validated input on success")

func test_read_candidates_on_empty_dir_returns_empty_array() -> void:
	var candidates: Array[Dictionary] = _io.read_candidates()
	assert_eq(candidates.size(), 0)

func test_read_candidates_after_one_write_returns_only_main() -> void:
	var json_text: String = JSON.stringify({"version": 1})
	_io.write_atomic(json_text)
	var candidates: Array[Dictionary] = _io.read_candidates()
	assert_eq(candidates.size(), 1)
	assert_eq(candidates[0]["source"], "main")
	assert_eq(candidates[0]["text"], json_text)

func test_read_candidates_surfaces_tmp_and_backup_files_placed_directly() -> void:
	# Simulates a crash mid-save (a leftover .tmp) and an existing backup,
	# with main absent -- read_candidates() must surface whatever raw text
	# exists on disk without deciding which one to trust.
	var tmp_text: String = JSON.stringify({"version": 1, "from": "tmp"})
	var backup_text: String = JSON.stringify({"version": 1, "from": "backup"})

	var tmp_file: FileAccess = FileAccess.open(_dir.path_join(SaveFileIO.TMP_FILENAME), FileAccess.WRITE)
	tmp_file.store_string(tmp_text)
	tmp_file.close()

	var backup_file: FileAccess = FileAccess.open(_dir.path_join(SaveFileIO.BACKUP_FILENAME), FileAccess.WRITE)
	backup_file.store_string(backup_text)
	backup_file.close()

	var candidates: Array[Dictionary] = _io.read_candidates()
	assert_eq(candidates.size(), 2)
	assert_eq(candidates[0]["source"], "tmp")
	assert_eq(candidates[0]["text"], tmp_text)
	assert_eq(candidates[1]["source"], "backup")
	assert_eq(candidates[1]["text"], backup_text)

func test_quarantine_damaged_renames_main_and_main_no_longer_exists() -> void:
	var json_text: String = JSON.stringify({"version": 1, "damaged": true})
	_io.write_atomic(json_text)
	var err: Error = _io.quarantine_damaged()
	assert_eq(err, OK)

	var main_path: String = _dir.path_join(SaveFileIO.MAIN_FILENAME)
	assert_false(FileAccess.file_exists(main_path), "Main should no longer exist after quarantine")

	var damaged_path: String = _dir.path_join(SaveFileIO.DAMAGED_FILENAME)
	assert_true(FileAccess.file_exists(damaged_path))
	var file: FileAccess = FileAccess.open(damaged_path, FileAccess.READ)
	var damaged_text: String = file.get_as_text()
	file.close()
	assert_eq(damaged_text, json_text)

	var candidates: Array[Dictionary] = _io.read_candidates()
	assert_eq(candidates.size(), 0, "read_candidates only looks at main/tmp/backup, not the damaged file")

func test_quarantine_damaged_on_dir_with_no_main_is_a_no_op() -> void:
	var err: Error = _io.quarantine_damaged()
	assert_eq(err, OK)
	var damaged_path: String = _dir.path_join(SaveFileIO.DAMAGED_FILENAME)
	assert_false(FileAccess.file_exists(damaged_path))
