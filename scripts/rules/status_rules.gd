class_name StatusRules
extends RefCounted

## Derived animal status per docs/ARCHITECTURE.md Section 9.2 (GDD
## Section 4 status language). Pure static functions over (state,
## definitions) only -- no autoloads, no clock, no nodes (CLAUDE.md
## Section 11: this is what makes the minimum test list cheap).
##
## Through Phase 3: flags() (feeds AnimalView's placeholder face) and
## primary_bubble() (the wheat bubble's visibility -- PRODUCT and CLOUD
## have no real trigger yet, since Collect doesn't exist until Phase 4
## and happiness.gainOnFeed is still the GDD's inert 0). is_low_bar()
## (status-bar amber threshold) waits for its real consumer, StatusBar,
## which is later UI-shell work.

const HUNGRY := 1
const READY := 2
const LOW_HAPPINESS := 4

## ARCHITECTURE.md Section 9.2: `enum Bubble { NONE, FEED, PRODUCT, CLOUD }`.
enum Bubble { NONE, FEED, PRODUCT, CLOUD }

static func flags(a: AnimalInstance, c: GameCatalog) -> int:
	var result := 0
	if a.hunger < c.status.hungry_below:
		result |= HUNGRY
	if a.progress >= 1.0:
		result |= READY
	if a.happiness < c.status.low_happiness_below:
		result |= LOW_HAPPINESS
	return result

## Which single bubble shows when several status flags apply at once
## (ARCHITECTURE.md Section 9.2/23 item 16, OPEN (arch), built default):
## READY > FEED > CLOUD. The product bubble wins over the wheat bubble
## because collecting also raises happiness; Phase 3 only ever produces
## HUNGRY (READY/LOW_HAPPINESS have no real trigger yet), so this
## priority is exercised in full once Phase 4 adds production.
static func primary_bubble(flags: int) -> Bubble:
	if flags & READY != 0:
		return Bubble.PRODUCT
	if flags & HUNGRY != 0:
		return Bubble.FEED
	if flags & LOW_HAPPINESS != 0:
		return Bubble.CLOUD
	return Bubble.NONE
