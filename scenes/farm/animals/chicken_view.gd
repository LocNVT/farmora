class_name ChickenView
extends AnimalView

## Per-species override script for chicken_view.tscn (Phase 9 Task 6).
## Attaching this script only changes the root node's `script` property
## in chicken_view.tscn -- it does NOT add/remove/reorder any child node,
## so every `parent="." index="N"` override in that scene (Wing/Comb/
## Beak) remains valid (see CLAUDE.md's structural-risk note this task
## was given, and tests/unit/test_animal_view.gd's species child-order
## regression coverage).
##
## DESIGN.md Section 7's chicken tap language: squash 90%->110%->100%,
## per this task's own spec (quicker/snappier than the base default).

func _tap_reaction() -> void:
	_squash_bounce(0.9, 1.1, 0.16)

func _ambient_flourish() -> void:
	# A quick peck: a brief downward nod.
	_play_timed_flourish_hop(-6.0, 0.4)

## Chicken-specific peck: a small downward dip and back (not a pure
## scale pulse like the base default), still releasing the shared
## ambient_budget slot via the same tween-callback convention.
func _play_timed_flourish_hop(offset_y: float, duration: float) -> void:
	if is_instance_valid(_flourish_tween):
		_flourish_tween.kill()
	var start_y: float = position.y
	_flourish_tween = create_tween()
	Motion.apply_ease_in_out(_flourish_tween.tween_property(self, "position:y", start_y + absf(offset_y), duration / 2.0))
	Motion.apply_ease_out(_flourish_tween.tween_property(self, "position:y", start_y, duration / 2.0))
	_flourish_tween.tween_callback(_release_flourish_slot)
