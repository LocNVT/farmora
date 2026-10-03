extends Node

## Game autoload per docs/ARCHITECTURE.md Section 13.1. Owns the catalog
## and state, loads balance.json, emits state_loaded, runs the one
## simulation path (_advance_to, the SimTick timer), and exposes
## feed_animal()/collect()/buy_animal()/buy_feed_pack()/sell_product()/
## sell_all()/upgrade_building(). Every successful command (other than
## sell_product/sell_all, which save synchronously instead -- see their
## own doc comments) calls `SaveService.request_autosave()` right after
## `state_changed.emit()` (ARCHITECTURE.md Section 11.6/10.4). No
## `class_name` (ARCHITECTURE.md Section 6.2: autoload scripts don't
## declare class_name, so they can't clash with the autoload name
## "Game").
##
## Deliberately absent (added when their real emitter/reader exists):
## rename_animal, collect_all, set_setting/set_tutorial_step/
## skip_tutorial (all need a UI shell that does not exist yet). Flipping
## `SaveService.persistence_enabled` true after a successful boot is
## Main's job (Phase 7 Task 9), not this file's. Building full stubs now
## would be exactly the kind of premature scope CLAUDE.md Section 16
## warns against -- a command with no real caller and no real effect is
## not simpler than adding it when a later phase actually needs it.

signal state_loaded()
signal state_changed()
signal feed_changed(new_value: int, old_value: int)
signal animal_changed(animal_id: String)
signal animal_fed(animal_id: String)
signal animal_status_changed(animal_id: String, flags: int)
signal simulation_ticked()
signal product_collected(animal_id: String, product_id: String, amount: int)
signal coins_changed(new_value: int, old_value: int)
signal bag_changed(product_id: String, new_value: int, old_value: int)
signal animal_added(animal_id: String)
signal feed_bought(amount: int)
signal products_sold(sold: Dictionary, coins_earned: int)  # product_id -> qty
signal building_upgraded(building_id: String, new_level: int)
signal offline_progress_applied(report: OfflineReport)

## Wall-clock interval between simulation ticks (ARCHITECTURE.md Section
## 13.1: "A child Timer 'SimTick': wait_time 1.0").
const SIM_TICK_SECONDS := 1.0

var catalog: GameCatalog
var state: GameState
var clock: GameClock = GameClock.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _guard := ActionGuard.new()
var _sim_tick: Timer

func _ready() -> void:
	catalog = GameCatalog.load_from_file("res://data/balance.json")
	assert(catalog != null, "Game: data/balance.json failed to load")
	var problems: PackedStringArray = catalog.validate()
	assert(problems.is_empty(), "Game: balance.json failed validation: %s" % [problems])

	_sim_tick = Timer.new()
	_sim_tick.wait_time = SIM_TICK_SECONDS
	_sim_tick.autostart = false
	add_child(_sim_tick)
	_sim_tick.timeout.connect(_on_sim_tick_timeout)

	SaveService.configure(_save_snapshot, catalog)

## Returns a fresh GameState with an empty farm (GDD Section 2/8: the
## real game starts with zero animals; the tutorial's second step buys
## the first chicken), a level-1 BuildingInstance for every
## `starts_built` catalog building ("Construction" per CLAUDE.md Phase
## 6 maps to this, not a player-facing build flow -- GDD Section 6's
## own OPEN default: all five buildings exist at Level 1 from first
## launch, and ARCHITECTURE.md Section 10.1 confirms "a construction
## flow is not designed in UI_SPEC and is not built"), the wallet
## seeded from balance.json's `start` group, one inventory entry at 0
## per catalog product (ARCHITECTURE.md Section 8.1: "one key per
## catalog product, zero included"), and `last_seen_ms` stamped to now
## so the first simulation advance has a real baseline instead of
## advancing from epoch 0.
func new_game_state() -> GameState:
	var fresh := GameState.new()
	for building_id: String in catalog.building_ids():
		if catalog.building(building_id).starts_built:
			var instance := BuildingInstance.new()
			instance.id = building_id
			instance.level = 1
			fresh.farm.buildings.append(instance)
	fresh.player.feed = catalog.start.feed
	fresh.player.coins = catalog.start.coins
	fresh.player.xp = catalog.start.xp
	fresh.player.level = catalog.start.level
	for product_id: String in catalog.product_ids():
		fresh.inventory.add(product_id, 0)
	fresh.last_seen_ms = clock.now_ms()
	return fresh

## Sets the active state, advances it to now as a RETURN (so a loaded/
## held state is never stale and a qualifying offline window emits
## offline_progress_applied), starts the SimTick timer, and emits
## state_loaded, per docs/ARCHITECTURE.md Section 13.1/12.2 ("Launch
## with a save... _advance_to(now, true)").
func begin_session(loaded: GameState) -> void:
	state = loaded
	_advance_to(clock.now_ms(), true)
	_sim_tick.start()
	state_loaded.emit()

## Called by Main on NOTIFICATION_APPLICATION_PAUSED/FOCUS_OUT/
## WM_CLOSE_REQUEST, per docs/ARCHITECTURE.md Section 11.6 ("On
## background... advances to now and calls SaveService.save_now()").
## Skipped entirely when no session has started yet (`state == null`,
## e.g. the app is backgrounded during the splash/boot moment itself,
## before begin_session() has run) -- there is nothing to advance or
## save. Uses the same synchronous save_now() as sell_product/sell_all,
## not request_autosave(), since the app may not get another chance to
## run the 2s debounce before the OS suspends or kills the process. Not
## a RETURN -- backgrounding does not reward offline progress; only
## actually coming BACK does (on_app_resumed, begin_session).
func on_app_backgrounded() -> void:
	if state == null:
		return
	_advance_to(clock.now_ms())
	SaveService.save_now()

## Called by Main on NOTIFICATION_APPLICATION_RESUMED (mobile only --
## there is no desktop-testing counterpart the way FOCUS_OUT stands in
## for PAUSED, since a desktop window regaining focus is not a return
## from a backgrounded/suspended process), per docs/ARCHITECTURE.md
## Section 12.2's trigger table. Skipped when no session has started
## yet, same reasoning as on_app_backgrounded().
func on_app_resumed() -> void:
	if state == null:
		return
	_advance_to(clock.now_ms(), true)

## Advances every animal's production by the elapsed wall-clock time
## since `state.last_seen_ms`, per docs/ARCHITECTURE.md Section 1/14:
## "the elapsed seconds always come from two clock readings" and "one
## simulation code path". Called by the SimTick timer, by
## begin_session()/on_app_resumed(), and by every command (feed_animal,
## collect) before it mutates, so a command never applies retroactively
## to time that has not been simulated yet (Section 14: "Order
## matters"). The ONLY advancement path (ARCHITECTURE.md Section 1) --
## online ticks and offline returns share this exact function, never a
## parallel one; `OfflineRules.elapsed_ms()`'s 8 h cap and
## backwards-clock handling therefore apply uniformly to every caller
## (the cap never matters for a ~1s online tick).
##
## `is_return` marks a trigger that can earn offline-progress credit
## (begin_session, on_app_resumed, and a SimTick gap that itself exceeds
## the reward-modal threshold -- ARCHITECTURE.md Section 12.2's trigger
## table row 6, which closes the real race where the OS may fire the
## RESUMED notification and the next SimTick timeout in either order;
## since _advance_to() always re-bases `last_seen_ms = now_ms`,
## whichever one runs first would otherwise silently consume the whole
## window with is_return=false and the player would never see credit
## for it). Every other command keeps calling the untouched
## `_advance_to(now)` default (`is_return = false`), so none of their
## behavior changes.
func _advance_to(now_ms: int, is_return: bool = false) -> OfflineReport:
	var raw_dt_ms: int = maxi(0, now_ms - state.last_seen_ms)
	var dt_ms: int = OfflineRules.elapsed_ms(now_ms, state.last_seen_ms, catalog.offline.cap_ms())
	var capped: bool = dt_ms < raw_dt_ms
	var dt: float = dt_ms / 1000.0

	var before_flags: Dictionary = {}  # String animal_id -> int flags
	for a: AnimalInstance in state.farm.animals:
		before_flags[a.id] = StatusRules.flags(a, catalog)

	var completed: Dictionary = {}  # String animal_id -> int products completed
	for a: AnimalInstance in state.farm.animals:
		completed[a.id] = ProductionRules.advance_animal(a, dt, _production_params_for(a))

	state.last_seen_ms = now_ms

	for a: AnimalInstance in state.farm.animals:
		var new_flags: int = StatusRules.flags(a, catalog)
		if new_flags != before_flags.get(a.id):
			animal_status_changed.emit(a.id, new_flags)

	simulation_ticked.emit()

	var report: OfflineReport = OfflineReport.build(completed, state, dt_ms, capped, catalog)
	if is_return:
		offline_progress_applied.emit(report)
	return report

## The SimTick Timer's own 1.0s callback. Computes the gap itself
## (before the one real _advance_to() call re-bases `last_seen_ms`) so
## it can pass `is_return = true` on the rare tick whose own gap alone
## exceeds the reward-modal threshold (trigger table row 6: "the OS
## suspended the app without a pause notification") -- a plain 1s tick
## is always far under the threshold and is_return stays false.
func _on_sim_tick_timeout() -> void:
	var now_ms: int = clock.now_ms()
	var gap_ms: int = OfflineRules.elapsed_ms(now_ms, state.last_seen_ms, catalog.offline.cap_ms())
	_advance_to(now_ms, OfflineRules.exceeds_modal_threshold(gap_ms, catalog))

## The Callable SaveService's `snapshot_provider` calls (docs/
## ARCHITECTURE.md Section 11.6: "That Callable advances to now and
## returns SaveCodec.encode(state)"). Advancing here means a save always
## reflects the state at the moment it is actually written, not whatever
## was last synced by a command.
func _save_snapshot() -> Dictionary:
	_advance_to(clock.now_ms())
	return SaveCodec.encode(state)

## Builds this animal's ProductionRules.Params for one advance.
## `cycle_seconds` is the catalog's base value divided by the housing
## building's own level multiplier (ARCHITECTURE.md Section 14:
## "cycle = catalog.animal(a.species).cycle_seconds /
## BuildingRules.production_multiplier(...)"). No tutorial-boost
## substitution yet (unassigned tutorial work) -- ProductionRules.
## Params's own shape never changes when that lands either.
func _production_params_for(a: AnimalInstance) -> ProductionRules.Params:
	var definition: AnimalDefinition = catalog.animal(a.species)
	var multiplier: float = BuildingRules.production_multiplier(state.farm, a.building_id, catalog)
	var p := ProductionRules.Params.new()
	p.cycle_seconds = definition.cycle_seconds / multiplier
	p.hunger_decay_per_second = catalog.feeding.hunger_decay_per_minute / 60.0
	p.happiness_decay_per_second = catalog.happiness.decay_per_minute / 60.0
	p.pause_when_ready = catalog.production.pause_when_ready
	return p

## Feeds one animal, per docs/ARCHITECTURE.md Section 17's "Feed an
## animal" data flow: _advance_to(now) -> FeedingRules.check_feed() ->
## ActionGuard debounce -> apply_meal() -> emit feed_changed,
## animal_fed, animal_changed, [animal_status_changed], state_changed.
## `animal_status_changed` fires only when the meal's own hunger/
## happiness change crosses a StatusRules flag boundary (e.g. clearing
## HUNGRY) -- distinct from the status transitions `_advance_to` itself
## already emitted for elapsed-time decay, a moment earlier in this
## same call. Calls `SaveService.request_autosave()` after
## `state_changed.emit()` on success (ARCHITECTURE.md Section 11.6).
## Returns UNKNOWN_ID for a missing
## animal, FeedingRules' own refusal codes, or DEBOUNCED inside the
## balance.json-configured `catalog.feeding.debounce_ms` lock (300ms by
## default -- checked only once the feed would otherwise succeed, so a
## refused feed never consumes the lock -- ActionGuard's own documented
## contract), without mutating state or emitting any signal in every
## refusal case.
##
## Calls _advance_to() FIRST (ARCHITECTURE.md Section 14: "Order
## matters... every command calls _advance_to(now) before it mutates"),
## so a meal applies only from this moment on, never retroactively --
## an animal that starved mid-interval has already had that decay
## applied before FeedingRules ever sees its hunger value.
func feed_animal(animal_id: String) -> ActionResult:
	_advance_to(clock.now_ms())

	var animal: AnimalInstance = state.farm.get_animal(animal_id)
	if animal == null:
		return ActionResult.of(ActionResult.Code.UNKNOWN_ID)

	var result: ActionResult = FeedingRules.check_feed(state.player, animal, catalog)
	if not result.ok():
		return result

	if not _guard.try_commit(FeedingRules.debounce_key(animal_id), clock.mono_ms(), catalog.feeding.debounce_ms):
		return ActionResult.of(ActionResult.Code.DEBOUNCED)

	var old_feed: int = state.player.feed
	var flags_before: int = StatusRules.flags(animal, catalog)
	FeedingRules.apply_meal(state.player, animal, catalog)

	feed_changed.emit(state.player.feed, old_feed)
	animal_fed.emit(animal_id)
	animal_changed.emit(animal_id)
	var flags_after: int = StatusRules.flags(animal, catalog)
	if flags_after != flags_before:
		animal_status_changed.emit(animal_id, flags_after)
	state_changed.emit()
	SaveService.request_autosave()

	return result

## Collects one animal's ready product, per docs/ARCHITECTURE.md
## Section 17's production data flow and Section 13.1's
## `collect(animal_id) -> ActionResult`: _advance_to(now) ->
## ProductionRules.check_collect() -> apply_collect() -> emit
## product_collected, animal_changed, state_changed. No ActionGuard
## debounce (ADR-13 exists to stop double-spends; collecting spends
## nothing, and a second collect attempt refuses on its own via
## NOT_READY once progress has reset to 0 -- see docs/PROGRESS.md
## "Phase 4" plan item 5). Calls `SaveService.request_autosave()` after
## `state_changed.emit()` on success. Returns
## UNKNOWN_ID for a missing animal or NOT_READY when progress has not
## reached 1.0, without mutating state or emitting any signal in either
## refusal case.
func collect(animal_id: String) -> ActionResult:
	_advance_to(clock.now_ms())

	var animal: AnimalInstance = state.farm.get_animal(animal_id)
	if animal == null:
		return ActionResult.of(ActionResult.Code.UNKNOWN_ID)

	var result: ActionResult = ProductionRules.check_collect(animal)
	if not result.ok():
		return result

	_collect_one(animal)
	state_changed.emit()
	SaveService.request_autosave()

	return result

## The per-animal apply-and-emit block shared by collect() and
## collect_offline_reward() -- product_collected, animal_changed, and
## animal_status_changed only when the READY flag actually changes.
## Callers own `state_changed`/persistence: collect() autosaves once per
## call, collect_offline_reward() saves once for the whole batch.
func _collect_one(animal: AnimalInstance) -> void:
	var flags_before: int = StatusRules.flags(animal, catalog)
	var product_id: String = ProductionRules.apply_collect(animal, state.inventory, catalog)

	product_collected.emit(animal.id, product_id, 1)
	animal_changed.emit(animal.id)
	var flags_after: int = StatusRules.flags(animal, catalog)
	if flags_after != flags_before:
		animal_status_changed.emit(animal.id, flags_after)

## Collects every animal named in an OfflineReport's `ready_animal_ids`,
## per docs/ARCHITECTURE.md Section 12.3 ("Collect... runs the normal
## collect logic for each id... It skips the 300 ms debounce. Then it
## calls SaveService.save_now()."). GDD Section 9 rule 6: "No coins are
## credited automatically; the player sells as usual" --
## `report.coin_value` is informational only, never applied to
## `state.player.coins` here or anywhere else.
##
## Tolerant of a stale report: an id that no longer exists, or whose
## `check_collect` is not OK (the player already collected it by hand,
## or it somehow is not READY), is silently skipped rather than failing
## the whole batch -- GDD Section 9 rule 7's "hold and show again" only
## concerns a SAVE failure, not a partially-stale id list.
##
## Rule 7 ("if saving the rewards fails, hold them and show the modal
## again on the next launch") needs no extra code: a failed save_now()
## leaves the in-memory collected products exactly where they are (nothing
## is rolled back, unlike sell_product/sell_all's snapshot pattern --
## there is nothing to roll back TO, since GDD never asks for that here),
## SaveService's own retry schedule and save_failed signal already run,
## and because the reward is defined by which animals are READY
## (ADR-08), a process restart before the next successful save simply
## recomputes the same still-READY animals and reports them again. This
## command still returns OK even when the save fails, matching the
## rule 7 contract ("play continues", Section 24) -- SAVE_FAILED is
## reserved for sell_product/sell_all's own snapshot/rollback contract,
## which does not apply here.
func collect_offline_reward(report: OfflineReport) -> ActionResult:
	_advance_to(clock.now_ms())

	var collected_any: bool = false
	for animal_id: String in report.ready_animal_ids:
		var animal: AnimalInstance = state.farm.get_animal(animal_id)
		if animal == null:
			continue
		if not ProductionRules.check_collect(animal).ok():
			continue
		_collect_one(animal)
		collected_any = true

	if collected_any:
		state_changed.emit()
		SaveService.save_now()

	return ActionResult.of(ActionResult.Code.OK)

## Generates a unique animal id per docs/ARCHITECTURE.md Section 8.1:
## `"a_%d_%04x" % [now_ms, rng.randi() & 0xFFFF]` -- unique without a
## saved counter.
func _generate_animal_id() -> String:
	return "a_%d_%04x" % [clock.now_ms(), rng.randi() & 0xFFFF]

## Buys one animal of `species`, per docs/ARCHITECTURE.md Section 13.1's
## `buy_animal(species) -> ActionResult` (`result.data.animal_id` for
## the "Meet Pip" card -- unbuilt UI, but the data is ready for it) and
## Section 10.4's transaction order: _advance_to(now) ->
## EconomyRules.check_buy_animal() -> ActionGuard("purchase") debounce
## -> apply (spend coins, append a new AnimalInstance housed at the
## species' definition-id building -- ARCHITECTURE.md Section 8.1:
## "Building ids are the definition ids in the MVP") -> emit
## coins_changed, animal_added, state_changed -> SaveService.
## request_autosave(). Returns EconomyRules' own refusal codes (UNKNOWN_ID,
## LOCKED_BY_LEVEL, BUILDING_FULL, NOT_ENOUGH_COINS) or DEBOUNCED inside
## the shared `"purchase"` lock (ARCHITECTURE.md Section 10.4 ADR-13:
## buy animal, buy feed pack, and upgrade share one key, so a double tap
## cannot buy/upgrade two different things) -- checked only once the
## purchase would otherwise succeed, so a refusal never consumes the
## lock, matching feed_animal's established order.
func buy_animal(species: String) -> ActionResult:
	_advance_to(clock.now_ms())

	var result: ActionResult = EconomyRules.check_buy_animal(state, species, catalog)
	if not result.ok():
		return result

	if not _guard.try_commit("purchase", clock.mono_ms(), catalog.economy.purchase_lock_ms):
		return ActionResult.of(ActionResult.Code.DEBOUNCED)

	var definition: AnimalDefinition = catalog.animal(species)
	var old_coins: int = state.player.coins
	state.player.coins -= definition.price

	var instance := AnimalInstance.new()
	instance.id = _generate_animal_id()
	instance.species = species
	instance.building_id = definition.housing_building_id
	instance.hunger = catalog.new_animal.hunger
	instance.happiness = catalog.new_animal.happiness
	instance.health = catalog.new_animal.health
	if not definition.default_names.is_empty():
		instance.name = definition.default_names[rng.randi() % definition.default_names.size()]
	state.farm.animals.append(instance)

	result.data = {"animal_id": instance.id}
	coins_changed.emit(state.player.coins, old_coins)
	animal_added.emit(instance.id)
	state_changed.emit()
	SaveService.request_autosave()

	return result

## Buys one feed pack, per docs/ARCHITECTURE.md Section 13.1's
## `buy_feed_pack() -> ActionResult` and Section 10.4's transaction
## order: _advance_to(now) -> EconomyRules.check_buy_feed_pack() ->
## ActionGuard("purchase") debounce -> apply (spend coins, add
## `economy.feed_pack_feed` to the wallet, clamped to
## `BuildingRules.feed_capacity()` -- GDD Section 6: "Feed beyond Feed
## Storage capacity cannot be held", which still applies even when
## `refuse_overflowing_feed_pack` is false and check_buy_feed_pack()
## allowed a partially-overflowing purchase through) -> emit
## coins_changed, feed_changed, feed_bought (the ACTUAL feed added,
## i.e. `new_feed - old_feed` -- not the nominal pack size, since the
## capacity clamp above can mean fewer units were really added than
## `economy.feed_pack_feed`), state_changed. Shares the `"purchase"`
## debounce key with buy_animal/upgrade_building
## (ARCHITECTURE.md Section 10.4 ADR-13). GDD Section 7: "Bought
## instantly, no confirm dialog" -- this command has no UI-level
## confirmation step to skip; it is itself the instant-purchase path.
func buy_feed_pack() -> ActionResult:
	_advance_to(clock.now_ms())

	var result: ActionResult = EconomyRules.check_buy_feed_pack(state, catalog)
	if not result.ok():
		return result

	if not _guard.try_commit("purchase", clock.mono_ms(), catalog.economy.purchase_lock_ms):
		return ActionResult.of(ActionResult.Code.DEBOUNCED)

	var old_coins: int = state.player.coins
	var old_feed: int = state.player.feed
	state.player.coins -= catalog.economy.feed_pack_price
	var cap: int = BuildingRules.feed_capacity(state.farm, catalog)
	state.player.feed = mini(cap, state.player.feed + catalog.economy.feed_pack_feed)

	coins_changed.emit(state.player.coins, old_coins)
	feed_changed.emit(state.player.feed, old_feed)
	feed_bought.emit(state.player.feed - old_feed)
	state_changed.emit()
	SaveService.request_autosave()

	return result

## Sells the ENTIRE stack of one product, per docs/ARCHITECTURE.md
## Section 13.1's `sell_product(product_id) -> ActionResult` ("sells
## the whole stack of that product -- UI_SPEC Section 8.1/9 per-row
## Sell") and Section 10.4's transaction order: _advance_to(now) ->
## check (NOTHING_TO_SELL if the stack is empty) -> ActionGuard("sell")
## debounce -> apply (remove the whole stack, credit
## EconomyRules.sale_total()'s coins) -> emit coins_changed,
## bag_changed, products_sold, state_changed.
##
## Saves SYNCHRONOUSLY, per ARCHITECTURE.md Section 10.4: sell_product/
## sell_all are the only commands that snapshot wallet+bag, apply, then
## call `SaveService.save_now()` before emitting anything -- on failure
## the snapshot is restored and `SAVE_FAILED` is returned with no sale
## signals emitted at all (not even `state_changed`). Every other
## command instead calls `SaveService.request_autosave()` (the 2s
## debounce) after its own emit block. `bonus_percent` reads the Market
## building's own level via `BuildingRules.sell_bonus_percent`.
func sell_product(product_id: String) -> ActionResult:
	_advance_to(clock.now_ms())

	var qty: int = state.inventory.get_qty(product_id)
	if qty <= 0:
		return ActionResult.of(ActionResult.Code.NOTHING_TO_SELL)

	if not _guard.try_commit("sell", clock.mono_ms(), catalog.economy.purchase_lock_ms):
		return ActionResult.of(ActionResult.Code.DEBOUNCED)

	var unit_price: int = catalog.product(product_id).sell_price
	var bonus_percent: float = BuildingRules.sell_bonus_percent(state.farm, catalog)
	var coins_earned: int = EconomyRules.sale_total(unit_price, qty, bonus_percent)

	var old_coins: int = state.player.coins
	var old_qty: int = qty
	var quantities_snapshot: Dictionary = state.inventory.quantities.duplicate()

	state.inventory.remove(product_id, qty)
	state.player.coins += coins_earned

	if not SaveService.save_now():
		state.player.coins = old_coins
		state.inventory.quantities = quantities_snapshot
		return ActionResult.of(ActionResult.Code.SAVE_FAILED)

	coins_changed.emit(state.player.coins, old_coins)
	bag_changed.emit(product_id, state.inventory.get_qty(product_id), old_qty)
	products_sold.emit({product_id: old_qty}, coins_earned)
	state_changed.emit()

	return ActionResult.of(ActionResult.Code.OK)

## Sells the entire bag at once ("Sell all"), per docs/ARCHITECTURE.md
## Section 13.1's `sell_all() -> ActionResult` ("domain applies all at
## once; UI staggers 60 ms") and the same transaction order as
## sell_product. Refuses NOTHING_TO_SELL when every product is at 0.
## Shares the `"sell"` debounce key with sell_product.
func sell_all() -> ActionResult:
	_advance_to(clock.now_ms())

	var sold: Dictionary = {}  # String product_id -> int qty
	for product_id: String in catalog.product_ids():
		var qty: int = state.inventory.get_qty(product_id)
		if qty > 0:
			sold[product_id] = qty
	if sold.is_empty():
		return ActionResult.of(ActionResult.Code.NOTHING_TO_SELL)

	if not _guard.try_commit("sell", clock.mono_ms(), catalog.economy.purchase_lock_ms):
		return ActionResult.of(ActionResult.Code.DEBOUNCED)

	var bonus_percent: float = BuildingRules.sell_bonus_percent(state.farm, catalog)
	var coins_earned: int = EconomyRules.sell_all_total(state.inventory, catalog, bonus_percent)

	var old_coins: int = state.player.coins
	var quantities_snapshot: Dictionary = state.inventory.quantities.duplicate()

	for product_id: String in sold.keys():
		state.inventory.remove(product_id, sold[product_id])
	state.player.coins += coins_earned

	if not SaveService.save_now():
		state.player.coins = old_coins
		state.inventory.quantities = quantities_snapshot
		return ActionResult.of(ActionResult.Code.SAVE_FAILED)

	for product_id: String in sold.keys():
		bag_changed.emit(product_id, state.inventory.get_qty(product_id), quantities_snapshot.get(product_id, 0))
	coins_changed.emit(state.player.coins, old_coins)
	products_sold.emit(sold, coins_earned)
	state_changed.emit()

	return ActionResult.of(ActionResult.Code.OK)

## Upgrades one building by one level, per docs/ARCHITECTURE.md Section
## 13.1's `upgrade_building(building_id) -> ActionResult` and Section
## 10.4's transaction order: _advance_to(now) ->
## BuildingRules.check_upgrade() -> ActionGuard("purchase") debounce ->
## apply (spend the next level's cost, increment level) -> emit
## coins_changed, building_upgraded(id, new_level), state_changed.
## Shares the `"purchase"` debounce key with buy_animal/buy_feed_pack
## (ARCHITECTURE.md Section 10.4 ADR-13 lists "buy animal, buy feed
## pack, upgrade" as one key). GDD Section 6: "Upgrade requires coins
## only. No other requirement." No XP awarded
## (`progression.xpPerEvent.upgrade` is still the inert 0 -- unassigned
## progression work). Calls `SaveService.request_autosave()` after
## `state_changed.emit()` on success. Returns
## BuildingRules' own refusal codes (UNKNOWN_ID, MAX_LEVEL,
## NOT_ENOUGH_COINS) or DEBOUNCED inside the shared lock, checked only
## once the upgrade would otherwise succeed.
func upgrade_building(building_id: String) -> ActionResult:
	_advance_to(clock.now_ms())

	var result: ActionResult = BuildingRules.check_upgrade(state, building_id, catalog)
	if not result.ok():
		return result

	if not _guard.try_commit("purchase", clock.mono_ms(), catalog.economy.purchase_lock_ms):
		return ActionResult.of(ActionResult.Code.DEBOUNCED)

	var instance: BuildingInstance = state.farm.get_building(building_id)
	var cost: int = BuildingRules.next_upgrade(instance, catalog).cost
	var old_coins: int = state.player.coins
	state.player.coins -= cost
	instance.level += 1

	coins_changed.emit(state.player.coins, old_coins)
	building_upgraded.emit(building_id, instance.level)
	state_changed.emit()
	SaveService.request_autosave()

	return result
