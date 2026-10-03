extends GutTest

## Keeps ui/theme/farmora_theme.tres in sync with ui/theme/ui_tokens.gd, per
## docs/ARCHITECTURE.md Section 15.5: "components never set colours inline
## ... a sync test" catches drift between the two artifacts.
##
## Phase 0 checks only the type variations Phase 0 ships (PrimaryButton,
## SecondaryButton, GhostButton, IconButton, the three Toast variations).
## Later phases add a row here per new type variation they introduce --
## do not add rows for variations that do not exist yet.

var _theme: Theme

func before_each() -> void:
	_theme = load("res://ui/theme/farmora_theme.tres")

func test_theme_resource_loads() -> void:
	assert_not_null(_theme, "farmora_theme.tres must load")

func test_primary_button_style_matches_tokens() -> void:
	var normal: StyleBoxFlat = _theme.get_stylebox("normal", "PrimaryButton")
	assert_eq(normal.bg_color, UiTokens.COLOR_PRIMARY, "PrimaryButton normal fill should be color.primary")
	assert_eq(normal.border_color, UiTokens.COLOR_PRIMARY_EDGE, "PrimaryButton edge should be color.primaryEdge")
	assert_eq(normal.border_width_bottom, UiTokens.BUTTON_EDGE_DEPTH, "Primary edge depth should match UiTokens")
	assert_eq(normal.corner_radius_top_left, UiTokens.RADIUS_BUTTON, "Button radius should match UiTokens")

func test_secondary_button_style_matches_tokens() -> void:
	var normal: StyleBoxFlat = _theme.get_stylebox("normal", "SecondaryButton")
	assert_eq(normal.bg_color, UiTokens.COLOR_SECONDARY, "SecondaryButton normal fill should be color.secondary (Sun)")
	assert_eq(normal.border_color, UiTokens.COLOR_SECONDARY_EDGE, "SecondaryButton edge should be color.secondaryEdge")

func test_ghost_button_style_matches_tokens() -> void:
	var normal: StyleBoxFlat = _theme.get_stylebox("normal", "GhostButton")
	assert_eq(normal.bg_color, Color.WHITE, "GhostButton fill should be white")
	assert_eq(normal.border_color, UiTokens.COLOR_LINE, "GhostButton border should be color.line")

func test_icon_button_style_matches_tokens() -> void:
	var normal: StyleBoxFlat = _theme.get_stylebox("normal", "IconButton")
	assert_eq(normal.bg_color, UiTokens.COLOR_PANEL, "IconButton fill should be color.panel")
	assert_eq(normal.border_color, UiTokens.COLOR_LINE, "IconButton border should be color.line")

func test_toast_styles_match_semantic_colors() -> void:
	# Label has no stylebox theme item in Godot 4, so the toast "pill"
	# background lives on its own PanelContainer-type variation, separate
	# from the Label's font-color variation (a variation name is unique
	# per Theme regardless of base type, so "ToastSuccess" cannot serve
	# both a Label and a PanelContainer at once -- see farmora_theme.tres).
	var success: StyleBoxFlat = _theme.get_stylebox("panel", "ToastSuccessPanel")
	var problem: StyleBoxFlat = _theme.get_stylebox("panel", "ToastProblemPanel")
	var info: StyleBoxFlat = _theme.get_stylebox("panel", "ToastInfoPanel")
	assert_eq(success.bg_color, UiTokens.COLOR_SUCCESS, "ToastSuccessPanel should use color.success")
	assert_eq(problem.bg_color, UiTokens.COLOR_ACCENT_TINT, "ToastProblemPanel should use Barn tint, never red fill")
	assert_eq(info.bg_color, UiTokens.COLOR_INFO, "ToastInfoPanel should use color.info")

func test_toast_problem_text_color_matches_tokens() -> void:
	var color: Color = _theme.get_color("font_color", "ToastProblemLabel")
	assert_eq(color, UiTokens.COLOR_ACCENT_TINT_TEXT, "ToastProblemLabel text should use the Barn-tint ink color, never pure red")
