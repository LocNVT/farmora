class_name SaveFileIO extends RefCounted

## Atomic file I/O for the save system, per docs/ARCHITECTURE.md Section 11.5.
## This class only moves bytes around: it never parses/decodes the save
## schema (that's SaveCodec) and never decides which candidate to trust on
## load (that's SaveService.load_game(), per the Section 11.5 Load order
## table). It just writes safely and surfaces whatever raw text exists.

const MAIN_FILENAME := "farmora_save.json"
const TMP_FILENAME := "farmora_save.json.tmp"
const BACKUP_FILENAME := "farmora_save.bak.json"
const DAMAGED_FILENAME := "farmora_save.damaged.json"

var _dir: String

func _init(dir: String = "user://save") -> void:
	_dir = dir
	DirAccess.make_dir_recursive_absolute(_dir)

func _main_path() -> String:
	return _dir.path_join(MAIN_FILENAME)

func _tmp_path() -> String:
	return _dir.path_join(TMP_FILENAME)

func _backup_path() -> String:
	return _dir.path_join(BACKUP_FILENAME)

func _damaged_path() -> String:
	return _dir.path_join(DAMAGED_FILENAME)

## Writes json_text to disk following the write-then-rename sequence from
## ARCHITECTURE.md Section 11.5:
## 1. Write to .tmp, flush and close; check for open/write errors.
## 2. Read .tmp back and JSON.parse it; abort (leaving main untouched) if
##    it does not parse.
## 3. If main exists, copy main -> .bak.json (exactly one backup kept).
## 4. Rename .tmp -> main (atomic replace on Android/iOS; remove-then-rename
##    fallback for desktop/editor use).
func write_atomic(json_text: String) -> Error:
	var tmp_path: String = _tmp_path()

	# Step 1: write to tmp, flush and close.
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	var open_err: Error = FileAccess.get_open_error()
	if file == null:
		return open_err if open_err != OK else ERR_CANT_CREATE
	file.store_string(json_text)
	file.flush()
	var write_err: Error = file.get_error()
	file.close()
	if write_err != OK:
		return write_err

	# Step 2: read tmp back and verify it parses as JSON. Leave main
	# untouched if it does not.
	var readback: FileAccess = FileAccess.open(tmp_path, FileAccess.READ)
	if readback == null:
		return FileAccess.get_open_error()
	var readback_text: String = readback.get_as_text()
	readback.close()

	var parsed: Variant = JSON.parse_string(readback_text)
	if parsed == null:
		return ERR_PARSE_ERROR

	var main_path: String = _main_path()

	# Step 3: if main exists, copy it to .bak.json (replaces old backup).
	if FileAccess.file_exists(main_path):
		var copy_err: Error = DirAccess.copy_absolute(main_path, _backup_path())
		if copy_err != OK:
			return copy_err

	# Step 4: rename tmp -> main. DirAccess.rename_absolute replaces
	# atomically on Android/iOS. On desktop (editor use), fall back to
	# remove-then-rename if the direct rename fails.
	var rename_err: Error = DirAccess.rename_absolute(tmp_path, main_path)
	if rename_err != OK:
		if FileAccess.file_exists(main_path):
			var remove_err: Error = DirAccess.remove_absolute(main_path)
			if remove_err != OK:
				return remove_err
		rename_err = DirAccess.rename_absolute(tmp_path, main_path)
	return rename_err

## Returns the raw text of whichever of main/tmp/backup exist, in that
## order. Does not parse or interpret the JSON -- SaveService decides what
## to do with each candidate.
func read_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var sources: Array = [
		["main", _main_path()],
		["tmp", _tmp_path()],
		["backup", _backup_path()],
	]
	for entry: Array in sources:
		var source: String = entry[0]
		var path: String = entry[1]
		if not FileAccess.file_exists(path):
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var text: String = file.get_as_text()
		file.close()
		if text.is_empty():
			continue
		candidates.append({"source": source, "text": text})
	return candidates

## Moves main -> farmora_save.damaged.json, overwriting any previous
## damaged file. No-op returning OK if main does not exist.
func quarantine_damaged() -> Error:
	var main_path: String = _main_path()
	if not FileAccess.file_exists(main_path):
		return OK
	var damaged_path: String = _damaged_path()
	if FileAccess.file_exists(damaged_path):
		var remove_err: Error = DirAccess.remove_absolute(damaged_path)
		if remove_err != OK:
			return remove_err
	return DirAccess.rename_absolute(main_path, damaged_path)
