class_name SaveCodec
extends RefCounted

## Encodes/decodes the version-1 save format, per docs/ARCHITECTURE.md
## Section 11.2/11.3. `encode()` composes the full save root from a
## GameState; `decode()` validates and parses a loaded save's Dictionary
## back into a GameState, tolerating unknown fields/ids (preserved, never
## dropped -- GDD Section 9/10) and clamping out-of-range values rather
## than failing on them. Structural/type problems that make the save
## untrustworthy are reported via DecodeResult.status instead of
## partially parsing. SaveFileIO/SaveService (later tasks) own the actual
## file read/write and what each status means for the file on disk.

const CURRENT_VERSION := 1


## Composes the full save root. Unknown root-level keys from `state.extra`
## are merged in without overwriting the known keys above (the same
## "extra written back unchanged" pattern as every state class's
## to_dict()).
static func encode(state: GameState) -> Dictionary:
	var result: Dictionary = {
		"version": CURRENT_VERSION,
		"lastSeen": state.last_seen_ms,
		"tutorialStep": state.tutorial_step,
		"wallet": state.player.to_dict(),
		"bag": state.inventory.to_dict(),
		"buildings": state.farm.to_buildings_array(),
		"animals": state.farm.to_animals_array(),
		"settings": state.settings.to_dict(),
	}
	for key: String in state.extra.keys():
		if not result.has(key):
			result[key] = state.extra[key]
	return result


## Validates and parses a loaded save. See class header for the ordered
## steps (ARCHITECTURE.md Section 11.3). Returns immediately with
## `state = null` on DAMAGED/TOO_NEW -- no partial parsing.
static func decode(d: Dictionary, c: GameCatalog) -> DecodeResult:
	# Step 1: structure check.
	if not _has_valid_structure(d):
		return DecodeResult.of(DecodeResult.Status.DAMAGED)

	# Step 2: version.
	var version: int = int(d["version"])
	if version > CURRENT_VERSION:
		return DecodeResult.of(DecodeResult.Status.TOO_NEW)
	var data: Dictionary = d
	if version < CURRENT_VERSION:
		data = SaveMigrator.migrate(d)
		if not _has_valid_structure(data):
			return DecodeResult.of(DecodeResult.Status.DAMAGED)

	# Step 3: field types (known fields only -- unknown fields are
	# preserved as `extra` by each state class's own from_dict(), not
	# type-checked here).
	if not _has_valid_field_types(data):
		return DecodeResult.of(DecodeResult.Status.DAMAGED)

	var problems: Array[String] = []
	var state := GameState.new()

	state.last_seen_ms = int(data.get("lastSeen", 0))
	state.tutorial_step = int(data.get("tutorialStep", 0))

	state.player = PlayerState.from_dict(data.get("wallet", {}))
	_clamp_player(state.player, problems)

	state.inventory = InventoryState.from_dict(data.get("bag", {}))
	_clamp_inventory(state.inventory, problems)

	state.settings = SettingsState.from_dict(data.get("settings", {}))

	state.farm = _decode_farm(data, c, problems)

	# Known root keys are excluded from `extra`; everything else on the
	# root is preserved unchanged (same pattern as the per-object extra
	# handling already in PlayerState/SettingsState/etc.).
	var known_root_keys: PackedStringArray = [
		"version", "lastSeen", "tutorialStep", "wallet", "bag",
		"buildings", "animals", "settings",
	]
	var extra: Dictionary = {}
	for key: String in data.keys():
		if not known_root_keys.has(key):
			extra[key] = data[key]
	state.extra = extra

	return DecodeResult.of(DecodeResult.Status.OK, state, problems)


## Root is a Dictionary; version is a number; wallet/bag/settings are
## Dictionaries; buildings/animals are Arrays (element-type checked
## separately so a bad element is a type failure, not a structure one).
static func _has_valid_structure(d: Dictionary) -> bool:
	if not (d is Dictionary):
		return false
	if not d.has("version") or not (d["version"] is float or d["version"] is int):
		return false
	for key: String in ["wallet", "bag", "settings"]:
		if not d.has(key) or not (d[key] is Dictionary):
			return false
	for key: String in ["buildings", "animals"]:
		if not d.has(key) or not (d[key] is Array):
			return false
	return true


## Known-field type checks beyond the structural pass: each element of
## `buildings`/`animals` must be a Dictionary (the per-field types inside
## wallet/bag/settings/each building/each animal).
static func _has_valid_field_types(d: Dictionary) -> bool:
	var buildings: Array = d["buildings"]
	for entry: Variant in buildings:
		if not (entry is Dictionary):
			return false
	var animals: Array = d["animals"]
	for entry: Variant in animals:
		if not (entry is Dictionary):
			return false

	var wallet: Dictionary = d["wallet"]
	if not _is_valid_numeric_field(wallet, "coins") or not _is_valid_numeric_field(wallet, "feed") \
			or not _is_valid_numeric_field(wallet, "xp") or not _is_valid_numeric_field(wallet, "level"):
		return false

	var bag: Dictionary = d["bag"]
	for key: String in bag.keys():
		if not (bag[key] is float or bag[key] is int):
			return false

	var settings: Dictionary = d["settings"]
	for key: String in ["sound", "music", "vibration", "reminders"]:
		if settings.has(key) and not (settings[key] is bool):
			return false
	if settings.has("language") and not (settings["language"] is String):
		return false

	for entry: Variant in buildings:
		var building: Dictionary = entry
		if building.has("id") and not (building["id"] is String):
			return false
		if not _is_valid_numeric_field(building, "level"):
			return false

	for entry: Variant in animals:
		var animal: Dictionary = entry
		for key: String in ["id", "species", "name", "buildingId"]:
			if animal.has(key) and not (animal[key] is String):
				return false
		for key: String in ["hunger", "happiness", "health", "progress"]:
			if not _is_valid_numeric_field(animal, key):
				return false

	return true


static func _is_valid_numeric_field(d: Dictionary, key: String) -> bool:
	if not d.has(key):
		return true  # missing is fine -- from_dict() supplies a default
	return d[key] is float or d[key] is int


static func _clamp_player(player: PlayerState, problems: Array[String]) -> void:
	var clamped_coins: int = max(player.coins, 0)
	if clamped_coins != player.coins:
		problems.append("coins clamped from %d to %d" % [player.coins, clamped_coins])
		player.coins = clamped_coins

	var clamped_feed: int = max(player.feed, 0)
	if clamped_feed != player.feed:
		problems.append("feed clamped from %d to %d" % [player.feed, clamped_feed])
		player.feed = clamped_feed


static func _clamp_inventory(inventory: InventoryState, problems: Array[String]) -> void:
	for product_id: String in inventory.quantities.keys():
		var qty: int = int(inventory.quantities[product_id])
		var clamped_qty: int = max(qty, 0)
		if clamped_qty != qty:
			problems.append("bag '%s' clamped from %d to %d" % [product_id, qty, clamped_qty])
			inventory.quantities[product_id] = clamped_qty


## Parses the save's buildings/animals arrays into a FarmState: known ids
## become typed instances (range-clamped), unknown ids are preserved
## verbatim in unrecognized_buildings/unrecognized_animals. Then any
## starts_built catalog building missing from the result is added at
## level 1 (ARCHITECTURE.md Section 10.2).
static func _decode_farm(data: Dictionary, c: GameCatalog, problems: Array[String]) -> FarmState:
	var farm := FarmState.new()

	var buildings: Array = data["buildings"]
	for entry: Variant in buildings:
		var raw: Dictionary = entry
		var building_id: String = String(raw.get("id", ""))
		var definition: BuildingDefinition = c.building(building_id)
		if definition == null:
			farm.unrecognized_buildings.append(raw)
			problems.append("unrecognized building id '%s' preserved" % building_id)
			continue
		var instance: BuildingInstance = BuildingInstance.from_dict(raw)
		var max_level: int = definition.max_level()
		var clamped_level: int = clampi(instance.level, 1, max_level)
		if clamped_level != instance.level:
			problems.append("%s level clamped from %d to %d" % [building_id, instance.level, clamped_level])
			instance.level = clamped_level
		farm.buildings.append(instance)

	var animals: Array = data["animals"]
	for entry: Variant in animals:
		var raw: Dictionary = entry
		var species: String = String(raw.get("species", ""))
		if c.animal(species) == null:
			farm.unrecognized_animals.append(raw)
			problems.append("unrecognized animal species '%s' preserved" % species)
			continue
		var instance: AnimalInstance = AnimalInstance.from_dict(raw)
		_clamp_animal(instance, problems)
		farm.animals.append(instance)

	for building_id: String in c.building_ids():
		var definition: BuildingDefinition = c.building(building_id)
		if definition.starts_built and farm.get_building(building_id) == null:
			var missing := BuildingInstance.new()
			missing.id = building_id
			missing.level = 1
			farm.buildings.append(missing)
			problems.append("missing starting building '%s' added at level 1" % building_id)

	return farm


static func _clamp_animal(animal: AnimalInstance, problems: Array[String]) -> void:
	var clamped_hunger: float = clampf(animal.hunger, 0.0, 100.0)
	if clamped_hunger != animal.hunger:
		problems.append("%s hunger clamped from %s to %s" % [animal.id, animal.hunger, clamped_hunger])
		animal.hunger = clamped_hunger

	var clamped_happiness: float = clampf(animal.happiness, 0.0, 100.0)
	if clamped_happiness != animal.happiness:
		problems.append("%s happiness clamped from %s to %s" % [animal.id, animal.happiness, clamped_happiness])
		animal.happiness = clamped_happiness

	var clamped_health: float = clampf(animal.health, 0.0, 100.0)
	if clamped_health != animal.health:
		problems.append("%s health clamped from %s to %s" % [animal.id, animal.health, clamped_health])
		animal.health = clamped_health

	var clamped_progress: float = clampf(animal.progress, 0.0, 1.0)
	if clamped_progress != animal.progress:
		problems.append("%s progress clamped from %s to %s" % [animal.id, animal.progress, clamped_progress])
		animal.progress = clamped_progress
