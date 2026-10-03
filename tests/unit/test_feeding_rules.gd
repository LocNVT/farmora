extends GutTest

## Verifies FeedingRules.check_feed()/apply_meal() against the fixture
## catalog's feeding/happiness values (feedPerMeal=1, hungerPerMeal=50,
## blockWhenFull=true, gainOnFeed=10), per docs/ARCHITECTURE.md Section
## 17's "Feed an animal" data flow.

var _catalog: GameCatalog

func before_each() -> void:
	_catalog = StateFactory.fixture_catalog()

func _player(feed: int) -> PlayerState:
	var p := PlayerState.new()
	p.feed = feed
	return p

func test_debounce_key_is_scoped_per_animal() -> void:
	assert_eq(FeedingRules.debounce_key("a1"), "feed:a1")
	assert_ne(FeedingRules.debounce_key("a1"), FeedingRules.debounce_key("a2"))

func test_check_feed_ok_when_feed_available_and_not_full() -> void:
	var player := _player(5)
	var a := StateFactory.animal("chicken", "chicken_coop", {"hunger": 50.0})
	var result: ActionResult = FeedingRules.check_feed(player, a, _catalog)
	assert_true(result.ok())

func test_check_feed_refuses_not_enough_feed() -> void:
	var player := _player(0)
	var a := StateFactory.animal("chicken", "chicken_coop", {"hunger": 50.0})
	var result: ActionResult = FeedingRules.check_feed(player, a, _catalog)
	assert_false(result.ok())
	assert_eq(result.code, ActionResult.Code.NOT_ENOUGH_FEED)

func test_check_feed_refuses_when_hunger_is_full_and_block_when_full_is_true() -> void:
	var player := _player(5)
	var a := StateFactory.animal("chicken", "chicken_coop", {"hunger": 100.0})
	var result: ActionResult = FeedingRules.check_feed(player, a, _catalog)
	assert_false(result.ok())
	assert_eq(result.code, ActionResult.Code.HUNGER_FULL)

func test_check_feed_prioritizes_not_enough_feed_over_hunger_full() -> void:
	var player := _player(0)
	var a := StateFactory.animal("chicken", "chicken_coop", {"hunger": 100.0})
	var result: ActionResult = FeedingRules.check_feed(player, a, _catalog)
	assert_eq(result.code, ActionResult.Code.NOT_ENOUGH_FEED)

func test_check_feed_allows_exactly_at_the_feed_per_meal_amount() -> void:
	var player := _player(1)
	var a := StateFactory.animal("chicken", "chicken_coop", {"hunger": 50.0})
	assert_true(FeedingRules.check_feed(player, a, _catalog).ok())

func test_apply_meal_spends_feed_and_increases_hunger_and_happiness() -> void:
	var player := _player(5)
	var a := StateFactory.animal("chicken", "chicken_coop", {"hunger": 40.0, "happiness": 60.0})
	FeedingRules.apply_meal(player, a, _catalog)
	assert_eq(player.feed, 4)
	assert_almost_eq(a.hunger, 90.0, 0.01)
	assert_almost_eq(a.happiness, 70.0, 0.01)

func test_apply_meal_clamps_hunger_at_100() -> void:
	var player := _player(5)
	var a := StateFactory.animal("chicken", "chicken_coop", {"hunger": 80.0})
	FeedingRules.apply_meal(player, a, _catalog)
	assert_almost_eq(a.hunger, 100.0, 0.01)

func test_apply_meal_clamps_happiness_at_100() -> void:
	var player := _player(5)
	var a := StateFactory.animal("chicken", "chicken_coop", {"happiness": 95.0})
	FeedingRules.apply_meal(player, a, _catalog)
	assert_almost_eq(a.happiness, 100.0, 0.01)
