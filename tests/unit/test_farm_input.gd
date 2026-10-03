extends GutTest

## Verifies FarmInput's gesture discrimination and hit-testing (docs/
## ARCHITECTURE.md Section 10.1): tap vs drag threshold, pinch-start
## detection, long press, hit-test priority order and nearest-centre
## selection, and that FarmWorld correctly re-emits its six intent
## signals and wires ground_double_tapped to FarmCamera.reset_zoom().
##
## Uses synthetic InputEventScreenTouch/InputEventScreenDrag fed
## directly into _unhandled_input() rather than Input.parse_input_event
## (which requires a running main loop's input pump) -- this keeps the
## tests deterministic and independent of frame timing except where the
## long-press timer itself is the thing under test.
##
## Uses GUT's watch_signals()/assert_signal_emitted() rather than a
## closure-captured bool flag: GDScript lambdas capture local vars BY
## VALUE, not by reference, so `var flag = false; sig.connect(func():
## flag = true)` never updates the outer `flag` -- confirmed directly
## against the engine before writing these tests this way, after an
## earlier closure-based draft of this file produced false negatives on
## every signal-based assertion.

var _input: FarmInput
var _fake_camera: FarmCamera
var _fake_buildings: Node2D

## A minimal duck-typed hit target, standing in for BuildingView without
## depending on the real scene (keeps these tests focused on FarmInput's
## hit-testing logic, not BuildingView's).
class _FakeTarget:
	extends Node2D
	var building_id: String = ""
	var _rect: Rect2
	func _init(id: String, rect: Rect2) -> void:
		building_id = id
		_rect = rect
	func tap_rect() -> Rect2:
		return _rect

func before_each() -> void:
	_input = FarmInput.new()
	_fake_camera = FarmCamera.new()
	_fake_buildings = Node2D.new()
	add_child_autofree(_fake_camera)
	add_child_autofree(_fake_buildings)
	add_child_autofree(_input)
	_input.camera = _fake_camera
	_input.buildings_container = _fake_buildings
	await wait_process_frames(1)  # let FarmInput._ready() create its Timer
	watch_signals(_input)

func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e

func _drag(index: int, pos: Vector2, relative: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = relative
	return e

## Converts a world position to the screen position that would hit it,
## given _fake_camera's current position/zoom and the test viewport's
## actual size (NOT assumed to be 390x844 -- GUT's headless test
## viewport is square, confirmed directly while diagnosing a test
## failure, not assumed).
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport_size: Vector2 = _input.get_viewport().get_visible_rect().size
	return viewport_size / 2.0 + (world_pos - _fake_camera.position) * _fake_camera.zoom

func test_small_movement_under_threshold_is_a_tap() -> void:
	_input._unhandled_input(_touch(0, Vector2(100, 100), true))
	_input._unhandled_input(_drag(0, Vector2(103, 101), Vector2(3, 1)))
	_input._unhandled_input(_touch(0, Vector2(103, 101), false))
	assert_signal_emitted(_input, "ground_tapped", "Movement under the 8 dp threshold should still register as a tap")

func test_movement_past_threshold_is_a_drag_not_a_tap() -> void:
	_input._unhandled_input(_touch(0, Vector2(100, 100), true))
	_input._unhandled_input(_drag(0, Vector2(120, 100), Vector2(20, 0)))
	_input._unhandled_input(_touch(0, Vector2(120, 100), false))
	assert_signal_not_emitted(_input, "ground_tapped", "Movement past the 8 dp threshold should be a drag, not a tap")

func test_drag_past_threshold_calls_camera_drag_by() -> void:
	# FarmCamera has no signal for drag_by, so verify via position change
	# instead: a drag should move the camera (it starts at world origin
	# by default for a bare FarmCamera.new()).
	var start_pos: Vector2 = _fake_camera.position
	_input._unhandled_input(_touch(0, Vector2(100, 100), true))
	_input._unhandled_input(_drag(0, Vector2(120, 100), Vector2(20, 0)))
	assert_ne(_fake_camera.position, start_pos, "A drag past the threshold should move the camera")

func test_releasing_a_fast_drag_gives_the_camera_a_nonzero_inertia_velocity() -> void:
	# Regression test for a real Phase 1 bug (found by independent Codex
	# review, not by any prior test): FarmInput called
	# camera.end_drag() with no argument, which defaults to
	# Vector2.ZERO, so the 400 ms pan inertia spec (docs/ARCHITECTURE.md
	# Section 10.1) never activated from a real gesture. FarmInput must
	# track and pass a real release velocity.
	#
	# Two drag samples are sent (not one): velocity is computed from the
	# elapsed time BETWEEN drag samples, so a single sample has no prior
	# timestamp to measure against -- this matches how a real gesture
	# actually arrives (a stream of drag events), not an artificial
	# single-event test.
	_input._unhandled_input(_touch(0, Vector2(100, 100), true))
	_input._unhandled_input(_drag(0, Vector2(120, 100), Vector2(20, 0)))
	await wait_physics_frames(2)
	_input._unhandled_input(_drag(0, Vector2(140, 100), Vector2(20, 0)))
	_input._unhandled_input(_touch(0, Vector2(140, 100), false))
	assert_ne(_fake_camera._inertia_velocity, Vector2.ZERO, "Releasing a drag in motion should leave FarmCamera with a nonzero inertia velocity")

func test_two_touches_start_pinch_and_do_not_fire_ground_tapped() -> void:
	_input._unhandled_input(_touch(0, Vector2(100, 100), true))
	_input._unhandled_input(_touch(1, Vector2(200, 100), true))
	_input._unhandled_input(_touch(1, Vector2(200, 100), false))
	_input._unhandled_input(_touch(0, Vector2(100, 100), false))
	assert_signal_not_emitted(_input, "ground_tapped", "Releasing after a second finger joined (a pinch gesture) should not register as a tap")

func test_long_press_on_building_tier_target_does_not_fire_animal_long_pressed() -> void:
	# Phase 1 has no real AnimalView instances, so there is no positive
	# "long press on an animal fires animal_long_pressed" case to test
	# without inventing a stub animal view (explicitly out of scope per
	# docs/PROGRESS.md's planning notes). This instead proves tier
	# discrimination: a long press on a BUILDING target must not be
	# misread as an animal-tier hit.
	var target := _FakeTarget.new("chicken_coop", Rect2(-36, -36, 72, 72))
	_fake_buildings.add_child(target)
	var screen_pos: Vector2 = _world_to_screen(Vector2.ZERO)
	_input._unhandled_input(_touch(0, screen_pos, true))
	await wait_seconds(FarmInput.LONG_PRESS_DURATION + 0.05)
	assert_signal_not_emitted(_input, "animal_long_pressed", "A long press on a BUILDING target should not fire animal_long_pressed (wrong tier)")

func test_long_press_on_a_building_fires_building_long_pressed() -> void:
	# docs/PROGRESS.md "Phase 6" Task 8: long-pressing a building is the
	# temporary upgrade-trigger seam.
	var target := _FakeTarget.new("chicken_coop", Rect2(-36, -36, 72, 72))
	_fake_buildings.add_child(target)
	var screen_pos: Vector2 = _world_to_screen(Vector2.ZERO)
	_input._unhandled_input(_touch(0, screen_pos, true))
	await wait_seconds(FarmInput.LONG_PRESS_DURATION + 0.05)
	assert_signal_emitted_with_parameters(_input, "building_long_pressed", ["chicken_coop"])

func test_long_press_on_a_building_does_not_also_fire_a_tap() -> void:
	# A fired long press must suppress the eventual tap-on-release
	# (same pattern already proven for animals' long_press_fired flag).
	var target := _FakeTarget.new("chicken_coop", Rect2(-36, -36, 72, 72))
	_fake_buildings.add_child(target)
	var screen_pos: Vector2 = _world_to_screen(Vector2.ZERO)
	_input._unhandled_input(_touch(0, screen_pos, true))
	await wait_seconds(FarmInput.LONG_PRESS_DURATION + 0.05)
	watch_signals(_input)
	_input._unhandled_input(_touch(0, screen_pos, false))
	assert_signal_not_emitted(_input, "building_tapped", "A long press that already fired should suppress the release's own tap")
	_input._unhandled_input(_touch(0, screen_pos, false))

func test_long_press_timer_does_not_fire_after_drag_started() -> void:
	_input._unhandled_input(_touch(0, Vector2(100, 100), true))
	_input._unhandled_input(_drag(0, Vector2(120, 100), Vector2(20, 0)))
	await wait_seconds(FarmInput.LONG_PRESS_DURATION + 0.05)
	assert_signal_not_emitted(_input, "animal_long_pressed", "A long-press timer should stop once the touch becomes a drag")
	_input._unhandled_input(_touch(0, Vector2(120, 100), false))

func test_building_tap_fires_building_tapped_with_correct_id() -> void:
	var target := _FakeTarget.new("market", Rect2(-36, -36, 72, 72))
	_fake_buildings.add_child(target)
	var screen_pos: Vector2 = _world_to_screen(Vector2.ZERO)
	_input._unhandled_input(_touch(0, screen_pos, true))
	_input._unhandled_input(_touch(0, screen_pos, false))
	assert_signal_emitted_with_parameters(_input, "building_tapped", ["market"])

func test_tap_outside_any_building_rect_fires_ground_tapped() -> void:
	var target := _FakeTarget.new("market", Rect2(-36, -36, 72, 72))
	_fake_buildings.add_child(target)
	# Tap far outside the building's rect (world space), converted to
	# the matching screen position.
	var screen_pos: Vector2 = _world_to_screen(Vector2(900, 900))
	_input._unhandled_input(_touch(0, screen_pos, true))
	_input._unhandled_input(_touch(0, screen_pos, false))
	assert_signal_emitted(_input, "ground_tapped", "A tap outside every tier's targets should fire ground_tapped")
	assert_signal_not_emitted(_input, "building_tapped")

func test_bubble_tap_fires_bubble_tapped_with_correct_id() -> void:
	var world_ui := Node2D.new()
	add_child_autofree(world_ui)
	_input.world_ui_container = world_ui
	var bubble: StatusBubble = load("res://scenes/farm/world_ui/status_bubble.tscn").instantiate()
	world_ui.add_child(bubble)
	var anchor := Node2D.new()
	add_child_autofree(anchor)
	bubble.bind("a1", StatusRules.Bubble.FEED, anchor)
	var screen_pos: Vector2 = _world_to_screen(Vector2.ZERO)
	_input._unhandled_input(_touch(0, screen_pos, true))
	_input._unhandled_input(_touch(0, screen_pos, false))
	assert_signal_emitted_with_parameters(_input, "bubble_tapped", ["a1"])

func test_bubble_tier_wins_over_an_overlapping_building() -> void:
	# Hit-test priority order (docs/ARCHITECTURE.md Section 10.1):
	# bubbles -> animals -> buildings -> ground. A bubble and a building
	# overlapping the same tap point must resolve to the bubble.
	var world_ui := Node2D.new()
	add_child_autofree(world_ui)
	_input.world_ui_container = world_ui
	var bubble: StatusBubble = load("res://scenes/farm/world_ui/status_bubble.tscn").instantiate()
	world_ui.add_child(bubble)
	var anchor := Node2D.new()
	add_child_autofree(anchor)
	bubble.bind("a1", StatusRules.Bubble.FEED, anchor)  # anchor at world origin -> bubble tap_rect centered there

	var building := _FakeTarget.new("chicken_coop", Rect2(-36, -36, 72, 72))
	_fake_buildings.add_child(building)

	var screen_pos: Vector2 = _world_to_screen(Vector2.ZERO)
	_input._unhandled_input(_touch(0, screen_pos, true))
	_input._unhandled_input(_touch(0, screen_pos, false))
	assert_signal_emitted(_input, "bubble_tapped")
	assert_signal_not_emitted(_input, "building_tapped")

func test_nearest_centre_wins_within_a_tier() -> void:
	# Two overlapping building rects, both containing the tap point at
	# world origin, but with DIFFERENT centres so "nearest" is
	# unambiguous: "near" is centred 10 units from the tap; "far" is
	# centred 40 units away. Both rects still contain (0,0).
	var far := _FakeTarget.new("far", Rect2(0, 0, 80, 80))        # centre (40, 40)
	var near := _FakeTarget.new("near", Rect2(-20, -20, 30, 30))  # centre (-5, -5)
	_fake_buildings.add_child(far)
	_fake_buildings.add_child(near)
	var screen_pos: Vector2 = _world_to_screen(Vector2.ZERO)
	_input._unhandled_input(_touch(0, screen_pos, true))
	_input._unhandled_input(_touch(0, screen_pos, false))
	assert_signal_emitted_with_parameters(_input, "building_tapped", ["near"])

func test_double_tap_on_ground_fires_ground_double_tapped_once() -> void:
	_input._unhandled_input(_touch(0, Vector2(100, 100), true))
	_input._unhandled_input(_touch(0, Vector2(100, 100), false))
	_input._unhandled_input(_touch(0, Vector2(102, 101), true))
	_input._unhandled_input(_touch(0, Vector2(102, 101), false))
	assert_signal_emit_count(_input, "ground_double_tapped", 1, "A second tap within the double-tap window and distance should fire ground_double_tapped exactly once")

func test_double_tap_first_tap_still_fires_single_ground_tapped() -> void:
	_input._unhandled_input(_touch(0, Vector2(100, 100), true))
	_input._unhandled_input(_touch(0, Vector2(100, 100), false))
	_input._unhandled_input(_touch(0, Vector2(102, 101), true))
	_input._unhandled_input(_touch(0, Vector2(102, 101), false))
	assert_signal_emit_count(_input, "ground_tapped", 1, "The first tap of a double-tap pair fires ground_tapped once; the second tap does not fire a second single tap")

func test_double_tap_resets_camera_zoom_through_farm_world() -> void:
	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	var world: FarmWorld = scene.instantiate()
	add_child_autofree(world)
	await wait_process_frames(1)
	world.farm_camera.zoom = Vector2.ONE * (world.farm_camera.fit_zoom() * 1.4)
	var world_input: FarmInput = world.get_node("FarmInput")
	# reset_zoom() tweens when Motion.reduced is false; force the
	# instant path for a deterministic assertion.
	Motion.reduced = true
	world_input._unhandled_input(_touch(0, Vector2(300, 300), true))
	world_input._unhandled_input(_touch(0, Vector2(300, 300), false))
	world_input._unhandled_input(_touch(0, Vector2(301, 299), true))
	world_input._unhandled_input(_touch(0, Vector2(301, 299), false))
	Motion.reduced = false
	assert_almost_eq(world.farm_camera.zoom.x, world.farm_camera.fit_zoom(), 0.01, "A ground double-tap should reset FarmCamera's zoom back to fit_zoom via FarmWorld's wiring")

func test_farm_world_reemits_building_tapped() -> void:
	# Since Phase 6 Task 7, building views spawn from Game.state.farm.buildings
	# (not the BuildingSlots scene children directly) -- a real session
	# must be set up first.
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([])

	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	var world: FarmWorld = scene.instantiate()
	add_child_autofree(world)
	await wait_process_frames(1)
	watch_signals(world)
	var world_input: FarmInput = world.get_node("FarmInput")
	# One of Task 3's spawned BuildingViews sits at an authored slot
	# position; convert that world position to the current screen
	# position through the camera so the tap resolves to it regardless
	# of the test viewport's actual size/aspect.
	var chicken_coop_slot: Node2D = world.building_slots.get_node("chicken_coop")
	var viewport_size: Vector2 = world.get_viewport().get_visible_rect().size
	var screen_pos: Vector2 = viewport_size / 2.0 + (chicken_coop_slot.position - world.farm_camera.position) * world.farm_camera.zoom
	world_input._unhandled_input(_touch(0, screen_pos, true))
	world_input._unhandled_input(_touch(0, screen_pos, false))
	# assert_signal_emitted_with_parameters's 3rd positional arg is an
	# emission INDEX, not a message (confirmed against GUT's own source
	# after an earlier call here crashed passing a String there) -- use
	# the plain assert plus a separate comment for intent instead.
	assert_signal_emitted_with_parameters(world, "building_tapped", ["chicken_coop"])

	Game.catalog = saved_catalog
	Game.state = saved_state

func test_tapping_a_wheat_bubble_feeds_that_animal() -> void:
	# End-to-end: a real tap on a real spawned StatusBubble reaches
	# Game.feed_animal through FarmWorld._on_bubble_tapped (docs/
	# PROGRESS.md "Phase 3 Task 8" -- the documented temporary seam
	# bypassing the not-yet-built Animal Interaction sheet). Saves and
	# restores Game.catalog/Game.state so this test cannot leak into
	# others (same pattern as test_farm_world_bubbles.gd).
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game.catalog = StateFactory.fixture_catalog()
	# last_seen_ms stamped to "now" (via the real Game.clock, not swapped
	# here) so Game.feed_animal's _advance_to(now) call -- added in
	# Phase 4 -- sees zero elapsed time and does not decay hunger before
	# the feed lands. A stale/zero last_seen_ms would otherwise read as
	# a huge elapsed gap and fully decay hunger first.
	Game.state = StateFactory.game_state_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0})], 5, Game.clock.now_ms())

	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	var world: FarmWorld = scene.instantiate()
	add_child_autofree(world)
	await wait_process_frames(1)
	var world_input: FarmInput = world.get_node("FarmInput")

	var bubble: StatusBubble = world._find_bubble("a1")
	assert_not_null(bubble, "Precondition: the hungry chicken should have spawned a wheat bubble")

	var viewport_size: Vector2 = world.get_viewport().get_visible_rect().size
	var screen_pos: Vector2 = viewport_size / 2.0 + (bubble.global_position - world.farm_camera.position) * world.farm_camera.zoom
	world_input._unhandled_input(_touch(0, screen_pos, true))
	world_input._unhandled_input(_touch(0, screen_pos, false))

	assert_eq(Game.state.player.feed, 4, "Tapping the wheat bubble should have called Game.feed_animal, spending one feed")
	assert_almost_eq(Game.state.farm.get_animal("a1").hunger, 55.0, 0.01)

	Game.catalog = saved_catalog
	Game.state = saved_state

func test_tapping_a_product_bubble_collects_that_animal() -> void:
	# End-to-end: a real tap on a real spawned PRODUCT StatusBubble
	# reaches Game.collect through FarmWorld._on_bubble_tapped's
	# recomputed-from-current-state routing (docs/PROGRESS.md
	# "Phase 4 Task 8").
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0, "progress": 1.0})], 5, Game.clock.now_ms())

	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	var world: FarmWorld = scene.instantiate()
	add_child_autofree(world)
	await wait_process_frames(1)
	var world_input: FarmInput = world.get_node("FarmInput")

	var bubble: StatusBubble = world._find_bubble("a1")
	assert_not_null(bubble, "Precondition: the READY chicken should have spawned a product bubble")
	assert_eq(bubble.bubble_kind, StatusRules.Bubble.PRODUCT)

	var viewport_size: Vector2 = world.get_viewport().get_visible_rect().size
	var screen_pos: Vector2 = viewport_size / 2.0 + (bubble.global_position - world.farm_camera.position) * world.farm_camera.zoom
	world_input._unhandled_input(_touch(0, screen_pos, true))
	world_input._unhandled_input(_touch(0, screen_pos, false))

	assert_eq(Game.state.inventory.get_qty("egg"), 1, "Tapping the product bubble should have called Game.collect, adding an egg")
	assert_almost_eq(Game.state.farm.get_animal("a1").progress, 0.0, 0.0001)

	Game.catalog = saved_catalog
	Game.state = saved_state

func test_tapping_the_chicken_coop_buys_a_chicken() -> void:
	# End-to-end: a real tap on the authored chicken_coop slot reaches
	# Game.buy_animal through FarmWorld._on_building_tapped's temporary
	# seam (docs/PROGRESS.md "Phase 5 Task 8").
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game._guard = ActionGuard.new()  # fresh lock state -- Game is a singleton, so the real guard persists across this file's other purchase/sale tests otherwise
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([], 5, Game.clock.now_ms(), 200, 1)

	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	var world: FarmWorld = scene.instantiate()
	add_child_autofree(world)
	await wait_process_frames(1)
	var world_input: FarmInput = world.get_node("FarmInput")

	var chicken_coop_slot: Node2D = world.building_slots.get_node("chicken_coop")
	var viewport_size: Vector2 = world.get_viewport().get_visible_rect().size
	var screen_pos: Vector2 = viewport_size / 2.0 + (chicken_coop_slot.position - world.farm_camera.position) * world.farm_camera.zoom
	world_input._unhandled_input(_touch(0, screen_pos, true))
	world_input._unhandled_input(_touch(0, screen_pos, false))

	assert_eq(Game.state.player.coins, 100, "Tapping the Coop should have called Game.buy_animal, spending 100 coins")
	assert_eq(Game.state.farm.animals.size(), 1)
	assert_eq(Game.state.farm.animals[0].species, "chicken")

	Game.catalog = saved_catalog
	Game.state = saved_state

func test_tapping_the_feed_storage_buys_a_feed_pack() -> void:
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game._guard = ActionGuard.new()
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([], 5, Game.clock.now_ms(), 200, 1)

	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	var world: FarmWorld = scene.instantiate()
	add_child_autofree(world)
	await wait_process_frames(1)
	var world_input: FarmInput = world.get_node("FarmInput")

	var feed_storage_slot: Node2D = world.building_slots.get_node("feed_storage")
	var viewport_size: Vector2 = world.get_viewport().get_visible_rect().size
	var screen_pos: Vector2 = viewport_size / 2.0 + (feed_storage_slot.position - world.farm_camera.position) * world.farm_camera.zoom
	world_input._unhandled_input(_touch(0, screen_pos, true))
	world_input._unhandled_input(_touch(0, screen_pos, false))

	assert_eq(Game.state.player.coins, 175, "Tapping Feed Storage should have called Game.buy_feed_pack, spending 25 coins")
	assert_eq(Game.state.player.feed, 15)

	Game.catalog = saved_catalog
	Game.state = saved_state

func test_tapping_the_market_sells_the_whole_bag() -> void:
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game._guard = ActionGuard.new()
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([], 5, Game.clock.now_ms(), 0, 1)
	Game.state.inventory.add("egg", 12)

	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	var world: FarmWorld = scene.instantiate()
	add_child_autofree(world)
	await wait_process_frames(1)
	var world_input: FarmInput = world.get_node("FarmInput")

	var market_slot: Node2D = world.building_slots.get_node("market")
	var viewport_size: Vector2 = world.get_viewport().get_visible_rect().size
	var screen_pos: Vector2 = viewport_size / 2.0 + (market_slot.position - world.farm_camera.position) * world.farm_camera.zoom
	world_input._unhandled_input(_touch(0, screen_pos, true))
	world_input._unhandled_input(_touch(0, screen_pos, false))

	assert_eq(Game.state.player.coins, 60, "Tapping Market should have called Game.sell_all, crediting 12 eggs * 5 coins")
	assert_eq(Game.state.inventory.get_qty("egg"), 0)

	Game.catalog = saved_catalog
	Game.state = saved_state

func test_long_pressing_the_chicken_coop_upgrades_it() -> void:
	# End-to-end: a real long press on the authored chicken_coop slot
	# reaches Game.upgrade_building through FarmWorld._on_building_long_pressed's
	# temporary seam (docs/PROGRESS.md "Phase 6 Task 8").
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game._guard = ActionGuard.new()
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([], 5, Game.clock.now_ms(), 1000, 1)

	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	var world: FarmWorld = scene.instantiate()
	add_child_autofree(world)
	await wait_process_frames(1)
	var world_input: FarmInput = world.get_node("FarmInput")

	var chicken_coop_slot: Node2D = world.building_slots.get_node("chicken_coop")
	var viewport_size: Vector2 = world.get_viewport().get_visible_rect().size
	var screen_pos: Vector2 = viewport_size / 2.0 + (chicken_coop_slot.position - world.farm_camera.position) * world.farm_camera.zoom
	world_input._unhandled_input(_touch(0, screen_pos, true))
	await wait_seconds(FarmInput.LONG_PRESS_DURATION + 0.05)
	world_input._unhandled_input(_touch(0, screen_pos, false))

	assert_eq(Game.state.farm.get_building("chicken_coop").level, 2, "Long-pressing the Coop should have called Game.upgrade_building")
	assert_eq(Game.state.player.coins, 500, "1000 - 500 (L2 cost) = 500")

	Game.catalog = saved_catalog
	Game.state = saved_state
