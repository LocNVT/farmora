class_name CowView
extends AnimalView

## Per-species override script for cow_view.tscn (Phase 9 Task 6). See
## chicken_view.gd's header comment for why attaching a script here is
## structurally safe (it does not touch cow_view.tscn's `index=`
## overrides for Patch/Horn/Bell).
##
## DESIGN.md Section 7 / this task's spec: a head-tilt-like reaction on
## tap, approximated via a brief whole-body rotation (~8 degrees) since
## there is no separate head node to animate (this task's own accepted
## judgment call), and a tail-swish ambient flourish (also approximated
## via rotation, at a smaller amplitude).

func _tap_reaction() -> void:
	_tilt(8.0, 0.4)

func _ambient_flourish() -> void:
	_play_timed_tilt(4.0, 0.6)

func _play_timed_tilt(degrees: float, duration: float) -> void:
	if is_instance_valid(_flourish_tween):
		_flourish_tween.kill()
	rotation = 0.0
	_flourish_tween = create_tween()
	Motion.apply_ease_in_out(_flourish_tween.tween_property(self, "rotation", deg_to_rad(degrees), duration / 2.0))
	Motion.apply_ease_out(_flourish_tween.tween_property(self, "rotation", 0.0, duration / 2.0))
	_flourish_tween.tween_callback(_release_flourish_slot)
