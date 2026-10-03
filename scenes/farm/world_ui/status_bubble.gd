class_name StatusBubble
extends Node2D

## World-space status indicator per docs/ARCHITECTURE.md Section 9.2/9.3
## ("WorldUi ... tags, bubbles, badges, floaters (drawn above sprites)";
## "BubbleAnchor (Marker2D) ... the StatusBubble is placed in WorldUi at
## this point") and docs/DESIGN.md Section 11 ("Bubbles | 36 dp visual,
## 48 dp target").
##
## Through Phase 4: FEED (wheat) and PRODUCT (per-product egg/milk/pork
## tint) bubbles. CLOUD has no real trigger yet (happiness.decayPerMinute
## is still inert in the live balance.json). Holds no game state except
## `animal_id`/`bubble_kind` -- it does not read Game.state itself;
## FarmWorld decides when to spawn/free it from
## StatusRules.primary_bubble().

const VISUAL_SIZE := 36.0
const TARGET_SIZE := 48.0

## DESIGN.md Section 11: "Product ready | Product bubble bobs 4 dp on a
## 1.6 s loop with a faint glow ring". FEED has no documented bob (the
## wheat bubble is static; only the ready/product state bobs).
const BOB_AMPLITUDE := 4.0
const BOB_SECONDS := 1.6

## Body tint per bubble kind: FEED uses DESIGN.md's COLOR_STAT_HUNGER
## token; PRODUCT's tint depends on WHICH product (set per-instance in
## bind() via `product_id`, since a chicken/pig/cow all show the same
## Bubble.PRODUCT enum value but a different resource color). CLOUD has
## no real trigger yet, so it falls back to a neutral placeholder tint.
const FEED_COLOR := "#E2A12B"
const PRODUCT_COLORS: Dictionary = {
	"egg": "#FFF3D6",
	"milk": "#E6F3FF",
	"pork": "#F4909A",
}
const FALLBACK_COLOR := "#CCCCCC"

## Glow ring tint for PRODUCT bubbles only (DESIGN.md Section 10's
## "Product bubble bobs 4 dp on a 1.6 s loop with a faint glow ring").
## Placeholder-tier visual work (CLAUDE.md Section 11): a single
## translucent circle behind the body, not final art.
const GLOW_COLOR := Color(1.0, 0.95, 0.6, 0.35)

## Pop-in/pop-out duration (this task's spec: "120ms pop-in on appear" /
## "120ms pop-out on removal").
const POP_DURATION := 0.12

## The animal this bubble belongs to -- the id FarmInput reports via its
## bubble tier (tests/unit/test_farm_input.gd's `_target_id()` duck-type:
## "bubble_id" in target). Tapping the bubble feeds THIS animal, not
## whichever animal happens to be selected.
var animal_id: String = ""
var bubble_kind: StatusRules.Bubble = StatusRules.Bubble.NONE

## The animal's BubbleAnchor Marker2D, followed every frame (docs/
## ARCHITECTURE.md Section 9.2: the bubble lives in WorldUi, a sibling
## of Animals, not a child of any one AnimalView -- "WorldUi ... drawn
## above sprites" -- but the animal wanders continuously (AnimalView's
## _process), so the bubble must track its anchor's position the same
## way, purely visual, never touching AnimalInstance).
var _anchor: Node2D
var _bob_time: float = 0.0

## The zoom-clamped indicator scale this bubble should be/animate to
## (FarmCamera.indicator_scale(), Task 3). Target scale for both the
## pop-in animation and the resting state once it completes -- NOT
## always 1.0, since the bubble must end up at whatever the current
## zoom-clamped scale is.
var _target_scale: float = 1.0

## Set the instant despawn() starts, so tap_rect() (and therefore
## FarmInput's hit-testing, which iterates world_ui_container's direct
## children with no other removal signal) stops matching this bubble
## immediately -- not only once the pop-out animation finishes and
## queue_free() actually runs.
var _despawning: bool = false

var _pop_tween: Tween

@onready var _body: Polygon2D = %Body
@onready var _glow: Polygon2D = %Glow

## `product_id` is read only when `kind == Bubble.PRODUCT` (empty
## string for FEED/CLOUD, which have no per-product variant).
func bind(id: String, kind: StatusRules.Bubble, anchor: Node2D, product_id: String = "") -> void:
	animal_id = id
	bubble_kind = kind
	_anchor = anchor
	global_position = anchor.global_position
	var color: Color = _color_for(kind, product_id)
	if is_instance_valid(_body):
		_body.color = color
	if is_instance_valid(_glow):
		_glow.visible = kind == StatusRules.Bubble.PRODUCT

## Plays the 120ms pop-in (DESIGN.md/this task's spec), ending at
## `target_scale` (the current zoom-clamped indicator scale, Task 3 --
## NOT always 1.0). Snaps directly to the end state under
## Motion.reduced. Callers (FarmWorld) call this once, right after
## bind(), on a freshly spawned bubble only -- re-binding an existing
## bubble (a kind/color change) does not replay the pop-in.
func play_pop_in(target_scale: float = 1.0) -> void:
	_target_scale = target_scale
	if Motion.reduced:
		scale = Vector2.ONE * target_scale
		return
	if is_instance_valid(_pop_tween):
		_pop_tween.kill()
	scale = Vector2.ONE * 0.01
	_pop_tween = create_tween()
	Motion.apply_overshoot(_pop_tween.tween_property(self, "scale", Vector2.ONE * target_scale, POP_DURATION))

## Applies the current zoom-clamped indicator scale (FarmCamera.
## indicator_scale(), Task 3) without animating -- called by FarmWorld
## whenever FarmCamera.zoom_changed fires for every live bubble. Updates
## _target_scale too, so a later despawn() shrinks FROM this new size,
## not a stale one. Interrupts an in-progress pop-in (a zoom change
## mid-pop-in should win immediately -- the bubble must always reflect
## the CURRENT zoom, not finish animating to a now-stale target).
func set_indicator_scale(target_scale: float) -> void:
	_target_scale = target_scale
	if is_instance_valid(_pop_tween):
		_pop_tween.kill()
	scale = Vector2.ONE * target_scale

## Animates a 120ms pop-out, then frees this node. Marks the bubble as
## despawning IMMEDIATELY (not after the animation) so tap_rect()
## excludes it from FarmInput's hit-testing the instant removal starts,
## per this task's spec. Callers (FarmWorld) must call this instead of
## queue_free() directly.
func despawn() -> void:
	if _despawning:
		return
	_despawning = true
	if Motion.reduced:
		queue_free()
		return
	if is_instance_valid(_pop_tween):
		_pop_tween.kill()
	_pop_tween = create_tween()
	Motion.apply_ease_out(_pop_tween.tween_property(self, "scale", Vector2.ZERO, POP_DURATION))
	_pop_tween.tween_callback(queue_free)

func _color_for(kind: StatusRules.Bubble, product_id: String) -> Color:
	if kind == StatusRules.Bubble.FEED:
		return Color(FEED_COLOR)
	if kind == StatusRules.Bubble.PRODUCT:
		return Color(PRODUCT_COLORS.get(product_id, FALLBACK_COLOR))
	return Color(FALLBACK_COLOR)

func _process(delta: float) -> void:
	if not is_instance_valid(_anchor):
		return
	global_position = _anchor.global_position
	if bubble_kind == StatusRules.Bubble.PRODUCT:
		_bob_time += delta
		global_position.y += sin(_bob_time / BOB_SECONDS * TAU) * BOB_AMPLITUDE

## Global-space 48dp tap target, centered on this bubble's position
## (DESIGN.md Section 11), for FarmInput's bubble tier. Scales with this
## bubble's own `scale.x` (Task 3's zoom-clamped indicator scale, applied
## via set_indicator_scale()/play_pop_in()), so the tappable area stays
## in sync with the visual: bigger at 1.2x, smaller at 0.9x. Returns an
## empty, zero-area Rect2 while despawning, so a pop-out in progress is
## excluded from FarmInput's hit-testing immediately, not only once
## queue_free() actually runs.
func tap_rect() -> Rect2:
	if _despawning:
		return Rect2()
	var size: Vector2 = Vector2(TARGET_SIZE, TARGET_SIZE) * scale.x
	return Rect2(global_position - size / 2.0, size)
