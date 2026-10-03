class_name ToastHost
extends Control

## Hosts one toast at a time, per docs/UI_SPEC.md Section 15 ("Queue: one
## at a time; a newer toast replaces the older one"). Positioned by its
## parent (AppShell, later phase) 16 dp above the nav, centered; Phase 0
## only implements the show/replace behavior itself.

const ToastScene := preload("res://ui/components/toast/toast.tscn")

var _current: Toast

func show_toast(text: String, kind: Toast.Kind) -> void:
	if is_instance_valid(_current):
		_current.finished.disconnect(_on_current_finished)
		_current.queue_free()
		_current = null
	_current = ToastScene.instantiate()
	add_child(_current)
	_current.finished.connect(_on_current_finished)
	_current.show_text(text, kind)

func _on_current_finished(toast: Toast) -> void:
	if toast == _current:
		_current = null
	toast.queue_free()
