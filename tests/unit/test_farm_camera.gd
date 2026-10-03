extends GutTest

## Verifies FarmCamera's pure, testable math (docs/ARCHITECTURE.md
## Section 10.1): fit_zoom, zoom clamping, and the clamped-position
## horizontal-inversion case at maximum zoom-out. Does not test input
## handling (FarmInput, Task 5) or tween/animation timing -- only the
## deterministic math a command API needs to get right.

func test_compute_fit_zoom_at_reference_width_is_one() -> void:
	# 390-wide viewport over a 390-wide world = fit_zoom 1.0 (the
	# reference device, DESIGN.md Section 12).
	assert_almost_eq(FarmCamera.compute_fit_zoom(390.0), 1.0, 0.001)

func test_compute_fit_zoom_scales_with_viewport_width() -> void:
	# A 412-wide viewport (Modern Android, DESIGN.md Section 12) should
	# yield fit_zoom > 1.0, proportional to its width over the 390 base.
	var result: float = FarmCamera.compute_fit_zoom(412.0)
	assert_almost_eq(result, 412.0 / 390.0, 0.001)

func test_compute_fit_zoom_falls_back_to_one_for_invalid_width() -> void:
	assert_eq(FarmCamera.compute_fit_zoom(0.0), 1.0)
	assert_eq(FarmCamera.compute_fit_zoom(-10.0), 1.0)

func test_compute_clamped_position_centers_horizontally_when_zoomed_out_past_world_width() -> void:
	# At 0.8x fit_zoom (fit_zoom=1.0 reference), viewport=390, cam_zoom=0.8:
	# visible world width = 390/0.8 = 487.5, wider than the 390-unit world,
	# so horizontal must center (result.x == 0), never clamp to an
	# inverted [min, max] range.
	var result: Vector2 = FarmCamera.compute_clamped_position(
		Vector2(999, 500), Vector2(390, 844), 0.8
	)
	assert_eq(result.x, 0.0, "Camera should center horizontally when the visible world width exceeds the authored world width")

func test_compute_clamped_position_clamps_normally_when_zoomed_in() -> void:
	# At 1.4x fit_zoom (fit_zoom=1.0), cam_zoom=1.4: visible world width
	# = 390/1.4 = 278.6, narrower than the 390-unit world, so a normal
	# [min, max] clamp applies and an out-of-range position gets pulled in.
	var result: Vector2 = FarmCamera.compute_clamped_position(
		Vector2(999, 500), Vector2(390, 844), 1.4
	)
	var world_half: float = FarmCamera.WORLD_WIDTH / 2.0
	assert_true(result.x <= world_half, "Camera should clamp inside the world's right edge when zoomed in enough for a normal clamp range")
	assert_true(result.x < 999.0, "An out-of-range request should actually be pulled toward the world, not left as-is")

func test_compute_clamped_position_centers_vertically_when_world_shorter_than_viewport() -> void:
	# A viewport taller than the 1100-unit world at the given zoom should
	# center vertically rather than produce an inverted clamp range.
	var result: Vector2 = FarmCamera.compute_clamped_position(
		Vector2(0, 999), Vector2(390, 3000), 1.0
	)
	assert_eq(result.y, FarmCamera.WORLD_HEIGHT / 2.0, "Camera should center vertically when the viewport is taller than the authored world")

func test_compute_clamped_position_respects_overshoot_for_rubber_band() -> void:
	# With a nonzero overshoot_fraction (an active drag), a position just
	# past the hard clamp edge should be allowed rather than snapped
	# immediately to the hard limit.
	var viewport_size := Vector2(390, 844)
	var cam_zoom := 1.4
	var hard: Vector2 = FarmCamera.compute_clamped_position(Vector2(999, 0), viewport_size, cam_zoom, 0.0)
	var soft: Vector2 = FarmCamera.compute_clamped_position(Vector2(999, 0), viewport_size, cam_zoom, 0.08)
	assert_true(soft.x > hard.x, "A nonzero overshoot_fraction should allow pulling further than the hard clamp")

func test_scene_has_farm_camera_script_attached() -> void:
	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	var world: FarmWorld = scene.instantiate()
	add_child_autofree(world)
	var cam: Node = world.get_node_or_null("FarmCamera")
	assert_not_null(cam)
	assert_true(cam is FarmCamera, "FarmWorld's FarmCamera child should use the FarmCamera script")

func test_indicator_scale_clamps_zoomed_out_player_zoom_to_0_9() -> void:
	# Player zoom 0.8 (min) should clamp to 0.9, so indicator_scale =
	# 0.9/0.8 = 1.125 (docs/ARCHITECTURE.md Section 10.1).
	assert_almost_eq(FarmCamera.indicator_scale(0.8), 0.9 / 0.8, 0.001)

func test_indicator_scale_is_unchanged_at_1_0_player_zoom() -> void:
	assert_almost_eq(FarmCamera.indicator_scale(1.0), 1.0, 0.001)

func test_indicator_scale_is_unchanged_at_the_1_2_clamp_edge() -> void:
	assert_almost_eq(FarmCamera.indicator_scale(1.2), 1.0, 0.001)

func test_indicator_scale_clamps_zoomed_in_player_zoom_to_1_2() -> void:
	# Player zoom 1.4 (max) should clamp to 1.2, so indicator_scale =
	# 1.2/1.4 ~= 0.857.
	assert_almost_eq(FarmCamera.indicator_scale(1.4), 1.2 / 1.4, 0.001)

func test_farm_camera_zoom_is_set_to_fit_zoom_on_ready() -> void:
	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	var world: FarmWorld = scene.instantiate()
	add_child_autofree(world)
	await wait_process_frames(1)
	var cam: FarmCamera = world.get_node("FarmCamera") as FarmCamera
	assert_true(cam.zoom.x > 0.0, "FarmCamera should have a positive zoom after _ready()")
	assert_almost_eq(cam.zoom.x, cam.zoom.y, 0.001, "FarmCamera zoom should be uniform on both axes")

func test_zoom_about_emits_zoom_changed() -> void:
	var cam := FarmCamera.new()
	add_child_autofree(cam)
	await wait_process_frames(1)
	watch_signals(cam)
	cam.zoom_about(1.1)
	assert_signal_emitted(cam, "zoom_changed")

func test_zoom_changed_is_emitted_once_on_ready() -> void:
	var cam := FarmCamera.new()
	watch_signals(cam)
	add_child_autofree(cam)
	await wait_process_frames(1)
	assert_signal_emit_count(cam, "zoom_changed", 1)
