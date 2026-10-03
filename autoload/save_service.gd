extends Node

## SaveService autoload per docs/ARCHITECTURE.md Section 11.6. Owns the
## debounced autosave timer, the failure retry schedule, and load_game()'s
## candidate-selection policy (Section 11.5's Load order table). Never
## imports Game (ADR-02/Section 11.6: "SaveService never imports Game") --
## it only gets data through the `snapshot_provider` Callable `Game` sets
## via configure(). No `class_name`, same autoload convention as
## autoload/game.gd (ARCHITECTURE.md Section 6.2: a script registered as
## an autoload singleton must not also declare class_name, since the two
## names would clash).
##
## `persistence_enabled` starts false and stays false until something
## else flips it (Main's boot step after a successful begin_session, or
## start_new_farm_after_damage() after quarantining a damaged main) --
## Task 9 (Main boot wiring) owns the "enable after begin_session" call;
## this file only ever reads the flag to gate request_autosave()/
## save_now(), never sets it true on its own initiative.

signal save_succeeded(manual: bool)
signal save_failed(manual: bool)
signal load_finished(result: LoadResult)

## 5s / 15s / 60s retry schedule after an automatic save failure, per
## ARCHITECTURE.md Section 11.6 / Section 24 item 9: "retries are
## scheduled at 5s, 15s, 60s after the failure... After the third retry
## no more timed retries run; the next trigger... tries again."
const AUTOSAVE_DEBOUNCE_SECONDS := 2.0
const RETRY_DELAYS_SECONDS: Array[float] = [5.0, 15.0, 60.0]

var persistence_enabled: bool = false
var io: SaveFileIO

var _snapshot_provider: Callable
var _catalog: GameCatalog
var _autosave_timer: Timer
var _retry_timer: Timer
var _retry_index: int = 0

func _ready() -> void:
	io = SaveFileIO.new()

	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_DEBOUNCE_SECONDS
	_autosave_timer.one_shot = true
	_autosave_timer.autostart = false
	add_child(_autosave_timer)
	_autosave_timer.timeout.connect(_on_autosave_timeout)

	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	_retry_timer.autostart = false
	add_child(_retry_timer)
	_retry_timer.timeout.connect(_on_retry_timeout)

## Wires the data source for saving. `snapshot_provider` must itself
## advance state to now and return SaveCodec.encode(state) -- by the time
## SaveService calls it, the state is current (Section 11.6: "That
## Callable advances to now and returns SaveCodec.encode(state)").
func configure(snapshot_provider: Callable, catalog: GameCatalog) -> void:
	_snapshot_provider = snapshot_provider
	_catalog = catalog

## Starts the 2s debounce timer if it is not already running. A no-op
## while persistence is disabled (no file should be written before a
## farm exists / while a damaged save is in limbo, Section 11.6).
func request_autosave() -> void:
	if not persistence_enabled:
		return
	if _autosave_timer.is_stopped():
		_autosave_timer.start()

## Synchronous save, used by sells, background, Save now, and the
## autosave timer's own timeout. Returns true on success. When
## persistence is disabled this is a no-op returning true (Section
## 11.6's own resolution: "disabled saves are a no-op returning true").
func save_now(manual: bool = false) -> bool:
	if not persistence_enabled:
		return true

	var snapshot: Dictionary = _snapshot_provider.call()
	var json_text: String = JSON.stringify(snapshot)
	var err: Error = io.write_atomic(json_text)

	if err == OK:
		_retry_index = 0
		_retry_timer.stop()
		save_succeeded.emit(manual)
		return true

	save_failed.emit(manual)
	_schedule_retry()
	return false

## Banner "Try now" -- an out-of-schedule retry attempt. Does not itself
## advance _retry_index beyond what save_now()'s own failure handling
## already does.
func retry_now() -> void:
	save_now(false)

## "Start new farm" after a damaged save (GDD Section 9): quarantine the
## damaged main so it is never confused with a real save again, then
## allow a fresh game to persist normally.
func start_new_farm_after_damage() -> void:
	io.quarantine_damaged()
	persistence_enabled = true

## Picks the first candidate (main, then tmp, then backup) that decodes
## successfully, per ARCHITECTURE.md Section 11.5's Load order table. A
## TOO_NEW main short-circuits immediately without trying tmp/backup --
## the file must never be touched/overwritten after that.
func load_game() -> LoadResult:
	var candidates: Array[Dictionary] = io.read_candidates()
	if candidates.is_empty():
		var no_save := LoadResult.of(DecodeResult.Status.NO_SAVE)
		load_finished.emit(no_save)
		return no_save

	var by_source: Dictionary = {}  # String source -> String text
	for candidate: Dictionary in candidates:
		by_source[candidate["source"]] = candidate["text"]

	if by_source.has("main"):
		var main_decoded: DecodeResult = _try_decode(by_source["main"])
		if main_decoded.status == DecodeResult.Status.TOO_NEW:
			var too_new := LoadResult.of(DecodeResult.Status.TOO_NEW)
			load_finished.emit(too_new)
			return too_new
		if main_decoded.status == DecodeResult.Status.OK:
			var ok_main := LoadResult.of(DecodeResult.Status.OK, main_decoded.state, "main")
			load_finished.emit(ok_main)
			return ok_main

	for source: String in ["tmp", "backup"]:
		if by_source.has(source):
			var decoded: DecodeResult = _try_decode(by_source[source])
			if decoded.status == DecodeResult.Status.OK:
				var ok_result := LoadResult.of(DecodeResult.Status.OK, decoded.state, source)
				load_finished.emit(ok_result)
				return ok_result

	var damaged := LoadResult.of(DecodeResult.Status.DAMAGED)
	load_finished.emit(damaged)
	return damaged

## Parses raw text as JSON and decodes it through SaveCodec. Unparseable
## JSON is reported as DAMAGED, matching decode()'s own treatment of a
## structurally-invalid root. Uses the instance JSON.new()/parse() API
## rather than the static JSON.parse_string() convenience method -- a
## damaged save is an expected, handled case here (not a bug), and
## parse_string() logs a noisy engine-level error on invalid input that
## parse()'s Error return code avoids.
func _try_decode(text: String) -> DecodeResult:
	var json := JSON.new()
	if json.parse(text) != OK:
		return DecodeResult.of(DecodeResult.Status.DAMAGED)
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return DecodeResult.of(DecodeResult.Status.DAMAGED)
	return SaveCodec.decode(parsed, _catalog)

func _on_autosave_timeout() -> void:
	save_now(false)

func _on_retry_timeout() -> void:
	save_now(false)

## Schedules the next timed retry per RETRY_DELAYS_SECONDS (5s/15s/60s).
## After the third scheduled retry has itself failed, no further timed
## retry is queued -- the next external trigger (a change, backgrounding,
## Save now, Try now) tries again instead (Section 24 item 9).
func _schedule_retry() -> void:
	if _retry_index >= RETRY_DELAYS_SECONDS.size():
		return
	_retry_timer.wait_time = RETRY_DELAYS_SECONDS[_retry_index]
	_retry_index += 1
	_retry_timer.start()
