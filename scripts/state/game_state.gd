class_name GameState
extends RefCounted

## Root runtime state per docs/ARCHITECTURE.md Section 8.1. Holds the
## farm (animals, buildings), the player wallet, the inventory (bag),
## `last_seen_ms` (the simulation snapshot timestamp, ARCHITECTURE.md
## Section 12.2/ADR-06: "state is valid at lastSeen"), `tutorial_step`
## (no tutorial logic reads this yet -- unassigned work -- but
## SaveCodec round-trips it per GDD Section 9's save shape), `settings`
## (same reasoning -- see settings_state.gd), and `extra` (unknown
## root-level JSON keys, preserved and written back unchanged).

var farm: FarmState = FarmState.new()
var player: PlayerState = PlayerState.new()
var inventory: InventoryState = InventoryState.new()
var last_seen_ms: int = 0
var tutorial_step: int = 0
var settings: SettingsState = SettingsState.new()
var extra: Dictionary = {}
