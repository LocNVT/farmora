extends GutTest

## Verifies AnimalView's per-species sizing, the no-building_id-property
## invariant FarmInput's hit-testing depends on, deterministic wander
## stepping, selection ring toggling, and the placeholder face reacting
## to StatusRules flags. Does not test FarmWorld spawning (that's
## test_farm_world.gd) or FarmInput hit-testing against real
## AnimalViews (that's test_farm_input.gd).
##
## Phase 9 Task 6/9 additions: the species child-order/index regression
## guard (CRITICAL -- see CLAUDE.md's structural-risk note; every
## species scene hardcodes `parent="." index="N"` overrides against the
## base animal_view.tscn's exact child order/count), play_tap()/
## play_feed()/play_collect() safety invariants (never mutates
## Game.state, retriggering kills the previous tween, Motion.reduced is
## respected), and AmbientBudget's slot-capping behavior.

## --- CRITICAL regression guard: species scene child order/indices ---
## Re-run this FIRST and after every edit touching animal_view.tscn or
## any species .tscn -- it is the safety net the structural-risk section
## of this task exists for. All three species scenes must still resolve
## child index 2 to "Body" (and have the right total child count/species
## part at each hardcoded index), proving no node was inserted into the
## base scene's root ahead of where each species scene expects.

func test_chicken_scene_child_indices_are_unaffected() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	assert_eq(view.get_child(0).name, "Shadow")
	assert_eq(view.get_child(1).name, "Outline")
	assert_eq(view.get_child(2).name, "Body")
	assert_eq(view.get_child(3).name, "Wing")
	assert_eq(view.get_child(4).name, "Comb")
	assert_eq(view.get_child(5).name, "Beak")
	assert_eq(view.get_child(6).name, "Cheek")
	assert_eq(view.get_child(7).name, "Eyes")
	assert_eq(view.get_child(8).name, "SelectionRing")
	assert_eq(view.get_child(9).name, "BubbleAnchor")

func test_cow_scene_child_indices_are_unaffected() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/cow_view.tscn").instantiate()
	add_child_autofree(view)
	assert_eq(view.get_child(0).name, "Shadow")
	assert_eq(view.get_child(1).name, "Outline")
	assert_eq(view.get_child(2).name, "Body")
	assert_eq(view.get_child(3).name, "Patch")
	assert_eq(view.get_child(4).name, "Horn")
	assert_eq(view.get_child(5).name, "Bell")
	assert_eq(view.get_child(6).name, "Cheek")
	assert_eq(view.get_child(7).name, "Eyes")
	assert_eq(view.get_child(8).name, "SelectionRing")
	assert_eq(view.get_child(9).name, "BubbleAnchor")

func test_pig_scene_child_indices_are_unaffected() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/pig_view.tscn").instantiate()
	add_child_autofree(view)
	assert_eq(view.get_child(0).name, "Shadow")
	assert_eq(view.get_child(1).name, "Outline")
	assert_eq(view.get_child(2).name, "Body")
	assert_eq(view.get_child(3).name, "Snout")
	assert_eq(view.get_child(4).name, "Ear")
	assert_eq(view.get_child(5).name, "Cheek")
	assert_eq(view.get_child(6).name, "Eyes")
	assert_eq(view.get_child(7).name, "SelectionRing")
	assert_eq(view.get_child(8).name, "BubbleAnchor")

func test_base_animal_view_scene_has_the_expected_root_child_order() -> void:
	# Guards the base scene itself: if anyone ever adds a node to its
	# root, this fails FIRST and loudly, before the species-specific
	# tests above start failing for a less obvious reason.
	var view: AnimalView = load("res://scenes/farm/animals/animal_view.tscn").instantiate()
	add_child_autofree(view)
	assert_eq(view.get_child_count(), 7, "animal_view.tscn's root should have exactly 7 children (Shadow, Outline, Body, Cheek, Eyes, SelectionRing, BubbleAnchor)")
	assert_eq(view.get_child(0).name, "Shadow")
	assert_eq(view.get_child(1).name, "Outline")
	assert_eq(view.get_child(2).name, "Body")
	assert_eq(view.get_child(3).name, "Cheek")
	assert_eq(view.get_child(4).name, "Eyes")
	assert_eq(view.get_child(5).name, "SelectionRing")
	assert_eq(view.get_child(6).name, "BubbleAnchor")

func test_chicken_view_has_gdd_sizes() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	assert_eq(view.tap_zone_size, Vector2(64, 64))
	assert_eq(view.walk_speed, 40.0)

func test_pig_view_has_gdd_sizes() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/pig_view.tscn").instantiate()
	add_child_autofree(view)
	assert_eq(view.tap_zone_size, Vector2(80, 72))
	assert_eq(view.walk_speed, 36.0)

func test_cow_view_has_gdd_sizes() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/cow_view.tscn").instantiate()
	add_child_autofree(view)
	assert_eq(view.tap_zone_size, Vector2(96, 80))
	assert_eq(view.walk_speed, 20.0)

func test_animal_view_has_no_building_id_property() -> void:
	# FarmInput._target_id() checks "building_id" BEFORE "animal_id"
	# (farm_input.gd); if AnimalView ever gained a building_id property,
	# a tapped animal would incorrectly report its housing id instead of
	# its own. This is a structural regression guard for that ordering.
	var view: AnimalView = load("res://scenes/farm/animals/animal_view.tscn").instantiate()
	add_child_autofree(view)
	assert_false("building_id" in view, "AnimalView must not have a building_id property")

func test_tap_rect_is_sized_to_tap_zone_and_anchored_above_origin() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	view.global_position = Vector2(100, 200)
	var rect: Rect2 = view.tap_rect()
	assert_eq(rect.size, Vector2(64, 64))
	# Anchored above the origin (the view's origin sits at the animal's
	# feet, for correct y-sorting) -- the rect's bottom edge should be at
	# the origin's y, not straddling it.
	assert_almost_eq(rect.position.y + rect.size.y, 200.0, 0.01)

func test_set_selected_toggles_the_ring() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/animal_view.tscn").instantiate()
	add_child_autofree(view)
	view.set_selected(true)
	assert_true(view.get_node("SelectionRing").visible)
	view.set_selected(false)
	assert_false(view.get_node("SelectionRing").visible)

func test_wander_step_moves_toward_target_proportional_to_delta() -> void:
	var start := Vector2(0, 0)
	var target := Vector2(100, 0)
	var step: Vector2 = AnimalView.compute_wander_step(start, target, 40.0, 1.0)
	# speed 40 dp/s * delta 1.0 s = 40 dp step toward the target.
	assert_almost_eq(step.distance_to(start), 40.0, 0.01)

func test_wander_step_never_overshoots_the_target() -> void:
	var start := Vector2(0, 0)
	var target := Vector2(10, 0)
	# speed * delta (40 * 1.0 = 40) far exceeds the 10-unit distance.
	var step: Vector2 = AnimalView.compute_wander_step(start, target, 40.0, 1.0)
	assert_eq(step, target, "A step larger than the remaining distance should land exactly on the target, not overshoot")

func test_wander_step_is_frame_rate_independent() -> void:
	# Two small steps at half the delta should cover the same ground as
	# one step at the full delta (within float tolerance), proving the
	# step scales with delta rather than being a fixed per-call amount
	# (CLAUDE.md Section 8).
	var start := Vector2(0, 0)
	var target := Vector2(100, 0)
	var one_step: Vector2 = AnimalView.compute_wander_step(start, target, 40.0, 0.5)
	var two_steps: Vector2 = AnimalView.compute_wander_step(one_step, target, 40.0, 0.5)
	var single_full_step: Vector2 = AnimalView.compute_wander_step(start, target, 40.0, 1.0)
	assert_almost_eq(two_steps.x, single_full_step.x, 0.01)

func test_refresh_applies_hungry_face() -> void:
	# Mutates the real Game autoload singleton (refresh() reads
	# Game.state/Game.catalog, per docs/ARCHITECTURE.md Section 9.3) --
	# save and restore both so this test cannot leak state into others.
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0})])

	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	view.animal_id = "a1"
	view.refresh()
	var eyes: Node2D = view.get_node("Eyes")
	assert_eq(eyes.scale, Vector2(1.0, 0.6), "A hungry animal should show the squashed placeholder eyes")

	Game.catalog = saved_catalog
	Game.state = saved_state

func test_bind_reacts_to_game_animal_changed_for_its_own_id() -> void:
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})])

	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	view.bind("a1", Rect2())
	var eyes: Node2D = view.get_node("Eyes")
	assert_eq(eyes.scale, Vector2.ONE, "Precondition: not hungry yet")

	Game.state.farm.get_animal("a1").hunger = 5.0
	Game.animal_changed.emit("a1")
	assert_eq(eyes.scale, Vector2(1.0, 0.6), "The view should refresh when ITS OWN animal_id changes")

	Game.catalog = saved_catalog
	Game.state = saved_state

func test_bind_ignores_game_animal_changed_for_a_different_id() -> void:
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a2", "hunger": 5.0}),
	])

	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	view.bind("a1", Rect2())
	var eyes: Node2D = view.get_node("Eyes")

	Game.animal_changed.emit("a2")
	assert_eq(eyes.scale, Vector2.ONE, "A different animal's change must not refresh this view")

	Game.catalog = saved_catalog
	Game.state = saved_state

func test_freed_view_does_not_error_when_game_animal_changed_fires_again() -> void:
	# Godot auto-disconnects a signal connection when the connected
	# object is freed -- this guards that the bind()->connect() wiring
	# does not leave a dangling callable that errors on the next emit
	# (FarmWorld._rebuild_animals() frees old views with free(), not
	# queue_free() -- docs/PROGRESS.md "Phase 1 Task 3").
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1"})])

	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child(view)
	view.bind("a1", Rect2())
	remove_child(view)
	view.free()

	Game.animal_changed.emit("a1")  # must not error
	assert_true(true, "Reaching this line means the freed view's connection did not error on emit")

	Game.catalog = saved_catalog
	Game.state = saved_state

func test_bind_reacts_to_game_animal_status_changed_for_its_own_id() -> void:
	# docs/PROGRESS.md "Phase 4": the first phase where status can
	# change with no accompanying animal_changed (the SimTick crossing a
	# threshold with no command involved).
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})])

	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	view.bind("a1", Rect2())
	var eyes: Node2D = view.get_node("Eyes")
	assert_eq(eyes.scale, Vector2.ONE, "Precondition: not hungry yet")

	Game.state.farm.get_animal("a1").hunger = 5.0
	Game.animal_status_changed.emit("a1", StatusRules.HUNGRY)
	assert_eq(eyes.scale, Vector2(1.0, 0.6), "The view should refresh when ITS OWN animal_id's status changes")

	Game.catalog = saved_catalog
	Game.state = saved_state

func test_bind_ignores_game_animal_status_changed_for_a_different_id() -> void:
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0}),
		StateFactory.animal("chicken", "chicken_coop", {"id": "a2", "hunger": 5.0}),
	])

	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	view.bind("a1", Rect2())
	var eyes: Node2D = view.get_node("Eyes")

	Game.animal_status_changed.emit("a2", StatusRules.HUNGRY)
	assert_eq(eyes.scale, Vector2.ONE, "A different animal's status change must not refresh this view")

	Game.catalog = saved_catalog
	Game.state = saved_state

## --- Task 6: play_tap()/play_feed()/play_collect() safety invariants ---

func _with_fixture_animal(overrides: Dictionary = {}) -> Dictionary:
	var saved_catalog: GameCatalog = Game.catalog
	var saved_state: GameState = Game.state
	Game.catalog = StateFactory.fixture_catalog()
	var full_overrides: Dictionary = overrides.duplicate()
	full_overrides["id"] = "a1"
	Game.state = StateFactory.game_state_with([StateFactory.animal("chicken", "chicken_coop", full_overrides)])
	return {"catalog": saved_catalog, "state": saved_state}

func test_play_tap_does_not_mutate_game_state() -> void:
	var saved: Dictionary = _with_fixture_animal({"hunger": 100.0, "happiness": 100.0, "progress": 0.0})
	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	view.bind("a1", Rect2())
	var before: Dictionary = Game.state.farm.get_animal("a1").to_dict()
	view.play_tap()
	var after: Dictionary = Game.state.farm.get_animal("a1").to_dict()
	assert_eq(before, after, "play_tap() must be pure presentation, never mutating AnimalInstance")
	Game.catalog = saved.catalog
	Game.state = saved.state

func test_play_feed_does_not_mutate_game_state() -> void:
	var saved: Dictionary = _with_fixture_animal({"hunger": 100.0, "happiness": 100.0, "progress": 0.0})
	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	view.bind("a1", Rect2())
	var before: Dictionary = Game.state.farm.get_animal("a1").to_dict()
	view.play_feed()
	var after: Dictionary = Game.state.farm.get_animal("a1").to_dict()
	assert_eq(before, after, "play_feed() must be pure presentation, never mutating AnimalInstance")
	Game.catalog = saved.catalog
	Game.state = saved.state

func test_play_collect_does_not_mutate_game_state() -> void:
	var saved: Dictionary = _with_fixture_animal({"hunger": 100.0, "happiness": 100.0, "progress": 0.0})
	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	view.bind("a1", Rect2())
	var before: Dictionary = Game.state.farm.get_animal("a1").to_dict()
	view.play_collect()
	var after: Dictionary = Game.state.farm.get_animal("a1").to_dict()
	assert_eq(before, after, "play_collect() must be pure presentation, never mutating AnimalInstance")
	Game.catalog = saved.catalog
	Game.state = saved.state

func test_play_tap_retrigger_kills_the_previous_tween() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	view.play_tap()
	var first_tween: Tween = view._reaction_tween
	assert_true(is_instance_valid(first_tween) and first_tween.is_running(), "Precondition: the first tap's tween should be running")
	view.play_tap()
	assert_false(first_tween.is_running(), "A second play_tap() should kill the first tween, not let both run concurrently")

func test_play_feed_retrigger_kills_the_previous_tween() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	view.play_feed()
	var first_tween: Tween = view._reaction_tween
	view.play_feed()
	assert_false(first_tween.is_running(), "A second play_feed() should kill the first tween")

func test_play_tap_respects_motion_reduced() -> void:
	Motion.reduced = true
	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	view.play_tap()
	assert_false(is_instance_valid(view._reaction_tween) and view._reaction_tween.is_running(), "No reaction tween should start under Motion.reduced")
	assert_eq(view.scale, Vector2.ONE, "Scale should stay untouched under Motion.reduced")
	Motion.reduced = false

func test_play_feed_emits_heart_requested() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	watch_signals(view)
	view.play_feed()
	assert_signal_emitted(view, "heart_requested")

func test_play_tap_calls_the_overridden_per_species_reaction() -> void:
	# Each species scene gets ITS OWN reaction via a per-species script
	# subclass overriding _tap_reaction() -- verified here by checking
	# the view ends up mid-tween after play_tap() on each species
	# (proving _tap_reaction() actually ran, not just the base no-op).
	for scene_path: String in [
		"res://scenes/farm/animals/chicken_view.tscn",
		"res://scenes/farm/animals/cow_view.tscn",
		"res://scenes/farm/animals/pig_view.tscn",
	]:
		var view: AnimalView = load(scene_path).instantiate()
		add_child_autofree(view)
		view.play_tap()
		assert_true(is_instance_valid(view._reaction_tween) and view._reaction_tween.is_running(), "%s's play_tap() should start a reaction tween" % scene_path)

func test_chicken_view_is_chicken_view_subclass() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/chicken_view.tscn").instantiate()
	add_child_autofree(view)
	assert_true(view is ChickenView, "chicken_view.tscn's root should use the ChickenView subclass script")

func test_cow_view_is_cow_view_subclass() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/cow_view.tscn").instantiate()
	add_child_autofree(view)
	assert_true(view is CowView, "cow_view.tscn's root should use the CowView subclass script")

func test_pig_view_is_pig_view_subclass() -> void:
	var view: AnimalView = load("res://scenes/farm/animals/pig_view.tscn").instantiate()
	add_child_autofree(view)
	assert_true(view is PigView, "pig_view.tscn's root should use the PigView subclass script")

## --- Task 9: AmbientBudget ---

func test_ambient_budget_caps_at_two_slots() -> void:
	var budget := AmbientBudget.new()
	assert_true(budget.request_slot())
	assert_true(budget.request_slot())
	assert_false(budget.request_slot(), "A 3rd request while 2 are held should fail")

func test_ambient_budget_release_frees_a_slot_for_the_next_request() -> void:
	var budget := AmbientBudget.new()
	budget.request_slot()
	budget.request_slot()
	assert_false(budget.request_slot())
	budget.release_slot()
	assert_true(budget.request_slot(), "Releasing a slot should free capacity for the next request")

func test_ambient_budget_release_never_goes_negative() -> void:
	var budget := AmbientBudget.new()
	budget.release_slot()  # no matching request_slot() -- must not corrupt the budget
	budget.release_slot()
	assert_eq(budget.used_slots(), 0)
	assert_true(budget.request_slot())
	assert_true(budget.request_slot())
	assert_false(budget.request_slot(), "A stray release should not grant extra capacity beyond MAX_SLOTS")

## --- Task 9: low-happiness flourish interval (pure function) ---

func test_low_happiness_flourish_interval_is_slower_than_normal() -> void:
	var normal_mult: float = AnimalView.compute_flourish_interval_multiplier(false)
	var low_happiness_mult: float = AnimalView.compute_flourish_interval_multiplier(true)
	assert_gt(low_happiness_mult, normal_mult, "A low-happiness animal's flourish interval multiplier should be larger (slower cadence) than normal")
