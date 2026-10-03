class_name FarmCamera
extends Camera2D

## Farm world camera per docs/ARCHITECTURE.md Section 10.1 and
## docs/DESIGN.md Section 11's "Camera" spec.
##
## Phase 1 Task 4 scope only: a COMMAND API, not an input handler. This
## node has no `_unhandled_input` of its own -- FarmInput (Task 5) owns
## tap-vs-drag discrimination and pinch detection, and drives this
## camera by calling its public methods. Splitting it this way avoids
## two nodes fighting over the same drag gesture (flagged during Phase 1
## planning, before Task 1 was implemented; see docs/PROGRESS.md).
##
## Not built here: any signal connections to FarmInput (Task 5's job),
## double-tap detection (FarmInput's job; this node only exposes
## reset_zoom() for FarmInput to call), and anything that reads
## Game/state.

## World is authored at 390 units wide (matches FarmWorld.WORLD_WIDTH).
const WORLD_WIDTH := 390.0
## World is authored at 1100 units tall (matches FarmWorld.WORLD_HEIGHT).
const WORLD_HEIGHT := 1100.0

## Player zoom range as a multiplier of fit_zoom (docs/ARCHITECTURE.md
## Section 10.1: "Player zoom is 0.8-1.4 x fit_zoom").
const MIN_ZOOM_MULT := 0.8
const MAX_ZOOM_MULT := 1.4

## Inertia decay duration (docs/ARCHITECTURE.md Section 10.1: "400 ms
## inertia"). Visual only -- does not touch any game state.
const INERTIA_DURATION := 0.4

## Rubber-band: how far past the clamped edge the camera may be pulled
## before snapping back, as a fraction of the viewport size. Not
## specified by any doc (OPEN (arch), see docs/PROGRESS.md); chosen as a
## small, soft overshoot consistent with the "soft rubber-band" wording
## in docs/ARCHITECTURE.md Section 10.1 and docs/DESIGN.md Section 11.
const RUBBER_BAND_FRACTION := 0.08

## focus_on()/reset_zoom() default duration (docs/ARCHITECTURE.md
## Section 10.1: "focus_on(world_pos, duration = 0.28)").
const DEFAULT_FOCUS_DURATION := 0.28

## Emitted whenever the camera's PLAYER zoom (zoom.x / _fit_zoom, the
## 0.8-1.4x range above, not the raw Camera2D.zoom property) actually
## changes, so world-space indicators (StatusBubble, Floater, etc.) can
## rescale via indicator_scale() (docs/ARCHITECTURE.md Section 10.1:
## "World-space indicators ... are scaled by clamp(zoom, 0.9, 1.2) /
## zoom each time the zoom changes"). Emitted once in _ready() so an
## initial scale gets applied, on every zoom_about() call, and once at
## the start and once at the end of a reset_zoom() tween -- not on every
## intermediate tween frame; DESIGN.md does not require perfectly
## continuous rescaling during that single animated transition, only
## that indicators end up correctly sized, so start+end is a reasonable
## approximation per this task's own guidance.
signal zoom_changed(player_zoom: float)

var _fit_zoom: float = 1.0
var _inertia_velocity: Vector2 = Vector2.ZERO
var _inertia_tween: Tween
var _move_tween: Tween
var _zoom_tween: Tween

func _ready() -> void:
	_fit_zoom = fit_zoom()
	zoom = Vector2.ONE * _fit_zoom
	position = _clamp_to_world(position)
	zoom_changed.emit(_player_zoom())

func _process(delta: float) -> void:
	if _inertia_velocity == Vector2.ZERO:
		return
	position += _inertia_velocity * delta
	position = _clamp_to_world(position)
	var decay: float = clampf(1.0 - delta / INERTIA_DURATION, 0.0, 1.0)
	_inertia_velocity *= decay
	if _inertia_velocity.length() < 1.0:
		_inertia_velocity = Vector2.ZERO

## `fit_zoom`: the zoom level at which the authored world width exactly
## fills the viewport width (docs/ARCHITECTURE.md Section 10.1:
## "fit_zoom = viewport_width / world_width"). Computed from the live
## logical viewport width, not the 390 project-setting constant, so it
## stays correct after ScreenFit/content_scale_size adjustments and on
## tablets (planning review: "compute it from the live logical width").
func fit_zoom() -> float:
	return compute_fit_zoom(get_viewport_rect().size.x)

## Pure function so fit_zoom's formula is independently testable without
## a live Viewport.
static func compute_fit_zoom(viewport_width: float) -> float:
	if viewport_width <= 0.0:
		return 1.0
	return viewport_width / WORLD_WIDTH

## Begins a drag gesture. FarmInput calls this once per gesture start.
func begin_drag() -> void:
	_inertia_velocity = Vector2.ZERO
	if is_instance_valid(_inertia_tween):
		_inertia_tween.kill()

## Moves the camera by a screen-space delta during an active drag.
## `screen_delta` is in the same units as input events (dp); converted
## to world units by dividing by the current zoom.
func drag_by(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom
	position = _clamp_to_world(position, RUBBER_BAND_FRACTION)

## Ends a drag gesture, optionally continuing with inertia.
## `release_velocity` is in screen-space dp/s, same convention as
## `drag_by`'s delta.
func end_drag(release_velocity: Vector2 = Vector2.ZERO) -> void:
	position = _clamp_to_world(position)
	_inertia_velocity = -release_velocity / zoom

## Zooms by `factor` (multiplicative) about a screen-space point,
## clamped to [MIN_ZOOM_MULT, MAX_ZOOM_MULT] x fit_zoom. `screen_point`
## is unused for Phase 1 Task 4 (no pinch-about-point visual
## requirement is specified beyond basic clamped zoom); accepted now so
## FarmInput's pinch handling (Task 5) has a stable signature to call
## without a future API change.
func zoom_about(factor: float, _screen_point: Vector2 = Vector2.ZERO) -> void:
	var new_zoom: float = clampf(zoom.x * factor, _fit_zoom * MIN_ZOOM_MULT, _fit_zoom * MAX_ZOOM_MULT)
	zoom = Vector2.ONE * new_zoom
	position = _clamp_to_world(position)
	zoom_changed.emit(_player_zoom())

## Animates back to 1.0x fit_zoom (docs/ARCHITECTURE.md Section 10.1:
## "A double tap on empty ground animates back to 1.0x"). FarmInput
## calls this on a detected double tap; this node does not detect
## double taps itself.
func reset_zoom(duration: float = DEFAULT_FOCUS_DURATION) -> void:
	if is_instance_valid(_zoom_tween):
		_zoom_tween.kill()
	if Motion.reduced:
		zoom = Vector2.ONE * _fit_zoom
		zoom_changed.emit(_player_zoom())
		return
	zoom_changed.emit(_player_zoom())
	_zoom_tween = create_tween()
	Motion.apply_ease_out(_zoom_tween.tween_property(self, "zoom", Vector2.ONE * _fit_zoom, duration))
	_zoom_tween.tween_callback(func() -> void: zoom_changed.emit(_player_zoom()))

## Pans the camera so `world_pos` is centered (docs/ARCHITECTURE.md
## Section 10.1: "pans the camera so an animal sits above the 272 dp
## sheet"). Phase 1 Task 4 scope: centers on the point. The 272 dp sheet
## vertical offset is Task 2+'s AnimalSheet UI, which does not exist yet
## -- callers may pass an already-offset `world_pos` once that exists.
func focus_on(world_pos: Vector2, duration: float = DEFAULT_FOCUS_DURATION) -> void:
	var target: Vector2 = _clamp_to_world(world_pos)
	if is_instance_valid(_move_tween):
		_move_tween.kill()
	if Motion.reduced:
		position = target
		return
	_move_tween = create_tween()
	Motion.apply_ease_in_out(_move_tween.tween_property(self, "position", target, duration))

## Clamps a candidate camera position to the world rect, accounting for
## the current zoom's visible area. `overshoot_fraction` (0 normally,
## RUBBER_BAND_FRACTION during an active drag) allows a soft pull past
## the hard edge. Thin wrapper around the pure, independently testable
## `compute_clamped_position` -- see that function for the horizontal
## inversion case this exists to handle.
func _clamp_to_world(pos: Vector2, overshoot_fraction: float = 0.0) -> Vector2:
	return compute_clamped_position(pos, get_viewport_rect().size, zoom.x, overshoot_fraction)

## PLAYER zoom (zoom.x / fit_zoom), the 0.8-1.4x range this file clamps
## to -- distinct from the raw Camera2D.zoom property, which is
## fit_zoom-scaled and not centered around 1.0.
func _player_zoom() -> float:
	if _fit_zoom <= 0.0:
		return 1.0
	return zoom.x / _fit_zoom

## World-space indicator scale factor for the given PLAYER zoom
## (docs/ARCHITECTURE.md Section 10.1: "World-space indicators ... are
## scaled by clamp(zoom, 0.9, 1.2) / zoom each time the zoom changes, so
## their on-screen size stays between 0.9x and 1.2x"). Pure static
## function, independently testable with no live Camera2D node, per the
## same precedent as compute_fit_zoom/compute_clamped_position above.
static func indicator_scale(player_zoom: float) -> float:
	if player_zoom <= 0.0:
		return 1.0
	return clampf(player_zoom, 0.9, 1.2) / player_zoom

## Pure function so the horizontal-inversion edge case is independently
## testable without a live Camera2D/Viewport.
##
## Horizontal case: at the most-zoomed-out level (0.8x fit_zoom), the
## visible world width (viewport_width / (0.8 * fit_zoom)) is WIDER than
## the 390-unit authored world itself, so a normal [min, max] clamp would
## be inverted (min > max). When that happens, this centers horizontally
## instead of clamping -- caught during Task 4 planning before writing
## this function, not discovered by a failing test.
static func compute_clamped_position(pos: Vector2, viewport_size: Vector2, cam_zoom: float, overshoot_fraction: float = 0.0) -> Vector2:
	var visible_half: Vector2 = (viewport_size / cam_zoom) / 2.0
	var overshoot: Vector2 = viewport_size * overshoot_fraction / cam_zoom

	var result: Vector2 = pos

	var min_x: float = -WORLD_WIDTH / 2.0 + visible_half.x
	var max_x: float = WORLD_WIDTH / 2.0 - visible_half.x
	if min_x > max_x:
		result.x = 0.0
	else:
		result.x = clampf(pos.x, min_x - overshoot.x, max_x + overshoot.x)

	var min_y: float = visible_half.y
	var max_y: float = WORLD_HEIGHT - visible_half.y
	if min_y > max_y:
		result.y = WORLD_HEIGHT / 2.0
	else:
		result.y = clampf(pos.y, min_y - overshoot.y, max_y + overshoot.y)

	return result
