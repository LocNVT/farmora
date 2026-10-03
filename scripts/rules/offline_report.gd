class_name OfflineReport
extends RefCounted

## The result of one `Game._advance_to()` call, per docs/ARCHITECTURE.md
## Section 12.3. Its own top-level file (GDScript allows one class_name
## per file) rather than nested inside OfflineRules or Game -- same
## precedent as DecodeResult/LoadResult living apart from SaveCodec/
## SaveService.
##
## `products`/`ready_animal_ids` describe only what was produced DURING
## this window (an animal whose READY flag went from false to true), not
## the player's whole bag or every currently-ready animal -- an animal
## already READY before the player left produced nothing while away
## (GDD Section 9: "no free production") and is correctly excluded.
## `coin_value` is informational only (ARCHITECTURE.md Section 12.3's
## "Built default: display only") -- `Game.collect_offline_reward()`
## never credits it.

var elapsed_ms: int = 0
var capped: bool = false
var ready_animal_ids: Array[String] = []
var products: Dictionary = {}  # String product_id -> int qty
var coin_value: int = 0

## Builds a report from each animal's advance_animal() return value
## (`completed: Dictionary` of animal_id -> products completed in this
## window, 0 or 1 under the enforced pause_when_ready default) plus the
## elapsed/capped window data. `state`/`catalog` are read-only here, used
## only to map a READY animal's species to its product id and to price
## the informational coin value through BuildingRules' own Market bonus.
static func build(completed: Dictionary, state: GameState, elapsed_ms: int, capped: bool, catalog: GameCatalog) -> OfflineReport:
	var report := OfflineReport.new()
	report.elapsed_ms = elapsed_ms
	report.capped = capped

	for animal_id: String in completed.keys():
		var count: int = completed[animal_id]
		if count <= 0:
			continue
		report.ready_animal_ids.append(animal_id)
		var animal: AnimalInstance = state.farm.get_animal(animal_id)
		if animal == null:
			continue
		var product_id: String = catalog.animal(animal.species).product_id
		report.products[product_id] = report.products.get(product_id, 0) + count

	var bonus_percent: float = BuildingRules.sell_bonus_percent(state.farm, catalog)
	report.coin_value = EconomyRules.offline_coin_value(report.products, catalog, bonus_percent)

	return report
