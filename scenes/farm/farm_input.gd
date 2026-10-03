class_name FarmInput
extends Node

## Farm world input per docs/ARCHITECTURE.md Section 10.1 and
## docs/DESIGN.md Section 11's "Camera"/touch-zone specs.
##
## Tap-vs-drag discrimination, pinch detection, long press, and generic
## duck-typed hit-testing over whatever tiers currently have content.
## The Buildings tier (Phase 1) and Animals tier (Phase 2) have real
## targets; the Bubbles tier is still empty (no WorldUi indicators exist
## until Phase 3/4) -- per the Phase 1 planning review recorded in
## docs/PROGRESS.md ("don't create stub view classes; that's Phase 2/4
## work"), still true for the one remaining empty tier.
##
## Drives FarmCamera's command API (begin_drag/drag_by/end_drag/
## zoom_about) -- this node owns all gesture discrimination; FarmCamera
## has no _unhandled_input of its own (docs/PROGRESS.md Task 4 section).
## Emits the six intent signals docs/ARCHITECTURE.md Section 10.1 names;
## FarmWorld re-emits them and wires ground_double_tapped to
## FarmCamera.reset_zoom() itself (this node does not reach into
## FarmCamera for that -- see FarmWorld._on_ground_double_tapped()).
##
## Only InputEventScreenTouch/InputEventScreenDrag are handled, never
## InputEventMouseButton/InputEventMouseMotion. With
## project.godot's `emulate_touch_from_mouse = true`, Godot delivers
## BOTH a synthetic touch event and the original mouse event per desktop
## click -- handling both would double-fire every tap. Desktop testing
## works entirely through the synthetic touch events.

signal animal_tapped(id: String)
signal bubble_tapped(id: String)
signal building_tapped(id: String)
signal ground_tapped()
signal ground_double_tapped()
signal animal_long_pressed(id: String)
signal building_long_pressed(id: String)

## A touch moving less than this (dp) counts as a tap, not a drag
## (docs/ARCHITECTURE.md Section 10.1: "8 dp or more starts a pan").
const DRAG_THRESHOLD := 8.0

## Long press duration before animal_long_pressed fires (docs/
## ARCHITECTURE.md Section 10.1: "A long press (400 ms) on an animal").
const LONG_PRESS_DURATION := 0.4

## Double-tap timing window. Not specified by any design doc (OPEN
## (arch); see docs/PROGRESS.md) -- 300 ms matches common platform
## double-tap conventions (Android ViewConfiguration / iOS defaults).
const DOUBLE_TAP_WINDOW := 0.3
## Double-tap distance tolerance between the two taps, in dp. Same OPEN
## (arch) status as the timing window.
const DOUBLE_TAP_DISTANCE := 24.0

@export var camera: FarmCamera
@export var buildings_container: Node2D
@export var animals_container: Node2D
@export var world_ui_container: Node2D

## One active-touch record per finger, keyed by Godot's touch `index`.
class _TouchState:
	var start_screen_pos: Vector2
	var last_screen_pos: Vector2
	var start_time_ms: int
	var moved_past_threshold: bool = false
	var long_press_fired: bool = false
	## Release velocity estimate (screen-space dp/s), updated on each
	## drag event from the most recent relative motion and elapsed time.
	## Used to hand FarmCamera.end_drag() a real velocity so the 400 ms
	## inertia spec (docs/ARCHITECTURE.md Section 10.1) actually
	## activates -- an earlier version of this file called
	## camera.end_drag() with no argument, which defaults to
	## Vector2.ZERO and silently never produced inertia. Caught by
	## independent Codex review, not by any test (no test exercised the
	## real _unhandled_input drag-then-release path end to end with
	## timing), so it is recorded here to explain why this field exists.
	var last_drag_velocity: Vector2 = Vector2.ZERO
	var last_drag_time_ms: int = 0

var _touches: Dictionary = {}  # int (touch index) -> _TouchState
var _pinch_start_distance: float = 0.0
var _pinch_active: bool = false
## True once a second finger has joined during the current gesture
## (all touches down -> all touches up), even after that second finger
## lifts first. Without this, releasing the fingers of a pinch in the
## "wrong" order (second finger first) let the remaining single-finger
## release fall through and register as a tap -- caught by
## tests/unit/test_farm_input.gd's pinch-then-release test, not assumed
## correct from the single-finger-released-last case alone.
var _gesture_was_multitouch: bool = false
var _last_tap_time_ms: int = -100000
var _last_tap_pos: Vector2 = Vector2.ZERO
var _long_press_timer: Timer

func _ready() -> void:
	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.wait_time = LONG_PRESS_DURATION
	add_child(_long_press_timer)
	_long_press_timer.timeout.connect(_on_long_press_timer_timeout)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_on_touch_began(event)
	else:
		_on_touch_ended(event)

func _on_touch_began(event: InputEventScreenTouch) -> void:
	var state := _TouchState.new()
	state.start_screen_pos = event.position
	state.last_screen_pos = event.position
	state.start_time_ms = Time.get_ticks_msec()
	_touches[event.index] = state

	if _touches.size() == 1:
		_gesture_was_multitouch = false
		if is_instance_valid(camera):
			camera.begin_drag()
		_long_press_timer.start()
	elif _touches.size() == 2:
		_long_press_timer.stop()
		_pinch_active = true
		_gesture_was_multitouch = true
		_pinch_start_distance = _current_pinch_distance()

func _on_touch_ended(event: InputEventScreenTouch) -> void:
	var state: _TouchState = _touches.get(event.index)
	_touches.erase(event.index)

	if _pinch_active and _touches.size() < 2:
		_pinch_active = false

	if state == null:
		return

	if _touches.is_empty():
		_long_press_timer.stop()
		if is_instance_valid(camera):
			camera.end_drag(state.last_drag_velocity)

	if state.long_press_fired:
		return
	if state.moved_past_threshold:
		return
	if _gesture_was_multitouch:
		# This gesture included a second finger at some point, even if
		# that finger already lifted -- never a tap.
		return
	if not _touches.is_empty():
		# Another finger is still down (e.g. ending a pinch) -- not a tap.
		return

	_handle_tap(event.position)

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	var state: _TouchState = _touches.get(event.index)
	if state == null:
		return
	state.last_screen_pos = event.position

	if not state.moved_past_threshold:
		var total_delta: float = (event.position - state.start_screen_pos).length()
		if total_delta >= DRAG_THRESHOLD:
			state.moved_past_threshold = true
			_long_press_timer.stop()

	if _pinch_active and _touches.size() == 2:
		var new_distance: float = _current_pinch_distance()
		if _pinch_start_distance > 0.0 and is_instance_valid(camera):
			var factor: float = new_distance / _pinch_start_distance
			camera.zoom_about(factor)
		_pinch_start_distance = new_distance
	elif _touches.size() == 1 and state.moved_past_threshold:
		if is_instance_valid(camera):
			camera.drag_by(event.relative)
		_update_drag_velocity(state, event.relative)

## Estimates the touch's release velocity (screen-space dp/s) from the
## most recent drag sample, so FarmCamera.end_drag() can apply real
## inertia. `InputEventScreenDrag` has no built-in velocity in all
## cases, so this is computed from relative motion over elapsed time
## rather than assumed to exist on the event.
func _update_drag_velocity(state: _TouchState, relative: Vector2) -> void:
	var now_ms: int = Time.get_ticks_msec()
	var dt_ms: int = now_ms - state.last_drag_time_ms
	if state.last_drag_time_ms > 0 and dt_ms > 0:
		state.last_drag_velocity = relative / (dt_ms / 1000.0)
	state.last_drag_time_ms = now_ms

func _current_pinch_distance() -> float:
	var positions: Array = _touches.values()
	if positions.size() < 2:
		return 0.0
	var a: Vector2 = (positions[0] as _TouchState).last_screen_pos
	var b: Vector2 = (positions[1] as _TouchState).last_screen_pos
	return a.distance_to(b)

## ARCHITECTURE.md Section 10.1 only documents a long press on an
## animal. `building_long_pressed` is this phase's own temporary
## upgrade-trigger seam (docs/PROGRESS.md "Phase 6" plan item 6 --
## explicitly asked to and approved by the user), added alongside it
## rather than as a separate timer/duration, since GDD Section 6 does
## not specify a different press duration for buildings.
func _on_long_press_timer_timeout() -> void:
	if _touches.size() != 1:
		return
	var state: _TouchState = _touches.values()[0]
	if state.moved_past_threshold:
		return
	var world_pos: Vector2 = _screen_to_world(state.start_screen_pos)
	var hit: Dictionary = _hit_test(world_pos)
	match hit.get("tier"):
		"animal":
			state.long_press_fired = true
			animal_long_pressed.emit(hit.get("id"))
		"building":
			state.long_press_fired = true
			building_long_pressed.emit(hit.get("id"))

func _handle_tap(screen_pos: Vector2) -> void:
	var now_ms: int = Time.get_ticks_msec()
	var is_double_tap: bool = (
		now_ms - _last_tap_time_ms <= int(DOUBLE_TAP_WINDOW * 1000.0)
		and screen_pos.distance_to(_last_tap_pos) <= DOUBLE_TAP_DISTANCE
	)
	_last_tap_time_ms = now_ms
	_last_tap_pos = screen_pos

	var world_pos: Vector2 = _screen_to_world(screen_pos)
	var hit: Dictionary = _hit_test(world_pos)

	match hit.get("tier"):
		"bubble":
			bubble_tapped.emit(hit.get("id"))
		"animal":
			animal_tapped.emit(hit.get("id"))
		"building":
			building_tapped.emit(hit.get("id"))
		_:
			if is_double_tap:
				ground_double_tapped.emit()
				# Reset so a third rapid tap isn't misread as part of
				# another double-tap pair.
				_last_tap_time_ms = -100000
			else:
				ground_tapped.emit()

## Hit-testing priority order (docs/ARCHITECTURE.md Section 10.1):
## bubbles -> animals -> buildings -> empty ground. Within a tier, the
## nearest centre wins. Bubble and animal tiers are empty in Phase 1
## (no WorldUi indicators or AnimalView instances exist yet); the
## contract is duck-typed (`tap_rect() -> Rect2`, `building_id`/`id`
## property) so later phases can add real nodes to these tiers without
## this function changing shape.
func _hit_test(world_pos: Vector2) -> Dictionary:
	var bubble_hit: Variant = _nearest_hit(_bubble_targets(), world_pos)
	if bubble_hit != null:
		return {"tier": "bubble", "id": bubble_hit}

	var animal_hit: Variant = _nearest_hit(_animal_targets(), world_pos)
	if animal_hit != null:
		return {"tier": "animal", "id": animal_hit}

	var building_hit: Variant = _nearest_hit(_building_targets(), world_pos)
	if building_hit != null:
		return {"tier": "building", "id": building_hit}

	return {"tier": "ground"}

## Phase 3: StatusBubble instances now exist (FarmWorld wires
## world_ui_container to its WorldUi container). Returns an empty list
## only if world_ui_container was never set.
func _bubble_targets() -> Array[Node]:
	if not is_instance_valid(world_ui_container):
		return []
	var result: Array[Node] = []
	for child: Node in world_ui_container.get_children():
		result.append(child)
	return result

## Phase 2: AnimalView instances now exist (FarmWorld wires
## animals_container to its Animals container). Returns an empty list
## only if animals_container was never set.
func _animal_targets() -> Array[Node]:
	if not is_instance_valid(animals_container):
		return []
	var result: Array[Node] = []
	for child: Node in animals_container.get_children():
		result.append(child)
	return result

func _building_targets() -> Array[Node]:
	if not is_instance_valid(buildings_container):
		return []
	var result: Array[Node] = []
	for child: Node in buildings_container.get_children():
		result.append(child)
	return result

## Finds the nearest-centre match among `targets` whose tap_rect()
## contains `world_pos`. Each target must duck-type tap_rect() -> Rect2
## and expose a String id via `building_id` (buildings today) or
## `animal_id`/`bubble_id` (future tiers) -- this function reads
## whichever id property exists rather than assuming a type.
func _nearest_hit(targets: Array[Node], world_pos: Vector2) -> Variant:
	var best_id: Variant = null
	var best_distance: float = INF
	for target: Node in targets:
		if not target.has_method("tap_rect"):
			continue
		var rect: Rect2 = target.call("tap_rect")
		if not rect.has_point(world_pos):
			continue
		var center: Vector2 = rect.get_center()
		var distance: float = center.distance_to(world_pos)
		if distance < best_distance:
			best_distance = distance
			best_id = _target_id(target)
	return best_id

func _target_id(target: Node) -> String:
	if "building_id" in target:
		return target.get("building_id")
	if "animal_id" in target:
		return target.get("animal_id")
	if "bubble_id" in target:
		return target.get("bubble_id")
	return ""

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if not is_instance_valid(camera):
		return screen_pos
	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var offset: Vector2 = screen_pos - viewport_size / 2.0
	return camera.position + offset / camera.zoom
