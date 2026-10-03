class_name FarmWorld
extends Node2D

## The farm world scene per docs/ARCHITECTURE.md Section 4.1 / 10.1.
##
## Phase 1 scope (through Task 3): the authored world scaffold (Backdrop,
## BuildingSlots, Buildings/Animals/WorldUi containers), the world-space
## constants later tasks (FarmCamera, FarmInput) read, and spawning
## BuildingView instances at the authored BuildingSlots markers. This file
## does not handle input or own a camera yet, does not spawn animals, and
## has no economy/production/save logic -- those are separate Phase 1+
## tasks per the agreed breakdown (docs/PROGRESS.md records the full
## sequencing).
##
## "Farm grid" / "Basic terrain" (CLAUDE.md Phase 1) are not a tile/grid
## mechanic -- docs/GDD.md has none. They map to this authored world
## layout (the world rect and BuildingSlots positions) and the static
## Backdrop (meadow/sky/soil), respectively. Recorded in docs/PROGRESS.md
## alongside the other phase-wording interpretations
## (docs/ARCHITECTURE.md Section 24 item 7 already did the same for
## "Building placement foundation").

## World is authored at 390 units wide (docs/ARCHITECTURE.md Section 10.1:
## "The world is authored at 390 units wide").
const WORLD_WIDTH := 390.0
## Total authored world height. Taller than the 390x844 reference screen
## so there is ground below and sky above to crop per docs/DESIGN.md
## Section 12 rule 2 ("taller screens add ground at the bottom, shorter
## screens crop sky at the top. Buildings and animals are never cropped").
const WORLD_HEIGHT := 1100.0

## The safe band: the vertical range (in world/local Y) where buildings
## and animals may be placed so they are never cropped at any reference
## size. Derived from docs/DESIGN.md Section 11's Farm screen zones at
## the 390x844 reference: HUD 72 dp + up to 59 dp top inset, bottom nav
## 106 dp. At zoom 1.0 (fit_zoom), 1 world unit = 1 dp, so the same
## numbers apply directly in world space.
const SAFE_BAND_TOP := 140.0
const SAFE_BAND_BOTTOM := 738.0

## Base building view scene, used as the fallback for every building id
## until per-id override scenes (`<building_id>_view.tscn`) exist, per
## docs/ARCHITECTURE.md Section 3 and Section 9.3's "missing art fallback"
## rule (applied to buildings per Section 10.1).
const BUILDING_VIEW_SCENE: PackedScene = preload("res://scenes/farm/buildings/building_view.tscn")

## Base animal view scene, used as the fallback for any species with no
## `<species_id>_view.tscn` (there should always be one for the 3 MVP
## species, but this guards against a typo'd/missing scene per DESIGN.md
## Section 12 rule 9's "missing art falls back to a placeholder" rule).
const ANIMAL_VIEW_SCENE: PackedScene = preload("res://scenes/farm/animals/animal_view.tscn")

## The world-space status indicator placed at each animal's BubbleAnchor
## (docs/ARCHITECTURE.md Section 9.2/9.3), spawned/freed by FarmWorld
## rather than owned by AnimalView itself, since "WorldUi (tags, bubbles,
## badges, floaters)" is a sibling container to Animals, not a child of
## any one AnimalView.
const STATUS_BUBBLE_SCENE: PackedScene = preload("res://scenes/farm/world_ui/status_bubble.tscn")

## The pooled "+1"-style world-space reward indicator (docs/
## ARCHITECTURE.md Section 4.1's folder map: "floater.tscn/.gd '+1 Egg'
## rising text"; Section 23 item: "a small reusable pool (8) owned by
## the HUD and FarmWorld"). Phase 9 Task 5 scope: text-free (a plain
## number, no localized string) per this task's approved decision --
## see Floater's own header comment.
const FLOATER_SCENE: PackedScene = preload("res://scenes/farm/world_ui/floater.tscn")

## Pool size (this task's spec + ARCHITECTURE.md Section 23's "a small
## reusable pool (8)").
const FLOATER_POOL_SIZE := 8

## Confetti/sparkle particle cap (Phase 9 Task 7/8 spec: "Confetti capped
## at 20 particles"; the upgrade sparkle reuses the same ceiling for
## consistency, per this task's own "your call, keep it modest" guidance).
const CONFETTI_PARTICLE_COUNT := 20
const SPARKLE_PARTICLE_COUNT := 12

## Re-emitted FarmInput intent signals, per docs/ARCHITECTURE.md Section
## 10.1: "FarmInput emits intent signals. FarmWorld re-emits them."
## FarmScreen (a later phase) connects to these on FarmWorld, not on
## FarmInput directly.
signal animal_tapped(id: String)
signal bubble_tapped(id: String)
signal building_tapped(id: String)
signal ground_tapped()
signal ground_double_tapped()
signal animal_long_pressed(id: String)
signal building_long_pressed(id: String)

@onready var backdrop: Node2D = %Backdrop
@onready var building_slots: Node2D = %BuildingSlots
@onready var buildings: Node2D = %Buildings
@onready var animals: Node2D = %Animals
@onready var world_ui: Node2D = %WorldUi
@onready var farm_camera: FarmCamera = %FarmCamera
@onready var farm_input: FarmInput = %FarmInput

## The currently selected animal, if any (docs/PROGRESS.md "Phase 2 —
## Animals": selection feedback only, no Animal Interaction sheet yet).
var selected_animal_id: String = ""

## True only while _rebuild() is actively (re)constructing views from
## Game.state -- i.e. on every boot AND on Phase 8's begin_session/
## on_app_resumed, which all route through Game.state_loaded. Guards the
## product-ready chime in _refresh_bubble(): a bubble created while this
## is true is "already READY before this rebuild", not a live transition,
## so it must never chime (this task's spec: no chime storm on
## rebuild/boot/offline-return).
var _rebuilding: bool = false

## The fixed-size Floater pool (Task 5), created once in _ready() and
## reused for every "+amount" indicator rather than instanced per use.
## Order matters: index 0 is replaced first once all 8 are busy (the
## "recycle the oldest" rule), so a newly recycled floater is always
## appended to the end -- see _spawn_floater().
var _floater_pool: Array[Floater] = []

## Shared ambient-flourish slot budget (Phase 9 Task 9), one instance
## owned by FarmWorld and handed to every spawned AnimalView -- NOT
## created per-view. Caps at most 2 animals farm-wide mid-flourish at
## once; wandering, the bubble bob, and blinking are all exempt (see
## AmbientBudget's own header comment for the approved interpretation).
var _ambient_budget: AmbientBudget = AmbientBudget.new()

func _ready() -> void:
	_wire_farm_input()
	_init_floater_pool()
	_rebuild()
	Game.state_loaded.connect(_rebuild)
	Game.animal_changed.connect(_refresh_bubble)
	Game.animal_status_changed.connect(_on_animal_status_changed)
	Game.animal_added.connect(_on_animal_added)
	Game.product_collected.connect(_on_product_collected)
	Game.building_upgraded.connect(_on_building_upgraded)
	animal_tapped.connect(select_animal)
	ground_tapped.connect(func() -> void: clear_selection())
	farm_camera.zoom_changed.connect(_on_zoom_changed)

## Wires FarmInput's dependencies and re-emits its six intent signals.
## Also connects ground_double_tapped to FarmCamera.reset_zoom()
## directly here (not inside FarmInput, which must not know about
## FarmCamera's specific reset behavior) -- per the Phase 1 planning
## review: "nothing consumes ground_double_tapped in Phase 1 ... have
## FarmWorld connect it to FarmCamera.reset_zoom()".
func _wire_farm_input() -> void:
	farm_input.camera = farm_camera
	farm_input.buildings_container = buildings
	farm_input.animals_container = animals
	farm_input.world_ui_container = world_ui
	farm_input.animal_tapped.connect(func(id: String) -> void: animal_tapped.emit(id))
	farm_input.bubble_tapped.connect(_on_bubble_tapped)
	farm_input.building_tapped.connect(_on_building_tapped)
	farm_input.ground_tapped.connect(func() -> void: ground_tapped.emit())
	farm_input.animal_long_pressed.connect(func(id: String) -> void: animal_long_pressed.emit(id))
	farm_input.building_long_pressed.connect(_on_building_long_pressed)
	farm_input.ground_double_tapped.connect(_on_ground_double_tapped)

## Tapping a bubble performs that bubble's action directly (feed or
## collect), bypassing the Animal Interaction sheet (which does not
## exist yet -- see docs/PROGRESS.md "Phase 3" plan item 7: no animal
## can exist in real play before Phase 5's buying system, so sheet
## infrastructure now would be unreachable regardless). This is a
## documented TEMPORARY seam: once the sheet exists, its own Feed/
## Collect buttons call Game.feed_animal/Game.collect directly and this
## bubble-tap shortcut either stays as a convenience or is removed, per
## that phase's own design.
##
## Recomputes StatusRules.primary_bubble() from CURRENT state rather
## than trusting the tapped StatusBubble's own stored `bubble_kind` --
## the bubble's kind was set whenever it last bound, which can be
## stale by the time the tap is actually processed (e.g. a SimTick
## between spawn and tap). Reading live state is also what the real
## Animal Interaction sheet will have to do regardless, so this is not
## a shortcut that regresses once the sheet replaces it.
##
## Still re-emits bubble_tapped so FarmScreen (a later phase) can also
## react (e.g. a toast on refusal), matching every other FarmInput tier.
func _on_bubble_tapped(id: String) -> void:
	bubble_tapped.emit(id)
	var animal: AnimalInstance = Game.state.farm.get_animal(id)
	if animal == null:
		return
	match StatusRules.primary_bubble(StatusRules.flags(animal, Game.catalog)):
		StatusRules.Bubble.PRODUCT:
			Game.collect(id)
		StatusRules.Bubble.FEED:
			Game.feed_animal(id)

## Tapping a building buys/sells directly, a TEMPORARY stand-in for the
## unbuilt Shop UI (docs/PROGRESS.md "Phase 5" plan item 9 -- explicitly
## asked to and approved by the user). Unlike the Phase 3/4 bubble-tap
## seams, this one has NO design-doc counterpart: UI_SPEC routes a
## building tap to Building Details, and GDD Section 7 requires a
## confirm dialog for every animal purchase, which this seam skips
## entirely. It exists only so the full Phase 5 economy loop (and
## Phases 3/4's feed/collect, which are otherwise unreachable in real
## play since new_game_state() always starts with zero animals) can be
## exercised end to end before the real Shop UI lands. Removed or
## replaced once that UI exists.
##
## Routing: a housing building (chicken_coop/pig_pen/cow_barn) buys
## that building's species if affordable; feed_storage buys a feed
## pack; market sells the entire bag. Any other building id (or a
## refused purchase/sale) does nothing beyond the bubble_tapped-style
## re-emission below.
func _on_building_tapped(id: String) -> void:
	building_tapped.emit(id)
	if Game.state == null:
		return
	var species: String = _species_housed_in(id)
	if species != "":
		Game.buy_animal(species)
	elif id == "feed_storage":
		Game.buy_feed_pack()
	elif id == "market":
		Game.sell_all()

## Reverse lookup: which catalog species is housed in building `id`, or
## "" if none (Market/Feed Storage house no species). ARCHITECTURE.md
## Section 8.1: "Building ids are the definition ids in the MVP", so
## this is a simple linear scan over the (3-entry) animal catalog, not
## a cached map.
func _species_housed_in(building_id: String) -> String:
	for species: String in Game.catalog.animal_ids():
		if Game.catalog.animal(species).housing_building_id == building_id:
			return species
	return ""

## Long-pressing ANY building upgrades it, a second TEMPORARY stand-in
## for the unbuilt Shop UI (docs/PROGRESS.md "Phase 6" plan item 6 --
## explicitly asked to and approved by the user). Same caveat as
## _on_building_tapped(): no design-doc counterpart (UI_SPEC routes a
## building tap to Building Details with its own confirm dialog, which
## GDD Section 6 requires for every upgrade; this seam skips it
## entirely). Added because once BUILDING_FULL/STORAGE_FULL refusals
## are live (Task 4), a real playthrough can hit a genuine dead end
## (coop full, feed capped) with no way to progress before the real
## Shop UI exists.
func _on_building_long_pressed(id: String) -> void:
	building_long_pressed.emit(id)
	if Game.state == null:
		return
	Game.upgrade_building(id)

func _on_ground_double_tapped() -> void:
	ground_double_tapped.emit()
	farm_camera.reset_zoom()

## Selects one animal (lighting its ring only) and focuses the camera on
## it (docs/ARCHITECTURE.md Section 10.1: FarmCamera.focus_on). Phase 2
## scope: selection feedback only -- no Animal Interaction sheet (see
## docs/PROGRESS.md "Phase 2 — Animals" for why).
func select_animal(animal_id: String) -> void:
	if selected_animal_id == animal_id:
		return
	clear_selection()
	var view: AnimalView = _find_animal_view(animal_id)
	if view == null:
		return
	selected_animal_id = animal_id
	view.set_selected(true)
	view.play_tap()
	farm_camera.focus_on(view.global_position)

func clear_selection() -> void:
	if selected_animal_id.is_empty():
		return
	var view: AnimalView = _find_animal_view(selected_animal_id)
	if view != null:
		view.set_selected(false)
	selected_animal_id = ""

func _find_animal_view(animal_id: String) -> AnimalView:
	for child: Node in animals.get_children():
		var view: AnimalView = child as AnimalView
		if view != null and view.animal_id == animal_id:
			return view
	return null

## Rebuilds every BuildingView and AnimalView from Game.state, in that
## order (docs/ARCHITECTURE.md Section 10.1: "Building views from
## state" -- buildings first, since _spawn_animal_view() reads the
## housing building's own view for its wander area). Runs once from
## _ready() and again on Game.state_loaded. Clears existing views
## first: removed from the tree with remove_child (so they vanish from
## the child list/hit-testing immediately, not at end of frame), then
## freed immediately with free() rather than queue_free() -- the node
## is already detached, so there is no mid-signal-processing hazard
## queue_free() guards against, and queue_free()'s deferred timing was
## observed to leave short-lived orphans in rapid test rebuilds (caught
## by GUT's own orphan counter, not assumed).
##
## Unknown species/building ids, or missing housing, are skipped with a
## push_warning, never a crash (docs/ARCHITECTURE.md Section 18
## error-handling pattern: "Programmer errors ... never crash in
## release").
##
## Tolerates Game.state being null (no session has begun yet) by simply
## clearing any existing views and returning -- real production boot
## always calls Game.begin_session() before FarmWorld would observe a
## real state_loaded, but FarmWorld itself must not assume that, since
## its own _ready() can run before Main's (children ready before
## parents in Godot) and some tests instantiate farm_world.tscn without
## a session at all (caught directly: those tests failed with "Invalid
## access to property ... on a base object of type 'Nil'" before this
## guard existed).
func _rebuild() -> void:
	_rebuilding = true
	clear_selection()
	for child: Node in buildings.get_children():
		buildings.remove_child(child)
		child.free()
	for child: Node in animals.get_children():
		animals.remove_child(child)
		child.free()
	for child: Node in world_ui.get_children():
		if child is Floater:
			continue
		world_ui.remove_child(child)
		child.free()

	if Game.state == null:
		_rebuilding = false
		return

	for instance: BuildingInstance in Game.state.farm.buildings:
		_spawn_building_view(instance)

	for instance: AnimalInstance in Game.state.farm.animals:
		_spawn_animal_view(instance)
	_rebuilding = false

## Spawns one BuildingView for `instance`, positioned at its authored
## BuildingSlots/<id> Marker2D (position lookup ONLY -- the iteration
## source is Game.state.farm.buildings, not the slot children, per
## ARCHITECTURE.md Section 10.1's "Building views from state"). Skips
## with a push_warning if no slot marker exists for this id (a
## programmer-error state: every real building id has an authored
## slot) or if the catalog has no matching BuildingDefinition. Every
## building currently uses the base BUILDING_VIEW_SCENE (no
## `<building_id>_view.tscn` overrides exist yet).
func _spawn_building_view(instance: BuildingInstance) -> void:
	if Game.catalog.building(instance.id) == null:
		push_warning("FarmWorld: unknown building id '%s', skipping" % instance.id)
		return
	var marker: Marker2D = building_slots.get_node_or_null(instance.id) as Marker2D
	if marker == null:
		push_warning("FarmWorld: no authored BuildingSlots marker for building '%s', skipping" % instance.id)
		return
	var view: BuildingView = BUILDING_VIEW_SCENE.instantiate()
	buildings.add_child(view)
	view.position = marker.position
	view.sparkle_requested.connect(_spawn_sparkle)
	view.bind(instance.id)

## Spawns a view for a single newly bought animal (docs/PROGRESS.md
## "Phase 5" Task 5: Game.buy_animal() appends to
## state.farm.animals and emits animal_added). Does not rebuild every
## existing view -- that would needlessly re-roll every other animal's
## wander position and recreate their StatusBubbles.
##
## Phase 9 Task 7: plays the drop-in animation (+ confetti + purchase
## sound/haptic) for this view ONLY when reached via a LIVE
## Game.animal_added signal (a genuine buy_animal() purchase) -- NEVER
## during _rebuild()/boot/begin_session/on_app_resumed, all of which
## also spawn views for pre-existing animals via _spawn_animal_view()
## but must never replay a "just bought" flourish for them. Same
## established "_rebuilding flag gates a live-only effect" pattern as
## _should_chime_on_ready() above.
func _on_animal_added(animal_id: String) -> void:
	var instance: AnimalInstance = Game.state.farm.get_animal(animal_id)
	if instance == null:
		return
	var view: AnimalView = _spawn_animal_view(instance)
	if view == null:
		return
	if not _should_play_drop_in(_rebuilding):
		return

	# Door/entrance point: the housing building's own position (no
	## authored "door" marker exists per this task's own note -- a
	## reasonable simple stand-in). Animals is not offset/rotated
	## relative to FarmWorld in the authored scene, so global and local
	## positions share the same basis and can be compared directly.
	var definition: AnimalDefinition = Game.catalog.animal(instance.species)
	var door_pos: Vector2 = view.position
	if definition != null:
		var housing_view: BuildingView = _find_building_view(definition.housing_building_id)
		if housing_view != null:
			door_pos = housing_view.position

	view.play_drop_in(door_pos)
	_spawn_confetti(view.position)
	AudioService.play("purchase")
	AudioService.haptic(AudioService.Haptic.MEDIUM)

## Pure decision function (testable without a live view/particles):
## the drop-in/confetti/purchase flourish plays only outside _rebuild(),
## mirroring _should_chime_on_ready()'s established pattern.
static func _should_play_drop_in(rebuilding: bool) -> bool:
	return not rebuilding

func _spawn_animal_view(instance: AnimalInstance) -> AnimalView:
	var definition: AnimalDefinition = Game.catalog.animal(instance.species)
	if definition == null:
		push_warning("FarmWorld: unknown animal species '%s' (id %s), skipping" % [instance.species, instance.id])
		return null

	var housing_view: BuildingView = _find_building_view(definition.housing_building_id)
	var area: Rect2
	if housing_view == null:
		push_warning("FarmWorld: animal '%s' has no housing view for building '%s'; using the world rect as a fallback wander area" % [instance.id, definition.housing_building_id])
		area = world_rect()
	else:
		area = housing_view.wander_area()

	var scene_path := "res://scenes/farm/animals/%s_view.tscn" % instance.species
	var view_scene: PackedScene = load(scene_path) if ResourceLoader.exists(scene_path) else ANIMAL_VIEW_SCENE
	var view: AnimalView = view_scene.instantiate()
	animals.add_child(view)
	view.ambient_budget = _ambient_budget
	view.heart_requested.connect(_on_heart_requested)
	view.bind(instance.id, area)
	_refresh_bubble(instance.id)
	return view

## AnimalView.heart_requested (Task 6's play_feed()): spawns a heart-
## tinted floater via the existing pooled Floater, reusing _spawn_floater()
## rather than a second pool. "heart" is not a real product id (no
## PRODUCT_COLORS entry), so Floater's own fallback tint applies -- a
## reasonable placeholder-tier choice per this task's own guidance, since
## no new product/color concept is being introduced for a cosmetic heart.
func _on_heart_requested(world_pos: Vector2) -> void:
	_spawn_floater(world_pos, "heart", 0)

func _find_building_view(building_id: String) -> BuildingView:
	for child: Node in buildings.get_children():
		var view: BuildingView = child as BuildingView
		if view != null and view.building_id == building_id:
			return view
	return null

## Only matches a LIVE (non-despawning) bubble -- a bubble mid-pop-out
## is excluded immediately (Task 4 spec), so a fresh _refresh_bubble()
## call during that brief window spawns a new one rather than reusing a
## node that is about to free itself.
func _find_bubble(animal_id: String) -> StatusBubble:
	for child: Node in world_ui.get_children():
		var bubble: StatusBubble = child as StatusBubble
		if bubble != null and bubble.animal_id == animal_id and not bubble._despawning:
			return bubble
	return null

## Game.animal_status_changed fires whenever the SimTick (or a command's
## own _advance_to) crosses a StatusRules flag boundary with no command
## of its own -- e.g. an animal becoming READY purely from elapsed time.
## _refresh_bubble() already reacts to Game.animal_changed; this adds
## the second real trigger Phase 4 introduces (docs/ARCHITECTURE.md
## Section 9.2: "Views that need continuous values... animal_status_
## changed is emitted only when the flags change").
func _on_animal_status_changed(animal_id: String, _flags: int) -> void:
	_refresh_bubble(animal_id)

## Shows, hides, or re-tints the one StatusBubble for `animal_id`,
## per StatusRules.primary_bubble() (docs/ARCHITECTURE.md Section 9.2).
## Runs once per spawned animal (from _spawn_animal_view) and again on
## every Game.animal_changed/Game.animal_status_changed, so the wheat
## or product bubble appears/disappears immediately after a real feed,
## collect, or an off-command simulation tick.
##
## Plays the product-ready chime (Task 4 spec) only when a bubble
## transitions to PRODUCT for the first time through this function
## OUTSIDE of _rebuild() -- i.e. _rebuilding is false. That excludes
## every boot and every Phase 8 begin_session/on_app_resumed rebuild
## (all of which call this via _spawn_animal_view during _rebuild()),
## while still firing on a genuine live transition reached via
## Game.animal_changed/Game.animal_status_changed during normal play.
## _should_chime_on_ready() is split out as a pure/testable decision
## separate from the AudioService.play() side effect itself.
func _refresh_bubble(animal_id: String) -> void:
	var instance: AnimalInstance = Game.state.farm.get_animal(animal_id)
	var existing: StatusBubble = _find_bubble(animal_id)
	if instance == null:
		if existing != null:
			existing.despawn()
		return

	var kind: StatusRules.Bubble = StatusRules.primary_bubble(StatusRules.flags(instance, Game.catalog))
	if kind == StatusRules.Bubble.NONE:
		if existing != null:
			existing.despawn()
		return

	var anchor_view: AnimalView = _find_animal_view(animal_id)
	if anchor_view == null:
		return
	var anchor: Marker2D = anchor_view.get_node("%BubbleAnchor")
	var product_id: String = ""
	if kind == StatusRules.Bubble.PRODUCT:
		product_id = Game.catalog.animal(instance.species).product_id

	var is_new: bool = existing == null
	var previous_kind: StatusRules.Bubble = existing.bubble_kind if existing != null else StatusRules.Bubble.NONE
	if is_new:
		existing = STATUS_BUBBLE_SCENE.instantiate()
		world_ui.add_child(existing)
	existing.bind(animal_id, kind, anchor, product_id)

	var indicator_scale: float = FarmCamera.indicator_scale(_current_player_zoom())
	if is_new:
		existing.play_pop_in(indicator_scale)
	else:
		existing.set_indicator_scale(indicator_scale)

	if _should_chime_on_ready(kind, previous_kind, is_new, _rebuilding):
		AudioService.play("product_ready")

## Pure decision function (testable without a live AudioService call):
## true only for a bubble that just became PRODUCT for the first time
## through a LIVE refresh (not a fresh _rebuild() spawn, and not a
## refresh that was already showing PRODUCT).
static func _should_chime_on_ready(kind: StatusRules.Bubble, previous_kind: StatusRules.Bubble, is_new: bool, rebuilding: bool) -> bool:
	if rebuilding:
		return false
	if kind != StatusRules.Bubble.PRODUCT:
		return false
	if is_new:
		# A bubble created outside of _rebuild() with no prior bubble at
		# all only happens via _on_animal_added (Game.buy_animal) --
		# a freshly bought animal cannot already be READY, so this
		# branch is reachable but always previous_kind == NONE in
		# practice; treated as a genuine transition regardless.
		return true
	return previous_kind != StatusRules.Bubble.PRODUCT

## Current PLAYER zoom (0.8-1.4x fit_zoom), read from the live
## FarmCamera. Falls back to 1.0 (no rescale) if the camera is not yet
## ready -- FarmWorld's own _ready() wires farm_camera before calling
## _rebuild(), so this should always resolve in practice, but a fallback
## avoids a division concern if ever called before FarmCamera._ready().
func _current_player_zoom() -> float:
	if not is_instance_valid(farm_camera) or farm_camera.fit_zoom() <= 0.0:
		return 1.0
	return farm_camera.zoom.x / farm_camera.fit_zoom()

## FarmCamera.zoom_changed handler (Task 3): rescales every live
## StatusBubble to the new zoom-clamped indicator scale. Floaters are
## NOT rescaled here -- they are short-lived (600ms) reward indicators,
## not persistent world-space tags, and this task's spec only requires
## indicator scaling for "world-space indicators (tags, bubbles)".
func _on_zoom_changed(player_zoom: float) -> void:
	var indicator_scale: float = FarmCamera.indicator_scale(player_zoom)
	for child: Node in world_ui.get_children():
		var bubble: StatusBubble = child as StatusBubble
		if bubble != null:
			bubble.set_indicator_scale(indicator_scale)

## Creates the fixed-size Floater pool (Task 5), parented under WorldUi
## alongside StatusBubbles (docs/ARCHITECTURE.md Section 4.1's folder
## map lists Floater alongside StatusBubble/BuildingTag/UpgradeBadge
## under world_ui/). Each pooled Floater starts invisible/idle; _rebuild()
## skips Floater children when clearing world_ui so the pool survives a
## rebuild (docs/ARCHITECTURE.md Section 23: "a small reusable pool (8)
## owned by ... FarmWorld", not recreated per rebuild).
func _init_floater_pool() -> void:
	for i in range(FLOATER_POOL_SIZE):
		var floater: Floater = FLOATER_SCENE.instantiate()
		world_ui.add_child(floater)
		_floater_pool.append(floater)

## Shows a "+amount" floater at `world_pos` for `product_id` (Task 5).
## Finds the first currently-idle pooled Floater; if all FLOATER_POOL_SIZE
## are busy, recycles the OLDEST one (index 0, since a just-used floater
## is moved to the end of _floater_pool below) rather than dropping the
## request, per this task's spec.
func _spawn_floater(world_pos: Vector2, product_id: String, amount: int) -> void:
	var floater: Floater = null
	for candidate: Floater in _floater_pool:
		if candidate.is_idle():
			floater = candidate
			break
	if floater == null:
		floater = _floater_pool[0]

	_floater_pool.erase(floater)
	_floater_pool.append(floater)
	floater.show_at(world_pos, product_id, amount)

## Wires Game.product_collected to a "+amount" floater at the collected
## animal's position (Task 5's optional wiring -- clean and low-risk
## enough to include per this task's own guidance). Silently does
## nothing if the animal's view no longer exists (e.g. sold/removed
## between the command and this signal, which should not happen in
## practice but costs nothing to guard).
##
## Phase 9 Task 6: also plays the collect sound/haptic here (DESIGN.md
## Section 10: "Collect | Pop, flight, floater | Plink, light haptic").
## This is the one real Game.product_collected connection FarmWorld
## already owned before this task (Task 5's floater wiring) -- the
## sound/haptic calls are added to it rather than adding a second
## FarmWorld connection to the same signal. AnimalView.play_collect()
## (its own separate Game.product_collected connection, id-filtered to
## its own animal) only adds this view's visual flourish; it does not
## duplicate this sound/haptic.
func _on_product_collected(animal_id: String, product_id: String, amount: int) -> void:
	var view: AnimalView = _find_animal_view(animal_id)
	if view == null:
		return
	_spawn_floater(view.global_position, product_id, amount)
	AudioService.play("collect")
	AudioService.haptic(AudioService.Haptic.LIGHT)

## Game.building_upgraded (Phase 6): plays the matching BuildingView's
## upgrade flourish (Task 8) for that building id only.
func _on_building_upgraded(building_id: String, new_level: int) -> void:
	var view: BuildingView = _find_building_view(building_id)
	if view == null:
		return
	view.play_upgrade(new_level)

## Runtime-added (NOT authored in any .tscn -- see the structural-risk
## guidance this task was given) CPUParticles2D burst for a purchase
## drop-in, capped at CONFETTI_PARTICLE_COUNT. Parented under world_ui so
## it draws above sprites and is unaffected by Animals' y-sort. Frees
## itself via its own `finished` signal (one-shot). Skipped entirely
## under Motion.reduced (this task's spec: reduced motion SKIPS
## particles, not just shortens them).
func _spawn_confetti(world_pos: Vector2) -> void:
	if Motion.reduced:
		return
	var particles := CPUParticles2D.new()
	world_ui.add_child(particles)
	particles.global_position = world_pos
	particles.amount = CONFETTI_PARTICLE_COUNT
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 160.0
	particles.gravity = Vector2(0, 220)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.95, 0.75, 0.3, 1.0)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

## Runtime-added CPUParticles2D sparkle for a building upgrade (Task 8),
## capped at SPARKLE_PARTICLE_COUNT (fewer than confetti -- "sparkle" is
## a subtler effect than a purchase burst, per this task's own "your
## call, keep it modest" guidance). Same runtime-only/Motion.reduced
## rules as _spawn_confetti().
func _spawn_sparkle(world_pos: Vector2) -> void:
	if Motion.reduced:
		return
	var particles := CPUParticles2D.new()
	world_ui.add_child(particles)
	particles.global_position = world_pos
	particles.amount = SPARKLE_PARTICLE_COUNT
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 60.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.color = Color(1.0, 0.95, 0.6, 1.0)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

## World-space rect buildings/animals/tags must stay inside.
static func safe_band_rect() -> Rect2:
	return Rect2(
		-WORLD_WIDTH / 2.0, SAFE_BAND_TOP,
		WORLD_WIDTH, SAFE_BAND_BOTTOM - SAFE_BAND_TOP
	)

## Full authored world rect (origin centered horizontally, per the
## BuildingSlots layout below).
static func world_rect() -> Rect2:
	return Rect2(-WORLD_WIDTH / 2.0, 0.0, WORLD_WIDTH, WORLD_HEIGHT)
