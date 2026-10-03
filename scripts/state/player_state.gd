class_name PlayerState
extends RefCounted

## Runtime player wallet per docs/ARCHITECTURE.md Section 8.1 ("wallet"
## save group) / Section 8.3 (`PlayerState` table: `coins`, `feed`,
## `xp`, `level`, `extra`). Through Phase 7: all fields exist, matching
## GDD Section 9's save shape. `xp` has no gameplay reader yet (no
## ProgressionRules exists -- GDD Section 8's XP-source numbers are
## still the inert placeholder 0, unassigned work) but IS read/written
## by SaveCodec, which is a real reader: the save format is structural
## (GDD Section 9), not a balance.json group that waits for its owning
## phase. `extra` holds unknown JSON keys, preserved and written back
## unchanged (GDD Section 9/10).

var feed: int = 0
var coins: int = 0
var xp: int = 0
var level: int = 1
var extra: Dictionary = {}

func to_dict() -> Dictionary:
	var result: Dictionary = {
		"coins": coins,
		"feed": feed,
		"xp": xp,
		"level": level,
	}
	for key: String in extra.keys():
		if not result.has(key):
			result[key] = extra[key]
	return result

static func from_dict(data: Dictionary) -> PlayerState:
	var state := PlayerState.new()
	var known_keys: PackedStringArray = ["coins", "feed", "xp", "level"]

	state.coins = int(data.get("coins", 0))
	state.feed = int(data.get("feed", 0))
	state.xp = int(data.get("xp", 0))
	state.level = int(data.get("level", 1))

	var extra: Dictionary = {}
	for key: String in data.keys():
		if not known_keys.has(key):
			extra[key] = data[key]
	state.extra = extra

	return state
