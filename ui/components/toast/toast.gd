class_name Toast
extends PanelContainer

## One toast, per docs/UI_SPEC.md Section 15: 48 dp tall, in 200 ms, holds
## 2.2 s, out 160 ms. ToastHost owns the one-at-a-time queue; this scene
## only knows how to show itself and signal when it is done.

enum Kind { SUCCESS, PROBLEM, INFO }

signal finished(this_toast: Toast)

@onready var _label: Label = %Label

var kind: Kind = Kind.INFO

func _ready() -> void:
	custom_minimum_size.y = 48
	modulate.a = 0.0

func show_text(text: String, toast_kind: Kind) -> void:
	kind = toast_kind
	_label.text = text
	# Label has no stylebox theme item in Godot 4 (verified against the
	# engine's theme item list), so the pill background is a separate
	# PanelContainer-type variation on `self` (the root); the Label takes
	# its own matching font-color variation. A Theme type variation name
	# is unique regardless of base type, so these cannot share one name.
	match kind:
		Kind.SUCCESS:
			theme_type_variation = &"ToastSuccessPanel"
			_label.theme_type_variation = &"ToastSuccessLabel"
		Kind.PROBLEM:
			theme_type_variation = &"ToastProblemPanel"
			_label.theme_type_variation = &"ToastProblemLabel"
		Kind.INFO:
			theme_type_variation = &"ToastInfoPanel"
			_label.theme_type_variation = &"ToastInfoLabel"
	_play()

func _play() -> void:
	var tween := create_tween()
	if Motion.reduced:
		tween.tween_property(self, "modulate:a", 1.0, 0.0)
		tween.tween_interval(UiTokens.TOAST_HOLD)
		tween.tween_property(self, "modulate:a", 0.0, 0.0)
	else:
		Motion.apply_ease_out(tween.tween_property(self, "modulate:a", 1.0, UiTokens.TOAST_IN))
		tween.tween_interval(UiTokens.TOAST_HOLD)
		Motion.apply_ease_out(tween.tween_property(self, "modulate:a", 0.0, UiTokens.TOAST_OUT))
	tween.finished.connect(func() -> void: finished.emit(self))
