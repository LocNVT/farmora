class_name UiTokens
extends RefCounted

## Design tokens from docs/DESIGN.md. This is the only place hex values and
## design-system sizes appear in code. Components read these constants or a
## Theme type variation; never inline a color or size.

# --- Color: primary (Leaf) ---
const COLOR_PRIMARY := Color("#26803A")
const COLOR_PRIMARY_PRESSED := Color("#1D6730")
const COLOR_PRIMARY_EDGE := Color("#1B5E2C")
const COLOR_PRIMARY_LIGHT := Color("#7BD389")
const COLOR_PRIMARY_TINT := Color("#E4F5DA")

# --- Color: secondary (Sun) and accent (Barn) ---
const COLOR_SECONDARY := Color("#FFC53D")
const COLOR_SECONDARY_EDGE := Color("#D99A0B")
const COLOR_SECONDARY_TEXT := Color("#4A2F12")
const COLOR_SECONDARY_PRESSED := Color("#F2B52A")
const COLOR_ACCENT := Color("#C94A32")
const COLOR_ACCENT_TINT := Color("#FBE3DC")
const COLOR_ACCENT_TINT_TEXT := Color("#7A2A1B")
const COLOR_ACCENT_TINT_BORDER := Color("#E8B3A6")

# --- Color: background, panel, card, text ---
const COLOR_BG := Color("#FFF6DF")
const COLOR_PANEL := Color("#FFFBEF")
const COLOR_CARD := Color("#FFFFFF")
const COLOR_INK := Color("#3B2A1A")
const COLOR_INK_SOFT := Color("#6E5A46")
const COLOR_LINE := Color("#EBDDBB")
const COLOR_TRACK := Color("#F0E5C8")
const COLOR_SELECTED_CARD_TINT := Color("#F3FAEC")
const COLOR_PRESSED_NEUTRAL := Color("#F6EED8")
const COLOR_DISABLED_FILL := Color("#E6DCC3")
const COLOR_DISABLED_EDGE := Color("#D3C7A8")
const COLOR_TOGGLE_OFF := Color("#D8CBA8")
const COLOR_GRABBER := Color("#E3D4AE")
const COLOR_SCRIM := Color(0.23137255, 0.16470589, 0.101960786, 0.45)

# --- Color: semantic ---
const COLOR_SUCCESS := Color("#26803A")
const COLOR_WARNING := Color("#E59A00")
const COLOR_ERROR := Color("#C63B32")
const COLOR_INFO := Color("#256FB8")

# --- Color: resources and status ---
const COLOR_RES_COIN := Color("#FFC53D")
const COLOR_RES_COIN_OUTLINE := Color("#C98A00")
const COLOR_RES_FEED := Color("#E0A84A")
const COLOR_RES_FEED_DISC := Color("#F3D9A0")
const COLOR_RES_FEED_OUTLINE := Color("#C99A3F")
const COLOR_RES_EGG := Color("#FFF3D6")
const COLOR_RES_EGG_OUTLINE := Color("#E9C98B")
const COLOR_RES_MILK := Color("#E6F3FF")
const COLOR_RES_MILK_OUTLINE := Color("#7DB8EA")
const COLOR_RES_PORK := Color("#F4909A")
const COLOR_RES_PORK_EDGE := Color("#E06C7A")
const COLOR_RES_XP := Color("#8A63D9")
const COLOR_RES_XP_TINT := Color("#EEE7FB")
const COLOR_RES_GEM := Color("#24B8C9") # Future / Not MVP. Defined only, never shown.
const COLOR_STAT_HEALTH := Color("#E5584F")
const COLOR_STAT_HUNGER := Color("#E2A12B")
const COLOR_STAT_HAPPINESS := Color("#F27FA5")
const COLOR_BADGE_READY_BG := Color("#E4F5DA")
const COLOR_BADGE_READY_TEXT := Color("#1D5A2C")
const COLOR_BADGE_HUNGRY_BG := Color("#FFE9A8")
const COLOR_BADGE_HUNGRY_TEXT := Color("#6B4400")

# --- Spacing scale (dp) ---
const SPACE_4 := 4
const SPACE_8 := 8
const SPACE_12 := 12
const SPACE_16 := 16
const SPACE_20 := 20
const SPACE_24 := 24
const SPACE_32 := 32
const SPACE_48 := 48

# --- Corner radius (dp) ---
const RADIUS_CHIP := 10
const RADIUS_BUTTON := 14
const RADIUS_CARD := 20
const RADIUS_MODAL := 28
const RADIUS_PILL := 999

# --- Touch targets (dp) ---
const TOUCH_MIN := 48
const BUTTON_HEIGHT := 52
const BUTTON_HEIGHT_ROW := 44
const BUTTON_HEIGHT_TILE := 48
const NAV_ITEM_HEIGHT := 56

# --- Elevation ---
const BUTTON_EDGE_DEPTH := 4
const BUTTON_EDGE_PRESSED := 1

# --- Animation timing (seconds) ---
const DUR_INSTANT := 0.08
const DUR_QUICK := 0.12
const DUR_STANDARD := 0.24
const DUR_EMPHASIS := 0.4
const DUR_CELEBRATION := 0.8
const TOAST_IN := 0.2
const TOAST_HOLD := 2.2
const TOAST_OUT := 0.16

# --- Typography sizes (sp) ---
const FONT_SIZE_DISPLAY := 36
const FONT_SIZE_TITLE := 28
const FONT_SIZE_SECTION := 20
const FONT_SIZE_BODY := 15
const FONT_SIZE_BUTTON := 16
const FONT_SIZE_NUMBER := 18
const FONT_SIZE_CAPTION := 12
