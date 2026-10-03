class_name GameCatalog
extends RefCounted

## Parses data/balance.json into typed definitions, per docs/
## ARCHITECTURE.md Section 7. Through Phase 8: parses `schema`,
## `products`, `animals`, `status`, `feeding`, `happiness`, `start`,
## `production`, `economy`, `newAnimal`, `buildings`, and `offline` --
## every other balance.json group (tutorial, progression, names) sits in
## the file unparsed until the phase that actually uses it (CLAUDE.md
## Section 16: don't expand MVP scope; ARCHITECTURE.md Section 7.3:
## inert/unused values wait for their owning phase). Adding a parsed
## group later only touches this file and the group's own definition
## class -- it never requires re-authoring balance.json, since the full
## v1 shape is already there.
##
## Static read-only groups (like these) are parsed in full even before
## every field has a Phase 3 reader -- unlike mutable runtime state
## (Section 8), an unread static field costs nothing and avoids
## reopening this file when a later phase needs the rest of the group.

const CURRENT_SCHEMA := 1

## Hunger/happiness bubble and status-bar thresholds (GDD Section 4,
## OPEN (design); DESIGN.md Section 17.8's amber-bar rule). Phase 2 only
## needs these for StatusRules.flags(); the bubble-priority and
## low-bar-color consumers are later phases.
class StatusParams:
	var hungry_below: float = 30.0
	var low_happiness_below: float = 30.0
	var low_bar_below_percent: float = 30.0

var status: StatusParams = StatusParams.new()

## GDD Section 4 feeding rules / balance.json "feeding" block.
class FeedingParams:
	var feed_per_meal: int = 1
	var hunger_per_meal: float = 50.0
	var hunger_decay_per_minute: float = 1.0  # unused until Phase 4's ProductionRules
	var debounce_ms: int = 300
	var block_when_full: bool = true  # OPEN (design), GDD Section 4 / UI_SPEC Section 6

## GDD Section 4 happiness rules (OPEN, design) / balance.json
## "happiness" block. `gain_on_collect` and `decay_per_minute` have no
## Phase 3 reader (Collect and the simulation tick are Phase 4); parsed
## now anyway since they're already on disk and read-only.
class HappinessParams:
	var gain_on_feed: float = 0.0
	var gain_on_collect: float = 0.0
	var decay_per_minute: float = 0.0

## GDD Section 7 starting values / balance.json "start" block.
## `coins`/`xp`/`level` have no Phase 3 reader (Phase 5/7 use them).
class StartParams:
	var coins: int = 0
	var feed: int = 0
	var xp: int = 0
	var level: int = 1

## GDD Section 4 "progress when a product is ready but not collected"
## (OPEN, design) / balance.json "production" block. ARCHITECTURE.md
## Section 14: `pause_when_ready = true` is the recommended default and
## the only path built (the `else` continuous-production branch is
## explicitly "do not build until confirmed").
class ProductionParams:
	var pause_when_ready: bool = true

## GDD Section 7 economy rules / balance.json "economy" block. The 300ms
## commit lock shared by both buy commands (ARCHITECTURE.md Section
## 10.4 ADR-13: `"purchase"` key) and both sell commands (`"sell"` key).
## `refuse_overflowing_feed_pack` has no Phase 5 reader (feed storage
## capacity is Phase 6) -- parsed now anyway since it is already on
## disk and read-only.
class EconomyParams:
	var purchase_lock_ms: int = 300
	var feed_pack_feed: int = 10
	var feed_pack_price: int = 25
	var refuse_overflowing_feed_pack: bool = true

## GDD Section 2 ("starts hungry") / balance.json "newAnimal" block --
## the starting stat values for a freshly bought AnimalInstance.
class NewAnimalParams:
	var hunger: float = 0.0
	var happiness: float = 100.0
	var health: float = 100.0

## GDD Section 9 ("Offline progression") / balance.json "offline" block.
## `cap_ms()`/`reward_modal_min_ms()` convert the authored hours/minutes
## to the millisecond units `OfflineRules` actually operates in, so every
## caller reads the same pre-converted values instead of repeating the
## `* 3600000`/`* 60000` conversion at each call site.
class OfflineParams:
	var cap_hours: float = 8.0
	var reward_modal_min_minutes: float = 5.0

	func cap_ms() -> int:
		return int(cap_hours * 3600000.0)

	func reward_modal_min_ms() -> int:
		return int(reward_modal_min_minutes * 60000.0)

var feeding: FeedingParams = FeedingParams.new()
var happiness: HappinessParams = HappinessParams.new()
var start: StartParams = StartParams.new()
var production: ProductionParams = ProductionParams.new()
var economy: EconomyParams = EconomyParams.new()
var new_animal: NewAnimalParams = NewAnimalParams.new()
var offline: OfflineParams = OfflineParams.new()

var _products: Dictionary = {}   # String id -> ProductDefinition
var _animals: Dictionary = {}    # String id -> AnimalDefinition
var _buildings: Dictionary = {}  # String id -> BuildingDefinition
var _product_ids: Array[String] = []
var _animal_ids: Array[String] = []
var _building_ids: Array[String] = []

## Loads and parses data/balance.json (or any path, e.g. the frozen
## test fixture). Returns null if the file is missing or not valid JSON
## -- callers decide how to handle that (Game._ready() asserts in
## debug per docs/ARCHITECTURE.md Section 7.4).
static func load_from_file(path: String) -> GameCatalog:
	if not FileAccess.file_exists(path):
		push_error("GameCatalog: balance file not found at %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameCatalog: could not open %s (error %d)" % [path, FileAccess.get_open_error()])
		return null
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameCatalog: %s did not parse as a JSON object" % path)
		return null
	return from_dict(parsed as Dictionary)

static func from_dict(data: Dictionary) -> GameCatalog:
	var catalog := GameCatalog.new()

	var products_data: Dictionary = data.get("products", {})
	for product_id: String in products_data.keys():
		var product_def := ProductDefinition.from_dict(product_id, products_data[product_id])
		catalog._products[product_id] = product_def
		catalog._product_ids.append(product_id)

	var animals_data: Dictionary = data.get("animals", {})
	for animal_id: String in animals_data.keys():
		var animal_def := AnimalDefinition.from_dict(animal_id, animals_data[animal_id])
		catalog._animals[animal_id] = animal_def
		catalog._animal_ids.append(animal_id)

	var buildings_data: Dictionary = data.get("buildings", {})
	for building_id: String in buildings_data.keys():
		var building_def := BuildingDefinition.from_dict(building_id, buildings_data[building_id])
		catalog._buildings[building_id] = building_def
		catalog._building_ids.append(building_id)

	var status_data: Dictionary = data.get("status", {})
	var status_params := StatusParams.new()
	status_params.hungry_below = float(status_data.get("hungryBelow", 30.0))
	status_params.low_happiness_below = float(status_data.get("lowHappinessBelow", 30.0))
	status_params.low_bar_below_percent = float(status_data.get("lowBarBelowPercent", 30.0))
	catalog.status = status_params

	var feeding_data: Dictionary = data.get("feeding", {})
	var feeding_params := FeedingParams.new()
	feeding_params.feed_per_meal = int(feeding_data.get("feedPerMeal", 1))
	feeding_params.hunger_per_meal = float(feeding_data.get("hungerPerMeal", 50.0))
	feeding_params.hunger_decay_per_minute = float(feeding_data.get("hungerDecayPerMinute", 1.0))
	feeding_params.debounce_ms = int(feeding_data.get("debounceMs", 300))
	feeding_params.block_when_full = bool(feeding_data.get("blockWhenFull", true))
	catalog.feeding = feeding_params

	var happiness_data: Dictionary = data.get("happiness", {})
	var happiness_params := HappinessParams.new()
	happiness_params.gain_on_feed = float(happiness_data.get("gainOnFeed", 0.0))
	happiness_params.gain_on_collect = float(happiness_data.get("gainOnCollect", 0.0))
	happiness_params.decay_per_minute = float(happiness_data.get("decayPerMinute", 0.0))
	catalog.happiness = happiness_params

	var start_data: Dictionary = data.get("start", {})
	var start_params := StartParams.new()
	start_params.coins = int(start_data.get("coins", 0))
	start_params.feed = int(start_data.get("feed", 0))
	start_params.xp = int(start_data.get("xp", 0))
	start_params.level = int(start_data.get("level", 1))
	catalog.start = start_params

	var production_data: Dictionary = data.get("production", {})
	var production_params := ProductionParams.new()
	production_params.pause_when_ready = bool(production_data.get("pauseWhenReady", true))
	catalog.production = production_params

	var economy_data: Dictionary = data.get("economy", {})
	var economy_params := EconomyParams.new()
	economy_params.purchase_lock_ms = int(economy_data.get("purchaseLockMs", 300))
	var feed_pack_data: Dictionary = economy_data.get("feedPack", {})
	economy_params.feed_pack_feed = int(feed_pack_data.get("feed", 10))
	economy_params.feed_pack_price = int(feed_pack_data.get("price", 25))
	economy_params.refuse_overflowing_feed_pack = bool(economy_data.get("refuseOverflowingFeedPack", true))
	catalog.economy = economy_params

	var new_animal_data: Dictionary = data.get("newAnimal", {})
	var new_animal_params := NewAnimalParams.new()
	new_animal_params.hunger = float(new_animal_data.get("hunger", 0.0))
	new_animal_params.happiness = float(new_animal_data.get("happiness", 100.0))
	new_animal_params.health = float(new_animal_data.get("health", 100.0))
	catalog.new_animal = new_animal_params

	var offline_data: Dictionary = data.get("offline", {})
	var offline_params := OfflineParams.new()
	offline_params.cap_hours = float(offline_data.get("capHours", 8.0))
	offline_params.reward_modal_min_minutes = float(offline_data.get("rewardModalMinMinutes", 5.0))
	catalog.offline = offline_params

	catalog._schema = int(data.get("schema", 0))

	return catalog

var _schema: int = 0

## Validates the parsed catalog. Returns a human-readable problem list;
## empty means OK. Through Phase 6: schema version, every animal's
## product_id/housing_building_id exist, cycle_seconds/price/
## unlock_level are sane, status thresholds are within 0..100, and the
## building checks from ARCHITECTURE.md Section 7.2 ("every animal's
## housing_building_id exists; every building has at least one level;
## level costs are non-negative; exactly one FEED_STORAGE and one
## MARKET building" -- "no duplicate ids" needs no check, since JSON
## object keys are already unique by construction).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()

	if _schema != CURRENT_SCHEMA:
		problems.append("schema is %d, expected %d" % [_schema, CURRENT_SCHEMA])

	for animal_id: String in _animal_ids:
		var animal_def: AnimalDefinition = _animals[animal_id]
		if not _products.has(animal_def.product_id):
			problems.append("animal '%s' references unknown product '%s'" % [animal_id, animal_def.product_id])
		if not _buildings.has(animal_def.housing_building_id):
			problems.append("animal '%s' references unknown housing building '%s'" % [animal_id, animal_def.housing_building_id])
		elif _buildings[animal_def.housing_building_id].kind != BuildingDefinition.Kind.HOUSING:
			problems.append("animal '%s' is housed in '%s', which is not a HOUSING building" % [animal_id, animal_def.housing_building_id])
		if animal_def.cycle_seconds <= 0.0:
			problems.append("animal '%s' has non-positive cycle_seconds (%s)" % [animal_id, animal_def.cycle_seconds])
		if animal_def.price < 0:
			problems.append("animal '%s' has a negative price" % animal_id)
		if animal_def.unlock_level < 1:
			problems.append("animal '%s' has unlock_level below 1" % animal_id)

	for threshold: float in [status.hungry_below, status.low_happiness_below, status.low_bar_below_percent]:
		if threshold < 0.0 or threshold > 100.0:
			problems.append("a status threshold is outside 0..100: %s" % threshold)

	if feeding.feed_per_meal < 1:
		problems.append("feeding.feed_per_meal must be at least 1, got %d" % feeding.feed_per_meal)
	if feeding.hunger_per_meal <= 0.0 or feeding.hunger_per_meal > 100.0:
		problems.append("feeding.hunger_per_meal must be in (0, 100], got %s" % feeding.hunger_per_meal)
	if feeding.debounce_ms < 0:
		problems.append("feeding.debounce_ms must not be negative, got %d" % feeding.debounce_ms)
	if feeding.hunger_decay_per_minute < 0.0:
		problems.append("feeding.hunger_decay_per_minute must not be negative, got %s" % feeding.hunger_decay_per_minute)

	for happiness_value: float in [happiness.gain_on_feed, happiness.gain_on_collect, happiness.decay_per_minute]:
		if happiness_value < 0.0:
			problems.append("a happiness value must not be negative, got %s" % happiness_value)

	if start.feed < 0:
		problems.append("start.feed must not be negative, got %d" % start.feed)
	if start.coins < 0:
		problems.append("start.coins must not be negative, got %d" % start.coins)
	if start.level < 1:
		problems.append("start.level must be at least 1, got %d" % start.level)

	if economy.purchase_lock_ms < 0:
		problems.append("economy.purchase_lock_ms must not be negative, got %d" % economy.purchase_lock_ms)
	if economy.feed_pack_feed < 1:
		problems.append("economy.feed_pack_feed must be at least 1, got %d" % economy.feed_pack_feed)
	if economy.feed_pack_price < 0:
		problems.append("economy.feed_pack_price must not be negative, got %d" % economy.feed_pack_price)

	for new_animal_value: float in [new_animal.hunger, new_animal.happiness, new_animal.health]:
		if new_animal_value < 0.0 or new_animal_value > 100.0:
			problems.append("a newAnimal value is outside 0..100: %s" % new_animal_value)

	if offline.cap_hours <= 0.0:
		problems.append("offline.cap_hours must be positive, got %s" % offline.cap_hours)
	if offline.reward_modal_min_minutes < 0.0:
		problems.append("offline.reward_modal_min_minutes must not be negative, got %s" % offline.reward_modal_min_minutes)

	var feed_storage_count := 0
	var market_count := 0
	for building_id: String in _building_ids:
		var building_def: BuildingDefinition = _buildings[building_id]
		if building_def.kind == BuildingDefinition.Kind.FEED_STORAGE:
			feed_storage_count += 1
		elif building_def.kind == BuildingDefinition.Kind.MARKET:
			market_count += 1
		if building_def.raw_kind != "housing" and building_def.raw_kind != "feed_storage" and building_def.raw_kind != "market":
			problems.append("building '%s' has an unrecognized kind '%s'" % [building_id, building_def.raw_kind])
		if building_def.levels.is_empty():
			problems.append("building '%s' has no levels" % building_id)
		for upgrade: UpgradeDefinition in building_def.levels:
			if upgrade.cost < 0:
				problems.append("building '%s' level %d has a negative cost" % [building_id, upgrade.level])
			if building_def.kind == BuildingDefinition.Kind.HOUSING and upgrade.production_multiplier <= 0.0:
				problems.append("building '%s' level %d has a non-positive production_multiplier" % [building_id, upgrade.level])
	if feed_storage_count != 1:
		problems.append("expected exactly one FEED_STORAGE building, found %d" % feed_storage_count)
	if market_count != 1:
		problems.append("expected exactly one MARKET building, found %d" % market_count)

	return problems

func animal(animal_id: String) -> AnimalDefinition:
	return _animals.get(animal_id)

func product(product_id: String) -> ProductDefinition:
	return _products.get(product_id)

func building(building_id: String) -> BuildingDefinition:
	return _buildings.get(building_id)

## The one building of `kind` (ARCHITECTURE.md Section 7.2:
## "exactly one FEED_STORAGE and one MARKET building" -- validate()
## enforces this, so the first match found is unambiguous in practice).
## Returns null if none exists (a validate() failure state).
func building_of_kind(kind: BuildingDefinition.Kind) -> BuildingDefinition:
	for building_id: String in _building_ids:
		var def: BuildingDefinition = _buildings[building_id]
		if def.kind == kind:
			return def
	return null

func animal_ids() -> Array[String]:
	return _animal_ids.duplicate()

func product_ids() -> Array[String]:
	return _product_ids.duplicate()

func building_ids() -> Array[String]:
	return _building_ids.duplicate()
