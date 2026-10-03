class_name BuildingView
extends Node2D

## Base building presentation per docs/ARCHITECTURE.md Section 3 (folder
## structure: "building_view.tscn/.gd (base)") and Section 9.3's AnimalView
## pattern, adapted for buildings per Section 10.1.
##
## Phase 1 Task 3 scope only: this is a placeholder visual with no
## per-building art yet. No `<building_id>_view.tscn` override scenes
## exist, so every building currently uses this base view, distinguished
## only by a body tint selected in bind(). No signals, no economy,
## production or upgrade logic, and no input handling (FarmInput is a
## later task) belong here.

## Body tint per docs/DESIGN.md Section 8 "Building visual direction"
## (primary body color for each MVP building). Used only to visually tell
## the five placeholder blocks apart until real per-building art exists.
const BODY_COLORS: Dictionary = {
	"chicken_coop": Color("#D9A066"),
	"cow_barn": Color("#C94A32"),
	"pig_pen": Color("#B07D4F"),
	"feed_storage": Color("#F1D9A0"),
	"market": Color("#C94A32"),
}

## Fallback tint for an id that does not match any known MVP building.
## Should not happen in practice, but must not crash.
const FALLBACK_COLOR: Color = Color("#CCCCCC")

## Minimum tap-zone size per docs/DESIGN.md Section 5 ("Buildings: 72 x 72 dp")
## and docs/ARCHITECTURE.md Section 10.1.
const MIN_TAP_SIZE: Vector2 = Vector2(72.0, 72.0)

## Phase 9 Task 8: DESIGN.md Section 10's "Upgrade | Squash, sparkle,
## swap | Three hammer taps, medium haptic". The "swap" (per-level art
## change) is an explicit no-op per this task's own spec -- BuildingView
## is still a single placeholder tint block with no L2/L3 art variants,
## so there is nothing to swap. Total duration ~1.2s: a quick squash,
## then a sparkle window. Input is never blocked -- this is pure
## presentation on a Tween, with no modal/freeze of any kind, so the
## farm stays fully interactive throughout.
const UPGRADE_SQUASH_DURATION := 0.3
const UPGRADE_TOTAL_DURATION := 1.2

## Emitted partway through play_upgrade() so FarmWorld can spawn the
## runtime-only sparkle CPUParticles2D at this view's position --
## BuildingView does not reach into FarmWorld/world_ui directly, same
## signal-based decoupling as AnimalView.heart_requested.
signal sparkle_requested(world_pos: Vector2)

## Local-space area animals housed here wander within (Phase 2
## planning note: a reasonable default footprint in front of the
## building; per-building scenes may override this later, same as
## ADR-05's naming-convention extensibility for the body itself). Not
## specified by any design doc -- OPEN (arch), see docs/PROGRESS.md.
@export var wander_rect: Rect2 = Rect2(-56.0, 44.0, 112.0, 56.0)

@onready var _body: Polygon2D = %Body

## The building id this view represents, set by bind(). This is the only
## game-identity state the view holds (the upgrade tween handle below is
## pure presentation, not game state).
var building_id: String = ""

var _upgrade_tween: Tween

## Binds this view to a building id: stores the id and selects the body
## tint from docs/DESIGN.md Section 8. Does not touch any game state --
## there is none to read yet (Phase 1 has no Game/state system).
func bind(id: String) -> void:
	building_id = id
	var color: Color = BODY_COLORS.get(id, FALLBACK_COLOR)
	if is_instance_valid(_body):
		_body.color = color

## Returns the tap zone in GLOBAL coordinates, at least 72x72, centered on
## this view's position. Exists now so FarmInput (Task 5) can hit-test
## buildings later; no input handling happens here.
func tap_rect() -> Rect2:
	var size: Vector2 = MIN_TAP_SIZE
	var half: Vector2 = size / 2.0
	return Rect2(global_position - half, size)

## Returns `wander_rect` in GLOBAL coordinates, for FarmWorld to place
## animals housed here (docs/ARCHITECTURE.md Section 9.3: "the housing
## building's WanderArea rect").
func wander_area() -> Rect2:
	return Rect2(global_position + wander_rect.position, wander_rect.size)

## Plays the upgrade flourish (Task 8): a quick squash, then a sparkle
## window, with three "hammer tap" sound/haptic beats spaced through the
## ~1.2s total. `level` is accepted for a future per-level swap hook but
## unused today (see this const block's own comment -- the swap is an
## explicit no-op for now). Retriggering (a second upgrade before the
## first finishes) kills any in-flight tween first, matching every other
## animated node in this codebase (farm_camera.gd/status_bubble.gd).
## Never blocks input -- purely a Tween on this node's own properties.
func play_upgrade(_level: int) -> void:
	AudioService.play("upgrade")
	AudioService.haptic(AudioService.Haptic.MEDIUM)

	if Motion.reduced:
		return

	if is_instance_valid(_upgrade_tween):
		_upgrade_tween.kill()
	scale = Vector2.ONE
	_upgrade_tween = create_tween()
	Motion.apply_overshoot(_upgrade_tween.tween_property(self, "scale", Vector2(1.1, 0.85), UPGRADE_SQUASH_DURATION / 2.0))
	Motion.apply_ease_out(_upgrade_tween.tween_property(self, "scale", Vector2.ONE, UPGRADE_SQUASH_DURATION / 2.0))
	_upgrade_tween.tween_callback(func() -> void: sparkle_requested.emit(global_position))
	_upgrade_tween.tween_callback(func() -> void: AudioService.play("upgrade"))
	_upgrade_tween.tween_interval((UPGRADE_TOTAL_DURATION - UPGRADE_SQUASH_DURATION) / 2.0)
	_upgrade_tween.tween_callback(func() -> void: AudioService.play("upgrade"))
