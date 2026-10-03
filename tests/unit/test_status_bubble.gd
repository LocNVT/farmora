extends GutTest

## Verifies StatusBubble's own binding/tap-rect behavior in isolation
## (docs/DESIGN.md Section 11: "Bubbles | 36 dp visual, 48 dp target").
## FarmWorld's spawn/show/hide decisions are covered separately in
## test_farm_world_bubbles.gd.

func test_tap_rect_is_48dp_centered_on_the_bubble() -> void:
	var bubble: StatusBubble = load("res://scenes/farm/world_ui/status_bubble.tscn").instantiate()
	add_child_autofree(bubble)
	bubble.global_position = Vector2(100, 200)
	var rect: Rect2 = bubble.tap_rect()
	assert_eq(rect.size, Vector2(48, 48))
	assert_eq(rect.get_center(), Vector2(100, 200))

func test_bind_sets_animal_id_and_bubble_kind() -> void:
	var bubble: StatusBubble = load("res://scenes/farm/world_ui/status_bubble.tscn").instantiate()
	add_child_autofree(bubble)
	var anchor := Node2D.new()
	add_child_autofree(anchor)
	bubble.bind("a1", StatusRules.Bubble.FEED, anchor)
	assert_eq(bubble.animal_id, "a1")
	assert_eq(bubble.bubble_kind, StatusRules.Bubble.FEED)

func test_bind_snaps_to_the_anchors_position_immediately() -> void:
	var bubble: StatusBubble = load("res://scenes/farm/world_ui/status_bubble.tscn").instantiate()
	add_child_autofree(bubble)
	var anchor := Node2D.new()
	add_child_autofree(anchor)
	anchor.global_position = Vector2(40, 60)
	bubble.bind("a1", StatusRules.Bubble.FEED, anchor)
	assert_eq(bubble.global_position, Vector2(40, 60))

func test_process_follows_the_anchor_after_it_moves() -> void:
	var bubble: StatusBubble = load("res://scenes/farm/world_ui/status_bubble.tscn").instantiate()
	add_child_autofree(bubble)
	var anchor := Node2D.new()
	add_child_autofree(anchor)
	bubble.bind("a1", StatusRules.Bubble.FEED, anchor)
	anchor.global_position = Vector2(10, 20)
	bubble._process(0.016)
	assert_eq(bubble.global_position, Vector2(10, 20))

func test_bind_accepts_a_product_id_for_the_product_bubble() -> void:
	var bubble: StatusBubble = load("res://scenes/farm/world_ui/status_bubble.tscn").instantiate()
	add_child_autofree(bubble)
	var anchor := Node2D.new()
	add_child_autofree(anchor)
	bubble.bind("a1", StatusRules.Bubble.PRODUCT, anchor, "egg")
	assert_eq(bubble.bubble_kind, StatusRules.Bubble.PRODUCT)

func test_feed_bubble_does_not_bob() -> void:
	var bubble: StatusBubble = load("res://scenes/farm/world_ui/status_bubble.tscn").instantiate()
	add_child_autofree(bubble)
	var anchor := Node2D.new()
	add_child_autofree(anchor)
	bubble.bind("a1", StatusRules.Bubble.FEED, anchor)
	bubble._process(0.8)  # half a bob cycle -- would be at a bob extreme if it bobbed
	assert_eq(bubble.global_position, anchor.global_position, "DESIGN.md Section 11 only documents the bob for the PRODUCT-ready bubble, not FEED")

func test_product_bubble_bobs_around_the_anchor_over_time() -> void:
	var bubble: StatusBubble = load("res://scenes/farm/world_ui/status_bubble.tscn").instantiate()
	add_child_autofree(bubble)
	var anchor := Node2D.new()
	add_child_autofree(anchor)
	bubble.bind("a1", StatusRules.Bubble.PRODUCT, anchor, "egg")
	bubble._process(0.4)  # quarter of the 1.6s loop -> sin(TAU/4) = 1.0 -> +4dp
	assert_almost_eq(bubble.global_position.y, anchor.global_position.y + 4.0, 0.01)

func test_product_bubble_returns_to_the_anchor_after_a_full_cycle() -> void:
	var bubble: StatusBubble = load("res://scenes/farm/world_ui/status_bubble.tscn").instantiate()
	add_child_autofree(bubble)
	var anchor := Node2D.new()
	add_child_autofree(anchor)
	bubble.bind("a1", StatusRules.Bubble.PRODUCT, anchor, "egg")
	bubble._process(1.6)  # exactly one full 1.6s loop -> sin(TAU) = 0
	assert_almost_eq(bubble.global_position.y, anchor.global_position.y, 0.01)
