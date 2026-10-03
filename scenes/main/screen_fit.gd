class_name ScreenFit
extends RefCounted

## Fits the game's logical (dp) size to the real device, per
## docs/ARCHITECTURE.md Section 2 and docs/DESIGN.md Section 12.
##
## Phase 0 scope only: on mobile, compute a dp size from the device and
## apply it as `window.content_scale_size`, clamped to the design's
## minimum supported size (360x640, docs/DESIGN.md Section 12 OPEN item).
## This keeps 1 logical unit approx 1 dp so the touch-target minimums
## (48 dp etc.) hold on both reference sizes named in the Phase 0 plan:
## 390x844 and 360x640. Tablet centering (DESIGN.md Section 12 rule 4)
## and safe-area application are later-phase/AppShell concerns, not this
## helper's job.
##
## Mobile density paths (docs/ARCHITECTURE.md Section 2):
## - iOS: DisplayServer.screen_get_scale() returns a dp-per-px scale factor
##   directly (e.g. 2.0 or 3.0); no division by 160 needed.
## - Android: DisplayServer.screen_get_dpi() returns physical DPI; divide by
##   160.0 (MOBILE_BASELINE_DPI) to get dp-per-px scale.
##
## Desktop is a separate case (verified during Phase 0 visual
## verification, not assumed): project.godot's `canvas_items` stretch
## mode already makes the window's own pixel size equal the configured
## viewport size (390x844) with no DPI correction needed -- the OS
## reports a desktop monitor's "no scaling" DPI as 96, which is NOT the
## same 160-per-unit baseline Android/iOS use, so running the mobile
## formula on desktop silently inflated content_scale_size to ~1.67x the
## window size and shrank every control. `OS.has_feature("pc")` tells
## these cases apart; on desktop this applies the window's own size
## directly instead.

const BASE_WIDTH := 390
const BASE_HEIGHT := 844
const MIN_WIDTH := 360
const MIN_HEIGHT := 640

## Android/CSS "1x" baseline DPI; mobile OS-reported DPI is physical and
## is divided by this to get a dp-per-px scale. Desktop DPI (commonly 96,
## "100% scaling") is a different convention and must not use this.
const MOBILE_BASELINE_DPI := 160.0

static func apply(window: Window) -> void:
	if not OS.has_feature("pc"):
		window.content_scale_size = _compute_mobile_dp_size(window)
	# Desktop: project.godot's canvas_items stretch mode already keeps
	# window.size at the configured dp size (390x844) with no further
	# scaling needed, so content_scale_size is left at its project
	# default (0,0 -> "use the viewport size") rather than recomputed.

## Pure function so it is independently testable without a live Window's
## platform-specific DisplayServer calls returning real hardware values.
## Computes dp size from a dp-per-px scale factor directly (used by both
## iOS and Android paths; see compute_fit_size_from_scale below).
static func _compute_fit_size_from_scale(window_px_size: Vector2i, scale: float) -> Vector2i:
	if scale <= 0.0:
		return Vector2i(BASE_WIDTH, BASE_HEIGHT)
	var dp_width: int = int(round(window_px_size.x / scale))
	var dp_height: int = int(round(window_px_size.y / scale))
	dp_width = maxi(dp_width, MIN_WIDTH)
	dp_height = maxi(dp_height, MIN_HEIGHT)
	return Vector2i(dp_width, dp_height)

## Pure function so it is independently testable without a live Window's
## platform-specific DisplayServer calls returning real hardware values.
## Mobile-only math: `window_px_size` is the WINDOW's own pixel size,
## which on mobile fills the whole physical screen, so it is equivalent
## to the device's screen size. For iOS, pass the scale directly from
## DisplayServer.screen_get_scale(); for Android, pass screen_dpi / 160.0.
static func compute_fit_size_from_scale(window_px_size: Vector2i, scale: float) -> Vector2i:
	return _compute_fit_size_from_scale(window_px_size, scale)

## Android DPI-based compute: divides screen_dpi by MOBILE_BASELINE_DPI
## and calls compute_fit_size_from_scale with the result.
static func compute_fit_size(window_px_size: Vector2i, screen_dpi: float) -> Vector2i:
	if screen_dpi <= 0.0:
		return Vector2i(BASE_WIDTH, BASE_HEIGHT)
	var scale: float = screen_dpi / MOBILE_BASELINE_DPI
	return _compute_fit_size_from_scale(window_px_size, scale)

static func _compute_mobile_dp_size(window: Window) -> Vector2i:
	var px_size := window.size
	if px_size.x <= 0 or px_size.y <= 0:
		# Fallback per docs/ARCHITECTURE.md Section 2: the 390-wide base.
		# Record any device family where this triggers in docs/PROGRESS.md
		# as a known issue -- do not silently switch to a different
		# approach (CLAUDE.md Section 19).
		push_warning("ScreenFit: Window did not report a usable size; falling back to the 390x844 base.")
		return Vector2i(BASE_WIDTH, BASE_HEIGHT)

	# Branch on OS to determine the density path (docs/ARCHITECTURE.md Section 2).
	if OS.get_name() == "iOS":
		# iOS: screen_get_scale() returns the dp-per-px scale factor directly
		# (e.g. 2.0 for 2x, 3.0 for 3x).
		var scale := DisplayServer.screen_get_scale(window.current_screen)
		if scale <= 0.0:
			push_warning("ScreenFit: iOS device did not report a usable scale factor; falling back to the 390x844 base.")
			return Vector2i(BASE_WIDTH, BASE_HEIGHT)
		return compute_fit_size_from_scale(px_size, scale)
	else:
		# Android and other platforms: screen_get_dpi() returns physical DPI;
		# divide by 160.0 to convert to dp-per-px scale.
		var dpi := float(DisplayServer.screen_get_dpi(window.current_screen))
		if dpi <= 0.0:
			push_warning("ScreenFit: Device did not report a usable DPI; falling back to the 390x844 base.")
			return Vector2i(BASE_WIDTH, BASE_HEIGHT)
		return compute_fit_size(px_size, dpi)
