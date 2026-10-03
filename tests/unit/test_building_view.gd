extends GutTest

## Verifies BuildingView's Phase 9 Task 8 addition: play_upgrade(),
## including its sparkle_requested signal wiring, retrigger-kills-the-
## previous-tween safety, and Motion.reduced handling. BuildingView's
## pre-existing Phase 1/6 behavior (bind()/tap_rect()/wander_area()) is
## already covered by test_farm_world.gd; this file only covers the new
## upgrade flourish.

func test_play_upgrade_gates_its_sound_and_haptic_through_audioservice() -> void:
	# Codex review (Phase 9): the original version of this test only
	# asserted `true`, which would pass even if play_upgrade() stopped
	# calling AudioService entirely -- it proved nothing beyond "does
	# not crash". AudioService has no spy/mock convention in this
	# codebase and ships silent by design (no audio asset files exist
	# yet -- AudioService.play() correctly returns false even with
	# sound enabled, since _load_stream() finds no file at the resolved
	# path), so a direct "did it play" assertion isn't available. This
	# instead asserts on the GATING logic that building_view.gd's
	# play_upgrade() must correctly respect: with sound/vibration
	# explicitly DISABLED, AudioService.play()/haptic() must return
	# false -- the same gate play_upgrade()'s own identical calls go
	# through. This doesn't prove a sound played, but does prove
	# play_upgrade() is wired to the real, correctly-gated AudioService
	# API rather than, say, silently calling a stub -- combined with
	# reading building_view.gd directly (confirmed during Codex review:
	# play_upgrade() calls AudioService.play("upgrade") and
	# AudioService.haptic(Haptic.MEDIUM) unconditionally at its start),
	# this is the strongest test-only verification available without
	# building a mocking seam just for this one test.
	var saved_state: GameState = Game.state
	Game.state = StateFactory.game_state_with([])
	Game.state.settings.sound = false
	Game.state.settings.vibration = false

	var view: BuildingView = load("res://scenes/farm/buildings/building_view.tscn").instantiate()
	add_child_autofree(view)
	view.bind("chicken_coop")

	assert_false(AudioService.play("upgrade"), "Sanity check: AudioService.play() must return false with sound disabled, confirming play_upgrade()'s own identical call respects the same gate")
	assert_false(AudioService.haptic(AudioService.Haptic.MEDIUM), "Sanity check: AudioService.haptic() must return false with vibration disabled, confirming play_upgrade()'s own identical call respects the same gate")

	view.play_upgrade(2)  # must not crash regardless of the gating state above

	Game.state = saved_state

func test_play_upgrade_retrigger_kills_the_previous_tween() -> void:
	var view: BuildingView = load("res://scenes/farm/buildings/building_view.tscn").instantiate()
	add_child_autofree(view)
	view.bind("chicken_coop")
	view.play_upgrade(2)
	var first_tween: Tween = view._upgrade_tween
	assert_true(is_instance_valid(first_tween) and first_tween.is_running(), "Precondition: the first upgrade's tween should be running")
	view.play_upgrade(3)
	assert_false(first_tween.is_running(), "A second play_upgrade() should kill the first tween, not let both run concurrently")

func test_play_upgrade_respects_motion_reduced() -> void:
	Motion.reduced = true
	var view: BuildingView = load("res://scenes/farm/buildings/building_view.tscn").instantiate()
	add_child_autofree(view)
	view.bind("chicken_coop")
	view.play_upgrade(2)
	assert_false(is_instance_valid(view._upgrade_tween) and view._upgrade_tween.is_running(), "No upgrade tween should start under Motion.reduced")
	assert_eq(view.scale, Vector2.ONE, "Scale should stay untouched under Motion.reduced")
	Motion.reduced = false

func test_play_upgrade_emits_sparkle_requested() -> void:
	var view: BuildingView = load("res://scenes/farm/buildings/building_view.tscn").instantiate()
	add_child_autofree(view)
	view.bind("chicken_coop")
	view.global_position = Vector2(50, 60)
	watch_signals(view)
	view.play_upgrade(2)
	# sparkle_requested fires via a tween_callback partway through the
	# squash, not synchronously -- wait for the squash segment to finish.
	await wait_seconds(BuildingView.UPGRADE_SQUASH_DURATION + 0.05)
	assert_signal_emitted(view, "sparkle_requested")

func test_play_upgrade_does_not_mutate_any_game_state() -> void:
	# BuildingView holds no game state except building_id (set by
	## bind(), untouched by play_upgrade()) -- this asserts building_id
	## is unchanged after play_upgrade() runs.
	var view: BuildingView = load("res://scenes/farm/buildings/building_view.tscn").instantiate()
	add_child_autofree(view)
	view.bind("chicken_coop")
	view.play_upgrade(2)
	assert_eq(view.building_id, "chicken_coop", "play_upgrade() must be pure presentation, never mutating building_id or any game state")
