extends GutTest

## Verifies AudioService per docs/DESIGN.md Section 10 / docs/
## ARCHITECTURE.md Section 13. Through Phase 9: no audio asset files
## exist yet, so play()/play_music() are always silent no-ops that
## still correctly report whether they WOULD have played (gating logic
## is what's tested here, not actual sound output, which needs real
## files). Haptics need no asset file and are fully exercised.
##
## Saves/restores Game.state around every test (AudioService is a
## singleton reading the real Game singleton's state) so this file
## never leaks state into any other test, matching the project's
## established autoload-isolation convention.

var _saved_state: GameState

func before_each() -> void:
	_saved_state = Game.state
	Game.state = StateFactory.game_state_with([])

func after_each() -> void:
	Game.state = _saved_state

func test_play_returns_false_when_sound_is_off() -> void:
	Game.state.settings.sound = false
	assert_false(AudioService.play("button_press"))

func test_play_returns_false_for_an_unknown_id() -> void:
	Game.state.settings.sound = true
	assert_false(AudioService.play("not_a_real_sound"))

func test_play_returns_false_when_no_stream_file_exists_yet() -> void:
	# No audio/sfx files exist in the repo yet (Phase 9 scope decision:
	# ship the API silent until real assets land) -- every known id
	# should resolve to "recognized but no file", not crash.
	Game.state.settings.sound = true
	assert_false(AudioService.play("button_press"))

func test_play_is_safe_with_no_game_state() -> void:
	Game.state = null
	assert_false(AudioService.play("button_press"))

func test_play_music_returns_false_when_sound_is_off() -> void:
	Game.state.settings.sound = false
	assert_false(AudioService.play_music("ambience"))

func test_play_music_returns_false_for_an_unknown_id() -> void:
	Game.state.settings.sound = true
	assert_false(AudioService.play_music("not_a_real_track"))

func test_haptic_returns_false_when_vibration_is_off() -> void:
	Game.state.settings.vibration = false
	assert_false(AudioService.haptic(AudioService.Haptic.LIGHT))

func test_haptic_returns_true_when_vibration_is_on() -> void:
	# Input.vibrate_handheld() is a real no-op on desktop/editor/web, so
	# this only verifies AudioService's OWN gating logic runs the call,
	# not that a real device actually buzzes (that needs Phase 10's
	# device validation).
	Game.state.settings.vibration = true
	assert_true(AudioService.haptic(AudioService.Haptic.LIGHT))
	assert_true(AudioService.haptic(AudioService.Haptic.MEDIUM))
	assert_true(AudioService.haptic(AudioService.Haptic.SUCCESS))
	assert_true(AudioService.haptic(AudioService.Haptic.ERROR_DOUBLE))

func test_haptic_is_safe_with_no_game_state() -> void:
	Game.state = null
	assert_false(AudioService.haptic(AudioService.Haptic.LIGHT))

func test_sfx_pool_has_the_documented_size() -> void:
	assert_eq(AudioService._sfx_pool.size(), AudioService.SFX_POOL_SIZE)

func test_every_design_section_10_event_has_a_registered_sound_id() -> void:
	# DESIGN Section 10's event table: button press, purchase, sell,
	# feed, collect, level up, upgrade, error, product ready.
	var expected_ids: PackedStringArray = [
		"button_press", "purchase", "sell", "feed", "collect",
		"level_up", "upgrade", "error", "product_ready",
	]
	for id: String in expected_ids:
		assert_true(AudioService.SOUND_PATHS.has(id), "Missing a registered sound id for '%s'" % id)
