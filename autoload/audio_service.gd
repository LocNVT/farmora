extends Node

## AudioService autoload per docs/ARCHITECTURE.md Section 13 (ADR-02's
## four core autoloads: Game, SaveService, Nav, AudioService) and
## docs/DESIGN.md Section 10's sound/haptic event table. Through Phase
## 9: no Nav yet, so registered after SaveService; Nav will sit between
## SaveService and this one once it exists, per ARCHITECTURE.md Section
## 13's ordering. No `class_name` (ARCHITECTURE.md Section 6.2: an
## autoload script doesn't declare class_name, so it can't clash with
## the autoload name "AudioService").
##
## Built as a silent-by-default API (Phase 9 planning decision, user
## approved): there are no sound/music asset files in the repo yet
## (CLAUDE.md Section 10 -- do not block gameplay implementation waiting
## for final artwork, and this extends to audio). `play(id)`/
## `play_music(id)` resolve a sound id to a stream path through
## SOUND_PATHS; a path with no file at it (every path today) is a
## silent, warn-once no-op rather than a crash. The moment real files
## land at these exact paths, sound plays with no code change. Haptics
## need no asset file and are fully functional and testable today
## (gated on `Input.vibrate_handheld`, which itself is a real device
## no-op in the editor/desktop -- see `haptic()`'s own comment).
##
## Reads `Game.state.settings` fresh on every call rather than caching
## it or listening for a settings-changed signal -- there is no
## `Game.set_setting()`/`settings_changed` signal yet (no Settings
## screen exists to call it), so there is nothing to react to; reading
## live avoids a stale-cache bug the moment that command is added later
## without requiring this file to change.

## docs/DESIGN.md Section 10's event table, mapped to a path under
## assets/audio/sfx/ (none of these files exist yet -- see class
## comment). One id per row of the table; "ambience" is music, not sfx,
## and lives in MUSIC_PATHS instead.
const SOUND_PATHS: Dictionary = {
	"button_press": "res://assets/audio/sfx/button_press.ogg",
	"purchase": "res://assets/audio/sfx/purchase.ogg",
	"sell": "res://assets/audio/sfx/sell.ogg",
	"feed": "res://assets/audio/sfx/feed.ogg",
	"collect": "res://assets/audio/sfx/collect.ogg",
	"level_up": "res://assets/audio/sfx/level_up.ogg",
	"upgrade": "res://assets/audio/sfx/upgrade.ogg",
	"error": "res://assets/audio/sfx/error.ogg",
	"product_ready": "res://assets/audio/sfx/product_ready.ogg",
}

const MUSIC_PATHS: Dictionary = {
	"ambience": "res://assets/audio/music/ambience.ogg",
}

## DESIGN Section 10 rule 3's three haptic patterns, plus the shared
## error pattern -- a named enum so callers don't pass raw magic
## strings/ints for "which pattern", matching this project's established
## enum-over-string convention (e.g. ActionResult.Code, BuildingDefinition.Kind).
enum Haptic { LIGHT, MEDIUM, SUCCESS, ERROR_DOUBLE }

## Pool size for overlapping one-shot sfx (a sell's "up to 3" coin
## clinks in quick succession, DESIGN Section 10, is the largest
## concurrent-sound case the event table describes).
const SFX_POOL_SIZE := 4

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _warned_missing_ids: Dictionary = {}  # String id -> true, so a missing stream warns once, not every call

func _ready() -> void:
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_pool.append(player)

	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)

## Plays a one-shot sound effect by id, per DESIGN Section 10's event
## table, through the next free pooled player (or the least-recently-
## started one if all are busy, rather than dropping the sound).
## Returns false (and plays nothing) when: `Game.state` doesn't exist
## yet, the sound setting is off, the id is unknown, or no stream file
## exists yet at the resolved path (warns once per id in that last
## case, via push_warning so it's visible in dev builds without
## spamming every call).
func play(id: String) -> bool:
	if not _sound_enabled():
		return false
	if not SOUND_PATHS.has(id):
		push_warning("AudioService: unknown sound id '%s'" % id)
		return false

	var stream: AudioStream = _load_stream(SOUND_PATHS[id], id)
	if stream == null:
		return false

	var player: AudioStreamPlayer = _next_pool_player()
	player.stream = stream
	player.play()
	return true

## Starts looping background music by id, per DESIGN Section 10's
## "Ambience... off with Sound" -- ambience is gated on the SOUND
## toggle, not a separate music-only check, matching the table's own
## wording ("off with Sound"). Returns false under the same conditions
## as play().
func play_music(id: String) -> bool:
	if not _sound_enabled():
		return false
	if not MUSIC_PATHS.has(id):
		push_warning("AudioService: unknown music id '%s'" % id)
		return false

	var stream: AudioStream = _load_stream(MUSIC_PATHS[id], id)
	if stream == null:
		return false

	_music_player.stream = stream
	_music_player.play()
	return true

func stop_music() -> void:
	_music_player.stop()

## Triggers a haptic pattern, per DESIGN Section 10 rule 3: LIGHT
## (collect, buy), SUCCESS (level-up), ERROR_DOUBLE (a short double
## tick for errors); MEDIUM covers the event table's "medium haptic"
## rows (purchase, upgrade) that rule 3's prose doesn't separately name.
## Gated on the vibration setting. `Input.vibrate_handheld()` is itself
## an Android/iOS-only no-op everywhere else (desktop, web, the editor),
## so this is safe to call unconditionally in tests/desktop runs -- it
## simply does nothing there, which is why haptics, unlike sound, need
## no asset file to be fully functional and testable today.
func haptic(kind: Haptic) -> bool:
	if not _vibration_enabled():
		return false

	match kind:
		Haptic.LIGHT:
			Input.vibrate_handheld(20)
		Haptic.MEDIUM:
			Input.vibrate_handheld(40)
		Haptic.SUCCESS:
			Input.vibrate_handheld(60)
		Haptic.ERROR_DOUBLE:
			Input.vibrate_handheld(15)
			# A genuine double-tap pattern needs two calls spaced apart;
			# Input.vibrate_handheld() only takes one duration per call
			# with no built-in repeat, so the second tick is scheduled
			# via a one-shot timer rather than blocking this call.
			var timer: SceneTreeTimer = get_tree().create_timer(0.1)
			timer.timeout.connect(func() -> void: Input.vibrate_handheld(15))
	return true

func _sound_enabled() -> bool:
	return Game.state != null and Game.state.settings.sound

func _vibration_enabled() -> bool:
	return Game.state != null and Game.state.settings.vibration

func _load_stream(path: String, id: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		if not _warned_missing_ids.has(id):
			push_warning("AudioService: no audio file at '%s' for id '%s' (silent no-op until one is added)" % [path, id])
			_warned_missing_ids[id] = true
		return null
	return load(path) as AudioStream

func _next_pool_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_pool:
		if not player.playing:
			return player
	return _sfx_pool[0]
