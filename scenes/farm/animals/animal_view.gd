class_name AnimalView
extends Node2D

## Base animal presentation per docs/ARCHITECTURE.md Section 9.3. The
## view holds no game state except `animal_id` -- it reads
## `Game.state.farm.get_animal(animal_id)` when `refresh()` runs.
## Per-species scenes (chicken_view.tscn etc.) inherit this and override
## `tap_zone_size`/`walk_speed`/the body's color and polygon.
##
## Phase 2 scope: bind/refresh (placeholder face only, no bubbles yet --
## those are Phase 3/4), selection ring, and wandering. Feed/collect/tap
## animations (play_feed, play_collect, play_tap, play_drop_in) are
## later-phase additions once there is a real action to animate.
##
## Phase 9 Task 6/9 additions: play_tap()/play_feed()/play_collect()
## react to selection/Game.animal_fed/Game.product_collected for this
## view's own animal_id only (same id-filtering convention as
## _on_animal_changed below). play_tap() delegates its actual motion to
## the overridable _tap_reaction() so each species scene can give its
## own per-species subclass script (chicken_view.gd/cow_view.gd/
## pig_view.gd) a distinct reaction WITHOUT adding any node to this
## base .tscn's root (CLAUDE.md structural risk: every species scene
## hardcodes `index=` values against this scene's exact child order/
## count -- see docs/PROGRESS.md's Phase 2 section for the bug this
## already caused once). Ambient idle flourishes (peck/wiggle/swish) are
## similarly delegated to the overridable _ambient_flourish() hook,
## gated by an injected AmbientBudget (Task 9) so at most 2 animals
## farm-wide are mid-flourish at once. All animation here is pure
## presentation: never mutates Game.state, always kills any in-flight
## tween before starting a new one, and always respects Motion.reduced
## (skipped or drastically shortened).

## Emitted when play_feed() wants a small reward-style floater spawned
## above this animal (a heart, per DESIGN.md Section 10's "Feed | Toss,
## eat, bar fill, heart"). FarmWorld owns the pooled Floater (Task 5) --
## this view does not reach into FarmWorld/world_ui directly, matching
## the existing signal-based decoupling FarmWorld already uses for
## animal_tapped/bubble_tapped/etc. (see FarmWorld._wire_farm_input()).
signal heart_requested(world_pos: Vector2)

## Minimum tap zone per-species (GDD Section 4): chicken 64x64, pig
## 80x72, cow 96x80. Overridden by inherited scenes.
@export var tap_zone_size: Vector2 = Vector2(64, 64)
## Wander speed in dp/s (GDD Section 4): chicken 40, pig 36, cow 20.
@export var walk_speed: float = 40.0

var animal_id: String = ""

## Injectable so wander tests are deterministic (Phase 2 planning note).
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _wander_area: Rect2
var _wander_target: Vector2
var _has_wander_target: bool = false

## Shared budget (Task 9), injected by FarmWorld right after
## instantiation/bind -- NOT created per-view. A view with no budget
## assigned (e.g. a bare instantiate() in a unit test) simply never
## starts an ambient flourish; it never crashes, since every call site
## below null-checks it first.
var ambient_budget: AmbientBudget = null

## Tween handles. Each is killed before a new one starts on the same
## property group (Task 6/9 "retriggering kills any previous in-flight
## tween" requirement), and each is independent so e.g. a tap reaction
## and a blink can run concurrently without fighting over the same tween.
var _reaction_tween: Tween
var _blink_tween: Tween
var _flourish_tween: Tween
var _selection_pulse_tween: Tween

## True while this view currently holds an ambient_budget slot for an
## in-progress flourish, so it releases it exactly once when the
## flourish ends (naturally or interrupted by a retrigger/free).
var _holding_flourish_slot: bool = false

var _blink_timer: float = 0.0
var _next_blink_at: float = 0.0
var _flourish_timer: float = 0.0
var _next_flourish_at: float = 0.0

@onready var _selection_ring: Node2D = %SelectionRing
@onready var _eyes: Node2D = %Eyes

func _ready() -> void:
	_selection_ring.visible = false
	_roll_next_blink()
	_roll_next_flourish()

func bind(id: String, wander_area: Rect2) -> void:
	animal_id = id
	_wander_area = wander_area
	position = _random_point_in_area(wander_area)
	refresh()
	Game.animal_changed.connect(_on_animal_changed)
	Game.animal_status_changed.connect(_on_animal_status_changed)
	Game.animal_fed.connect(_on_animal_fed)
	Game.product_collected.connect(_on_product_collected)

## Re-runs refresh() only for this view's own animal (Game.animal_changed
## fires for whichever animal was just fed/collected/renamed -- every
## other AnimalView's connection ignores it). The connection is freed
## automatically when the view is freed (FarmWorld._rebuild_animals()
## uses free(), not queue_free() -- docs/PROGRESS.md "Phase 1 Task 3"),
## so no manual disconnect is needed here.
func _on_animal_changed(changed_id: String) -> void:
	if changed_id == animal_id:
		refresh()

## Re-runs refresh() for this view's own animal when the SimTick (or any
## command's own _advance_to) changes its status with no accompanying
## animal_changed -- e.g. hunger crossing the HUNGRY threshold purely
## from elapsed time, with no feed/collect command involved (docs/
## PROGRESS.md "Phase 4": the first phase where this can happen).
func _on_animal_status_changed(changed_id: String, _flags: int) -> void:
	if changed_id == animal_id:
		refresh()

## Reads Game.state and applies the placeholder face. Runs on bind()
## and on Game.animal_changed/Game.animal_status_changed for this
## animal (docs/ARCHITECTURE.md Section 9.3).
func refresh() -> void:
	var instance: AnimalInstance = Game.state.farm.get_animal(animal_id)
	if instance == null:
		return
	var flags: int = StatusRules.flags(instance, Game.catalog)
	_apply_face(flags)

## Placeholder face: squash when hungry, tilt when low-happiness. Real
## face art, bubbles, and the wheat/product/cloud indicators are later
## phases (DESIGN.md Section 7's status language).
func _apply_face(flags: int) -> void:
	if flags & StatusRules.HUNGRY != 0:
		_eyes.scale = Vector2(1.0, 0.6)
	else:
		_eyes.scale = Vector2.ONE
	if flags & StatusRules.LOW_HAPPINESS != 0:
		_eyes.rotation = deg_to_rad(8.0)
	else:
		_eyes.rotation = 0.0

## Game.animal_fed fires for whichever animal a feed command just
## succeeded on (every other view's own connection ignores it) -- same
## id-filtering convention as _on_animal_changed above.
func _on_animal_fed(fed_id: String) -> void:
	if fed_id == animal_id:
		play_feed()

## Game.product_collected fires for whichever animal was just collected.
## Note: FarmWorld._on_product_collected() already spawns the reward
## "+amount" Floater and plays the collect sound/haptic (Task 5/6) --
## this handler only adds THIS view's own flourish, it does not
## duplicate any of that.
func _on_product_collected(collected_id: String, _product_id: String, _amount: int) -> void:
	if collected_id == animal_id:
		play_collect()

func set_selected(on: bool) -> void:
	_selection_ring.visible = on
	if on:
		_start_selection_pulse()
	else:
		_stop_selection_pulse()

## Global-space tap rect, used by FarmInput (docs/ARCHITECTURE.md
## Section 9.3). Anchored above the view's origin (the origin sits at
## the animal's feet for correct y-sorting), matching GDD Section 4's
## per-species tap zone size.
func tap_rect() -> Rect2:
	var half: Vector2 = tap_zone_size / 2.0
	return Rect2(global_position + Vector2(-half.x, -tap_zone_size.y), tap_zone_size)

func _process(delta: float) -> void:
	_step_wander(delta)
	_step_blink(delta)
	_step_flourish(delta)

## Purely visual: moves `position` toward a random point inside
## `_wander_area`, never touching AnimalInstance (CLAUDE.md Section 8:
## no persistent state may be frame-driven). Positions are never saved
## (docs/ARCHITECTURE.md Section 9.3).
func _step_wander(delta: float) -> void:
	if _wander_area.size == Vector2.ZERO:
		return
	if not _has_wander_target or position.distance_to(_wander_target) < 2.0:
		_wander_target = _random_point_in_area(_wander_area)
		_has_wander_target = true
		return
	position = compute_wander_step(position, _wander_target, walk_speed, delta)

## Pure function so wander movement is independently testable (frame-rate
## independence: the step must scale with delta, not be a fixed amount
## per _process call per CLAUDE.md Section 8).
static func compute_wander_step(current: Vector2, target: Vector2, speed: float, delta: float) -> Vector2:
	var to_target: Vector2 = target - current
	var distance: float = to_target.length()
	var max_step: float = speed * delta
	if distance <= max_step or distance == 0.0:
		return target
	return current + to_target.normalized() * max_step

func _random_point_in_area(area: Rect2) -> Vector2:
	if area.size == Vector2.ZERO:
		return area.position
	return Vector2(
		rng.randf_range(area.position.x, area.position.x + area.size.x),
		rng.randf_range(area.position.y, area.position.y + area.size.y)
	)

## --- Task 6: tap/feed/collect reactions ---

## Called when the player selects/taps this animal (FarmWorld.
## select_animal(), via animal_tapped -> select_animal). Plays a brief
## per-species reaction (delegated to the overridable _tap_reaction()
## hook so each species subclass script supplies its own language per
## DESIGN.md Section 7) plus a press sound. DESIGN.md Section 10 rule 1
## ("every tap answers with at least one of press animation/sound/
## haptic") is already satisfied by the animation+sound alone; a light
## haptic is added anyway as a reasonable, low-risk touch per this
## task's own guidance.
func play_tap() -> void:
	AudioService.play("button_press")
	AudioService.haptic(AudioService.Haptic.LIGHT)
	if Motion.reduced:
		return
	_tap_reaction()

## Overridable per-species hook (base default: a generic squash, used by
## any species with no more specific override and by the base
## animal_view.tscn itself). chicken_view.gd/cow_view.gd/pig_view.gd
## override this with their own language (CLAUDE.md structural risk: a
## new script file is safe, it does not touch any .tscn node tree/index).
func _tap_reaction() -> void:
	_squash_bounce(0.9, 1.1, 0.16)

## Toss-and-eat feed reaction (DESIGN.md Section 10: "Feed | Toss, eat,
## bar fill, heart"): a squash/bounce over 250-450ms, then a heart
## floater request (FarmWorld owns the pooled Floater -- see
## heart_requested's own comment) plus the feed sound/haptic.
func play_feed() -> void:
	AudioService.play("feed")
	AudioService.haptic(AudioService.Haptic.LIGHT)
	heart_requested.emit(global_position + Vector2(0, -tap_zone_size.y))
	if Motion.reduced:
		return
	_squash_bounce(0.85, 1.15, 0.35)

## Collect flourish (DESIGN.md Section 10: "Collect | Pop, flight,
## floater"). FarmWorld._on_product_collected() already spawns the
## reward floater and (per this task's own wiring choice, see report)
## the collect sound/haptic -- this is ONLY this view's own small pop,
## so neither is duplicated here.
func play_collect() -> void:
	if Motion.reduced:
		return
	_squash_bounce(1.12, 0.95, 0.22)

## Shared squash-then-settle implementation: scales to `down_scale`,
## then to `up_scale`, then back to 1.0, parameterized so _tap_reaction()
## overrides and play_feed()/play_collect() can each use their own
## amount/duration without duplicating the tween plumbing. Always kills
## any in-flight reaction tween first (Task 6/9's "retriggering kills
## the previous tween" requirement) and never touches `self.position`
## beyond the tap zone's own tolerance, so tap_rect() hit-testing is not
## meaningfully desynced mid-animation.
func _squash_bounce(down_scale: float, up_scale: float, total_duration: float) -> void:
	if is_instance_valid(_reaction_tween):
		_reaction_tween.kill()
	scale = Vector2.ONE
	_reaction_tween = create_tween()
	var third: float = total_duration / 3.0
	Motion.apply_overshoot(_reaction_tween.tween_property(self, "scale", Vector2(up_scale, down_scale), third))
	Motion.apply_overshoot(_reaction_tween.tween_property(self, "scale", Vector2(down_scale, up_scale), third))
	Motion.apply_ease_out(_reaction_tween.tween_property(self, "scale", Vector2.ONE, third))

## A small jump: offsets `position.y` up and back. Used by PigView's
## _tap_reaction() override (a pig hop, per this task's species-language
## guidance) -- kept here, not duplicated per-species, since the only
## thing that varies is which hook calls it and with what amount.
func _hop(height: float, total_duration: float) -> void:
	if is_instance_valid(_reaction_tween):
		_reaction_tween.kill()
	var start_y: float = position.y
	_reaction_tween = create_tween()
	Motion.apply_overshoot(_reaction_tween.tween_property(self, "position:y", start_y - height, total_duration / 2.0))
	Motion.apply_ease_out(_reaction_tween.tween_property(self, "position:y", start_y, total_duration / 2.0))

## A brief tilt: rotates and back. Used by CowView's _tap_reaction()
## override (an approximated head-tilt, per this task's own guidance --
## there is no separate head node to animate).
func _tilt(degrees: float, total_duration: float) -> void:
	if is_instance_valid(_reaction_tween):
		_reaction_tween.kill()
	rotation = 0.0
	_reaction_tween = create_tween()
	Motion.apply_overshoot(_reaction_tween.tween_property(self, "rotation", deg_to_rad(degrees), total_duration / 2.0))
	Motion.apply_ease_out(_reaction_tween.tween_property(self, "rotation", 0.0, total_duration / 2.0))

## --- Task 7: drop-in on purchase ---

## Animates this freshly spawned view from `from_pos` (the housing
## building's door/entrance point) to its own current `position` (where
## FarmWorld/bind() already placed it inside the wander area), ending
## with a squash-on-landing. Called by FarmWorld right after bind() for
## a genuine purchase only (never during _rebuild()/boot -- see
## FarmWorld._on_animal_added()). Confetti is a separate, FarmWorld-
## owned runtime-added CPUParticles2D (not this view's concern -- it is
## parented in world space, not to this view, per the structural-risk
## guidance on runtime-only children).
func play_drop_in(from_pos: Vector2, duration: float = 0.3) -> void:
	var target: Vector2 = position
	if Motion.reduced:
		position = target
		return
	position = from_pos
	if is_instance_valid(_reaction_tween):
		_reaction_tween.kill()
	_reaction_tween = create_tween()
	Motion.apply_ease_out(_reaction_tween.tween_property(self, "position", target, duration))
	_reaction_tween.tween_callback(func() -> void: _squash_bounce(1.15, 0.92, 0.18))

## --- Task 9: ambient life (blink, selection pulse, species flourish) ---

const BLINK_MIN_INTERVAL := 4.0
const BLINK_MAX_INTERVAL := 6.0
const BLINK_DURATION := 0.15

const FLOURISH_MIN_INTERVAL := 3.0
const FLOURISH_MAX_INTERVAL := 6.0
## Multiplier applied to the randomized interval when this animal's
## happiness is low (Task 9 spec: "noticeably slower/less frequent...
## a simple multiplier... is sufficient"). Chosen in the middle of the
## spec's suggested 2x-3x range.
const LOW_HAPPINESS_INTERVAL_MULT := 2.5

func _roll_next_blink() -> void:
	_blink_timer = 0.0
	_next_blink_at = rng.randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)

func _roll_next_flourish() -> void:
	_flourish_timer = 0.0
	var base_interval: float = rng.randf_range(FLOURISH_MIN_INTERVAL, FLOURISH_MAX_INTERVAL)
	_next_flourish_at = base_interval * compute_flourish_interval_multiplier(_is_low_happiness())

## Pure function (independently testable without real randomized
## timing, per this task's own test guidance): the interval multiplier
## applied when an animal's happiness is low vs. normal.
static func compute_flourish_interval_multiplier(low_happiness: bool) -> float:
	return LOW_HAPPINESS_INTERVAL_MULT if low_happiness else 1.0

func _is_low_happiness() -> bool:
	if Game.state == null:
		return false
	var instance: AnimalInstance = Game.state.farm.get_animal(animal_id)
	if instance == null:
		return false
	return StatusRules.flags(instance, Game.catalog) & StatusRules.LOW_HAPPINESS != 0

## Blinking is exempt from the ambient budget (Task 9's approved
## interpretation: closer to a status cue than a discretionary
## flourish). Runs every 4-6s regardless of Motion.reduced gating on
## OTHER ambient effects -- but still fully skipped under Motion.reduced
## itself, per this task's own rule 7 ("everything in this task respects
## Motion.reduced").
func _step_blink(delta: float) -> void:
	if Motion.reduced:
		return
	_blink_timer += delta
	if _blink_timer < _next_blink_at:
		return
	_roll_next_blink()
	_play_blink()

func _play_blink() -> void:
	if is_instance_valid(_blink_tween):
		_blink_tween.kill()
	var base_scale: Vector2 = _eyes.scale
	_blink_tween = create_tween()
	Motion.apply_ease_in_out(_blink_tween.tween_property(_eyes, "scale:y", base_scale.y * 0.1, BLINK_DURATION / 2.0))
	Motion.apply_ease_out(_blink_tween.tween_property(_eyes, "scale:y", base_scale.y, BLINK_DURATION / 2.0))

## Species idle flourish, gated by the shared AmbientBudget (Task 9: at
## most 2 animals farm-wide mid-flourish at once). If no slot is free
## this cycle, the attempt is simply skipped -- a new interval is still
## rolled so the animal tries again later, per this task's spec ("no
## error, no queueing needed").
func _step_flourish(delta: float) -> void:
	if Motion.reduced:
		return
	if ambient_budget == null:
		return
	_flourish_timer += delta
	if _flourish_timer < _next_flourish_at:
		return
	_roll_next_flourish()
	if not ambient_budget.request_slot():
		return
	_holding_flourish_slot = true
	_ambient_flourish()

## Overridable per-species hook (base default: a subtle idle nod, used
## by any species with no more specific override). chicken_view.gd/
## cow_view.gd/pig_view.gd override this with their own flourish (peck/
## tail swish/snout wiggle). MUST call _release_flourish_slot() when the
## flourish animation ends, exactly once, so the budget slot is freed.
func _ambient_flourish() -> void:
	_play_timed_flourish(Vector2(1.0, 0.95), 0.5)

## Shared helper: a brief scale-based flourish under 1s that releases
## its ambient_budget slot in a tween callback when it ends. Species
## overrides call this with their own target scale/duration rather than
## each re-implementing the budget release bookkeeping.
func _play_timed_flourish(target_scale: Vector2, duration: float) -> void:
	if is_instance_valid(_flourish_tween):
		_flourish_tween.kill()
	_flourish_tween = create_tween()
	Motion.apply_ease_in_out(_flourish_tween.tween_property(self, "scale", target_scale, duration / 2.0))
	Motion.apply_ease_out(_flourish_tween.tween_property(self, "scale", Vector2.ONE, duration / 2.0))
	_flourish_tween.tween_callback(_release_flourish_slot)

func _release_flourish_slot() -> void:
	if _holding_flourish_slot and ambient_budget != null:
		ambient_budget.release_slot()
	_holding_flourish_slot = false

## Subtle pulsing scale/alpha loop while selected (Task 9: "not gated by
## the budget -- this is tied to a deliberate player action"). Loops
## indefinitely until _stop_selection_pulse() (called from
## set_selected(false)). Skipped entirely under Motion.reduced (the ring
## still shows/hides via `visible`, it just doesn't pulse).
func _start_selection_pulse() -> void:
	if Motion.reduced:
		return
	if is_instance_valid(_selection_pulse_tween):
		_selection_pulse_tween.kill()
	_selection_ring.scale = Vector2.ONE
	_selection_ring.modulate.a = 1.0
	_selection_pulse_tween = create_tween()
	_selection_pulse_tween.set_loops()
	Motion.apply_ease_in_out(_selection_pulse_tween.tween_property(_selection_ring, "scale", Vector2.ONE * 1.1, 0.5))
	Motion.apply_ease_in_out(_selection_pulse_tween.tween_property(_selection_ring, "scale", Vector2.ONE, 0.5))

func _stop_selection_pulse() -> void:
	if is_instance_valid(_selection_pulse_tween):
		_selection_pulse_tween.kill()
	_selection_ring.scale = Vector2.ONE
	_selection_ring.modulate.a = 1.0

## Releases a held ambient-budget slot if this view is freed mid-
## flourish (FarmWorld._rebuild() uses free(), not queue_free() -- a
## view can be freed while its flourish tween is still running). Without
## this, a rebuilt-away view would permanently leak its held slot since
## no tween callback would ever run to release it.
func _exit_tree() -> void:
	_release_flourish_slot()
