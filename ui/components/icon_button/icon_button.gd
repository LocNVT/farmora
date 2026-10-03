class_name IconButton
extends Button

## 48x48 circular icon button per docs/UI_SPEC.md Section 17.4.
## docs/UI_SPEC.md Section 19 requires every icon button to carry an
## accessibility label, so this component refuses to be silent about one:
## an empty `accessibility_label` fails loudly in debug builds rather than
## shipping an unlabeled control.

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_inside_tree():
			_apply_icon()

## Required. Screen readers announce this (e.g. "Settings", "Close").
@export var accessibility_label: String = "":
	set(value):
		accessibility_label = value
		tooltip_text = value

const DIAMETER := 48
const GLYPH_SIZE := 24

func _ready() -> void:
	assert(not accessibility_label.is_empty(), "IconButton requires accessibility_label (docs/UI_SPEC.md Section 19)")
	theme_type_variation = &"IconButton"
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_icon()
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _apply_icon() -> void:
	icon = icon_texture

func _on_button_down() -> void:
	if Motion.reduced:
		return
	var tween := create_tween()
	Motion.apply_ease_out(tween.tween_property(self, "scale", Vector2(0.94, 0.94), UiTokens.DUR_INSTANT))

func _on_button_up() -> void:
	if Motion.reduced:
		return
	var tween := create_tween()
	Motion.apply_overshoot(tween.tween_property(self, "scale", Vector2.ONE, UiTokens.DUR_QUICK))
