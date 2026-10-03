class_name PigView
extends AnimalView

## Per-species override script for pig_view.tscn (Phase 9 Task 6). See
## chicken_view.gd's header comment for why attaching a script here is
## structurally safe (it does not touch pig_view.tscn's `index=`
## overrides for Snout/Ear).
##
## DESIGN.md Section 7 / this task's spec: a small jump on tap (~8
## units), and a snout-wiggle ambient flourish.

func _tap_reaction() -> void:
	_hop(8.0, 0.3)

func _ambient_flourish() -> void:
	# Snout wiggle: approximated with a tiny side-to-side rotation,
	# reusing the shared _play_timed_flourish rotation-free scale helper
	# would look wrong for a "wiggle", so this uses rotation instead,
	# with the same budget-release-on-callback convention.
	_play_wiggle(6.0, 0.5)

func _play_wiggle(degrees: float, duration: float) -> void:
	if is_instance_valid(_flourish_tween):
		_flourish_tween.kill()
	rotation = 0.0
	_flourish_tween = create_tween()
	Motion.apply_ease_in_out(_flourish_tween.tween_property(self, "rotation", deg_to_rad(degrees), duration / 4.0))
	Motion.apply_ease_in_out(_flourish_tween.tween_property(self, "rotation", deg_to_rad(-degrees), duration / 2.0))
	Motion.apply_ease_out(_flourish_tween.tween_property(self, "rotation", 0.0, duration / 4.0))
	_flourish_tween.tween_callback(_release_flourish_slot)
