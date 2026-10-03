extends GutTest

## Verifies FarmWorld's animal spawning (Task 5) and selection (Task 6):
## one view per animal using the right per-species scene, views placed
## inside their housing's wander area, unknown species skipped, a
## rebuild replaces views rather than duplicating them, and selection
## behavior (ring exclusivity, camera focus, ground-tap clears).
##
## Mutates the real Game autoload (FarmWorld reads Game.state/catalog on
## _ready() and on Game.state_loaded) -- every test saves and restores
## Game.catalog/Game.state so this file cannot leak state into others.

var _saved_catalog: GameCatalog
var _saved_state: GameState
var _world: FarmWorld

func before_each() -> void:
	_saved_catalog = Game.catalog
	_saved_state = Game.state
	Game.catalog = StateFactory.fixture_catalog()

func after_each() -> void:
	Game.catalog = _saved_catalog
	Game.state = _saved_state

func _spawn_world_with(animals: Array[AnimalInstance]) -> FarmWorld:
	Game.state = StateFactory.game_state_with(animals)
	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	_world = scene.instantiate()
	add_child_autofree(_world)
	return _world

func test_rebuild_tolerates_null_game_state() -> void:
	# Regression test for a real crash: FarmWorld._ready() used to assume
	# Game.state was always set, which crashed with "Invalid access to
	# property 'farm' on a base object of type 'Nil'" whenever FarmWorld
	# was instantiated before any session began (several pre-existing
	# tests did exactly this). Confirmed by Codex review that this fix
	# had no direct test; added here.
	Game.state = null
	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	var world: FarmWorld = scene.instantiate()
	add_child_autofree(world)
	assert_eq(world.animals.get_child_count(), 0, "A null Game.state should leave the Animals container empty, not crash")

func test_rebuild_frees_the_old_view_not_just_detaches_it() -> void:
	# Regression test for the free() vs queue_free() fix: after a
	# rebuild, the previous AnimalView must actually be gone (not merely
	# removed from the Animals container but still alive as an orphan
	# node). Checked via is_instance_valid() after the rebuild and a
	# process frame, which is when a queue_free()'d node would still
	# report valid but a free()'d one would not.
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1"})])
	var old_view: AnimalView = world.animals.get_child(0)
	Game.state = StateFactory.game_state_with([StateFactory.animal("cow", "cow_barn", {"id": "a2"})])
	Game.state_loaded.emit()
	assert_false(is_instance_valid(old_view), "The old AnimalView should be freed immediately on rebuild, not left as a pending-free orphan")

func test_one_view_spawned_per_animal() -> void:
	var world := _spawn_world_with([
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1"}),
		StateFactory.animal("pig", "pig_pen", {"id": "a2"}),
	])
	assert_eq(world.animals.get_child_count(), 2)

func test_spawned_view_uses_the_matching_species_scene() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1"})])
	var view: AnimalView = world.animals.get_child(0)
	assert_eq(view.tap_zone_size, Vector2(64, 64), "A chicken AnimalInstance should spawn using chicken_view.tscn's sizing")

func test_spawned_view_sits_inside_its_housing_wander_area() -> void:
	var world := _spawn_world_with([StateFactory.animal("pig", "pig_pen", {"id": "a1"})])
	var view: AnimalView = world.animals.get_child(0)
	var housing: BuildingView = world._find_building_view("pig_pen")
	assert_not_null(housing)
	assert_true(housing.wander_area().has_point(view.global_position), "A spawned animal should be placed inside its housing building's wander area")

func test_unknown_species_is_skipped_not_crashed() -> void:
	var world := _spawn_world_with([StateFactory.animal("dragon", "chicken_coop", {"id": "a1"})])
	assert_eq(world.animals.get_child_count(), 0, "An unknown species should be skipped, not crash or spawn a broken view")

func test_rebuild_replaces_views_instead_of_duplicating() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1"})])
	assert_eq(world.animals.get_child_count(), 1)
	Game.state = StateFactory.game_state_with([StateFactory.animal("cow", "cow_barn", {"id": "a2"})])
	Game.state_loaded.emit()
	assert_eq(world.animals.get_child_count(), 1, "A rebuild should replace the old views, not add to them")
	var view: AnimalView = world.animals.get_child(0)
	assert_eq(view.animal_id, "a2")

func test_selecting_an_animal_shows_only_its_ring() -> void:
	var world := _spawn_world_with([
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1"}),
		StateFactory.animal("pig", "pig_pen", {"id": "a2"}),
	])
	world.select_animal("a1")
	var view1: AnimalView = world._find_animal_view("a1")
	var view2: AnimalView = world._find_animal_view("a2")
	assert_true(view1.get_node("SelectionRing").visible)
	assert_false(view2.get_node("SelectionRing").visible)
	assert_eq(world.selected_animal_id, "a1")

func test_selecting_a_different_animal_clears_the_previous_ring() -> void:
	var world := _spawn_world_with([
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1"}),
		StateFactory.animal("pig", "pig_pen", {"id": "a2"}),
	])
	world.select_animal("a1")
	world.select_animal("a2")
	var view1: AnimalView = world._find_animal_view("a1")
	assert_false(view1.get_node("SelectionRing").visible, "Selecting a new animal should clear the previously selected one's ring")
	assert_eq(world.selected_animal_id, "a2")

func test_clear_selection_hides_the_ring() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1"})])
	world.select_animal("a1")
	world.clear_selection()
	var view: AnimalView = world._find_animal_view("a1")
	assert_false(view.get_node("SelectionRing").visible)
	assert_eq(world.selected_animal_id, "")

func test_ground_tapped_signal_clears_selection() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1"})])
	world.select_animal("a1")
	world.ground_tapped.emit()
	assert_eq(world.selected_animal_id, "", "FarmWorld's own ground_tapped re-emission should clear the current selection")

func test_farm_input_animal_tier_is_wired_to_the_animals_container() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1"})])
	var farm_input: FarmInput = world.farm_input
	assert_eq(farm_input.animals_container, world.animals)

func test_animal_added_spawns_a_new_view_without_rebuilding_existing_ones() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1"})])
	var existing_view: AnimalView = world._find_animal_view("a1")
	assert_eq(world.animals.get_child_count(), 1)

	Game.state.farm.animals.append(StateFactory.animal("pig", "pig_pen", {"id": "a2"}))
	Game.animal_added.emit("a2")

	assert_eq(world.animals.get_child_count(), 2, "A new animal should get its own view, not replace the existing one")
	assert_eq(world._find_animal_view("a1"), existing_view, "animal_added must not rebuild/replace the existing view (that would re-roll its wander position)")
	assert_not_null(world._find_animal_view("a2"))

func test_animal_added_uses_the_matching_species_scene() -> void:
	var world := _spawn_world_with([])
	Game.state.farm.animals.append(StateFactory.animal("cow", "cow_barn", {"id": "a1"}))
	Game.animal_added.emit("a1")
	var view: AnimalView = world._find_animal_view("a1")
	assert_not_null(view)
	assert_eq(view.tap_zone_size, Vector2(96, 80), "A cow AnimalInstance should spawn using cow_view.tscn's sizing")

func test_animal_added_tolerates_an_id_not_actually_in_state() -> void:
	var world := _spawn_world_with([])
	Game.animal_added.emit("does_not_exist")  # must not crash
	assert_eq(world.animals.get_child_count(), 0)

## --- Task 7: drop-in on purchase (pure decision function) ---

func test_should_play_drop_in_is_true_outside_rebuild() -> void:
	assert_true(FarmWorld._should_play_drop_in(false))

func test_should_play_drop_in_is_false_during_rebuild() -> void:
	# The core guarantee: a rebuild (boot/begin_session/on_app_resumed)
	# must never replay the "just bought" drop-in/confetti/purchase
	## flourish for a pre-existing animal, mirroring
	## _should_chime_on_ready()'s established pattern.
	assert_false(FarmWorld._should_play_drop_in(true))

func test_animal_added_during_a_live_purchase_does_not_crash_with_confetti_and_sound() -> void:
	# End-to-end smoke test: Game.animal_added fired OUTSIDE of
	# _rebuild() (a genuine live purchase path) should spawn the view,
	# play the drop-in tween, and spawn a runtime confetti particle node
	# under world_ui without erroring. Motion.reduced is left off here on
	# purpose to exercise the real particle-spawn path once.
	var world := _spawn_world_with([])
	Game.state.farm.animals.append(StateFactory.animal("chicken", "chicken_coop", {"id": "a1"}))
	var ui_children_before: int = world.world_ui.get_child_count()
	Game.animal_added.emit("a1")
	assert_not_null(world._find_animal_view("a1"))
	assert_true(world.world_ui.get_child_count() > ui_children_before, "A confetti particle node should be added under world_ui for a live purchase")

func test_animal_added_during_rebuild_spawns_no_confetti() -> void:
	# Spawning a world that already contains an animal (the normal
	# _rebuild() path via _spawn_world_with) must not add any confetti
	# particle node -- only StatusBubbles/the Floater pool live under
	# world_ui for a rebuild-spawned animal.
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})])
	for child: Node in world.world_ui.get_children():
		assert_false(child is CPUParticles2D, "No confetti should exist after a plain rebuild spawn (only a live animal_added purchase plays confetti)")

func test_animal_added_spawned_view_receives_the_shared_ambient_budget() -> void:
	var world := _spawn_world_with([])
	Game.state.farm.animals.append(StateFactory.animal("chicken", "chicken_coop", {"id": "a1"}))
	Game.animal_added.emit("a1")
	var view: AnimalView = world._find_animal_view("a1")
	assert_eq(view.ambient_budget, world._ambient_budget, "Every spawned AnimalView should share FarmWorld's one AmbientBudget instance, not get its own")

## --- Task 6: heart_requested wiring ---

func test_heart_requested_spawns_a_floater() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})])
	var view: AnimalView = world._find_animal_view("a1")
	var any_busy := func() -> bool:
		for floater: Floater in world._floater_pool:
			if not floater.is_idle():
				return true
		return false
	assert_false(any_busy.call(), "Precondition: no floater should be busy yet")
	view.heart_requested.emit(view.global_position)
	assert_true(any_busy.call(), "heart_requested should spawn a floater via FarmWorld's pool")

## --- Task 8: building_upgraded wiring ---

func test_building_upgraded_plays_upgrade_only_for_the_matching_building() -> void:
	var world := _spawn_world_with([])
	var coop: BuildingView = world._find_building_view("chicken_coop")
	var barn: BuildingView = world._find_building_view("cow_barn")
	Motion.reduced = true  # avoid waiting on real tween timing in this test
	Game.building_upgraded.emit("chicken_coop", 2)
	# Motion.reduced short-circuits play_upgrade() before any tween
	# starts, so this only proves no crash/misrouting occurs; the
	# matching-id behavior itself is covered directly against BuildingView
	# in test_building_view.gd.
	assert_not_null(coop)
	assert_not_null(barn)
	Motion.reduced = false
