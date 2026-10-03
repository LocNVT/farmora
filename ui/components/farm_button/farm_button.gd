class_name FarmButton
extends Button

## Primary/secondary/ghost button per docs/UI_SPEC.md Sections 17.1-17.3
## and docs/DESIGN.md Section 9 (press/release timing). Phase 0 ships this
## as a standalone reusable component; feeding real affordability/loading
## state into it is later-phase work (ARCHITECTURE.md Section 15.4).

enum Variant { PRIMARY, SECONDARY, GHOST }
enum SizeVariant { REGULAR, ROW, TILE }

@export var variant: Variant = Variant.PRIMARY:
	set(value):
		variant = value
		_apply_variant()

## Named `size_variant` (not `size`) to avoid shadowing Control.size.
@export var size_variant: SizeVariant = SizeVariant.REGULAR:
	set(value):
		size_variant = value
		_apply_size_variant()

## Milliseconds the button stays visually locked after a press, per
## docs/UI_SPEC.md Section 12 ("buttons lock 300 ms"). Phase 0 only
## provides the visual lock; the domain-side ActionGuard lock described in
## docs/ARCHITECTURE.md Section 10.4 belongs to the Game autoload (later
## phase).
@export var commit_lock_ms: int = 300

var _disabled_reason: String = ""
var _reason_label: Label
var _lock_timer: Timer
var _scale_tween: Tween

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	_apply_variant()
	_apply_size_variant()
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pressed.connect(_on_pressed)

	# Create the lock timer as a child so it's inspectable and doesn't
	# depend on the node being in SceneTree's create_timer path.
	_lock_timer = Timer.new()
	_lock_timer.one_shot = true
	add_child(_lock_timer)
	_lock_timer.timeout.connect(_on_lock_timer_timeout)

func _apply_variant() -> void:
	match variant:
		Variant.PRIMARY:
			theme_type_variation = &"PrimaryButton"
		Variant.SECONDARY:
			theme_type_variation = &"SecondaryButton"
		Variant.GHOST:
			theme_type_variation = &"GhostButton"

func _apply_size_variant() -> void:
	var height: int
	match size_variant:
		SizeVariant.REGULAR:
			height = UiTokens.BUTTON_HEIGHT
		SizeVariant.ROW:
			height = UiTokens.BUTTON_HEIGHT_ROW
		SizeVariant.TILE:
			height = UiTokens.BUTTON_HEIGHT_TILE
		_:
			height = UiTokens.BUTTON_HEIGHT
	custom_minimum_size.y = height
	custom_minimum_size.x = maxf(custom_minimum_size.x, 88.0)

## Shows (or clears, with an empty string) the reason a disabled button is
## disabled, next to the button. docs/DESIGN.md principle 6: "Disabled
## always explains" -- never a silent grey button.
func set_disabled_reason(text: String) -> void:
	_disabled_reason = text
	if text.is_empty():
		if is_instance_valid(_reason_label):
			_reason_label.queue_free()
			_reason_label = null
		return
	if not is_instance_valid(_reason_label):
		_reason_label = Label.new()
		_reason_label.theme_type_variation = &"CaptionLabel"
		_reason_label.name = "DisabledReasonLabel"
		var parent := get_parent()
		if parent:
			parent.add_child(_reason_label)
		else:
			push_warning("FarmButton.set_disabled_reason() called before the button has a parent; the reason label cannot be shown yet.")
			return
	_reason_label.text = text

## The clay-button "sink" from docs/DESIGN.md Section 9 is normally a 3 dp
## downward translation plus the bottom edge shrinking to 1 dp. A Control
## inside a Container cannot safely animate `position` (the Container
## reassigns it every sort pass), so Phase 0 expresses the same press
## feedback as a small vertical scale toward the pivot instead. Swapping
## this for a position-based sink later (e.g. once buttons sit in
## Container-free overlays) only touches this file.
func _on_button_down() -> void:
	if Motion.reduced:
		return
	# Kill any previously-running scale tween to avoid concurrent tweens.
	if is_instance_valid(_scale_tween):
		_scale_tween.kill()
	pivot_offset = size / 2.0
	_scale_tween = create_tween()
	Motion.apply_ease_out(_scale_tween.tween_property(self, "scale", Vector2(1.0, 0.96), UiTokens.DUR_INSTANT))

func _on_button_up() -> void:
	if Motion.reduced:
		return
	# Kill any previously-running scale tween to avoid concurrent tweens.
	if is_instance_valid(_scale_tween):
		_scale_tween.kill()
	_scale_tween = create_tween()
	Motion.apply_overshoot(_scale_tween.tween_property(self, "scale", Vector2.ONE, UiTokens.DUR_QUICK))

func _on_pressed() -> void:
	# Implement the visual lock: disable the button for commit_lock_ms milliseconds.
	disabled = true
	_lock_timer.start(commit_lock_ms / 1000.0)

func _on_lock_timer_timeout() -> void:
	# Re-enable the button after the lock expires.
	disabled = false
