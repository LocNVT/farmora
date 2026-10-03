class_name Motion
extends RefCounted

## Easing/timing helpers per docs/DESIGN.md Section 9. Godot has no
## cubic-bezier preset, so curves are supplied as Godot's built-in
## Tween.TransitionType/EaseType pairs that visually match the DESIGN.md
## curves closely enough for Phase 0. A perceptual difference, if ever
## found, is a styling fix in this file only.

## Reduced-motion flag. Reading the real OS setting is an engine capability
## gap on Android/iOS noted in docs/ARCHITECTURE.md Section 24 item 13.
## Defaults false; may be toggled in debug builds until that gap is solved.
static var reduced: bool = false

## Entrances. DESIGN.md: cubic-bezier(0.2, 0.8, 0.2, 1).
static func ease_out_transition() -> Tween.TransitionType:
	return Tween.TRANS_CUBIC

static func ease_out_ease() -> Tween.EaseType:
	return Tween.EASE_OUT

## Movement. DESIGN.md: cubic-bezier(0.4, 0, 0.2, 1).
static func ease_in_out_transition() -> Tween.TransitionType:
	return Tween.TRANS_CUBIC

static func ease_in_out_ease() -> Tween.EaseType:
	return Tween.EASE_IN_OUT

## Rewards. DESIGN.md: cubic-bezier(0.34, 1.56, 0.64, 1) (overshoot).
static func overshoot_transition() -> Tween.TransitionType:
	return Tween.TRANS_BACK

static func overshoot_ease() -> Tween.EaseType:
	return Tween.EASE_OUT

## Applies the standard easing to a tweener, honoring reduced-motion by
## leaving duration/transition untouched (callers shorten duration and
## drop particles themselves per DESIGN.md's reduced-motion rules; this
## helper only centralizes which curve "ease_out" etc. means).
static func apply_ease_out(tweener: PropertyTweener) -> PropertyTweener:
	tweener.set_trans(ease_out_transition())
	tweener.set_ease(ease_out_ease())
	return tweener

static func apply_ease_in_out(tweener: PropertyTweener) -> PropertyTweener:
	tweener.set_trans(ease_in_out_transition())
	tweener.set_ease(ease_in_out_ease())
	return tweener

static func apply_overshoot(tweener: PropertyTweener) -> PropertyTweener:
	tweener.set_trans(overshoot_transition())
	tweener.set_ease(overshoot_ease())
	return tweener
