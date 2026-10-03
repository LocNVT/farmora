extends GutTest

## Verifies Floater's own show_at()/pooling contract in isolation
## (Phase 9 Task 5): initial position/visibility, Motion.reduced vs
## normal animation behavior, and that it exposes no tap_rect()/id
## property FarmInput's duck-typed hit-testing would match.
##
## Resets Motion.reduced after every test that sets it, matching the
## established convention in test_farm_input.gd.

func test_show_at_sets_position_and_becomes_visible() -> void:
	var floater: Floater = load("res://scenes/farm/world_ui/floater.tscn").instantiate()
	add_child_autofree(floater)
	assert_false(floater.visible, "A freshly instantiated floater should start invisible/idle")
	floater.show_at(Vector2(50, 80), "egg", 1)
	assert_eq(floater.global_position, Vector2(50, 80))
	assert_true(floater.visible)

func test_show_at_is_not_idle_while_animating() -> void:
	var floater: Floater = load("res://scenes/farm/world_ui/floater.tscn").instantiate()
	add_child_autofree(floater)
	assert_true(floater.is_idle(), "A floater with no animation started yet should be idle")
	floater.show_at(Vector2.ZERO, "egg", 1)
	assert_false(floater.is_idle(), "A floater mid rise-and-fade should not be idle")

func test_reduced_motion_uses_a_shorter_fade_with_no_rise() -> void:
	Motion.reduced = true
	var floater: Floater = load("res://scenes/farm/world_ui/floater.tscn").instantiate()
	add_child_autofree(floater)
	var start_pos := Vector2(10, 10)
	floater.show_at(start_pos, "milk", 2)
	await wait_seconds(Floater.REDUCED_DURATION + 0.05)
	assert_almost_eq(floater.global_position.x, start_pos.x, 0.5, "Reduced motion should skip the rise -- position stays put")
	assert_almost_eq(floater.modulate.a, 0.0, 0.05, "Reduced motion should still fade out, just faster")
	Motion.reduced = false

func test_normal_motion_rises_and_fades_over_600ms() -> void:
	var floater: Floater = load("res://scenes/farm/world_ui/floater.tscn").instantiate()
	add_child_autofree(floater)
	var start_pos := Vector2(0, 0)
	floater.show_at(start_pos, "pork", 1)
	await wait_seconds(Floater.DURATION + 0.1)
	assert_almost_eq(floater.modulate.a, 0.0, 0.05, "Floater should be fully faded out after its 600ms animation")
	assert_false(floater.visible, "Floater should become invisible/available for reuse once its animation ends")

func test_floater_exposes_no_tap_rect_method() -> void:
	var floater: Floater = load("res://scenes/farm/world_ui/floater.tscn").instantiate()
	add_child_autofree(floater)
	assert_false(floater.has_method("tap_rect"), "Floater must not be hit-testable by FarmInput's duck-typed tap_rect() check")

func test_floater_exposes_no_bubble_or_animal_or_building_id() -> void:
	var floater: Floater = load("res://scenes/farm/world_ui/floater.tscn").instantiate()
	add_child_autofree(floater)
	assert_false("bubble_id" in floater)
	assert_false("animal_id" in floater)
	assert_false("building_id" in floater)
