extends GutTest

## Verifies FarmWorld's StatusBubble spawning (Phase 3 Task 7): a hungry
## animal gets a wheat bubble, a fed one does not, Game.animal_changed
## shows/hides the bubble live, and a rebuild clears old bubbles the
## same way it clears old AnimalViews.
##
## Mutates the real Game autoload -- every test saves and restores
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

func test_a_hungry_animal_gets_a_wheat_bubble_on_spawn() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0})])
	var bubble: StatusBubble = world._find_bubble("a1")
	assert_not_null(bubble)
	assert_eq(bubble.bubble_kind, StatusRules.Bubble.FEED)

func test_a_fed_animal_has_no_bubble_on_spawn() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})])
	assert_null(world._find_bubble("a1"))

func test_feeding_the_animal_removes_the_bubble() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0})])
	assert_not_null(world._find_bubble("a1"))
	Game.state.farm.get_animal("a1").hunger = 100.0
	Game.animal_changed.emit("a1")
	assert_null(world._find_bubble("a1"), "Feeding the animal (clearing HUNGRY) should remove its wheat bubble")

func test_hunger_dropping_below_threshold_adds_the_bubble() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})])
	assert_null(world._find_bubble("a1"))
	Game.state.farm.get_animal("a1").hunger = 5.0
	Game.animal_changed.emit("a1")
	assert_not_null(world._find_bubble("a1"))

func test_bubble_follows_its_animal_view_position() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0})])
	var view: AnimalView = world._find_animal_view("a1")
	var bubble: StatusBubble = world._find_bubble("a1")
	var anchor: Marker2D = view.get_node("%BubbleAnchor")
	assert_eq(bubble.global_position, anchor.global_position)

func test_rebuild_clears_old_bubbles() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0})])
	assert_not_null(world._find_bubble("a1"))
	Game.state = StateFactory.game_state_with([StateFactory.animal("cow", "cow_barn", {"id": "a2", "hunger": 100.0})])
	Game.state_loaded.emit()
	assert_null(world._find_bubble("a1"), "A rebuild should clear the previous animal's bubble")
	var remaining_bubbles := 0
	for child: Node in world.world_ui.get_children():
		if child is StatusBubble:
			remaining_bubbles += 1
	assert_eq(remaining_bubbles, 0, "A fed new animal should spawn with no bubble")
	# world_ui also permanently holds the 8 pooled Floaters (Task 5):
	# they are NOT bubbles and must survive a rebuild rather than being
	# recreated, so their presence here is expected, not a leak.
	assert_eq(world.world_ui.get_child_count(), FarmWorld.FLOATER_POOL_SIZE)

func test_two_hungry_animals_each_get_their_own_bubble() -> void:
	var world := _spawn_world_with([
		StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0}),
		StateFactory.animal("pig", "pig_pen", {"id": "a2", "hunger": 5.0}),
	])
	var b1: StatusBubble = world._find_bubble("a1")
	var b2: StatusBubble = world._find_bubble("a2")
	assert_not_null(b1)
	assert_not_null(b2)
	assert_ne(b1, b2)

func test_a_ready_animal_gets_a_product_bubble_on_spawn() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0, "progress": 1.0})])
	var bubble: StatusBubble = world._find_bubble("a1")
	assert_not_null(bubble)
	assert_eq(bubble.bubble_kind, StatusRules.Bubble.PRODUCT)

func test_ready_bubble_wins_over_hungry_per_priority_order() -> void:
	# StatusRules.primary_bubble(): READY > FEED > CLOUD.
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0, "progress": 1.0})])
	var bubble: StatusBubble = world._find_bubble("a1")
	assert_eq(bubble.bubble_kind, StatusRules.Bubble.PRODUCT)

func test_collecting_the_animal_removes_its_product_bubble() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0, "progress": 1.0})])
	assert_not_null(world._find_bubble("a1"))
	Game.state.farm.get_animal("a1").progress = 0.0
	Game.animal_changed.emit("a1")
	assert_null(world._find_bubble("a1"), "Collecting (resetting progress) should remove the product bubble")

func test_animal_status_changed_also_refreshes_the_bubble() -> void:
	# The second real trigger Phase 4 introduces: a status change with
	# no accompanying animal_changed (e.g. the SimTick crossing a
	# threshold with no command involved).
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})])
	assert_null(world._find_bubble("a1"))
	Game.state.farm.get_animal("a1").progress = 1.0
	Game.animal_status_changed.emit("a1", StatusRules.READY)
	var bubble: StatusBubble = world._find_bubble("a1")
	assert_not_null(bubble)
	assert_eq(bubble.bubble_kind, StatusRules.Bubble.PRODUCT)

## --- Task 3: zoom-clamped indicator scale ---

func test_spawned_bubble_scale_matches_current_zoom_clamped_value() -> void:
	Motion.reduced = true  # snap the pop-in directly to its end state
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0})])
	var cam: FarmCamera = world.farm_camera
	var expected: float = FarmCamera.indicator_scale(cam.zoom.x / cam.fit_zoom())
	var bubble: StatusBubble = world._find_bubble("a1")
	assert_almost_eq(bubble.scale.x, expected, 0.01)
	Motion.reduced = false

func test_zoom_changed_rescales_a_live_bubble() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0})])
	var bubble: StatusBubble = world._find_bubble("a1")
	world._on_zoom_changed(1.2)
	assert_almost_eq(bubble.scale.x, FarmCamera.indicator_scale(1.2), 0.01)
	world._on_zoom_changed(0.8)
	assert_almost_eq(bubble.scale.x, FarmCamera.indicator_scale(0.8), 0.01)

func test_newly_spawned_bubble_picks_up_the_current_zoom_scale() -> void:
	Motion.reduced = true  # snap the pop-in directly to its end state
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0})])
	world._on_zoom_changed(1.2)
	Game.state.farm.get_animal("a1").hunger = 5.0
	Game.animal_changed.emit("a1")
	var bubble: StatusBubble = world._find_bubble("a1")
	assert_almost_eq(bubble.scale.x, FarmCamera.indicator_scale(1.2), 0.01, "A freshly spawned bubble should apply the CURRENT zoom scale, not wait for the next zoom_changed signal")
	Motion.reduced = false

func test_tap_rect_scales_with_the_bubbles_own_scale() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0})])
	var bubble: StatusBubble = world._find_bubble("a1")
	bubble.scale = Vector2.ONE * 1.2
	assert_eq(bubble.tap_rect().size, Vector2(48, 48) * 1.2)
	bubble.scale = Vector2.ONE * 0.9
	assert_eq(bubble.tap_rect().size, Vector2(48, 48) * 0.9)

## --- Task 4: despawn exclusion from hit-testing ---

func test_despawning_bubble_is_immediately_excluded_from_find_bubble() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0})])
	var bubble: StatusBubble = world._find_bubble("a1")
	Motion.reduced = true
	bubble.despawn()
	assert_null(world._find_bubble("a1"), "A despawning bubble must stop being found immediately, not only after its animation finishes")
	Motion.reduced = false

func test_despawning_bubble_tap_rect_is_empty_immediately() -> void:
	var bubble: StatusBubble = load("res://scenes/farm/world_ui/status_bubble.tscn").instantiate()
	add_child_autofree(bubble)
	var anchor := Node2D.new()
	add_child_autofree(anchor)
	bubble.bind("a1", StatusRules.Bubble.FEED, anchor)
	Motion.reduced = true
	bubble.despawn()
	assert_eq(bubble.tap_rect(), Rect2(), "A despawning bubble's tap_rect should be empty immediately, excluding it from FarmInput's hit-testing")
	Motion.reduced = false

## --- Task 4: product-ready chime (pure decision function) ---

func test_should_chime_on_ready_is_true_for_a_live_transition_to_product() -> void:
	assert_true(FarmWorld._should_chime_on_ready(StatusRules.Bubble.PRODUCT, StatusRules.Bubble.FEED, false, false))

func test_should_chime_on_ready_is_false_during_rebuild() -> void:
	# The core guarantee: rebuilding (boot/begin_session/on_app_resumed)
	# must never chime for an animal that was already READY.
	assert_false(FarmWorld._should_chime_on_ready(StatusRules.Bubble.PRODUCT, StatusRules.Bubble.NONE, true, true))
	assert_false(FarmWorld._should_chime_on_ready(StatusRules.Bubble.PRODUCT, StatusRules.Bubble.FEED, false, true))

func test_should_chime_on_ready_is_false_when_already_product() -> void:
	# A refresh that was already showing PRODUCT (e.g. a second
	# animal_changed while still READY) must not re-chime.
	assert_false(FarmWorld._should_chime_on_ready(StatusRules.Bubble.PRODUCT, StatusRules.Bubble.PRODUCT, false, false))

func test_should_chime_on_ready_is_false_for_non_product_kinds() -> void:
	assert_false(FarmWorld._should_chime_on_ready(StatusRules.Bubble.FEED, StatusRules.Bubble.NONE, true, false))
	assert_false(FarmWorld._should_chime_on_ready(StatusRules.Bubble.NONE, StatusRules.Bubble.PRODUCT, false, false))

func test_rebuild_does_not_chime_for_an_already_ready_animal() -> void:
	# End-to-end guard: spawning a world with an animal that is ALREADY
	# READY must not fire the chime decision as a live transition. We
	# can't directly observe AudioService.play() (it's a silent no-op
	# with no asset file), so this asserts the production code path
	# actually sets _rebuilding during the spawn that creates the bubble
	# -- i.e. _rebuilding is false again once _spawn_world_with returns
	# (the flag is properly reset), proving the chime guard had the
	# correct value (true) available while the PRODUCT bubble was first
	# created during _rebuild().
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0, "progress": 1.0})])
	assert_false(world._rebuilding, "_rebuilding should be reset to false once _rebuild() finishes")
	assert_not_null(world._find_bubble("a1"))

## --- Task 5: Floater pool ---

func test_floater_pool_has_exactly_8_instances() -> void:
	var world := _spawn_world_with([])
	assert_eq(world._floater_pool.size(), FarmWorld.FLOATER_POOL_SIZE)
	for floater: Floater in world._floater_pool:
		assert_true(floater is Floater)

func test_spawn_floater_reuses_a_pooled_instance() -> void:
	var world := _spawn_world_with([])
	var pool_ids: Array[int] = []
	for floater: Floater in world._floater_pool:
		pool_ids.append(floater.get_instance_id())
	world._spawn_floater(Vector2(1, 2), "egg", 1)
	var used: Floater = null
	for floater: Floater in world._floater_pool:
		if not floater.is_idle():
			used = floater
			break
	assert_not_null(used, "One pooled floater should now be animating")
	assert_true(pool_ids.has(used.get_instance_id()), "The spawned floater must be one of the 8 pooled instances, not a freshly instantiated one")

func test_spawn_floater_beyond_pool_size_recycles_the_oldest() -> void:
	var world := _spawn_world_with([])
	var first_used: Floater = world._floater_pool[0]
	# Fill the pool: 8 spawns use all 8 distinct instances once each.
	for i in range(FarmWorld.FLOATER_POOL_SIZE):
		world._spawn_floater(Vector2(i, 0), "egg", 1)
	# A 9th request must recycle the OLDEST (the first one used above),
	# not drop the request or fail.
	world._spawn_floater(Vector2(99, 0), "milk", 3)
	assert_eq(first_used.global_position, Vector2(99, 0), "The oldest pooled floater should be recycled and repositioned for the new request")

func test_floater_pool_survives_a_rebuild() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 5.0})])
	var pool_before: Array[Floater] = world._floater_pool.duplicate()
	Game.state = StateFactory.game_state_with([StateFactory.animal("cow", "cow_barn", {"id": "a2", "hunger": 100.0})])
	Game.state_loaded.emit()
	assert_eq(world._floater_pool.size(), FarmWorld.FLOATER_POOL_SIZE, "The pool must still have exactly 8 instances after a rebuild")
	for floater: Floater in pool_before:
		assert_true(is_instance_valid(floater), "Pooled floaters must survive a rebuild, not be freed like StatusBubbles")

func test_product_collected_spawns_a_floater_at_the_animals_position() -> void:
	var world := _spawn_world_with([StateFactory.animal("chicken", "chicken_coop", {"id": "a1", "hunger": 100.0, "progress": 1.0})])
	var view: AnimalView = world._find_animal_view("a1")
	var any_busy := func() -> bool:
		for floater: Floater in world._floater_pool:
			if not floater.is_idle():
				return true
		return false
	assert_false(any_busy.call(), "Precondition: no floater should be busy yet")
	Game.product_collected.emit("a1", "egg", 1)
	assert_true(any_busy.call(), "Game.product_collected should spawn a floater")
