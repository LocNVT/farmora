extends GutTest

## ScreenFit.compute_fit_size is a pure function (docs/ARCHITECTURE.md
## Section 2), so its device-size math is tested directly without a live
## Window or real DisplayServer hardware values.

func test_reference_device_390x844_at_3x_yields_base_size() -> void:
	# iPhone 15 reference: 1170x2532 px at 3.0x (401 dpi-ish; use 480 dpi
	# which is the common "3x" Android bucket so the math is exact: 480/160=3).
	var result := ScreenFit.compute_fit_size(Vector2i(1170, 2532), 480.0)
	assert_eq(result, Vector2i(390, 844))

func test_small_android_360x640_at_2x_yields_minimum_size() -> void:
	# 720x1280 px at 2.0x (320 dpi).
	var result := ScreenFit.compute_fit_size(Vector2i(720, 1280), 320.0)
	assert_eq(result, Vector2i(360, 640))

func test_result_never_falls_below_the_documented_minimum() -> void:
	# An implausibly tiny/high-dpi report should still clamp to the floor.
	var result := ScreenFit.compute_fit_size(Vector2i(100, 100), 1000.0)
	assert_eq(result.x, ScreenFit.MIN_WIDTH)
	assert_eq(result.y, ScreenFit.MIN_HEIGHT)

func test_zero_dpi_falls_back_to_base_size() -> void:
	var result := ScreenFit.compute_fit_size(Vector2i(1080, 1920), 0.0)
	assert_eq(result, Vector2i(ScreenFit.BASE_WIDTH, ScreenFit.BASE_HEIGHT))

func test_compute_fit_size_from_scale_with_ios_3x() -> void:
	# iOS 3x device: 1170x2532 px at scale 3.0 should yield 390x844 dp
	var result := ScreenFit.compute_fit_size_from_scale(Vector2i(1170, 2532), 3.0)
	assert_eq(result, Vector2i(390, 844))

func test_compute_fit_size_from_scale_with_zero_scale_returns_base() -> void:
	# Zero or negative scale should fall back to base size
	var result := ScreenFit.compute_fit_size_from_scale(Vector2i(1170, 2532), 0.0)
	assert_eq(result, Vector2i(ScreenFit.BASE_WIDTH, ScreenFit.BASE_HEIGHT))

func test_compute_fit_size_from_scale_below_minimum_clamps_to_minimum() -> void:
	# Very small device or implausible scale should clamp to the minimum
	var result := ScreenFit.compute_fit_size_from_scale(Vector2i(100, 100), 10.0)
	assert_eq(result.x, ScreenFit.MIN_WIDTH)
	assert_eq(result.y, ScreenFit.MIN_HEIGHT)

func test_apply_leaves_content_scale_size_untouched_on_desktop() -> void:
	# Regression test for a real Phase 0 bug: ScreenFit.apply() used to
	# run the mobile dpi/160 formula unconditionally, including on
	# desktop. Desktop DPI is commonly 96 ("100% scaling"), a different
	# convention than mobile's physical-density DPI, and project.godot's
	# canvas_items stretch mode already keeps the window at the
	# configured dp size (390x844) with no further scaling needed. That
	# bug inflated content_scale_size to ~1.67x the window size and
	# shrank every control -- caught by comparing a screenshot against
	# the expected layout, not by this test alone, but this pins the fix:
	# on desktop (which is what this whole suite runs on), apply() must
	# not override content_scale_size away from the project default.
	var window := Window.new()
	add_child_autofree(window)
	window.content_scale_size = Vector2i.ZERO
	ScreenFit.apply(window)
	if OS.has_feature("pc"):
		assert_eq(window.content_scale_size, Vector2i.ZERO, "Desktop must not have content_scale_size overridden by the mobile dpi formula")
