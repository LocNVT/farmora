# Farmora: Architecture

> **Status:** Approved for implementation, MVP v1.0. Read this before writing any code. Code is not written yet.
> **Companion docs (higher priority, per CLAUDE.md Section 3):** `docs/GDD.md` (rules and numbers), `docs/DESIGN.md` (visual tokens), `docs/UI_SPEC.md` (screens and components).
> **Engine:** Godot 4.x (latest stable 4.x when the project is created; record the exact version in `docs/PROGRESS.md`). GDScript only. 2D. Portrait. Android and iOS. Local JSON save. No network.
> **Conventions used in this file**
> - `res://...` paths and class, file, signal and key names are **binding**. Follow them exactly. If one turns out to be wrong in practice, change it here first, then in code.
> - `OPEN (design)` means the GDD, DESIGN or UI_SPEC marked the rule `OPEN`. This architecture does **not** decide it. It shows the one place in code where the decision lives. That place is built with the design doc's recommended default, and the default is listed in `docs/PROGRESS.md` as waiting for the owner to confirm.
> - `OPEN (arch)` means the design docs are silent or ambiguous on something this architecture has to handle. The same handling applies.
> - Anything marked **Future / Not MVP** must not be built.

---

## 1. Principles

Every rule below comes from CLAUDE.md or the GDD. Nothing here exists only "for flexibility".

1. **Static definitions and runtime state are separate (CLAUDE.md §7).** Definitions are read-only objects built from `res://data/balance.json`. Runtime state is plain data objects that serialize to the save JSON. State refers to definitions by **string id**, never by object reference.
2. **All game time is wall-clock based (CLAUDE.md §8).** Persistent progress (hunger, happiness, production, offline) only advances through `ProductionRules.advance_animal(animal, elapsed_seconds, ...)`, and the elapsed seconds always come from two clock readings. `_process(delta)` and frame counts are used **only for visuals** (wandering, tweens, bobbing). They never write to game state.
3. **One simulation code path.** Online ticks, resume-from-background and launch-after-days all call the same `Game._advance_to(now_ms)` function. Offline progression is not a separate algorithm (GDD §9 rule 3).
4. **Balance is data (GDD §7 "Balance data file").** Every number marked *(placeholder)* in the GDD lives in `res://data/balance.json`. Code never hard-codes prices, cycle times, capacities, thresholds or caps.
5. **Rules are pure functions.** All game math is in `static func`s that take state, definitions and parameters as arguments. They read no autoloads, no clock and no nodes. This is what makes CLAUDE.md §11's minimum test list cheap to write.
6. **UI depends on the domain, never the reverse.** Domain code never imports UI or scene code.
7. **Small and Godot-native.** Four autoloads, scenes, signals, one Theme resource, one JSON data file, GUT for tests. No ECS, no DI container, no database, no plugin system, no networking.

---

## 2. Godot project configuration

Set these in `project.godot` during Phase 0.

| Setting | Value | Why |
|---|---|---|
| `application/config/name` | `Farmora` | |
| `application/run/main_scene` | `res://scenes/main/main.tscn` | Single root scene (Section 4) |
| `display/window/size/viewport_width` / `viewport_height` | `390` / `844` | DESIGN §11 reference frame. 1 unit = 1 dp at the reference size |
| `display/window/stretch/mode` | `canvas_items` | Crisp UI and text at every density |
| `display/window/stretch/aspect` | `expand` | Taller screens get more height, wider screens get more width (DESIGN §12 rule 2 and rule 4) |
| `display/window/handheld/orientation` | Portrait | DESIGN §12 rule 1 |
| `rendering/renderer/rendering_method` (and `.mobile`) | `gl_compatibility` | 2D only. Widest Android device support and lowest overhead on mid-range phones (DESIGN §9 rule 2: 60 fps on a three-year-old phone) |
| `application/config/quit_on_go_back` | `false` | Android back is handled by `Nav` (UI_SPEC §2 back table) |
| `input_devices/pointing/emulate_touch_from_mouse` | `true` | Desktop testing uses the touch code path |
| `gui/theme/custom` | `res://ui/theme/farmora_theme.tres` | Section 15 |
| `debug/gdscript/warnings/untyped_declaration` | `Error` | Static typing is required (Section 6) |
| `debug/gdscript/warnings/exclude_addons` | `true` | Typing rule does not apply to GUT |
| `internationalization/locale/translations` | `res://data/i18n/strings.en.translation` (generated from the CSV) | Section 15.6 |

**Density fit (`res://scenes/main/screen_fit.gd`, class `ScreenFit`).** DESIGN §12 requires the touch minimums (48 dp targets, 52 dp buttons, 64 dp animals) to hold on every reference device, down to 360 x 640 dp. With a fixed 390 x 844 base, `expand` would shrink 16:9 phones by about 24%, breaking those minimums. So at startup `ScreenFit.apply(window)` works out the device size in dp (iOS: `DisplayServer.screen_get_scale()`; Android: `DisplayServer.screen_get_dpi() / 160.0`; fallback: window width / 390). It then sets `window.content_scale_size` to that dp size, clamped to at least 360 x 640. The result is 1 logical unit ≈ 1 dp on every phone. On tablets, `AppShell` centres a game column at most 480 dp wide (DESIGN §12 rule 4). Build this in Phase 0. Verify it on real devices in Phase 10. If density detection proves unreliable on a device family, the fallback is the 390-wide base. Record that in `docs/PROGRESS.md` as a known issue. Do not silently switch to a different approach.

**Safe areas.** `AppShell` reads `DisplayServer.get_display_safe_area()` on start and on `size_changed`, converts it into logical units, and applies it as top and bottom margins: the HUD starts below the top inset + 14 dp, and the nav is 72 dp + the bottom inset (DESIGN §11).

---

## 3. Folder structure

```
res://
├── project.godot
├── addons/
│   └── gut/                          GUT test framework. Dev only, excluded from export presets
├── autoload/                         The only global singletons (Section 13)
│   ├── game.gd                       Game: owns state + catalog, simulation tick, commands, domain signals
│   ├── save_service.gd               SaveService: load, atomic save, autosave debounce, retries
│   ├── nav.gd                        Nav: tabs, overlay stack, Android back, toasts, banner
│   └── audio_service.gd              AudioService: sfx, music, haptics; respects settings
├── data/
│   ├── balance.json                  ALL tunable numbers + definition data (Section 7)
│   └── i18n/
│       └── strings.csv               All player-facing copy, keyed (English column in MVP)
├── scripts/                          Pure logic only. No Node scripts in here. Everything has class_name
│   ├── core/
│   │   ├── game_clock.gd             GameClock: wall-clock (UTC ms) + monotonic ms; fakeable in tests
│   │   ├── action_guard.gd           ActionGuard: 300 ms commit lock / debounce
│   │   ├── action_result.gd          ActionResult: OK or a reason code (+ missing amount)
│   │   └── number_format.gd          NumberFormat: thousands separators (GDD §7)
│   ├── definitions/
│   │   ├── game_catalog.gd           GameCatalog: parses balance.json, validates, exposes lookups
│   │   ├── animal_definition.gd      AnimalDefinition
│   │   ├── product_definition.gd     ProductDefinition
│   │   ├── building_definition.gd    BuildingDefinition
│   │   └── upgrade_definition.gd     UpgradeDefinition (one building level)
│   ├── state/
│   │   ├── game_state.gd             GameState (root of everything saved)
│   │   ├── player_state.gd           PlayerState  <-> save "wallet"
│   │   ├── inventory_state.gd        InventoryState <-> save "bag"
│   │   ├── farm_state.gd             FarmState   <-> save "buildings" + "animals"
│   │   ├── animal_instance.gd        AnimalInstance
│   │   ├── building_instance.gd      BuildingInstance
│   │   └── settings_state.gd         SettingsState <-> save "settings"
│   ├── rules/
│   │   ├── production_rules.gd       Time-based hunger/happiness/progress (the only simulation math)
│   │   ├── feeding_rules.gd          Can-feed checks, meal effects
│   │   ├── status_rules.gd           Derived status flags + which bubble shows
│   │   ├── economy_rules.gd          Prices, sale totals, market bonus, feed packs, affordability
│   │   ├── building_rules.gd         Capacity, upgrade cost/eligibility, level effects
│   │   ├── progression_rules.gd      XP and level, unlocks
│   │   ├── offline_rules.gd          Elapsed-time clamp, modal threshold, OfflineReport
│   │   └── tutorial_rules.gd         Step constants, boost window, skip grant
│   └── save/
│       ├── save_codec.gd             GameState <-> Dictionary, validation, unknown-field preservation
│       ├── save_migrator.gd          version N -> N+1 dictionary migrations
│       └── save_file_io.gd           Atomic temp-then-rename write, backup, read
├── scenes/                           Node scenes for the game world + the root
│   ├── main/
│   │   ├── main.tscn / main.gd       Root: boot sequence, app lifecycle notifications
│   │   └── screen_fit.gd             ScreenFit (Section 2)
│   └── farm/
│       ├── farm_world.tscn / .gd     FarmWorld: layered scene, spawns views from state
│       ├── farm_camera.gd            FarmCamera: pan/inertia/rubber-band/zoom
│       ├── farm_input.gd             FarmInput: tap vs drag, hit-testing, pinch
│       ├── ambient_budget.gd         AmbientBudget: max 2 ambient animations (Phase 9)
│       ├── buildings/
│       │   ├── building_view.tscn / .gd           Base building view
│       │   └── <building_id>_view.tscn            One inherited scene per building id
│       ├── animals/
│       │   ├── animal_view.tscn / .gd             Base animal view
│       │   └── <species_id>_view.tscn             One inherited scene per species id
│       └── world_ui/                              World-space indicators (DESIGN §11 overlays)
│           ├── status_bubble.tscn / .gd
│           ├── building_tag.tscn / .gd
│           ├── upgrade_badge.tscn / .gd
│           └── floater.tscn / .gd                 "+1 Egg" rising text
├── ui/                               Screen-space UI (Controls)
│   ├── theme/
│   │   ├── farmora_theme.tres        The Theme: fonts, styleboxes, type variations
│   │   ├── ui_tokens.gd              UiTokens: DESIGN.md tokens as constants
│   │   └── motion.gd                 Motion: duration/easing helpers + reduced-motion switch
│   ├── components/                   Reusable widgets, one folder each (Section 15.4)
│   ├── shell/
│   │   ├── app_shell.tscn / .gd      AppShell: layer layout, safe areas, tablet column
│   │   ├── overlay.gd                Overlay: base class for sheets, pushed screens, modals
│   │   ├── hud.tscn / .gd
│   │   ├── bottom_nav.tscn / .gd
│   │   ├── toast_host.tscn / .gd
│   │   └── banner_host.tscn / .gd
│   ├── screens/                      Root and pushed screens, one folder each
│   │   ├── splash/  main_menu/  farm_screen/  animals_tab/  market/  bag/
│   │   └── animal_details/  building_details/  settings/
│   ├── overlays/                     Sheets and modals, one folder each
│   │   ├── animal_sheet/  buy_animal_dialog/  upgrade_dialog/  offline_reward_modal/
│   │   └── rename_dialog/  confirm_dialog/  meet_animal_card/
│   ├── tutorial/
│   │   ├── tutorial_overlay.tscn / .gd   Scrim + spotlight + tooltip card + Skip
│   │   └── tutorial_controller.gd        Advances steps from Game signals
│   ├── ui_scenes.gd                  UiScenes: preload registry of screen/overlay scenes
│   └── result_messages.gd            ResultMessages: ActionResult code -> approved copy key
├── assets/
│   ├── fonts/                        Fredoka 600/700, Nunito 600/700 + OFL license files
│   ├── icons/                        23 approved glyphs (Section 15.5)
│   ├── art/
│   │   ├── animals/  buildings/  world/  fx/
│   ├── audio/
│   │   ├── sfx/  music/
│   └── placeholder/                  TEMPORARY art only. Nothing final lives here (CLAUDE.md §10)
└── tests/
    ├── fixtures/
    │   ├── balance_fixture.json      Frozen balance for tests (independent of tuning)
    │   └── saves/                    v1_valid.json, v1_unknown_fields.json, damaged_*.json ...
    ├── helpers/
    │   ├── fake_clock.gd             FakeClock extends GameClock
    │   ├── failing_save_file_io.gd   FailingSaveFileIO extends SaveFileIO
    │   └── state_factory.gd          StateFactory: builds GameStates for tests
    ├── unit/                         test_*.gd for rules, codec, catalog
    └── integration/                  test_*.gd for Game commands, SaveService + file IO
```

**Why this split**
- `scripts/` holds **non-Node logic**: definitions, state, rules, save. This is the code CLAUDE.md §11 requires tests for. Keeping it out of the scene folders means a test can load all of it without touching a scene.
- `scenes/` holds the **game world** (Node2D). `ui/` holds the **screen-space UI** (Control). They are separate because they use different coordinate spaces, input paths and owners (DESIGN §11: world-space versus screen-space overlays).
- **A Node script lives next to its `.tscn`** (Godot convention). One feature folder holds everything for that feature.
- `assets/placeholder/` keeps temporary art physically separate, so finished art can be checked by searching for `res://assets/placeholder/` references.

---

## 4. Scene structure

### 4.1 One root scene

The game runs in a **single persistent scene tree**. There are no `change_scene_to_*` calls. Screens are instanced into hosts inside `AppShell`. This keeps the farm world, the overlay stack and the simulation alive across tabs, which UI_SPEC requires: the farm stays visible under sheets; Animals-list actions jump the camera to an animal on the farm.

```
Main (Node)                                   scenes/main/main.gd
├── FarmWorld (Node2D)                        scenes/farm/farm_world.tscn
│   ├── FarmCamera (Camera2D)
│   ├── Backdrop (Node2D)                     sky, meadow, soil, clouds (parallax layers)
│   ├── BuildingSlots (Node2D)                one Marker2D per building id (fixed layout)
│   ├── Buildings (Node2D, y_sort_enabled)    BuildingView instances spawned from state
│   ├── Animals (Node2D, y_sort_enabled)      AnimalView instances spawned from state
│   ├── WorldUi (Node2D)                      tags, bubbles, badges, floaters (drawn above sprites)
│   └── FarmInput (Node)                      handles _unhandled_input for the world
└── UiLayer (CanvasLayer, layer = 10)
    └── AppShell (Control, full rect)         ui/shell/app_shell.tscn
        ├── RootHost (Control)                Splash | MainMenu | TabHost (one visible)
        │   └── TabHost (Control)             4 tab roots, pre-instanced, visibility-toggled
        │       ├── FarmScreen                transparent; Collect-all, empty-state hint
        │       ├── AnimalsTab
        │       ├── MarketScreen
        │       └── BagScreen
        ├── Hud                               shared, visible in game mode
        ├── BannerHost                        save-error banner, sits under the HUD
        ├── BottomNav
        ├── OverlayHost (Control)             the overlay stack (sheets, pushed screens, modals)
        ├── ToastHost                         one toast at a time, 16 dp above the nav
        └── TutorialOverlay                   topmost; scrim + spotlight + tooltip
```

**AppShell modes.** `AppShell.set_mode(mode)` where `enum Mode { BOOT, MENU, GAME }`:
- `BOOT`: Splash only.
- `MENU`: Main Menu only; HUD, nav and world hidden.
- `GAME`: TabHost + HUD + nav + world.

**Tab roots** are instanced once when entering `GAME` and only shown or hidden. This keeps scroll position and segment selection, and costs little at this scale. When the Farm tab is not selected, the Animals, Market and Bag screens draw an opaque cream background (`color.bg`). `FarmWorld` is then hidden and its ambient animation paused. **The simulation is not paused** (it does not live in the world, see Section 8).

### 4.2 Overlay stack (UI_SPEC §2, DESIGN §11 "Overlays form a stack")

Everything that opens on top of a tab root is an `Overlay` in **one** stack in `OverlayHost`. The order in the stack is the z-order. Back handling pops the top one.

```gdscript
# ui/shell/overlay.gd
class_name Overlay
extends Control

enum Kind { SHEET, SCREEN, MODAL, BLOCKING_MODAL }

signal closed(overlay: Overlay)

@export var kind: Kind = Kind.MODAL
@export var covers_world: bool = false   # true for pushed screens; pauses farm ambient (DESIGN §9 rule 3)

func open(args: Dictionary) -> void: pass          # populate from args; play enter animation
func on_back() -> bool:                            # return true if the back press was consumed
    request_close()
    return true
func request_close() -> void: ...                  # plays exit animation, then emits closed
```

| UI_SPEC item | Overlay kind | Scene |
|---|---|---|
| Animal Interaction (4) | `SHEET` | `ui/overlays/animal_sheet/animal_sheet.tscn` |
| Animal Details (7) | `SCREEN` | `ui/screens/animal_details/animal_details.tscn` |
| Building Details (8) | `SCREEN` | `ui/screens/building_details/building_details.tscn` |
| Settings (12) | `SCREEN` | `ui/screens/settings/settings.tscn` |
| Upgrade Dialog (9) | `MODAL` | `ui/overlays/upgrade_dialog/upgrade_dialog.tscn` |
| Buy Animal Dialog (10) | `MODAL` | `ui/overlays/buy_animal_dialog/buy_animal_dialog.tscn` |
| Rename dialog (OPEN, UI_SPEC §5) | `MODAL` | `ui/overlays/rename_dialog/rename_dialog.tscn` |
| Start new farm confirm (12.3) | `MODAL` | `ui/overlays/confirm_dialog/confirm_dialog.tscn` (generic confirm) |
| "Meet Pip" card (12.1) | `MODAL` | `ui/overlays/meet_animal_card/meet_animal_card.tscn` |
| Offline Reward (11) | `BLOCKING_MODAL` | `ui/overlays/offline_reward_modal/offline_reward_modal.tscn` |

Kind behaviour:
- `SHEET`: anchored above the nav (8 dp margins). Only the panel stops input. The rest of the overlay uses `mouse_filter = IGNORE` so the world, HUD and nav stay tappable (UI_SPEC §4 "World above stays interactive").
- `SCREEN`: full screen, opaque, covers the HUD and nav, slides in from the right in 240 ms.
- `MODAL`: scrim (`color.scrim`) plus a centred panel. A scrim tap or back press cancels.
- `BLOCKING_MODAL`: scrim taps are ignored. `on_back()` runs the modal's single action (Offline Reward: back = Collect, UI_SPEC §2).

**Tutorial is not in the stack.** It is a separate top layer with its own back rule ("ignored except on the final card"). `Nav.handle_back()` asks the tutorial first (Section 15.3).

### 4.3 Scene ownership summary

| Scene | Owner | Created | Freed |
|---|---|---|---|
| `main.tscn` | engine | launch | never |
| `farm_world.tscn` | `Main` | launch (hidden until GAME) | never |
| Building and animal views | `FarmWorld` | on `Game.state_loaded`, `Game.animal_added` | on reload |
| Splash, Main Menu | `AppShell` | on mode change | on mode change |
| Tab roots | `AppShell` | first entry into GAME | never |
| Overlays | `Nav` via `AppShell.OverlayHost` | on open | on close |

---

## 5. Layering and dependency direction

```
        data/balance.json
              │ parsed by
              ▼
   ┌─────────────────────┐
   │ definitions/        │  read-only; depends on nothing else in the project
   └─────────────────────┘
              ▲ (looked up by id)
   ┌─────────────────────┐
   │ state/              │  plain data + to_dict/from_dict; depends on nothing but core types
   └─────────────────────┘
              ▲
   ┌─────────────────────┐
   │ rules/   save/codec │  pure static functions over (state, definitions, params)
   └─────────────────────┘
              ▲
   ┌─────────────────────┐
   │ autoload/ Game,     │  orchestration: owns state, runs rules, emits signals,
   │ SaveService         │  performs IO. No UI knowledge.
   └─────────────────────┘
              ▲
   ┌─────────────────────┐
   │ scenes/farm, ui/,   │  presentation: reads state, calls Game commands,
   │ Nav, AudioService   │  listens to signals
   └─────────────────────┘
```

**Allowed dependencies (arrow = "may reference")**

| From | May reference | Must NOT reference |
|---|---|---|
| `scripts/definitions` | core types | state, rules, autoloads, nodes |
| `scripts/state` | core types, `scripts/core` | definitions (except ids as `String`), rules, autoloads, nodes |
| `scripts/rules` | definitions, state, `scripts/core` | autoloads, nodes, `Time`/clock, `FileAccess` |
| `scripts/save` | state, definitions (for validation), `scripts/core` | autoloads, nodes, UI |
| `autoload/game.gd` | everything in `scripts/`, `SaveService` | `Nav`, `AudioService`, anything in `ui/` or `scenes/` |
| `autoload/save_service.gd` | `scripts/save`, `scripts/core` | `Game` (it gets data through a `Callable`, Section 11.6), UI |
| `autoload/nav.gd`, `audio_service.gd` | `Game` (read only + signals), `ui/` | rules that mutate state |
| `scenes/`, `ui/` | `Game` (read state, call commands, connect signals), `Nav`, `AudioService`, definitions | mutating state directly; `SaveService` (except Settings > Save now and the banner's "Try now", which call `SaveService` directly) |

**Concrete enforcement of CLAUDE.md §7**
- `AnimalInstance` holds `species: String`, not an `AnimalDefinition`. To get the cycle time, code calls `Game.catalog.animal(animal.species).cycle_seconds`.
- Definitions have no setters used at runtime. `GameCatalog` builds them once and never changes them.
- **UI never assigns to state fields.** `ui/` and `scenes/` call `Game.feed_animal(id)` and similar methods. A code review rule: no `Game.state.` on the left side of `=` outside `autoload/game.gd`.

---

## 6. Script organization and GDScript conventions

### 6.1 Where code goes

| Kind of code | Location | Base class |
|---|---|---|
| Definitions | `scripts/definitions/` | `RefCounted` |
| Runtime state | `scripts/state/` | `RefCounted` |
| Game rules (math) | `scripts/rules/` | `RefCounted` with only `static func` and `const` |
| Save encoding and IO | `scripts/save/` | `RefCounted` |
| Global orchestration | `autoload/` | `Node` |
| World presentation | `scenes/farm/**` next to its `.tscn` | `Node2D` / `Camera2D` / `Node` |
| UI presentation | `ui/**` next to its `.tscn` | `Control` subclasses |

Business logic (anything that decides whether something is allowed or how much) **must not** be in a Node script under `scenes/` or `ui/`. A UI script asks a rule ("can I afford this?") to decide whether a button is disabled. It never does the arithmetic itself.

### 6.2 Static typing (required)

- Every variable, parameter and return value is typed: `var coins: int = 0`, `func sale_total(unit_price: int, qty: int, bonus_percent: float) -> int:`. Inference with `:=` is allowed when the type is obvious from the right-hand side.
- Typed arrays everywhere: `var animals: Array[AnimalInstance] = []`.
- `Dictionary` is used only (a) at the JSON boundary (`to_dict`/`from_dict`, catalog parsing), and (b) for maps keyed by id (`InventoryState.quantities: Dictionary  # String -> int`). Comment the key and value types. Typed dictionaries (`Dictionary[String, int]`) may be used only if the pinned Godot version is 4.4 or later.
- **All ids are `String`** (species, product, building, animal ids). Do not mix `StringName` and `String` keys in dictionaries.
- Every script that other code references gets a `class_name`. Autoload scripts **do not** declare `class_name`, so they cannot clash with the autoload name.
- Enums are declared inside the class that owns them (`ActionResult.Code.NOT_ENOUGH_COINS`, `Overlay.Kind.SHEET`).

### 6.3 Script layout order

Follow the Godot style guide: `class_name` and `extends`, doc comment, signals, enums, constants, `@export` vars, public vars, private vars (`_name`), `@onready` vars, built-in virtuals (`_ready`, `_process`...), public methods, private methods.

---

## 7. Static data definitions

### 7.1 Format decision: one JSON file, parsed into typed objects

`res://data/balance.json` is the **single** source for every *(placeholder)* number in the GDD and for the definition data (ids, product mapping, housing, kinds). `GameCatalog` parses it into typed `RefCounted` definition objects at startup.

- **Why JSON, not `.tres` Resources:** the GDD requires "one data file" that is tunable without code changes. One JSON file can be edited, diffed and reviewed in one place, outside the Godot editor too, and it matches the `balance` block shape the design delivered in `tokens.json`. When that file is supplied, reconcile key names with Section 7.3 and update this document.
- **Why parse into typed objects instead of passing Dictionaries around:** typing catches mistakes at parse time, and rules get autocomplete. Parsing happens once.
- **Presentation-only data is not in the balance file.** Sprite size, tap-zone size and walk speed (GDD §4 table, not marked placeholder) are `@export` values on each species' view scene `res://scenes/farm/animals/<species_id>_view.tscn`. Views are found **by naming convention** from the id, so adding a species means adding a JSON entry and a scene, with no code change.

### 7.2 Definition classes

```gdscript
class_name ProductDefinition extends RefCounted
var id: String                 # "egg"
var sell_price: int            # coins per item, before Market bonus (GDD §5)

class_name AnimalDefinition extends RefCounted
var id: String                 # "chicken"
var product_id: String         # "egg"
var price: int                 # coins
var unlock_level: int
var housing_building_id: String   # "chicken_coop"
var cycle_seconds: float       # base cycle at 100% speed, fed (GDD §4: minutes * 60)
var default_names: Array[String]  # OPEN (design): name pool

class_name UpgradeDefinition extends RefCounted   # one level of one building
var level: int                 # 1..3
var cost: int                  # coins to reach this level from level-1 (0 for level 1)
var capacity: int              # housing kind only; 0 otherwise
var production_multiplier: float  # housing kind only (1.0 / 1.25 / 1.5); 1.0 otherwise
var feed_capacity: int         # feed_storage kind only; 0 otherwise
var sell_bonus_percent: float  # market kind only (0 / 5 / 10); 0 otherwise

class_name BuildingDefinition extends RefCounted
enum Kind { HOUSING, FEED_STORAGE, MARKET }
var id: String                 # "chicken_coop"
var kind: Kind
var starts_built: bool         # OPEN (design) GDD §6 starting state; default true for all five
var levels: Array[UpgradeDefinition]   # index 0 = level 1
func max_level() -> int: return levels.size()
func level_def(level: int) -> UpgradeDefinition: return levels[level - 1]
```

`UpgradeDefinition` (named in CLAUDE.md §7) is **one level row of a building**: what it costs to reach and what it does. Using one class for all three building kinds keeps the data flat. Fields that do not apply to a kind stay at their neutral value. `BuildingRules` reads only the field for the building's `kind`.

`GameCatalog` also holds the **global balance parameters** (feeding, status thresholds, offline cap, tutorial boost, XP tables) as typed fields grouped in small inner classes (`FeedingParams`, `StatusParams`, `OfflineParams`, `TutorialParams`, `ProgressionParams`, `HappinessParams`, `EconomyParams`, `StartParams`).

```gdscript
class_name GameCatalog extends RefCounted
static func load_from_file(path: String) -> GameCatalog      # asserts/returns null on error
static func from_dict(data: Dictionary) -> GameCatalog
func validate() -> PackedStringArray                         # human-readable problems; empty = OK
func animal(id: String) -> AnimalDefinition
func product(id: String) -> ProductDefinition
func building(id: String) -> BuildingDefinition
func animal_ids() -> Array[String]      # in file order; drives Market rows, filter chips
func product_ids() -> Array[String]
func building_ids() -> Array[String]
func building_of_kind(kind: BuildingDefinition.Kind) -> BuildingDefinition   # feed storage, market
```

`validate()` checks: every animal's `product_id` and `housing_building_id` exist; every building has at least one level; level costs are non-negative; exactly one `FEED_STORAGE` and one `MARKET` building; no duplicate ids. A failure in debug builds stops with `assert`. Release builds cannot hit this because `test_balance_data.gd` runs the same check on the shipped file.

### 7.3 `balance.json` shape (v1)

Values are copied from the GDD. Keys marked `OPEN` hold the GDD's recommended default, or an **inert** value (one that has no gameplay effect) where the GDD gives no number. Inert values must be replaced by the owner before the phase that uses them (Section 23).

```json
{
  "schema": 1,
  "start": { "coins": 150, "feed": 5, "xp": 0, "level": 1 },
  "newAnimal": { "hunger": 0, "happiness": 100, "health": 100 },
  "feeding": { "feedPerMeal": 1, "hungerPerMeal": 50, "hungerDecayPerMinute": 1.0, "debounceMs": 300, "blockWhenFull": true },
  "happiness": { "gainOnFeed": 0, "gainOnCollect": 0, "decayPerMinute": 0 },
  "status": { "hungryBelow": 30, "lowHappinessBelow": 30, "lowBarBelowPercent": 30 },
  "production": { "pauseWhenReady": true },
  "economy": { "purchaseLockMs": 300, "feedPack": { "feed": 10, "price": 25 }, "refuseOverflowingFeedPack": true },
  "offline": { "capHours": 8, "rewardModalMinMinutes": 5 },
  "tutorial": { "boostSpecies": "chicken", "firstEggSeconds": 20, "skipGrantCoins": 150 },
  "progression": { "xpPerEvent": { "collect": 0, "buyAnimal": 0, "upgrade": 0 }, "xpToReachLevel": [0, 0, 0, 0, 0] },
  "names": { "maxLength": 12 },
  "products": {
    "egg":  { "sellPrice": 5 },
    "milk": { "sellPrice": 12 },
    "pork": { "sellPrice": 30 }
  },
  "animals": {
    "chicken": { "product": "egg",  "price": 100,  "unlockLevel": 1, "housing": "chicken_coop", "cycleMinutes": 3,  "defaultNames": ["Mimi", "Pip"] },
    "pig":     { "product": "pork", "price": 600,  "unlockLevel": 3, "housing": "pig_pen",      "cycleMinutes": 10, "defaultNames": [] },
    "cow":     { "product": "milk", "price": 1500, "unlockLevel": 5, "housing": "cow_barn",     "cycleMinutes": 6,  "defaultNames": [] }
  },
  "buildings": {
    "chicken_coop": { "kind": "housing", "startsBuilt": true, "levels": [
      { "cost": 0, "capacity": 4, "productionMultiplier": 1.0 },
      { "cost": 500, "capacity": 8, "productionMultiplier": 1.25 },
      { "cost": 1500, "capacity": 12, "productionMultiplier": 1.5 } ] },
    "cow_barn": { "kind": "housing", "startsBuilt": true, "levels": [
      { "cost": 0, "capacity": 2, "productionMultiplier": 1.0 },
      { "cost": 1200, "capacity": 4, "productionMultiplier": 1.25 },
      { "cost": 3500, "capacity": 6, "productionMultiplier": 1.5 } ] },
    "pig_pen": { "kind": "housing", "startsBuilt": true, "levels": [
      { "cost": 0, "capacity": 3, "productionMultiplier": 1.0 },
      { "cost": 800, "capacity": 6, "productionMultiplier": 1.25 },
      { "cost": 2400, "capacity": 9, "productionMultiplier": 1.5 } ] },
    "feed_storage": { "kind": "feed_storage", "startsBuilt": true, "levels": [
      { "cost": 0, "feedCapacity": 100 },
      { "cost": 300, "feedCapacity": 250 },
      { "cost": 900, "feedCapacity": 500 } ] },
    "market": { "kind": "market", "startsBuilt": true, "levels": [
      { "cost": 0, "sellBonusPercent": 0 },
      { "cost": 400, "sellBonusPercent": 5 },
      { "cost": 1200, "sellBonusPercent": 10 } ] }
  }
}
```

Notes on specific keys:
- `newAnimal.hunger = 0`: GDD §2 says a bought animal "starts hungry". 0 is the direct reading. `newAnimal.happiness = 100` is inert, because GDD §4 gives no starting happiness (OPEN, design).
- `happiness.*` = 0 and `progression.*` = 0 are **inert**. GDD §4 and §8 explicitly say these numbers must be defined in the balance file before building. With zeros, happiness never changes and XP never grows, so the player stays at level 1. See Section 23 for the impact on Phase 5.
- `feeding.blockWhenFull`, `production.pauseWhenReady` and `economy.refuseOverflowingFeedPack` are switches for OPEN (design) rules. Each defaults to the design doc's recommended behaviour, and each is read in exactly one rule function (Section 23).
- `status.lowBarBelowPercent` (the amber status bar, fixed by design) and `status.hungryBelow` / `lowHappinessBelow` (bubble thresholds, OPEN) are separate keys on purpose. The OPEN thresholds can change without touching the approved bar rule.

### 7.4 Loading

`Game._ready()` calls `GameCatalog.load_from_file("res://data/balance.json")`. The catalog is available as `Game.catalog` from then on. Tests build catalogs from `res://tests/fixtures/balance_fixture.json`, so **tuning `balance.json` never breaks unit tests**.

---

## 8. Runtime state

### 8.1 Classes and mapping to the save (GDD §9)

| Class | Save key | Fields (GDScript) ↔ JSON |
|---|---|---|
| `GameState` | root | `last_seen_ms: int` ↔ `lastSeen`; `tutorial_step: int` ↔ `tutorialStep`; `player`, `inventory`, `farm`, `settings`; `extra: Dictionary` (unknown root keys). `version` is handled by `SaveCodec` and is not stored on state |
| `PlayerState` | `wallet` | `coins: int`, `feed: int`, `xp: int`, `level: int`, `extra` |
| `InventoryState` | `bag` | `quantities: Dictionary` (product id → int). Written with one key per catalog product, zero included (`{"egg":0,"milk":0,"pork":0}`). Unknown product keys are kept as they are |
| `FarmState` | `buildings`, `animals` | `buildings: Array[BuildingInstance]`, `animals: Array[AnimalInstance]`, `unrecognized_buildings: Array[Dictionary]`, `unrecognized_animals: Array[Dictionary]` (entries whose id or species is not in the catalog: kept and written back, never simulated or shown) |
| `BuildingInstance` | `buildings[]` | `id: String`, `level: int`, `extra` |
| `AnimalInstance` | `animals[]` | `id`, `species`, `name`, `building_id` ↔ `buildingId`, `hunger: float`, `happiness: float`, `health: float`, `progress: float`, `extra` |
| `SettingsState` | `settings` | `sound: bool`, `music: bool`, `vibration: bool`, `reminders: bool` (default `false`), `language: String`, `extra` |

- **`extra`** on every state object holds JSON keys that object did not recognize. `to_dict()` writes them back unchanged. This is how GDD §9/§10 "preserve unknown fields (future traits, rarity)" is met without knowing those fields now.
- **`language`** is not in the GDD §9 save sketch, but GDD §3 and UI_SPEC §18.4 list Language as an MVP setting. It is added as an additive field. See Section 24.
- **Not saved (presentation or session only):** animal positions (views re-roll them inside their building area on load), camera zoom (DESIGN §11: "Zoom is not saved"), the Bag tab "newly collected" badge count, selected tab, open overlays.
- **Building ids are the definition ids** in the MVP (one building per definition: `"chicken_coop"`...). An animal's `building_id` points at a `BuildingInstance.id`. Extension hook, not built: if more than one building of a kind is ever allowed, `BuildingInstance` gets an additive `type` field that defaults to `id` when missing.
- **Animal ids** are generated as `"a_%d_%04x" % [now_ms, rng.randi() & 0xFFFF]`. They are unique without a saved counter.

### 8.2 Snapshot semantics (key invariant)

> **The animal fields in `GameState` are valid as of `GameState.last_seen_ms`.**

- `Game` keeps `state.last_seen_ms` equal to the time the simulation was last advanced to.
- Before any command mutates state, and before every save, `Game` calls `_advance_to(clock.now_ms())`. That keeps state and `lastSeen` consistent.
- So a save always pairs a state with the moment it describes. On load, advancing from `lastSeen` to now **is** the offline simulation, with no special case. GDD §9 rule 8 (update `lastSeen` on every save, on backgrounding and on Save now) follows directly from this.

### 8.3 `to_dict` / `from_dict`

Every state class implements:

```gdscript
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> <Class>   # tolerant: missing keys -> defaults; unknown keys -> extra
```

Validation (types, ranges, structure) is **not** in these methods. It lives in `SaveCodec` (Section 11.3), so the state classes stay trivial.

---

## 9. Animal architecture

### 9.1 State (GDD §4)

| Field | Type | Range | Changed by |
|---|---|---|---|
| `hunger` | float | 0–100 (100 = fully fed) | `ProductionRules` (decay), `FeedingRules` (+50 per meal) |
| `happiness` | float | 0–100 | `ProductionRules` (decay), feed and collect gains (OPEN numbers) |
| `health` | float | 0–100 | Constant 100 in the MVP. Display only. Sickness is **Future / Not MVP** |
| `progress` | float | 0.0–1.0 | `ProductionRules`; reset by collect |
| `name` | String | ≤ `names.maxLength` | Purchase (from name pool), rename |

Floats are used so time-based decay is exact between saves. The UI rounds for display.

### 9.2 Derived status (`StatusRules`)

```gdscript
class_name StatusRules extends RefCounted
const HUNGRY := 1
const READY := 2
const LOW_HAPPINESS := 4
enum Bubble { NONE, FEED, PRODUCT, CLOUD }

static func flags(a: AnimalInstance, c: GameCatalog) -> int
    # HUNGRY if a.hunger < c.status.hungry_below
    # READY if a.progress >= 1.0
    # LOW_HAPPINESS if a.happiness < c.status.low_happiness_below
static func primary_bubble(flags: int) -> Bubble     # OPEN (arch): priority when several apply
static func is_low_bar(value: float, c: GameCatalog) -> bool  # amber status bar, < 30%
```

GDD §4 says "one bubble above the head plus one face change", but does not say which bubble wins when an animal is both hungry and has a product ready (or has low happiness too). `primary_bubble()` is the single place that decides. It is built with READY > FEED > CLOUD (the product bubble wins, because collecting also raises happiness). This is listed as OPEN in Section 23. Tapping a bubble performs that bubble's action (UI_SPEC §3).

### 9.3 Presentation (`AnimalView`)

```
<species_id>_view.tscn  (inherits animal_view.tscn)
AnimalView (Node2D)                     scenes/farm/animals/animal_view.gd
├── Shadow (Sprite2D)
├── Body (AnimatedSprite2D or Sprite2D + AnimationPlayer)
├── SelectionRing (Node2D)
└── BubbleAnchor (Marker2D)             the StatusBubble is placed in WorldUi at this point
```

```gdscript
class_name AnimalView extends Node2D
@export var tap_zone_size: Vector2 = Vector2(64, 64)  # chicken 64x64, pig 80x72, cow 96x80 (GDD §4)
@export var walk_speed: float = 40.0                  # dp/s: chicken 40, pig 36, cow 20
var animal_id: String

func bind(animal_id: String, wander_area: Rect2) -> void
func refresh() -> void            # reads Game.state, sets face/idle speed/bubble from StatusRules
func play_feed() -> void          # visual only
func play_collect() -> void
func play_tap() -> void
func play_drop_in() -> void       # purchase drop + squash
func tap_rect() -> Rect2          # global rect used by FarmInput
```

- **The view holds no game state** except `animal_id`. It reads `Game.state.farm.get_animal(animal_id)` when `refresh()` runs.
- `refresh()` runs on `Game.animal_changed(id)`, `Game.animal_status_changed(id, flags)` and `Game.state_loaded`. It does **not** run every frame.
- Wandering is visual. `_process(delta)` moves the sprite toward a random point inside `wander_area` (the housing building's `WanderArea` rect) at `walk_speed`. Low happiness slows the idle animation (DESIGN §7). Positions are never saved.
- **Missing art fallback (DESIGN §12 rule 9):** if `<species_id>_view.tscn` does not exist, `FarmWorld` instances the base `animal_view.tscn`, which draws a rounded placeholder block from `assets/placeholder/`.

### 9.4 Production while hunger > 0

See Section 14. In short, `ProductionRules.advance_animal()` works out how many of the elapsed seconds the animal had food, and advances `progress` only for those seconds.

---

## 10. Farm, building, inventory and economy architecture

### 10.1 Farm world (Phase 1)

**Layout is authored, not placed.** The GDD has no player-driven building placement: there are exactly five buildings, and all exist from the start (OPEN default, GDD §6). `farm_world.tscn` contains a `BuildingSlots/<building_id>` `Marker2D` for each building id, and the farm layout lives in that scene. "Building placement foundation" (CLAUDE.md Phase 1) is therefore built as **spawning building views at authored slots from state**, with no drag-to-place system (Section 24).

**World size and fit.** The world is authored at 390 units wide. `FarmCamera` computes `fit_zoom = viewport_width / world_width`, so the world fits the screen width at the player-facing zoom of 1.0 (DESIGN §12 rule 2). Player zoom is `0.8–1.4 × fit_zoom`. The world rect has extra ground below the main content, and sky above it that may be cropped, so taller screens show more ground and shorter screens crop sky. Buildings and animals sit in a safe band that is never cropped.

**`FarmCamera` (Camera2D)** follows DESIGN §11:
- One-finger pan with 400 ms inertia (velocity decays over 400 ms; computed in `_process(delta)`, visual only), clamped to the world rect with a soft rubber band.
- Pinch zoom from 0.8x to 1.4x. A double tap on empty ground animates back to 1.0x. Zoom resets on every launch.
- `focus_on(world_pos: Vector2, duration: float = 0.28)` pans the camera so an animal sits above the 272 dp sheet (UI_SPEC §3), or jumps to it when Animals-list actions are used.
- With reduced motion on, pans become instant cuts (DESIGN §9).

**`FarmInput` (Node)** uses `_unhandled_input`, so UI Controls always get input first:
- A touch that moves less than 8 dp is a tap; 8 dp or more starts a pan, even when it starts on an animal (UI_SPEC §3). Two touches start a pinch.
- Tap hit-testing checks in priority order: bubbles (48 dp target) → animals (tap zones) → buildings (72 x 72 minimum) → empty ground. Within a tier, the nearest centre wins (UI_SPEC §3).
- A long press (400 ms) on an animal emits `animal_long_pressed(id)`, which shows a tooltip (no sheet).
- `FarmInput` emits intent signals. `FarmWorld` re-emits them: `animal_tapped(id)`, `bubble_tapped(id)`, `building_tapped(id)`, `ground_tapped()`, `ground_double_tapped()`, `animal_long_pressed(id)`. `FarmScreen` maps them to `Nav` calls and `Game` commands.
- World-space indicators (tags, bubbles) are scaled by `clamp(zoom, 0.9, 1.2) / zoom` each time the zoom changes, so their on-screen size stays between 0.9x and 1.2x (DESIGN §11).

**Building views from state.** On `Game.state_loaded`, `FarmWorld.rebuild()`:
1. Frees the existing views.
2. For each `BuildingInstance`, instances `res://scenes/farm/buildings/<id>_view.tscn` (or the placeholder base) at `BuildingSlots/<id>` and calls `view.bind(id)`.
3. For each `AnimalInstance`, instances `<species>_view.tscn` at a random point in its building's `WanderArea` and calls `view.bind(animal_id, area)`.

`Game.animal_added(id)` spawns a single view with `play_drop_in()`. `Game.building_upgraded(id, level)` calls `view.play_upgrade(level)`: 1.2 s total, art swap at 400 ms, input never blocked (GDD §6).

### 10.2 Building rules (Phase 6)

```gdscript
class_name BuildingRules extends RefCounted
static func housed_count(farm: FarmState, building_id: String) -> int
static func capacity(farm: FarmState, building_id: String, c: GameCatalog) -> int
static func is_full(farm: FarmState, building_id: String, c: GameCatalog) -> bool
static func production_multiplier(farm: FarmState, building_id: String, c: GameCatalog) -> float
static func feed_capacity(farm: FarmState, c: GameCatalog) -> int            # from the FEED_STORAGE building
static func sell_bonus_percent(farm: FarmState, c: GameCatalog) -> float     # from the MARKET building
static func is_max_level(b: BuildingInstance, c: GameCatalog) -> bool
static func next_upgrade(b: BuildingInstance, c: GameCatalog) -> UpgradeDefinition   # null at max
static func check_upgrade(state: GameState, building_id: String, c: GameCatalog) -> ActionResult
    # MAX_LEVEL | NOT_ENOUGH_COINS(missing) | OK   (GDD §6: coins only, no other requirement)
```

All level effects come from `UpgradeDefinition` fields. The building tag text ("Coop Lv 1 - 2/4"), the amber "full" state, the affordable-upgrade badge and Building Details' comparison rows ("4 to 8", "100% to 125%", sell bonus, storage) all read these functions. They never compute effects themselves.

**Starting buildings.** `Game.new_game_state()` creates a `BuildingInstance(level 1)` for every building with `starts_built = true`. When a save is loaded, any catalog building missing from the save that has `starts_built = true` is added at level 1 (forward-compatible when a building type is added). The OPEN rule for GDD §6 starting state lives in the `startsBuilt` data flag. A construction flow is not designed in UI_SPEC and is not built (Section 24).

### 10.3 Inventory (Phase 5)

- **Bag** = `InventoryState.quantities`, product id → int ≥ 0. Methods: `get_qty(id)`, `add(id, n)`, `remove(id, n) -> bool` (refuses to go negative). Products never expire or disappear (GDD §5).
- **Feed** is in `PlayerState.feed` (GDD §9 puts it in `wallet`). Its cap is `BuildingRules.feed_capacity()`. The Bag's feed tile shows `feed / cap` ("36 / 100").
- Zero-quantity tiles stay visible at 60% opacity. This is a UI concern only: the bag always contains every catalog product key.

### 10.4 Economy (Phase 5)

```gdscript
class_name EconomyRules extends RefCounted
static func missing_coins(coins: int, cost: int) -> int                 # max(0, cost - coins)
static func check_buy_animal(state: GameState, species: String, c: GameCatalog) -> ActionResult
    # LOCKED_BY_LEVEL | BUILDING_FULL | NOT_ENOUGH_COINS(missing) | OK
static func check_buy_feed_pack(state: GameState, c: GameCatalog) -> ActionResult
    # NOT_ENOUGH_COINS(missing) | STORAGE_FULL | OK   (OPEN: whole-pack refusal)
static func sale_total(unit_price: int, qty: int, bonus_percent: float) -> int
    # OPEN (design) rounding: round the TOTAL half-up (GDD §7 recommended)
static func sell_all_total(bag: InventoryState, farm: FarmState, c: GameCatalog) -> int
static func offline_coin_value(products: Dictionary, farm: FarmState, c: GameCatalog) -> int   # info only
```

**Transactions** are `Game` methods (Section 13.1). Each one follows the same pattern, so none of them can half-apply:

```
1. guard      ActionGuard: reject if the 300 ms commit lock is active   -> DEBOUNCED
2. sync       _advance_to(now)                                           (time-based state is current)
3. check      XxxRules.check_*(state, ...)                               -> reason code, no mutation
4. apply      mutate state (all changes together)
5. notify     emit specific signals, then state_changed
6. persist    SaveService.request_autosave()  (or save_now() for sells, see below)
```

**300 ms commit lock (GDD §7, DESIGN §10 rule 8, UI_SPEC §12).** It is enforced in **two** places:
- **Domain:** `ActionGuard.try_commit(key: String, now_mono_ms: int, lock_ms: int) -> bool`. Keys: `"purchase"` (buy animal, buy feed pack, upgrade; all share one key so a double tap cannot buy two different things), `"feed:<animal_id>"` (the feed debounce, GDD §4), `"sell"`. It uses `GameClock.mono_ms()` (`Time.get_ticks_msec()`). This is a real-time debounce, not persistent game time, so CLAUDE.md §8 is respected. This is the layer tests verify.
- **UI:** `FarmButton.commit_lock_ms = 300` disables the pressed button for 300 ms for visual feedback (UI_SPEC §12 "buttons lock 300 ms").

**Sell and save failure (UI_SPEC §9).** "If a sale cannot be saved, toast 'Could not sell. Try again' and quantities are restored." So `Game.sell_product()` and `Game.sell_all()` are the only commands that save **synchronously**: snapshot wallet + bag → apply → `SaveService.save_now()` → on failure, restore the snapshot and return `SAVE_FAILED` (no sale signals are emitted). All other commands use the debounced autosave. See Section 24 for how this sits next to GDD §9's general rule ("play continues").

**Number display.** `NumberFormat.int_with_separators(n)` is the only number formatter. It never abbreviates (GDD §7 says "not abbreviated below 10,000" and does not define abbreviation above that; Section 24).

---

## 11. Save / load architecture (Phase 7)

### 11.1 Files

| File | Path | Purpose |
|---|---|---|
| Main | `user://save/farmora_save.json` | Current save |
| Temp | `user://save/farmora_save.json.tmp` | Written first, then renamed over main |
| Backup | `user://save/farmora_save.bak.json` | The previous good main (GDD §9 "keep one previous backup") |
| Damaged | `user://save/farmora_save.damaged.json` | The file kept when the player chooses "Start new farm" after damage (GDD §9) |

### 11.2 Save file format (version 1)

```json
{
  "version": 1,
  "lastSeen": 1759392000000,
  "tutorialStep": 7,
  "wallet":   { "coins": 150, "feed": 5, "xp": 0, "level": 1 },
  "bag":      { "egg": 0, "milk": 0, "pork": 0 },
  "buildings": [ { "id": "chicken_coop", "level": 1 }, { "id": "cow_barn", "level": 1 },
                 { "id": "pig_pen", "level": 1 }, { "id": "feed_storage", "level": 1 },
                 { "id": "market", "level": 1 } ],
  "animals":  [ { "id": "a_1759392000123_4f2c", "species": "chicken", "name": "Pip",
                  "buildingId": "chicken_coop", "hunger": 0, "happiness": 100,
                  "health": 100, "progress": 0.0 } ],
  "settings": { "sound": true, "music": true, "vibration": true, "reminders": false, "language": "en" }
}
```

- The structure and key names are exactly GDD §9's, plus `settings.language` (Section 8.1).
- `lastSeen` is **integer Unix epoch milliseconds, UTC**. An integer is exact in JSON and avoids time-zone and string-parsing problems.
- `tutorialStep`: `0` = not started, `1`–`6` = current step (GDD §8 table), `7` = finished or skipped (`TutorialRules.DONE`).
- Defaults for `sound`, `music` and `vibration` are `true` (no default is specified). `reminders` defaults to `false` (GDD §9).

### 11.3 `SaveCodec`, validation and unknown fields

```gdscript
class_name SaveCodec extends RefCounted
const CURRENT_VERSION := 1
enum Status { OK, NO_SAVE, DAMAGED, TOO_NEW }
static func encode(state: GameState) -> Dictionary
static func decode(d: Dictionary, c: GameCatalog) -> DecodeResult    # {status, state, problems}
```

`decode` does, in order:
1. **Structure check.** The root is a Dictionary; `version` is a number; `wallet`, `bag` and `settings` are Dictionaries; `buildings` and `animals` are Arrays of Dictionaries. Any failure → `DAMAGED`.
2. **Version.** `version > CURRENT_VERSION` → `TOO_NEW` (handled like damaged, but the file is never overwritten; Section 11.5). `version < CURRENT_VERSION` → `SaveMigrator.migrate(d)`.
3. **Field types.** A wrong type on a known field (for example `"coins": "abc"`) → `DAMAGED`.
4. **Range clamps (not failures).** `hunger`, `happiness` and `health` are clamped to 0–100, `progress` to 0–1, `coins` and `feed` and bag quantities to ≥ 0, building `level` to 1..max. Every clamp is logged.
5. **Unknown fields** go into `extra` on the matching object. Unknown species and building ids go into `FarmState.unrecognized_*`. Both are written back unchanged by `encode`.
6. **Missing starting buildings** are added (Section 10.2).

### 11.4 Migrations

```gdscript
class_name SaveMigrator extends RefCounted
# Each step is a pure Dictionary -> Dictionary function. None exist in MVP v1.
const STEPS := {}            # e.g. { 1: "_v1_to_v2" }
static func migrate(d: Dictionary) -> Dictionary   # loops version -> CURRENT_VERSION; preserves unknown keys
```

Rules: a migration may only **add or rename** keys with defaults. It must never drop unknown keys. Each migration gets a fixture file `tests/fixtures/saves/vN_*.json` and a test.

### 11.5 `SaveFileIO`: atomic write and load order

```gdscript
class_name SaveFileIO extends RefCounted
func _init(dir: String = "user://save") -> void        # tests pass "user://test_saves/<case>"
func write_atomic(json_text: String) -> Error
func read_candidates() -> Array[Dictionary]            # [{source:"main"|"tmp"|"backup", text:String}]
func quarantine_damaged() -> Error                     # main -> farmora_save.damaged.json
```

**Write sequence** (GDD §9 "write to a temp file, then rename"):
1. Write the full JSON text to `.tmp`, flush and close. Check `FileAccess.get_open_error()` and `get_error()`.
2. Read `.tmp` back and `JSON.parse` it. If it does not parse, stop with an error and leave main untouched.
3. If main exists, **copy** main → `.bak.json`. This replaces the old backup, so exactly one previous version is kept.
4. **Rename** `.tmp` → main (`DirAccess.rename_absolute`, which replaces atomically on Android and iOS). Main is never missing during a normal save. If rename-over-existing fails on a desktop platform, the fallback is remove main then rename, used in the editor only.

**Load order** (`SaveService.load_game()`):

| Situation | Result |
|---|---|
| No main, no tmp, no backup | `NO_SAVE` → first launch |
| Main parses and decodes OK | `OK` |
| Main missing, `.tmp` decodes OK (crash during the very first save) | `OK` from tmp |
| Main damaged or missing, backup decodes OK | **OPEN (arch):** see below |
| Files exist but none decode | `DAMAGED` |
| Main is `TOO_NEW` | `DAMAGED` flow; main is never overwritten |

> **OPEN (arch): damaged main with a valid backup.** GDD §9 requires a backup, and also says "a damaged save offers Start new farm". It does not say whether a valid backup should be loaded automatically. `SaveService.load_game()` returns `LoadResult { status, state, source }` with `source = "backup"`, so either policy can be applied in `Main`'s boot step alone. Built default: **load the backup automatically** (the player loses at most one save interval of progress) and show the Damaged-save menu only when no candidate decodes. Listed in Section 23 for confirmation.

### 11.6 `SaveService` (autoload)

```gdscript
# autoload/save_service.gd
signal save_succeeded(manual: bool)
signal save_failed(manual: bool)
signal load_finished(result: LoadResult)

var persistence_enabled: bool = false     # off until a farm exists and is not in damaged limbo
func configure(snapshot_provider: Callable, catalog: GameCatalog) -> void   # Game passes func() -> Dictionary
func load_game() -> LoadResult
func request_autosave() -> void           # starts the 2 s timer if not already running
func save_now(manual: bool = false) -> bool   # synchronous; used by sells, background, Save now, Collect
func retry_now() -> void                  # banner "Try now"
func start_new_farm_after_damage() -> void    # quarantine damaged main, then enable persistence
```

- **Autosave, 2 s after a change (GDD §9).** `request_autosave()` starts a one-shot 2.0 s `Timer` **only if it is not already running**. So a save always happens within 2 s of the first unsaved change, and constant tapping cannot postpone it forever.
- **What counts as a change:** every successful `Game` command (it emits `state_changed`, and `Game` calls `request_autosave()`). **Simulation ticks do not trigger saves.** Hunger decay is covered by snapshot semantics (Section 8.2).
- **On background (GDD §9):** `Main._notification` handles `NOTIFICATION_APPLICATION_PAUSED` (mobile), `NOTIFICATION_APPLICATION_FOCUS_OUT` (desktop testing) and `NOTIFICATION_WM_CLOSE_REQUEST`, then calls `Game.on_app_backgrounded()`, which advances to now and calls `SaveService.save_now()`.
- **Settings > Save now:** `SaveService.save_now(true)`. Success → toast "Saved" (Info). Failure → the Settings row shows "Could not save" with **Try again** (UI_SPEC §18.4). The "Saved" toast is shown only for manual saves; Section 24 explains why.
- **Failure and retry (GDD §9, UI_SPEC §16):** on an automatic save failure, emit `save_failed(false)`. `AppShell.BannerHost` shows the non-blocking banner, and retries are scheduled at **5 s, 15 s, 60 s** after the failure. Any success resets the schedule and hides the banner. After the third retry no more timed retries run; the next trigger (a change, backgrounding, Save now, Try now) tries again, and the banner stays up until a save succeeds. This last behaviour is not specified in GDD §9 (Section 24).
- **`persistence_enabled`** is `false`:
  - on first launch until the player taps Play (a fresh `GameState` exists only in memory, so settings changed from the Main Menu are kept and then saved);
  - while the save is `DAMAGED`, until "Start new farm" is confirmed. **A damaged file is never overwritten by autosave.**
- `SaveService` never imports `Game`. It gets the data to save through the `snapshot_provider` Callable, which `Game` sets in `_ready`. That Callable advances to now and returns `SaveCodec.encode(state)`.

---

## 12. Offline progression architecture (Phase 8)

### 12.1 Elapsed time (GDD §9 rules 1, 2)

```gdscript
class_name OfflineRules extends RefCounted
static func elapsed_ms(now_ms: int, last_seen_ms: int, cap_ms: int) -> int:
    if now_ms < last_seen_ms:   # clock went backwards
        return 0
    return mini(now_ms - last_seen_ms, cap_ms)
static func should_show_modal(report: OfflineReport, c: GameCatalog) -> bool:
    # elapsed > rewardModalMinMinutes (strictly more than 5 min) AND something was produced
```

When the clock went backwards, `Game` also **re-bases** `last_seen_ms = now_ms`. Otherwise a moved-back clock would freeze production until real time caught up. Applying zero elapsed time and then saving with the current time matches GDD §9 rule 8.

### 12.2 Same code path as online play

```gdscript
# autoload/game.gd (excerpt)
func _advance_to(now_ms: int, is_return: bool = false) -> OfflineReport:
    var dt_ms := OfflineRules.elapsed_ms(now_ms, state.last_seen_ms, catalog.offline.cap_ms)
    var before := _ready_flags_snapshot()          # animal_id -> was READY
    for a in state.farm.animals:
        ProductionRules.advance_animal(a, dt_ms / 1000.0, _production_params_for(a))
    state.last_seen_ms = now_ms                    # also re-bases a backwards clock
    var report := OfflineReport.build(before, state, dt_ms, catalog)   # who became READY in this window
    _emit_status_transitions(before)
    simulation_ticked.emit()
    if is_return:
        offline_progress_applied.emit(report)
    return report
```

Callers:

| Trigger | Call | `is_return` |
|---|---|---|
| Online tick (1.0 s `Timer`, wall-clock delta) | `_advance_to(clock.now_ms(), false)` | false |
| Any command (feed, collect, buy...) | `_advance_to(now, false)` before applying | false |
| Before any save | via `snapshot_provider` | false |
| Launch with a save (`Game.begin_session`) | `_advance_to(now, true)` | **true** |
| Resume (`NOTIFICATION_APPLICATION_RESUMED`) | `Game.on_app_resumed()` → `_advance_to(now, true)` | **true** |
| Tick where the delta exceeds the modal threshold (the OS suspended the app without a pause notification) | treated as a return | **true** |

There is **no** separate offline simulation. The 8 h cap is applied to every delta (online deltas are about 1 s, so the cap never matters for them). This satisfies GDD §9 rule 3 and CLAUDE.md §8.

### 12.3 What the reward is

`OfflineReport`: `{ elapsed_ms: int, capped: bool, ready_animal_ids: Array[String], products: Dictionary (product_id -> int), coin_value: int }`.

- **Produced in the window** = animals whose READY flag went from false to true during this advance. With `production.pauseWhenReady = true` (the OPEN default), that is at most **one product per animal**. Animals that were already READY when the player left are not counted, because they produced nothing while away.
- **Collect** (the only exit, UI_SPEC §13) calls `Game.collect_offline_reward(report)`. That runs the **normal `collect` logic** for each id in `ready_animal_ids`: product into the Bag, progress reset, happiness and XP gains (OPEN numbers). It skips the 300 ms debounce. Then it calls `SaveService.save_now()`. No coins are credited (GDD §9 rule 6).
- **"Coins" row (OPEN, design, GDD §9).** `report.coin_value` is computed with `EconomyRules.offline_coin_value()` as information only. Whether coins are ever credited is decided in `collect_offline_reward()` alone. Built default: display only.
- **If saving the reward fails (GDD §9 rule 7):** nothing extra is needed. The disk still holds the earlier snapshot with the earlier `lastSeen`. If the app dies before a later save succeeds, the next launch recomputes the same window and shows the modal again. If a later autosave succeeds, the collected products are on disk. The reward is never lost and never credited twice, and no separate "pending reward" record is needed.
- **Hungry animals produce nothing (GDD §9 "no free production").** This follows automatically from `advance_animal` (Section 14).

### 12.4 Ordering: "before any other prompt"

`Main` connects `Game.offline_progress_applied` before calling `Game.begin_session()`. If `OfflineRules.should_show_modal(report)` is true, `Main` calls `Nav.open_blocking(UiScenes.OFFLINE_REWARD, {report = report})` **before** the tutorial resumes or any toast or banner is shown. `Nav` holds queued toasts, the save banner and tutorial resumption until the blocking modal closes. The modal is shown at most once per return.

---

## 13. Services (autoloads)

Four autoloads, registered in this order:

| Autoload | Script | Why it is global | Must not |
|---|---|---|---|
| `Game` | `res://autoload/game.gd` | Owns the single `GameState` and `GameCatalog`, runs the 1 s simulation tick, exposes every state-changing command, emits domain signals. Almost every screen needs it | Touch UI, play audio, do file IO |
| `SaveService` | `res://autoload/save_service.gd` | Timers (autosave, retry) and file IO must outlive any scene | Know about `Game` (Callable only) or UI |
| `Nav` | `res://autoload/nav.gd` | Overlay stack, tabs and back handling are needed by every screen and by `Main` | Mutate game state |
| `AudioService` | `res://autoload/audio_service.gd` | Sound, music and vibration toggles (GDD §3, DESIGN §10) apply everywhere; music must survive screen changes | Decide gameplay |

**Not services (deliberately):** the catalog (a field on `Game`), the clock (`GameClock`, a field on `Game`, replaced in tests), economy, production and the other rules (pure static classes, Section 6), the theme (a Theme resource + `UiTokens` constants), the tutorial (a UI controller, Section 15.3). Each of these has state that is already owned elsewhere, or no state at all.

### 13.1 `Game` API

```gdscript
# autoload/game.gd
# --- owned data ---
var catalog: GameCatalog
var state: GameState
var clock: GameClock = GameClock.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _guard: ActionGuard = ActionGuard.new()
# A child Timer "SimTick": wait_time 1.0, autostart only once a session begins.

# --- session ---
func new_game_state() -> GameState              # from catalog.start + startsBuilt buildings
func begin_session(loaded: GameState) -> void   # sets state, emits state_loaded, _advance_to(now, true)
func on_app_backgrounded() -> void              # advance + SaveService.save_now()
func on_app_resumed() -> void                   # _advance_to(now, true)
func build_save_dict() -> Dictionary            # advance to now, SaveCodec.encode(state)

# --- commands: each returns ActionResult ---
func feed_animal(animal_id: String) -> ActionResult
func collect(animal_id: String) -> ActionResult
func collect_all() -> ActionResult              # domain applies all at once; UI staggers 60 ms
func collect_offline_reward(report: OfflineReport) -> ActionResult
func buy_animal(species: String) -> ActionResult    # result.data.animal_id for the "Meet Pip" card
func buy_feed_pack() -> ActionResult
func sell_product(product_id: String) -> ActionResult   # sells the whole stack of that product (UI_SPEC §8.1/§9 per-row Sell)
func sell_all() -> ActionResult
func upgrade_building(building_id: String) -> ActionResult
func rename_animal(animal_id: String, new_name: String) -> ActionResult
func set_setting(key: String, value: Variant) -> void
func set_tutorial_step(step: int) -> void
func skip_tutorial() -> void                    # TutorialRules.skip_grant (OPEN, Section 24)
```

> Per-row **Sell** sells every unit of that product. UI_SPEC §8.1's toast "Sold 12 eggs +60 coins" and the Bag tile's single Sell button both indicate selling the whole stack, and no quantity picker is specified.

### 13.2 `ActionResult`

```gdscript
class_name ActionResult extends RefCounted
enum Code { OK, DEBOUNCED, NOT_ENOUGH_COINS, NOT_ENOUGH_FEED, HUNGER_FULL, NOT_READY,
            BUILDING_FULL, LOCKED_BY_LEVEL, STORAGE_FULL, MAX_LEVEL, NOTHING_TO_SELL,
            INVALID_NAME, UNKNOWN_ID, SAVE_FAILED }
var code: Code = Code.OK
var missing: int = 0            # coins missing, for "You need N more coins."
var data: Dictionary = {}       # e.g. {"animal_id": ...}, {"coins_earned": 60, "sold": {"egg": 12}}
func ok() -> bool
```

`ui/result_messages.gd` (`ResultMessages`) maps each code to the approved copy key in `strings.csv` ("No feed left", "You need N more coins.", "The coop is full", "Unlocks at level N", "Could not sell. Try again"...). Screens never write error strings inline.

### 13.3 `Nav` API

```gdscript
# autoload/nav.gd
enum Tab { FARM, ANIMALS, MARKET, BAG }
signal tab_changed(tab: Tab)
signal overlay_stack_changed(depth: int)
signal world_coverage_changed(covered: bool)      # FarmWorld pauses ambient animation
signal farm_focus_requested(animal_id: String)    # Animals-list actions jump the camera

func register_shell(shell: AppShell) -> void
func switch_tab(tab: Tab, args: Dictionary = {}) -> void   # e.g. {segment = "feed"} for Market
func push_screen(scene: PackedScene, args: Dictionary = {}) -> Overlay
func open_sheet(scene: PackedScene, args: Dictionary = {}) -> Overlay   # replaces an open sheet in place
func open_modal(scene: PackedScene, args: Dictionary = {}) -> Overlay
func open_blocking(scene: PackedScene, args: Dictionary = {}) -> Overlay
func close_top() -> void
func close_all_non_blocking() -> void
func top() -> Overlay
func handle_back() -> void                         # Section 15.2
func show_toast(text: String, kind: int) -> void   # SUCCESS | PROBLEM | INFO; newer replaces older
func show_save_banner(visible: bool) -> void
func set_tabs_locked(allowed: Array[Tab]) -> void  # tutorial lock (45% opacity)
```

**Switching tabs closes all non-blocking overlays first.** UI_SPEC does not say what happens to an open sheet or pushed screen when another tab is tapped; closing them keeps the stack meaning "on top of the current tab root" (Section 24).

---

## 14. Production architecture (Phase 4) — the only simulation math

```gdscript
class_name ProductionRules extends RefCounted

class Params:
    var cycle_seconds: float            # effective: base / building multiplier, or tutorial boost
    var hunger_decay_per_second: float  # feeding.hungerDecayPerMinute / 60
    var happiness_decay_per_second: float
    var pause_when_ready: bool          # OPEN (design) GDD §4

# Advances one animal by dt seconds. Returns the number of products completed (0 or 1 when paused-at-ready).
static func advance_animal(a: AnimalInstance, dt: float, p: Params) -> int:
    if dt <= 0.0:
        return 0
    # 1. Seconds during which the animal still had food (hunger > 0).
    var fed_time: float = dt
    if p.hunger_decay_per_second > 0.0:
        fed_time = clampf(a.hunger / p.hunger_decay_per_second, 0.0, dt)
    elif a.hunger <= 0.0:
        fed_time = 0.0
    # 2. Hunger and happiness decay on wall time, whether or not the animal is producing (GDD §4).
    a.hunger = maxf(0.0, a.hunger - p.hunger_decay_per_second * dt)
    a.happiness = maxf(0.0, a.happiness - p.happiness_decay_per_second * dt)
    # 3. Progress only during fed time.
    if p.pause_when_ready and a.progress >= 1.0:
        return 0
    a.progress += fed_time / p.cycle_seconds
    if a.progress >= 1.0:
        if p.pause_when_ready:
            a.progress = 1.0
            return 1
        var done := int(floor(a.progress))   # alternative resolution: see note below
        a.progress -= done
        return done
    return 0
```

**Effective cycle** (`Game._production_params_for(a)`):
`cycle = catalog.animal(a.species).cycle_seconds / BuildingRules.production_multiplier(farm, a.building_id)`. If `TutorialRules.boost_active(state, a, catalog)` is true (tutorial step ≤ 4 "Collect the egg", species is `tutorial.boostSpecies`), the cycle is `tutorial.firstEggSeconds` instead (GDD §8: first egg ready after 20 s). The boost is derived from the saved `tutorialStep`, so no new save field is needed, and it applies to offline time too.

**Properties this guarantees, each covered by a test (Section 19):**
1. **Split invariance:** advancing 8 h in one call gives the same result (within float epsilon) as 28,800 calls of 1 s, or random splits. So online and offline give identical results, and FPS cannot matter. This holds because hunger decays linearly, fed time is additive, and progress is clamped.
2. An animal at hunger 0 gains no progress, however long it waits.
3. One meal (+50) gives about 50 minutes of production (GDD §4 clarification).
4. Production speed scales with the housing building's level multiplier.

**Order matters:** every command calls `_advance_to(now)` **before** it mutates. So an upgrade or a meal applies only from that moment on, never retroactively.

**Production UI:** the progress bar (UI_SPEC §17.9) reads `animal.progress` on `simulation_ticked` and tweens to the new value over 300 ms, so 1 s ticks look smooth. When the bubble appears for the first time (READY transition), `AnimalView` plays the single chime through `AudioService` (DESIGN §10).

> **OPEN (design) GDD §4 "progress when a product is ready but not collected".** `production.pauseWhenReady = true` (the recommended default) is built and tested. If the owner chooses continuous production instead, the stored count needs an additive animal field `readyCount` (a schema-version bump with a default-0 migration), and `collect` takes `readyCount` items. The `else` branch above is where that change would go. **Do not build that path until it is confirmed.**

---

## 15. UI architecture

### 15.1 Screens, hosts, components

- **Root screens** (Splash, Main Menu) are swapped by `AppShell.set_mode()`.
- **Tab roots** (Farm, Animals, Market, Bag) are pre-instanced in `TabHost` and switched by `Nav.switch_tab()`.
- **Pushed screens, sheets and modals** are `Overlay`s in the stack (Section 4.2).
- **Shared chrome** (HUD, nav, toast host, banner host) lives in `AppShell` once.
- **Scene registry:** `ui/ui_scenes.gd` (`class_name UiScenes`) holds a `const X := preload("res://ui/...tscn")` for every screen and overlay. Screens open others through `UiScenes.X`, so paths are not scattered through the code.
- **Binding pattern for every screen and component that shows state:**
  1. In `_ready()`, connect only the `Game` signals it needs, then call `_refresh()`.
  2. `_refresh()` reads `Game.state` and asks rules for derived values (affordability, capacity, status).
  3. Actions call a `Game` command, check the `ActionResult`, and show feedback (toast, shake, disabled reason) through `ResultMessages`.
  Godot drops signal connections automatically when the receiving node is freed, so overlays need no manual disconnect.

### 15.2 Back handling (UI_SPEC §2)

`Main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)` → `Nav.handle_back()`:

```
1. AppShell mode BOOT                         -> ignore (Splash while loading)
2. Tutorial active                            -> TutorialOverlay.on_back(): ignored except on the final card
3. Overlay stack not empty                    -> top().on_back()   (BLOCKING_MODAL: Offline Reward = Collect)
4. Mode MENU                                  -> get_tree().quit()
5. Tab != FARM                                -> switch_tab(FARM)
6. Tab == FARM                                -> if the "Press back again to exit" toast is showing -> quit
                                                 else show that toast (Info)
```

"Press back again" uses the toast's visible window (2.2 s) as the exit window. UI_SPEC gives the toast text but no timing (Section 24). iOS has no system back. The on-screen Back and Close buttons call `Nav.close_top()`.

### 15.3 Tutorial

- `ui/tutorial/tutorial_controller.gd` (a child of `AppShell`, not an autoload) listens to `Game.animal_added`, `Game.animal_fed`, `Game.product_collected`, `Game.products_sold` and `Nav.tab_changed`, and moves `Game.state.tutorial_step` forward with `Game.set_tutorial_step()`. "No Next buttons" (UI_SPEC §14): only real actions advance a step.
- **Spotlight targets** are found through a Godot group. Any Control or world node that can be spotlit adds itself to group `"tutorial_target"` and sets `set_meta("tutorial_key", "market_tab")`. The controller looks up the node for the current step's key and spotlights its global rect. World targets (the egg bubble) are converted from world to screen space through `FarmCamera`.
- `TutorialRules` (pure) holds step constants (`WELCOME = 1 ... GROW = 6, DONE = 7`), `boost_active()`, `allowed_tabs(step)`, and `skip_grant(state, catalog)`.
- If the player deviates ("adapts or ends quietly", GDD §8), the controller checks the state against each step's precondition. If the state already satisfies a later step, it jumps there. If the state contradicts the tutorial in a way no step can handle, it sets `DONE`. It never blocks play.
- While the Offline Reward modal is open, the tutorial overlay is hidden and resumes when the modal closes (Section 12.4).

### 15.4 Component inventory (`res://ui/components/`)

Each component is a folder with `<name>.tscn` + `<name>.gd`. It supports the states listed in UI_SPEC §17 where they apply (default, pressed, disabled, selected, loading, error).

| Component (class_name) | UI_SPEC | Notes |
|---|---|---|
| `FarmButton` | 17.1–17.3 | `@export variant: PRIMARY / SECONDARY / GHOST`, `@export size: REGULAR(52) / ROW(44) / TILE(48)`, `icon`, `commit_lock_ms`, `set_loading(bool)`, `set_disabled_reason(text)` (shows a caption or tooltip next to it: "Disabled always explains"). Press sink of 3 dp in 80 ms, release in 120 ms with 4% overshoot |
| `IconButton` | 17.4 | 48 dp circle, 24 dp glyph, `accessibility_label` is **required** (asserted in `_ready`) |
| `ResourcePill` | 17.5 | Coin and feed HUD pills; number rolls over 400 ms, bump to 1.08x, `shake_error()` |
| `LevelBadge` | 17.5 | "Lv N", XP purple; `play_level_up()` |
| `ResourceDisc` | 17.20 | Coloured disc + glyph; sizes HUD / CARD / TILE |
| `StatusBar` | 17.8 | Icon, label, value, 8 dp track; amber below `status.lowBarBelowPercent`; never red |
| `FarmProgressBar` | 17.9 | Default, ready glow, empty, indeterminate loading sweep |
| `AnimalCard` | 17.10 | List row 80 dp; status badge; Collect or Feed action |
| `ProductTile` | 17.11 | Bag tile, 2 columns, dims at zero quantity |
| `MarketRow` | 17.11 | 72 dp row with 48 dp action |
| `BuildingCard` | 17.12 | 96 dp row |
| `BottomSheet` | 17.15 | Base for `AnimalSheet`: grabber, swipe-to-dismiss past 40% of height or faster than 600 dp/s |
| `ModalPanel` | 12 / 17.14 | Width = screen − 64, max 340; radius 28; ghost/primary 1 : 1.2 button row; focus kept inside |
| `Toast` | 15 | Shown by `ToastHost`; SUCCESS / PROBLEM / INFO styles |
| `Tooltip` | 15 | Info blue, max width 200; appears 200 ms after a 400 ms long press |
| `Banner` | 16 | Barn-tint, non-blocking, "Try now" action |
| `FarmToggle` | 17.16 | 56 x 32, 160 ms thumb |
| `SegmentedControl` | 17.17 | 48 dp; tap or horizontal swipe |
| `FilterChips` | 17.17 | Horizontally scrolling chips (Animals tab) |
| `EmptyState` | 16 | The recipe: icon, headline, body, one button |
| `SkeletonRow` | 16 | 44 dp shimmer row |
| `NavItem` | 17.6 | 56 dp item with selected pill and badge |

World-space indicators are **not** Controls. They are under `scenes/farm/world_ui/` (`StatusBubble`, `BuildingTag`, `UpgradeBadge`, `Floater`) because they scale with the camera (DESIGN §11).

### 15.5 Design tokens and theme

**Two artefacts, one set of values:**

1. **`res://ui/theme/ui_tokens.gd`** (`class_name UiTokens`): every DESIGN.md token as a `const`. This is the only place hex values and sizes appear in code.
   ```gdscript
   class_name UiTokens extends RefCounted
   const COLOR_PRIMARY := Color("#26803A")
   const COLOR_PRIMARY_PRESSED := Color("#1D6730")
   const COLOR_PRIMARY_EDGE := Color("#1B5E2C")
   # ... every color.*, res.*, stat.* token from DESIGN §2
   const SPACE_4 := 4; const SPACE_8 := 8; ... const SPACE_48 := 48      # DESIGN §5
   const RADIUS_CHIP := 10; const RADIUS_BUTTON := 14; const RADIUS_CARD := 20
   const RADIUS_MODAL := 28; const RADIUS_PILL := 999
   const TOUCH_MIN := 48; const BUTTON_HEIGHT := 52; const NAV_ITEM_HEIGHT := 56
   const DUR_INSTANT := 0.08; const DUR_QUICK := 0.12; const DUR_STANDARD := 0.24
   const DUR_EMPHASIS := 0.4; const DUR_CELEBRATION := 0.8                 # DESIGN §9
   const TOAST_HOLD := 2.2
   ```
2. **`res://ui/theme/farmora_theme.tres`**: the project Theme, made in the Godot editor. It holds the four fonts (Fredoka 600/700, Nunito 600/700, from `assets/fonts/`), default font sizes, and **type variations** for each component look: `PrimaryButton`, `SecondaryButton`, `GhostButton`, `RowButton`, `IconButton`, `Card`, `Panel`, `HudPill`, `TitleLabel`, `SectionLabel`, `BodyLabel`, `CaptionLabel`, `NumberLabel`, `ButtonLabel`, `ToastSuccess`, `ToastProblem`, `ToastInfo`. StyleBoxFlat resources reproduce the radius, border and the 4 dp "clay" bottom edge (a bottom border in the edge colour).

**Keeping them in sync:** `tests/unit/test_theme_tokens.gd` loads the Theme and asserts that its key colours and radii equal `UiTokens`. Components never set colours inline. They use a theme type variation, or `UiTokens` when the value is code-driven (tween targets, world-space drawing).

**Motion:** `ui/theme/motion.gd` (`class_name Motion`) wraps tween creation with the DESIGN §9 easings. Godot has no cubic-bezier preset, so `Motion` provides `ease_out()`, `ease_in_out()` and `overshoot()` as `Curve` resources, with values matching DESIGN §9, sampled through `PropertyTweener.set_custom_interpolator()` (Godot 4.3+) or a `tween_method` driven by the curve. It also holds `Motion.reduced: bool`. Every animation helper checks it: shakes become a flash, flights become 150 ms fades, particles are skipped (DESIGN §9 reduced motion). Reading the OS reduced-motion setting is an engine capability gap (Section 24). Until it is solved, `Motion.reduced` is `false` and can be toggled in debug builds.

**Icons:** the 23 glyphs (DESIGN §4) are kept in `assets/icons/source/` exactly as delivered (`stroke="currentColor"`). Godot rasterizes SVG at import, so runtime copies in `assets/icons/` use a **white** stroke and are recoloured with `modulate`. One asset still serves every state colour, which is the intent of DESIGN §4. Import scale is set so 24 dp glyphs stay sharp at 3x. Phase 0 checks whether Godot's importer handles `currentColor` directly; if it does, the copies are not needed.

### 15.6 Copy and localisation

All player-facing text goes through `tr("KEY")`, with keys in `res://data/i18n/strings.csv` (columns `keys,en`). Keys are UPPER_SNAKE with a screen prefix (`MARKET_TITLE`, `TOAST_OUT_OF_FEED`, `EMPTY_BAG_HEADLINE`). Numbers inside copy use `NumberFormat`. `SettingsState.language` sets `TranslationServer.set_locale()`. This is required because Language is an MVP setting (GDD §3). The MVP ships only `en` until the owner names other languages (Section 24).

---

## 16. Signals and events

### 16.1 When to use what

| Situation | Mechanism |
|---|---|
| UI or world asks the domain to change something | **Direct call** to a `Game` command; read the returned `ActionResult` |
| UI asks for a derived value (can afford? capacity?) | **Direct call** to a rule function |
| Domain state changed and many views may care | **`Game` signal** |
| Parent node needs to know about a child widget event | **Local signal** on the child (`pressed`, `closed`, `animal_tapped`) |
| Navigation | **Direct call** on `Nav` |
| Presentation feedback (sound, haptic) | **Direct call** on `AudioService` from the view that plays the matching visual |

Rule: **signals point up and out (domain → presentation, child → parent). Calls point down and in.** State objects (`AnimalInstance` and the rest) have **no signals**. All changes go through `Game`, so one emitter covers everything, and the state classes stay plain data.

### 16.2 `Game` signals (binding names)

```gdscript
signal state_loaded()                                         # whole state replaced: rebuild everything
signal simulation_ticked()                                    # once per tick/advance: bars may re-read
signal state_changed()                                        # a command changed saved data (autosave)
signal coins_changed(new_value: int, old_value: int)
signal feed_changed(new_value: int, old_value: int)
signal bag_changed(product_id: String, new_value: int, old_value: int)
signal xp_changed(new_xp: int)
signal level_changed(new_level: int, unlocked_species: Array[String])
signal animal_added(animal_id: String)
signal animal_changed(animal_id: String)                      # fed, collected, renamed
signal animal_status_changed(animal_id: String, flags: int)   # derived flags changed (tick or command)
signal animal_fed(animal_id: String)
signal product_collected(animal_id: String, product_id: String, amount: int)
signal products_sold(sold: Dictionary, coins_earned: int)     # product_id -> qty
signal feed_bought(amount: int)
signal building_upgraded(building_id: String, new_level: int)
signal settings_changed(key: String)
signal tutorial_step_changed(step: int)
signal offline_progress_applied(report: OfflineReport)
```

`SaveService`: `save_succeeded(manual)`, `save_failed(manual)`, `load_finished(result)`.
`Nav`: `tab_changed`, `overlay_stack_changed`, `world_coverage_changed`, `farm_focus_requested`.

`animal_status_changed` is emitted only when the flags **change** (for example when an animal becomes READY), not on every tick. Views that need continuous values (bars) listen to `simulation_ticked`.

---

## 17. Data flow examples

**Feed an animal (2-tap path, UI_SPEC §6)**
```
Tap chicken ─► FarmInput (tap < 8 dp, nearest centre) ─► FarmWorld.animal_tapped(id)
   ─► FarmScreen: Nav.open_sheet(UiScenes.ANIMAL_SHEET, {animal_id}) ; FarmCamera.focus_on(...)
Tap Feed ─► FarmButton (sink 80 ms, 300 ms lock) ─► AnimalSheet ─► Game.feed_animal(id)
   Game: ActionGuard("feed:id") ─► _advance_to(now) ─► FeedingRules.check_feed() ─► OK
         wallet.feed -= 1 ; hunger = min(100, hunger + 50) ; happiness += gainOnFeed
         emit feed_changed, animal_fed(id), animal_changed(id), [animal_status_changed], state_changed
         SaveService.request_autosave()  ─► 2 s timer ─► save_now() ─► atomic write
   Hud.ResourcePill(feed) rolls ; AnimalSheet status bar tweens 300 ms ;
   AnimalView.play_feed() + AudioService.play("feed_crunch") + haptic light
On NOT_ENOUGH_FEED ─► ResultMessages ─► Nav.show_toast("Out of feed...") ; pill.shake_error()
```

**Production becomes ready (online)**
```
SimTick (1 s Timer) ─► Game._advance_to(clock.now_ms(), false)
   ─► ProductionRules.advance_animal(...) for each animal ─► progress hits 1.0
   ─► emit simulation_ticked, animal_status_changed(id, READY)
AnimalView.refresh() shows product bubble (bob loop) + chime once ; AnimalsTab re-sorts (ready first)
```

**Return after 3 h**
```
NOTIFICATION_APPLICATION_RESUMED ─► Main ─► Game.on_app_resumed() ─► _advance_to(now, true)
   ─► OfflineRules.elapsed_ms (cap 8 h, clock check) ─► same advance_animal loop
   ─► offline_progress_applied(report) ─► Main: should_show_modal? ─► Nav.open_blocking(OFFLINE_REWARD)
Collect ─► Game.collect_offline_reward(report) ─► normal collect per animal ─► SaveService.save_now()
```

**Boot**
```
Main._ready ─► ScreenFit.apply ─► AppShell BOOT (Splash)
   ─► Game loads catalog ─► SaveService.load_game()
       NO_SAVE  ─► Game.state = new_game_state() (memory only) ─► MENU (Continue hidden)
                   Play ─► SaveService.persistence_enabled = true ─► begin_session ─► GAME ─► tutorial step 1
       OK       ─► begin_session(state) ─► GAME ─► [Offline Reward] ─► resume tutorial if step 1..6
       DAMAGED  ─► MENU in damaged state ("Save damaged", Start new farm behind confirm)
   (Splash: if load has not finished after 8 s, show "Taking longer than usual" + Try again)
```

---

## 18. Error handling

Error handling only connects to the UX that is already specified. No new error UI is introduced.

| Failure | Detected in | Surfaced as (spec) |
|---|---|---|
| Rule refusal (no coins, no feed, full, locked, max level, not ready) | `XxxRules.check_*` → `ActionResult` | Disabled button + reason, Error-red price, shake, problem toast (UI_SPEC §8, §16) via `ResultMessages` |
| Double tap within 300 ms | `ActionGuard` → `DEBOUNCED` | Silent (the button is visibly locked) |
| Autosave failure | `SaveService.save_failed(false)` | Non-blocking Banner under HUD, auto-retry 5/15/60 s, "Try now" (GDD §9, UI_SPEC §16) |
| Save now failure | `save_now(true)` returns false | Settings row "Could not save" + Try again (UI_SPEC §18.4) |
| Sale could not be saved | `Game.sell_*` → `SAVE_FAILED` (after rollback) | Problem toast "Could not sell. Try again" (UI_SPEC §9) |
| Offline-reward save failure | `save_now()` false after Collect | Banner as usual; reward reappears next launch if never saved (GDD §9 rule 7, Section 12.3) |
| Damaged or too-new save | `SaveCodec` → `DAMAGED` / `TOO_NEW` | Main Menu "Save damaged" + Start new farm confirm; the old file is kept (GDD §9, UI_SPEC §12.3) |
| Slow load (> 8 s) | Splash timer | "Taking longer than usual" + Try again (UI_SPEC §18.1) |
| Missing art | View scene or texture missing | Rounded placeholder block (DESIGN §12 rule 9) |
| Invalid `balance.json` | `GameCatalog.validate()` | `assert` in debug; prevented in release by `test_balance_data.gd` |
| Programmer errors (unknown id passed to a command) | `Game` | `UNKNOWN_ID` + `push_error`; never crash in release |

Logging: `push_warning` for clamps and recoveries, `push_error` for failures. There is no remote logging (no analytics in the MVP).

---

## 19. Testing strategy

**Framework: GUT (Godot Unit Test) for Godot 4**, installed into `res://addons/gut/` and excluded from export presets. It is pure GDScript, needs no extra runtime, and runs headless in CI or from the command line:

```
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Commit a `.gutconfig.json` with these settings. Every phase from Phase 0 onward must leave the suite green (CLAUDE.md §11).

**Test doubles (only these three):**
- `tests/helpers/fake_clock.gd`: `FakeClock extends GameClock`, with settable `now_ms` and `mono_ms`, and `advance(ms)`.
- `tests/helpers/failing_save_file_io.gd`: `FailingSaveFileIO extends SaveFileIO`, which fails on demand.
- `tests/helpers/state_factory.gd`: builds `GameState`s (for example "one chicken, hunger 50, coop L2").

Unit tests use `tests/fixtures/balance_fixture.json`, never the live `balance.json`.

| Test file | Covers (CLAUDE.md §11 minimum list in bold) |
|---|---|
| `unit/test_production_rules.gd` | **Production calculations**: fed progress; hunger runs out mid-interval; starving makes no progress; pause at 1.0; building multipliers; tutorial boost; **split invariance (1 × 8 h == 28,800 × 1 s == random splits)** |
| `unit/test_feeding_rules.gd` | 1 feed per meal, +50 clamped to 100, no feed, full (OPEN switch on and off), debounce key |
| `unit/test_economy_rules.gd` | **Economy calculations**: prices, missing coins, sale total with Market bonus and rounding, sell all, feed pack vs storage cap (OPEN switch), unlock level |
| `unit/test_building_rules.gd` | **Capacity rules**, **upgrade calculations**: housed count, full, next upgrade cost, max level, effects per level |
| `unit/test_inventory_state.gd` | **Inventory operations**: add, remove, never negative, unknown keys kept |
| `unit/test_offline_rules.gd` | **Offline progression**: 8 h cap, clock backwards = 0, modal threshold strictly > 5 min, nothing produced → no modal, hungry animals produce nothing, already-ready animals not counted |
| `unit/test_status_rules.gd` | Flag thresholds, bubble priority |
| `unit/test_progression_rules.gd` | Level from XP, unlocks (with fixture values, since live values are inert) |
| `unit/test_save_codec.gd` | **Save/load**: encode/decode round trip is lossless; unknown fields preserved at root, wallet, bag, settings, building and animal level; unknown species kept; clamps; structural damage → DAMAGED; too new; missing buildings added |
| `unit/test_save_migrator.gd` | Migration chain (empty in v1; structure test plus a fake v0 → v1 step in the test only) |
| `unit/test_balance_data.gd` | Live `balance.json` loads and `validate()` returns no problems; 3 levels per building; non-decreasing costs |
| `unit/test_theme_tokens.gd` | Theme colours and radii match `UiTokens` |
| `integration/test_save_file_io.gd` | Atomic write; backup kept (exactly one); corrupt main → backup; leftover tmp; quarantine on Start new farm. Uses `user://test_saves/<case>/` and deletes it afterwards |
| `integration/test_save_service.gd` | 2 s debounce (no restart), retry schedule, `persistence_enabled` guard (damaged file never overwritten) |
| `integration/test_game_commands.gd` | Full loop with `FakeClock`: buy → feed → wait → collect → sell; 300 ms lock blocks a double buy; sell rollback on `FailingSaveFileIO`; collect_offline_reward credits once; `lastSeen` equals the advance time after save |

**Not automated in the MVP:** layout, animation and touch feel. These are checked by running the game (CLAUDE.md §5 step 6) and in Phase 10 on devices. One smoke test, `integration/test_main_boots.gd`, instances `main.tscn` with a temporary `user://` directory and asserts it reaches `MENU` without errors.

---

## 20. Naming conventions

| Thing | Convention | Example |
|---|---|---|
| Files and folders | `snake_case` | `animal_instance.gd`, `buy_animal_dialog.tscn` |
| Classes (`class_name`) | `PascalCase`, matches the file name | `AnimalInstance` in `animal_instance.gd` |
| Autoload names | `PascalCase`, no `class_name` in the script | `Game`, `SaveService`, `Nav`, `AudioService` |
| Scene root node | `PascalCase`, matches the class | `AnimalSheet` |
| Child nodes | `PascalCase`, descriptive | `FeedButton`, `HungerBar` |
| Functions, variables | `snake_case`; private with a leading `_` | `feed_animal()`, `_advance_to()` |
| Signals | `snake_case`, past tense or `_changed` | `animal_fed`, `coins_changed`, `closed` |
| Signal handlers | `_on_<emitter>_<signal>` | `_on_game_coins_changed` |
| Constants | `UPPER_SNAKE_CASE` | `CURRENT_VERSION`, `COLOR_PRIMARY` |
| Enums | `PascalCase` type, `UPPER_SNAKE` members | `Overlay.Kind.SHEET` |
| Game ids (data) | lowercase `snake_case` strings | `chicken`, `egg`, `chicken_coop`, `feed_storage` |
| JSON keys (save and balance) | `camelCase`, as in the GDD §9 save sketch | `lastSeen`, `buildingId`, `cycleMinutes` |
| Translation keys | `UPPER_SNAKE`, screen prefix | `BAG_EMPTY_HEADLINE` |
| Species and building view scenes | `<id>_view.tscn` | `cow_view.tscn`, `pig_pen_view.tscn` |
| Tests | `test_<unit>.gd`, functions `test_<behaviour>` | `test_hungry_animal_makes_no_progress` |
| Units in names | `_ms` for milliseconds, `_seconds` for seconds | `last_seen_ms`, `cycle_seconds` |

---

## 21. Performance considerations

**Scale:** at most 12 + 6 + 9 = **27 animals** (all buildings at L3), 5 buildings, a few bubbles and tags. That is small for Godot's 2D renderer.

- **Target:** 60 fps on a three-year-old mid-range phone (DESIGN §9). The Compatibility renderer batches 2D draws. Animal art for a species shares one texture atlas, which keeps draw calls low.
- **Simulation cost:** 27 × a few float operations per 1 s tick, so negligible. There is no per-frame simulation.
- **`_process` usage:** only animal wandering, camera inertia and visual tweens. Views of offscreen or hidden animals (non-Farm tab) stop processing: `FarmWorld` sets `process_mode = PROCESS_MODE_DISABLED` on the world while `Nav.world_coverage_changed(true)`. Ambient animations are limited to 2 at once by `AmbientBudget` (DESIGN §9 rule 3) in Phase 9.
- **Pooling:** none for animals or buildings (there are few, and they live a long time). Particles use `CPUParticles2D` (Compatibility renderer), with the DESIGN caps: max 20 confetti, max 8 coin sprites. Coin-flight sprites and floaters come from a small reusable pool (8) owned by the HUD and FarmWorld, because sell and collect-all can fire bursts.
- **Saves:** the JSON is a few KB. A synchronous write on the main thread takes milliseconds. No threading.
- **Startup:** catalog parse and save load are synchronous and small. The Splash exists for presentation and the 8 s slow-load path, not because loading is heavy.
- **Battery:** `application/run/max_fps = 60`. When nothing animates (pushed screen open), Godot still renders. Phase 10 measures this and may enable `OS.low_processor_usage_mode` only on menu screens.
- **Memory:** overlays are freed on close. Tab roots stay resident (4 lightweight screens).

---

## 22. Extensibility for future features (hooks only — nothing below is built)

GDD §10 is **Future / Not MVP**. This architecture only avoids blocking it:

| Future need | Already accommodated by |
|---|---|
| Traits, genetics, rarity on animals | `AnimalInstance.extra` preserves unknown keys; `SaveMigrator` adds typed fields later without rewriting old saves (GDD §10 "Data model readiness") |
| New species, products, buildings | Data-driven `GameCatalog`; views found by `<id>_view.tscn`; bag keyed by product id; Market rows and filter chips come from `catalog.animal_ids()`. **No code assumes exactly three animals** |
| Breeding (two animals in the same building) | `buildingId` on every animal; `BuildingRules.housed_count` |
| Sickness and health | `health` is saved and clamped; `StatusRules` uses bit flags, so a `SICK` flag can be added; status-bubble logic is in one function |
| Multiple buildings of one kind | `BuildingInstance.id` is separate from the definition; an additive `type` field later |
| Downgrade or newer save | `TOO_NEW` is never overwritten; unknown species and buildings are kept, not dropped |
| Reserved UI room (breed row, traits block, chip lane, "More" tab, "Special" segment) | Screens use VBox/HBox containers, so later additions append below or beside without moving MVP buttons (DESIGN §6 rule 10). **No hidden placeholder nodes are added in the MVP** |
| Variants recolour | Art guideline only (DESIGN §7). No shader or param system is built |
| Premium currency | `UiTokens.COLOR_GEM` constant only. Nothing in state, save or UI |

---

## 23. OPEN items and where each lives in code

Each item is built with the design doc's recommended default (or an inert value), in exactly one place, and must be confirmed by the owner. Copy this list into `docs/PROGRESS.md` "Known issues".

| # | OPEN item (source) | Single decision point | Built default |
|---|---|---|---|
| 1 | Hunger / happiness bubble thresholds (GDD §4) | `balance.status.hungryBelow`, `lowHappinessBelow` | 30 / 30 |
| 2 | Progress at 1.0 when uncollected (GDD §4) | `balance.production.pauseWhenReady` + `ProductionRules.advance_animal` | Pause (1 stored product) |
| 3 | Happiness gain and decay numbers (GDD §4) | `balance.happiness.*` | **Inert 0** — needed before Phase 3 can show low happiness |
| 4 | Animal name pool and rename limit (GDD §4, UI_SPEC §5) | `balance.animals.*.defaultNames`, `balance.names.maxLength`; `rename_dialog` | Examples Mimi/Pip; 12 chars |
| 5 | Starting state of buildings (GDD §6) | `balance.buildings.*.startsBuilt` | All five at L1 |
| 6 | Feed pack overflowing storage (GDD §6) | `balance.economy.refuseOverflowingFeedPack` + `EconomyRules.check_buy_feed_pack` | Refuse the whole pack, "Storage is full" |
| 7 | Market bonus rounding (GDD §7) | `EconomyRules.sale_total` | Round total half up |
| 8 | Animal sell-back (GDD §7) | — | Not built |
| 9 | XP sources and level thresholds (GDD §8) | `balance.progression.*` + `ProgressionRules` | **Inert 0** — the player stays at level 1, so Pig and Cow stay locked. Needs values before Phase 5's unlocks can be playtested |
| 10 | Coins row in the Offline Reward (GDD §9) | `Game.collect_offline_reward` + `OfflineReport.coin_value` | Display only, not credited |
| 11 | "Full" caption at hunger 100 (UI_SPEC §6) | `balance.feeding.blockWhenFull` + `FeedingRules.check_feed` | Disabled with "Full" |
| 12 | Damaged-save dialog copy (UI_SPEC §12.3) | `strings.csv` | "Start a new farm?" / "Your old farm is kept as a backup." / Cancel / Start new |
| 13 | Out-of-feed toast wording (UI_SPEC §15) | `strings.csv` `TOAST_OUT_OF_FEED` | "Out of feed. Buy more at the market." |
| 14 | Segmented control and chip styling (UI_SPEC §17.17) | Theme type variations `Segment`, `Chip` | UI_SPEC recommendation |
| 15 | Minimum supported size (DESIGN §12) | `ScreenFit` clamp | 360 x 640 dp |
| 16 | (arch) Bubble priority when several statuses apply | `StatusRules.primary_bubble` | READY > FEED > CLOUD |
| 17 | (arch) Auto-load the backup when main is damaged | `Main` boot step on `LoadResult.source` | Auto-load the backup |

---

## 24. Ambiguities found while writing this document (not marked OPEN in the design docs)

These are recorded for owner review. The architecture handles each in one place so the answer can change cheaply.

1. **Selling vs. save failure.** UI_SPEC §9 says a sale that cannot be saved is rolled back ("Could not sell. Try again"). GDD §9 says save failures show a banner and play continues. Built: sells save synchronously and roll back on failure (the specific rule wins for sells); everything else follows GDD §9.
2. **Offline reward size under "pause at 1.0".** With the recommended pause rule (OPEN #2), an animal makes at most one product while away, however long the absence. That makes the 8 h cap and "You were away 3 h 20 min" mostly cosmetic. The GDD's offline section reads as if longer absences give more. Resolving OPEN #2 resolves this.
3. **Hunger keeps decaying while a product waits uncollected** (GDD §4 says decay is about 1%/min, unconditionally). Under the pause rule, an uncollected product therefore wastes food. Built as written.
4. **`settings.language` is missing from the GDD §9 save sketch** but Language is an MVP setting (GDD §3, UI_SPEC §18.4). It is added as an additive key. Which languages are supported is not specified; only `en` ships.
5. **Splash → Farm auto-continue vs. Main Menu "Continue farm is primary".** UI_SPEC §1 sends returning players from Splash straight to the Farm, but §18.2 describes Continue as the primary button after first launch. Built: an OK save goes straight to the Farm; the Main Menu appears on first launch and for a damaged save. When a returning player would see Continue is unclear.
6. **Tutorial skip grant.** "Skipping grants the same 150 starting coins" (GDD §8, UI_SPEC §14). It is unclear whether coins are added on skip (possibly mid-tutorial, after spending) or whether skippers simply keep the normal starting balance. Decided in `TutorialRules.skip_grant()` alone. Built default: no extra coins on skip (everyone already starts with `start.coins` = 150). `balance.tutorial.skipGrantCoins` exists only so the other reading (add 150 on skip) is a one-line change. Confirm.
7. **CLAUDE.md phases vs. GDD.** Phase 1 "Building placement foundation" and Phase 6 "Construction" have no counterpart in GDD/UI_SPEC (no player placement, no build flow; buildings exist at L1). Built as authored slots plus level upgrades only. Tutorial, XP/levels, Settings and Main Menu are MVP features that CLAUDE.md does not assign to any phase. Suggested: Main Menu, Splash and Settings in Phase 0/7 (they depend on save), XP gating in Phase 5, tutorial after Phase 8.
8. **Back-to-exit window.** UI_SPEC gives the "Press back again to exit" toast but no time window. The 2.2 s toast duration is used.
9. **Retries after 60 s.** GDD §9 lists 5/15/60 s retries but not what happens after the third. Built: no more timed retries; the next trigger tries again and the banner stays.
10. **"Saved" toast.** It is listed as approved, but showing it on every 2 s autosave would contradict "avoid clutter" (GDD §1). Shown only for Settings > Save now.
11. **Tab switch with an overlay open** is unspecified. Built: non-blocking overlays close.
12. **Number abbreviation at 10,000 and above** is unspecified. Built: never abbreviate.
13. **Engine capability gaps (verify in Phase 0 / 10):** reading the OS reduced-motion setting and OS font scale (DESIGN §3, §9), and screen-reader labels and announcements (UI_SPEC §19), are not exposed uniformly by Godot 4.x core on Android and iOS. They may need the engine's accessibility support (version-dependent) or a small platform plugin. Accessibility labels are still set on every icon button (`accessibility_label`) so they can be wired up once supported.
14. **Animal Details "pushed onto the Animals tab stack"** (UI_SPEC §5) but it is also reached from the sheet on the Farm tab. Built: one global overlay stack, so Back returns to wherever the player came from, which is what UI_SPEC §5 asks for.

---

## 25. Architecture decisions (ADR log)

| # | Decision | Rationale | Trade-off accepted |
|---|---|---|---|
| ADR-01 | Single persistent root scene; screens and overlays instanced into `AppShell` hosts | The farm must stay alive under sheets and across tabs; one overlay stack is required for back handling | Main scene owns more; no `change_scene` simplicity |
| ADR-02 | Four autoloads only (`Game`, `SaveService`, `Nav`, `AudioService`) | Each holds global state or timers that must outlive scenes; everything else is pure or owned | `Game` is the largest file; kept manageable by moving all math into `rules/` |
| ADR-03 | Pure static rule classes for all math | Directly enables CLAUDE.md §11's test list without scenes or mocks | Slightly more parameter passing |
| ADR-04 | Balance and definitions in one `balance.json`, parsed into typed `RefCounted` definitions | GDD: one tunable data file; typed access in code | No editor inspector for balance; edit JSON by hand |
| ADR-05 | Presentation data (sprite size, tap zone, walk speed) on per-id view scenes found by naming convention | Keeps balance free of art concerns; new species = data + scene, no code | Convention must be followed exactly |
| ADR-06 | Snapshot semantics: state is valid at `lastSeen`; every command and save advances to now first | Makes offline progression the same code as online (GDD §9 rule 3) and makes crash recovery automatically consistent | Must never mutate without `_advance_to` first (enforced by command pattern + tests) |
| ADR-07 | 1 s wall-clock `Timer` tick; no per-frame simulation | CLAUDE.md §8: FPS-independent; cheap | Status transitions can lag up to 1 s (invisible at 3 to 10 minute cycles) |
| ADR-08 | Offline reward delivered by running normal `collect` on animals that became ready while away; no separate pending-reward record | No duplicate logic; GDD §9 rule 7 is met by the snapshot model | Reward is defined by animal state, so it depends on OPEN #2 |
| ADR-09 | `lastSeen` as integer UTC epoch milliseconds | Exact in JSON, no parsing or time-zone issues | Not human-readable in the file |
| ADR-10 | Copy-then-rename atomic save with one backup; damaged files quarantined, never auto-overwritten | GDD §9; main file always present | Two writes per save (trivial at this size) |
| ADR-11 | Unknown JSON fields preserved via `extra` on every state object | GDD §9/§10 future fields without migration rewrite | Small amount of bookkeeping code in `from_dict`/`to_dict` |
| ADR-12 | Domain state objects have no signals; `Game` is the single emitter | One place to observe all changes; state stays plain data and is trivially serializable | Views filter by id |
| ADR-13 | 300 ms commit lock enforced in the domain (`ActionGuard`) and mirrored in the UI | Double-spend prevention is testable and cannot be bypassed by a new button | Two places to keep in step (shared value from balance) |
| ADR-14 | Hand-authored Theme `.tres` + `UiTokens` constants, checked by a sync test | Godot-native (editor previews work); one source for code-driven values | Two artefacts; drift caught by test, not prevented |
| ADR-15 | Compatibility renderer, `canvas_items` stretch, runtime `ScreenFit` density fit | Broad Android support; real dp sizing so touch minimums hold on 360 x 640 | Density detection must be verified per platform in Phase 10 |
| ADR-16 | GUT for tests, with a frozen fixture balance | Pure GDScript, headless CLI; tuning never breaks tests | Dev-only addon in the repo |
| ADR-17 | Authored building slots instead of a placement system | GDD has a fixed set of five buildings and no placement feature | Adding free placement later would need a new system (not planned) |
| ADR-18 | Every OPEN rule isolated behind a data flag or single function, built with the recommended default | Lets implementation proceed without silently fixing design decisions (CLAUDE.md §3, §19) | Some switches may become dead config once decided; remove them then |
