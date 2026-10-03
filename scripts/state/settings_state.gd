class_name SettingsState
extends RefCounted

## Runtime settings per docs/ARCHITECTURE.md Section 8.1's `settings`
## save group. Through Phase 7: pure round-trip data -- SaveCodec is
## its only reader/writer. No audio/vibration/language system exists
## yet to actually consume these values (AudioService is Phase 9;
## language/i18n via `tr()`/`strings.csv` is unbuilt) -- built now
## anyway because GDD Section 9's save FORMAT requires a `settings`
## object structurally (SaveCodec's own decode() rejects a save whose
## `settings` key is not a Dictionary), unlike a balance.json group
## that simply sits unparsed until its owning phase.

var sound: bool = true
var music: bool = true
var vibration: bool = true
var reminders: bool = false      # GDD Section 9: "defaults to off"
var language: String = "en"      # ARCHITECTURE.md Section 8.1: additive beyond GDD's own sketch
var extra: Dictionary = {}       # unknown JSON keys, preserved and written back unchanged

func to_dict() -> Dictionary:
	var result: Dictionary = {
		"sound": sound,
		"music": music,
		"vibration": vibration,
		"reminders": reminders,
		"language": language,
	}
	for key: String in extra.keys():
		if not result.has(key):
			result[key] = extra[key]
	return result

static func from_dict(data: Dictionary) -> SettingsState:
	var state := SettingsState.new()
	var known_keys: PackedStringArray = ["sound", "music", "vibration", "reminders", "language"]

	state.sound = bool(data.get("sound", true))
	state.music = bool(data.get("music", true))
	state.vibration = bool(data.get("vibration", true))
	state.reminders = bool(data.get("reminders", false))
	state.language = String(data.get("language", "en"))

	var extra: Dictionary = {}
	for key: String in data.keys():
		if not known_keys.has(key):
			extra[key] = data[key]
	state.extra = extra

	return state
