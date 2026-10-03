extends GutTest

## Verifies the Phase 1 farm world scaffold (docs/ARCHITECTURE.md Section
## 4.1 / 10.1): the node structure, the five authored BuildingSlots, and
## the world-rect / safe-band constants later tasks (FarmCamera,
## FarmInput) depend on, plus (since Phase 6) that building views spawn
## correctly from real Game.state.farm.buildings.
##
## Mutates the real Game autoload (FarmWorld reads Game.state/catalog on
## _ready() and on Game.state_loaded) -- every test saves and restores
## Game.catalog/Game.state so this file cannot leak state into others.

const EXPECTED_BUILDING_IDS := ["chicken_coop", "cow_barn", "pig_pen", "feed_storage", "market"]

var _saved_catalog: GameCatalog
var _saved_state: GameState
var _world: FarmWorld

func before_each() -> void:
	_saved_catalog = Game.catalog
	_saved_state = Game.state
	Game.catalog = StateFactory.fixture_catalog()
	Game.state = StateFactory.game_state_with([])
	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	_world = scene.instantiate()
	add_child_autofree(_world)

func after_each() -> void:
	Game.catalog = _saved_catalog
	Game.state = _saved_state

func test_scene_structure_matches_architecture() -> void:
	assert_not_null(_world.get_node_or_null("FarmCamera"), "FarmWorld should have a FarmCamera child")
	assert_not_null(_world.backdrop, "FarmWorld.backdrop should resolve via unique name")
	assert_not_null(_world.building_slots, "FarmWorld.building_slots should resolve via unique name")
	assert_not_null(_world.buildings, "FarmWorld.buildings should resolve via unique name")
	assert_not_null(_world.animals, "FarmWorld.animals should resolve via unique name")
	assert_not_null(_world.world_ui, "FarmWorld.world_ui should resolve via unique name")
	assert_not_null(_world.get_node_or_null("FarmInput"), "FarmWorld should have a FarmInput child")

func test_buildings_and_animals_containers_are_y_sorted() -> void:
	assert_true(_world.buildings.y_sort_enabled, "Buildings container should be y-sorted so taller buildings layer correctly")
	assert_true(_world.animals.y_sort_enabled, "Animals container should be y-sorted so animals layer correctly by vertical position")

func test_all_five_mvp_buildings_have_authored_slots() -> void:
	var found: Array[String] = []
	for child: Node in _world.building_slots.get_children():
		assert_true(child is Marker2D, "Every BuildingSlots child should be a Marker2D, found: " + child.get_class())
		found.append(child.name)
	for building_id: String in EXPECTED_BUILDING_IDS:
		assert_true(found.has(building_id), "BuildingSlots should contain a slot named '%s' (GDD Section 6 / balance.json Section 7.3)" % building_id)
	assert_eq(found.size(), EXPECTED_BUILDING_IDS.size(), "BuildingSlots should contain exactly the 5 MVP buildings, no more, no fewer")

func test_building_slots_sit_inside_the_safe_band() -> void:
	var safe_band := FarmWorld.safe_band_rect()
	for child: Node2D in _world.building_slots.get_children():
		var pos: Vector2 = child.position
		assert_true(safe_band.has_point(pos), "Building slot '%s' at %s should be inside the safe band %s (docs/DESIGN.md Section 12 rule 2: buildings are never cropped)" % [child.name, pos, safe_band])

func test_world_rect_contains_the_safe_band() -> void:
	var world_rect := FarmWorld.world_rect()
	var safe_band := FarmWorld.safe_band_rect()
	assert_true(world_rect.encloses(safe_band), "The authored world rect should fully contain the safe band")

func test_buildings_container_has_one_view_per_mvp_building() -> void:
	assert_eq(_world.buildings.get_child_count(), EXPECTED_BUILDING_IDS.size(), "Buildings container should hold exactly one BuildingView per MVP building")

func test_every_building_child_is_a_building_view() -> void:
	for child: Node in _world.buildings.get_children():
		assert_true(child is BuildingView, "Every child of Buildings should be a BuildingView, found: " + child.get_class())

func test_spawned_building_views_match_their_slot_id_and_position() -> void:
	var slots_by_id: Dictionary = {}
	for slot: Node2D in _world.building_slots.get_children():
		slots_by_id[String(slot.name)] = slot.position

	var seen_ids: Array[String] = []
	for child: Node in _world.buildings.get_children():
		var view: BuildingView = child as BuildingView
		assert_not_null(view, "Expected a BuildingView child")
		assert_true(slots_by_id.has(view.building_id), "BuildingView.building_id '%s' should match an authored slot name" % view.building_id)
		assert_eq(view.position, slots_by_id[view.building_id], "BuildingView for '%s' should be positioned exactly at its slot's authored position" % view.building_id)
		seen_ids.append(view.building_id)

	for building_id: String in EXPECTED_BUILDING_IDS:
		assert_true(seen_ids.has(building_id), "A BuildingView should have been spawned for '%s'" % building_id)

func test_every_building_view_tap_rect_is_at_least_72_by_72() -> void:
	for child: Node in _world.buildings.get_children():
		var view: BuildingView = child as BuildingView
		var rect: Rect2 = view.tap_rect()
		assert_true(rect.size.x >= 72.0, "BuildingView '%s' tap_rect width should be >= 72, got %s" % [view.building_id, rect.size.x])
		assert_true(rect.size.y >= 72.0, "BuildingView '%s' tap_rect height should be >= 72, got %s" % [view.building_id, rect.size.y])

func test_building_views_are_not_parented_under_slots_or_farm_world() -> void:
	for slot: Node in _world.building_slots.get_children():
		for grandchild: Node in slot.get_children():
			assert_false(grandchild is BuildingView, "BuildingSlots markers should remain empty position anchors, found a BuildingView under slot '%s'" % slot.name)
	for child: Node in _world.get_children():
		assert_false(child is BuildingView, "BuildingView instances should be children of Buildings, not direct children of FarmWorld")

func test_backdrop_extends_past_the_world_rect() -> void:
	# DESIGN.md Section 12 rule 4: "the meadow background extends to the
	# edges" on tablets, and the camera can zoom out to 0.8x fit_zoom, so
	# the backdrop must be wider than the authored 390-unit world to
	# avoid showing the clear background color at the edges.
	#
	# Phase 9 Task 9 added an "Ambient" Node2D (drifting clouds/swaying
	# grass, ambient_backdrop.gd) as a sibling of Sky/Meadow/Soil under
	# Backdrop -- it is intentionally not a full-width Polygon2D layer
	# (clouds/tufts are small individual shapes), so only the direct
	# Polygon2D children are checked here; this test's intent is "every
	# world-space background LAYER extends past the world rect", not
	# "every child of Backdrop is one".
	var world_rect := FarmWorld.world_rect()
	for layer: Node2D in _world.backdrop.get_children():
		if not (layer is Polygon2D):
			continue
		var poly: PackedVector2Array = (layer as Polygon2D).polygon
		var min_x: float = poly[0].x
		var max_x: float = poly[0].x
		for point: Vector2 in poly:
			min_x = minf(min_x, point.x)
			max_x = maxf(max_x, point.x)
		assert_true(min_x <= world_rect.position.x, "%s should extend to or past the world rect's left edge" % layer.name)
		assert_true(max_x >= world_rect.position.x + world_rect.size.x, "%s should extend to or past the world rect's right edge" % layer.name)

func test_building_views_spawn_from_game_state_not_the_authored_slots_directly() -> void:
	# ARCHITECTURE.md Section 10.1: "Building views from state". Removing
	# a building from Game.state.farm.buildings (while its authored slot
	# marker still exists in the scene) should mean no view spawns for it.
	Game.state = StateFactory.game_state_with([], 0, 0, 0, 1, {})
	Game.state.farm.buildings = Game.state.farm.buildings.filter(func(b: BuildingInstance) -> bool: return b.id != "market")
	Game.state_loaded.emit()
	assert_eq(_world.buildings.get_child_count(), 4, "Removing 'market' from state should mean only 4 views spawn, even though its slot marker still exists in the scene")
	for child: Node in _world.buildings.get_children():
		assert_ne((child as BuildingView).building_id, "market")

func test_rebuild_on_state_loaded_replaces_building_views_not_duplicates_them() -> void:
	Game.state_loaded.emit()
	assert_eq(_world.buildings.get_child_count(), EXPECTED_BUILDING_IDS.size(), "A rebuild should replace the building views, not add to them")

func test_no_building_views_spawn_with_a_null_game_state() -> void:
	# Regression-pattern test matching test_farm_world_animals.gd's own
	# "tolerates null Game.state" coverage, applied to buildings now that
	# they also spawn from state.
	Game.state = null
	var scene: PackedScene = load("res://scenes/farm/farm_world.tscn")
	var world: FarmWorld = scene.instantiate()
	add_child_autofree(world)
	assert_eq(world.buildings.get_child_count(), 0, "A null Game.state should leave the Buildings container empty, not crash")
