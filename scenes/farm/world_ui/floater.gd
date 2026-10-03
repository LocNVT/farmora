class_name Floater
extends Node2D

## Pooled world-space reward indicator per docs/ARCHITECTURE.md Section
## 4.1 ("floater.tscn/.gd '+1 Egg' rising text") and Section 23 ("a small
## reusable pool (8) owned by ... FarmWorld"), and docs/DESIGN.md Section
## 10's "Collect | Pop, flight, floater" / UI_SPEC.md Section 17's
## "600 ms '+1 Egg' floater rises and fades".
##
## Phase 9 Task 5 scope, per this session's approved decision: TEXT-FREE.
## No "+1 Egg" localized string (no tr()/strings.csv setup exists yet --
## explicitly deferred). Shows a plain number (Label, not a translated
## string) in front of a small colored disc tinted per product, reusing
## StatusBubble's PRODUCT_COLORS values so a floater's color matches its
## product's bubble color. Placeholder-tier visual work (CLAUDE.md
## Section 10), not final art.
##
## POOLED, not instanced-per-use: FarmWorld owns a fixed pool of 8 and
## calls show_at() to reuse an idle instance; this node never
## queue_free()s itself.

## Rise distance in dp/world-units over the animation (this task's own
## reference point: "a heart floater rising 40 dp").
const RISE_DISTANCE := 40.0

## Animation duration (UI_SPEC.md Section 17: "600 ms ... floater rises
## and fades").
const DURATION := 0.6

## Reduced-motion duration: a much shorter fade, no rise (this task's
## spec, matching DESIGN.md's general reduced-motion rule of shortening
## rather than fully removing feedback).
const REDUCED_DURATION := 0.15

## Disc tint per product id, reusing StatusBubble.PRODUCT_COLORS'
## values so a floater's color matches its product's bubble (this
## task's own suggestion).
const PRODUCT_COLORS: Dictionary = {
	"egg": "#FFF3D6",
	"milk": "#E6F3FF",
	"pork": "#F4909A",
}
const FALLBACK_COLOR := "#CCCCCC"

var _tween: Tween

@onready var _disc: Polygon2D = %Disc
@onready var _amount_label: Label = %AmountLabel

func _ready() -> void:
	visible = false

## True when this floater is not currently mid-animation -- FarmWorld's
## pool uses this to find the first free instance before falling back
## to recycling the oldest busy one.
func is_idle() -> bool:
	return not is_instance_valid(_tween) or not _tween.is_running()

## Resets this floater to visible at `world_pos`, appearance set from
## `product_id` (disc color) and `amount` (the plain number shown), and
## starts the rise-and-fade animation. Interrupts any animation already
## in progress (the recycle-oldest path) immediately.
func show_at(world_pos: Vector2, product_id: String, amount: int) -> void:
	if is_instance_valid(_tween):
		_tween.kill()

	global_position = world_pos
	modulate.a = 1.0
	visible = true
	if is_instance_valid(_disc):
		_disc.color = Color(PRODUCT_COLORS.get(product_id, FALLBACK_COLOR))
	if is_instance_valid(_amount_label):
		_amount_label.text = "+%d" % amount

	if Motion.reduced:
		_tween = create_tween()
		Motion.apply_ease_out(_tween.tween_property(self, "modulate:a", 0.0, REDUCED_DURATION))
		_tween.tween_callback(func() -> void: visible = false)
		return

	var start_pos: Vector2 = world_pos
	var end_pos: Vector2 = world_pos + Vector2(0, -RISE_DISTANCE)
	_tween = create_tween()
	_tween.set_parallel(true)
	Motion.apply_ease_out(_tween.tween_property(self, "global_position", end_pos, DURATION))
	Motion.apply_ease_out(_tween.tween_property(self, "modulate:a", 0.0, DURATION))
	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void: visible = false)
	# Reset position only after the callback above runs (parallel tweens
	# finish together, then the chained, non-parallel callback fires) --
	# avoids a visible snap back to start_pos while still fading out.
	_tween.tween_callback(func() -> void: global_position = start_pos)
