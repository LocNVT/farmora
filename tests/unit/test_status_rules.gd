extends GutTest

## Verifies StatusRules.flags() against the fixture catalog's thresholds
## (all 30 in the fixture, per docs/ARCHITECTURE.md Section 9.2 / GDD
## Section 4).

var _catalog: GameCatalog

func before_each() -> void:
	_catalog = StateFactory.fixture_catalog()

func test_no_flags_when_fed_happy_and_not_ready() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"hunger": 100.0, "happiness": 100.0, "progress": 0.5})
	assert_eq(StatusRules.flags(a, _catalog), 0)

func test_hungry_flag_below_threshold() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"hunger": 29.9})
	assert_true(StatusRules.flags(a, _catalog) & StatusRules.HUNGRY != 0)

func test_not_hungry_at_exactly_threshold() -> void:
	# GDD Section 4 OPEN default: "wheat bubble when hunger < 30" -- the
	# boundary itself (hunger == 30) is NOT hungry.
	var a := StateFactory.animal("chicken", "chicken_coop", {"hunger": 30.0})
	assert_true(StatusRules.flags(a, _catalog) & StatusRules.HUNGRY == 0)

func test_ready_flag_at_progress_one() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"progress": 1.0})
	assert_true(StatusRules.flags(a, _catalog) & StatusRules.READY != 0)

func test_not_ready_just_under_one() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"progress": 0.99})
	assert_true(StatusRules.flags(a, _catalog) & StatusRules.READY == 0)

func test_low_happiness_flag_below_threshold() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"happiness": 10.0})
	assert_true(StatusRules.flags(a, _catalog) & StatusRules.LOW_HAPPINESS != 0)

func test_combined_flags_can_all_be_set_at_once() -> void:
	var a := StateFactory.animal("chicken", "chicken_coop", {"hunger": 5.0, "happiness": 5.0, "progress": 1.0})
	var flags: int = StatusRules.flags(a, _catalog)
	assert_true(flags & StatusRules.HUNGRY != 0)
	assert_true(flags & StatusRules.READY != 0)
	assert_true(flags & StatusRules.LOW_HAPPINESS != 0)

func test_primary_bubble_is_none_with_no_flags() -> void:
	assert_eq(StatusRules.primary_bubble(0), StatusRules.Bubble.NONE)

func test_primary_bubble_is_feed_when_only_hungry() -> void:
	assert_eq(StatusRules.primary_bubble(StatusRules.HUNGRY), StatusRules.Bubble.FEED)

func test_primary_bubble_is_product_when_only_ready() -> void:
	assert_eq(StatusRules.primary_bubble(StatusRules.READY), StatusRules.Bubble.PRODUCT)

func test_primary_bubble_is_cloud_when_only_low_happiness() -> void:
	assert_eq(StatusRules.primary_bubble(StatusRules.LOW_HAPPINESS), StatusRules.Bubble.CLOUD)

func test_primary_bubble_prioritizes_ready_over_feed() -> void:
	var flags: int = StatusRules.HUNGRY | StatusRules.READY
	assert_eq(StatusRules.primary_bubble(flags), StatusRules.Bubble.PRODUCT)

func test_primary_bubble_prioritizes_feed_over_cloud() -> void:
	var flags: int = StatusRules.HUNGRY | StatusRules.LOW_HAPPINESS
	assert_eq(StatusRules.primary_bubble(flags), StatusRules.Bubble.FEED)

func test_primary_bubble_prioritizes_ready_over_everything() -> void:
	var flags: int = StatusRules.HUNGRY | StatusRules.READY | StatusRules.LOW_HAPPINESS
	assert_eq(StatusRules.primary_bubble(flags), StatusRules.Bubble.PRODUCT)
