## Design Status

* Status: COMPLETE

### Design Artifacts

* docs/GDD.md
* docs/DESIGN.md
* docs/UI_SPEC.md
* docs/ARCHITECTURE.md

### Implementation Status

* Status: **Phase 0 COMPLETE**; **Phase 1 COMPLETE**; **Phase 2
  COMPLETE**; **Phase 3 COMPLETE**; **Phase 4 COMPLETE**; **Phase 5
  COMPLETE**; **Phase 6 COMPLETE**; **Phase 7 COMPLETE**; **Phase 8
  COMPLETE**; **Phase 9 COMPLETE**; **Phase 10 COMPLETE for the
  environment-achievable scope** (see "Phase 10 — Mobile Validation"
  below; real device/build validation remains for the project owner).
  All CLAUDE.md-defined phases (0-10) are now addressed.
* Godot version: **4.7.2.stable.official** (installed via `winget install
  GodotEngine.GodotEngine` into this environment; was not present
  beforehand — see Environment setup below).
* GUT version: **9.6.1** (vendored into `addons/gut/`, downloaded from
  `https://github.com/bitwes/Gut/releases/tag/v9.6.1`, MIT licensed).

---

## Phase 0 — Foundation

### Environment setup (this session)

Godot 4.x and GUT were not available at the start of this task. Both were
real gaps, not architecture problems, and both were resolved without
changing anything about the approved design:

* **Godot**: installed via `winget install --id GodotEngine.GodotEngine
  --exact` → 4.7.2 (stable, non-Mono build — correct for a GDScript-only
  project). Executable:
  `C:\Users\LocNguyen\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.
* **GUT**: the real v9.6.1 release archive was downloaded from GitHub and
  its `addons/gut/` folder was vendored in whole (127 files). No mock or
  substitute test runner was created. The plugin is enabled in
  `project.godot` under `[editor_plugins]`.

### What was implemented

* Godot project setup: `project.godot` configured per `docs/ARCHITECTURE.md`
  Section 2 (viewport 390x844, `canvas_items` stretch, `expand` aspect,
  portrait orientation, `gl_compatibility` renderer, static-typing warnings
  as errors, custom theme path, GUT plugin enabled). A placeholder
  `icon.svg` was added since none existed (temporary art, per CLAUDE.md
  Section 10).
* Folder structure: the full tree from `docs/ARCHITECTURE.md` Section 3
  was created. Only the folders Phase 0 actually populates have files in
  them; the rest are empty, reserved for their owning phase.
* Main scene: `scenes/main/main.tscn` + `main.gd` — boots, applies
  `ScreenFit`, shows the Phase 0 component demo, and stubs the Android
  back notification as a documented no-op until `Nav` exists.
* Mobile portrait configuration: `scenes/main/screen_fit.gd` (`ScreenFit`)
  fits the logical (dp) size on mobile using the device's reported DPI,
  and deliberately does **not** touch `content_scale_size` on desktop
  (see Bugs found and fixed below for why).
* Basic theme: `ui/theme/ui_tokens.gd` (`UiTokens`), `ui/theme/
  farmora_theme.tres` (Button/Label/PanelContainer type variations for
  the Phase 0 component set), `ui/theme/motion.gd` (`Motion`).
* Design system foundation + basic reusable UI components (scope limited
  to four components per the approved plan): `FarmButton`, `IconButton`,
  `Toast` + `ToastHost`.
* Initial test infrastructure: `.gutconfig.json`, and three test scripts
  (`tests/unit/test_theme_tokens.gd`, `tests/unit/test_screen_fit.gd`,
  `tests/integration/test_main_boots.gd`), all passing — see Verification
  results below.
* Font fallback: no licensed Fredoka/Nunito font files were present.
  `farmora_theme.tres` uses Godot's built-in default font; the swap-in
  procedure is documented in `assets/fonts/README.md`.

### Bugs found and fixed during verification

Verification was not a rubber stamp — running the real engine surfaced
three genuine implementation defects, all fixed and re-verified:

1. **Theme type variations never registered.** The hand-authored
   `farmora_theme.tres` used `BaseType/VariationName/category/item` keys
   (e.g. `Button/PrimaryButton/styles/normal = ...`), which looked
   reasonable but is not how Godot 4 actually links a variation name to
   its base type. Confirmed by round-tripping a real `Theme` built via
   `Theme.set_type_variation()` through `ResourceSaver`: the correct,
   and only, serialized form is a flat `VariationName/category/item` key
   plus one `VariationName/base_type = &"BaseType"` line. Without it,
   every `PrimaryButton`/`SecondaryButton`/`IconButton`/etc. variation
   silently fell back to Godot's built-in default Button style — caught
   by `test_theme_tokens.gd`, which failed 6/7 assertions with colors
   that were Godot's defaults, not this project's tokens. Fixed in
   `ui/theme/farmora_theme.tres`.
2. **Float-precision mismatch between the theme and `UiTokens`.** After
   fixing (1), one assertion still failed:
   `SecondaryButton`'s fill printed as equal to the expected color but
   compared unequal. Cause: `Color("#FFC53D")` in `ui_tokens.gd` and the
   hand-typed `Color(1, 0.772549, 0.23921569, 1)` in the `.tres` differ
   in the last couple of float digits (`.tres` text resources do not
   accept the `Color("#HEX")` string form — verified directly — so every
   color had to be retyped as a numeric literal). Fixed by dumping every
   relevant `UiTokens` color at full float precision from a live Godot
   process and using those exact values in the `.tres`, with a comment
   warning against re-truncating them.
3. **`ScreenFit` shrank the UI on desktop.** The mobile dp-fit formula
   (`window_px_size / (dpi / 160)`) was being applied unconditionally.
   On desktop, `DisplayServer`-reported DPI follows a different
   convention (commonly 96 = "100% scaling", not physical pixel
   density), and `project.godot`'s `canvas_items` stretch mode already
   keeps the window at the configured dp size (390x844) with no further
   correction needed. Running the mobile formula there inflated
   `content_scale_size` to ~1.67x the window size, shrinking every
   control to a fraction of its intended size. Caught by comparing a
   screenshot of the running project against the expected layout (first
   screenshot showed tiny, clustered controls instead of the demo
   layout). Fixed by branching on `OS.has_feature("pc")`: desktop leaves
   `content_scale_size` untouched; only non-desktop (mobile) runs the
   dp-fit math. Added a regression test
   (`test_apply_leaves_content_scale_size_untouched_on_desktop`).

None of these required any architecture or design change — all three
were implementation bugs in how the Phase 0 code was written, found and
fixed within Phase 0's existing scope.

### Verification results

**1. Godot project validation (headless import):**
`godot --headless --path . --import` — completed with **zero errors,
zero warnings**. All Phase 0 classes registered correctly: `ScreenFit`,
`FarmButton`, `IconButton`, `Toast`, `ToastHost`, `Motion`, `UiTokens`,
plus GUT's own classes (`GutMain`, `GutTest`, etc.).
→ **PASS** (IMPLEMENTATION, confirmed working)

**2. GUT test suite (post Codex-review fixes; see below):**
`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests
-ginclude_subdirs -gexit`

```
res://tests/integration/test_main_boots.gd   5/5 passed.
res://tests/unit/test_screen_fit.gd          8/8 passed.
res://tests/unit/test_theme_tokens.gd        7/7 passed.

Totals: Scripts 3, Tests 20, Passing 20, Asserts 33/33
---- All tests passed! ----
```
→ **PASS** (IMPLEMENTATION, confirmed working; grew from 16/16, 27/27 to
20/20, 33/33 after the Codex review fix batch added test coverage for
the iOS density path and a deeper boot-state assertion)

**3. Visual verification — 390x844 (iPhone 15 reference size):**
Screenshot of the running project: cream background, "Farmora" title,
subtitle, Primary button (Leaf green, white text, visible bottom edge),
Secondary button (Sun gold, dark text, visible bottom edge), Ghost
button (white, bordered), IconButton (circular, bordered). No clipping,
no overflow, no stray background color. Portrait layout and theme
render correctly.
→ **PASS**

**4. Visual verification — 360x640 (minimum supported size):**
Same layout, correctly scaled, fully visible, no clipping or overflow at
the documented minimum size.
→ **PASS**

**5. Interaction check — Toast:**
Simulated pressing the Secondary ("Sell") button; captured screenshot
shows the "Sold 12 eggs  +60 coins" success toast rendering correctly
(green pill, white text, rounded corners) per the approved copy in
`docs/UI_SPEC.md` Section 15. Confirms the `FarmButton` → signal →
`ToastHost.show_toast()` → `Toast` render pipeline works end to end.
→ **PASS**

**6. Fonts/fallback:** Godot's built-in default font renders at every
Phase 0 type variation's configured size (visually confirmed in both
screenshots above — title, subtitle, and button labels are all legible
and distinctly sized). The font **family** is the documented, replaceable
fallback (not Fredoka/Nunito yet) — this is expected per the Phase 0
approval constraints, not a defect.
→ **PASS (fallback behaving as designed)**

**7. Safe areas:** Not independently verified — `AppShell`'s safe-area
handling is explicitly later-phase scope (Section "What was implemented"
above), and Phase 0's `main.tscn` has no safe-area-dependent layout yet
to check. Not a Phase 0 regression; nothing to verify at this phase.

**No ENVIRONMENT FAILUREs remain.** Every verification step that could
be run, was run, against the real engine and the real test framework,
and passed.

### Known issues (Phase 0 scope only)

1. **Fredoka/Nunito font files are not yet in `assets/fonts/`.** The
   theme uses the Godot default font as a documented, replaceable
   fallback (see `assets/fonts/README.md`). Font family only; sizes are
   correct. Swap in before visual/UX review of later phases.
2. **Safe-area and tablet-centering logic is not yet exercised** because
   `AppShell` does not exist yet (later phase, as designed). Nothing to
   fix now.
3. **GUT 9.7.1 is available upstream** (this project vendors 9.6.1, the
   latest at the time of installation). Not urgent; note for a future
   deliberate upgrade rather than an unplanned one.
4. **Four OPTIONAL Codex review suggestions were deliberately deferred**
   (not implemented): deeper theme-token test coverage, independent
   width/height clamp aspect-ratio hardening in `ScreenFit`, a real icon
   texture for the demo's `IconButton`, and a more structural
   demo/boot-scene replacement boundary. None are defects against the
   approved design; see `docs/CODEX_REVIEW.md` for the full reasoning.
   Recorded here as future tasks, not current gaps.

### Remaining work

* Source and swap in the real Fredoka/Nunito font files when available.
* Continue following the per-phase plan; `AppShell`, safe areas, and the
  rest of the component inventory are explicitly out of Phase 0 scope
  and belong to later phases.

### Next action

* Phase 0 is complete. Begin Phase 1 (Farm) when ready.

---

## Phase 1 — Farm

### Scope and sequencing

CLAUDE.md's Phase 1 scope: Farm scene, Farm grid, Basic terrain, Camera,
Basic interaction, Building placement foundation. As with Phase 0,
`docs/ARCHITECTURE.md` Section 10.1 is the authoritative resolution for
what these phrases mean in code; two interpretations are recorded here
(the same pattern ARCHITECTURE.md Section 24 item 7 already uses):

* **"Farm grid" / "Basic terrain"** do not refer to a tile-grid farming
  mechanic — `docs/GDD.md` has none (its only "grid" mention is the
  Future/Not-MVP Collection grid in Section 10). They map to: the
  **authored world layout** (the 390-unit-wide world rect, the safe band,
  and the `BuildingSlots` positions) for "Farm grid", and the static
  **Backdrop** (sky/meadow/soil) for "Basic terrain".
* **"Building placement foundation"** — per ARCHITECTURE.md Section
  10.1's own explicit resolution, this is "spawning building views at
  authored slots from state, with no drag-to-place system". Phase 1
  builds the authored-slots half and the view-spawning mechanism;
  "from state" is necessarily partial until `Game`/`GameCatalog` exist
  (Phase 2+), so Phase 1's building views are spawned from the scene's
  own `BuildingSlots` children rather than from saved state. This is a
  temporary seam, not a deviation — the spawning *function* carries over
  unchanged into the later state-driven version.

Before implementing, a Plan-mode review (Opus) of the proposed task
breakdown caught a real, un-shipped bug: Phase 0's `ComponentDemo` sits
directly under `Main` as an opaque, full-rect `Control` whose background
`ColorRect` defaults to `mouse_filter = MOUSE_FILTER_STOP` (verified
directly against a running Godot process, not assumed) — this would
silently swallow all touch input before `FarmInput`'s `_unhandled_input`
ever saw it, once that task wires the farm scene in. That review also
caught an inverted horizontal-clamp case at 0.8x zoom (world narrower
than viewport — must center, not clamp), the need to keep tap-vs-drag
ownership entirely in `FarmInput` (not split with `FarmCamera`, which
should expose a command API only), and several `OPEN (arch)` numbers
(double-tap timing, inertia decay shape, rubber-band stiffness) that
aren't specified anywhere in the design docs and will need a default
chosen and recorded when that task is implemented.

**Phase 1 task breakdown** (smallest logical units, implemented and
verified one at a time, per the approved process):

1. ✅ **Farm world scaffold** — DONE
2. ✅ **Wire `FarmWorld` into `main.tscn`** — DONE
3. ✅ **Building placement foundation** — placeholder `BuildingView` +
   scene-driven spawning at each `BuildingSlots` marker — DONE
4. ✅ **`FarmCamera`** — pan/inertia/zoom/rubber-band, command API — DONE
5. ✅ **`FarmInput`** — tap/drag/pinch hit-testing, intent signals — DONE
6. ✅ **Full verification pass** (GUT, headless, visual at both reference
   sizes) + Codex review of the completed phase — DONE (this update)

**Phase 1 — Farm: COMPLETE.**

Out of scope for all of Phase 1 (explicitly deferred to later phases):
`Game`, `SaveService`, `Nav`, `AudioService`, `GameCatalog`/definitions,
runtime state classes, `AnimalView`, world-space UI indicators (tags,
bubbles, badges, floaters), `WanderArea`, `AmbientBudget`, parallax/cloud
drift (Phase 9 ambient animation).

### Task 1: Farm world scaffold — implemented

**Files added:**
* `scenes/farm/farm_world.gd` (`class_name FarmWorld`) — world rect and
  safe-band constants/static helpers (`world_rect()`, `safe_band_rect()`),
  `@onready` references to the scaffold's named containers.
* `scenes/farm/farm_world.tscn` — the node structure from
  ARCHITECTURE.md Section 4.1: `FarmCamera` (plain `Camera2D`, no script
  yet — task 4), `Backdrop` (three `Polygon2D` layers: Sky, Meadow, Soil,
  each extending past the authored world rect per DESIGN.md Section 12
  rule 4 "the meadow background extends to the edges"), `BuildingSlots`
  (5 `Marker2D` children, named and positioned for the MVP buildings:
  `chicken_coop`, `cow_barn`, `pig_pen`, `feed_storage`, `market`),
  empty `Buildings`/`Animals` containers (both `y_sort_enabled`), empty
  `WorldUi`, and a plain `FarmInput` `Node` placeholder (no script yet —
  task 5).
* `tests/unit/test_farm_world.gd` — 6 tests: scene structure matches the
  architecture, y-sort is enabled on Buildings/Animals, all 5 MVP
  buildings have authored slots (and no extras), every slot sits inside
  the safe band, the world rect encloses the safe band, and the backdrop
  genuinely extends past the world rect on all three layers.

**A real bug was caught before it was ever a bug**: `Polygon2D` (a
`Node2D`-space primitive) was used for the Backdrop layers instead of
`ColorRect` (a `Control`), because `Control` nodes placed under a
`Node2D` parent use screen-space anchor/offset semantics, not world-unit
positioning — confirmed by reasoning through Godot's layout system before
writing the `.tscn`, not discovered by trial and error.

### Verification results (Task 1 only)

1. **Headless import**: zero errors, zero warnings.
2. **GUT suite**: all passing —
   ```
   res://tests/integration/test_main_boots.gd   5/5 passed.
   res://tests/unit/test_farm_world.gd          6/6 passed.
   res://tests/unit/test_screen_fit.gd          8/8 passed.
   res://tests/unit/test_theme_tokens.gd        7/7 passed.

   Totals: Scripts 4, Tests 26, Passing 26, Asserts 68/68
   ---- All tests passed! ----
   ```
3. **Visual check**: `farm_world.tscn` instantiated standalone (not yet
   wired into `main.tscn` — that's task 2) and screenshotted at 390x844.
   Sky and meadow backdrop render in the correct DESIGN.md colors
   (`#CBEBFF` sky, `#A9DB8A` meadow). The camera shows no proper framing
   yet (expected — `FarmCamera`'s `fit_zoom` logic is task 4's scope; the
   scene currently has a plain, scriptless `Camera2D`). `Marker2D` slots
   are correctly invisible at runtime (they are position anchors, not
   renderable nodes — building *views* don't exist until task 3).

### Task 2: Wire `FarmWorld` into `main.tscn` — implemented

**Composition change:**
* `scenes/main/main.tscn` — the single child under `Main` changed from
  `ComponentDemo` (Phase 0's UI demo) to `FarmWorld` (the Phase 1 farm
  world scaffold from Task 1). `unique_name_in_owner = true` preserved
  on the new child, matching the existing convention.
* `scenes/main/main.gd` — removed the `@onready var _demo: Control =
  %ComponentDemo` reference (Main must not reach into FarmWorld's
  internals; FarmWorld owns its own content per
  docs/ARCHITECTURE.md Section 10.1). `_ready()` still only calls
  `ScreenFit.apply(get_window())`; nothing else changed. Doc comments
  updated to state the ownership rule explicitly: Main owns
  application-level composition (what is shown, when); it does not own
  farm-world content or behavior.
* **Deleted** (no longer referenced anywhere in production code):
  `scenes/main/component_demo.gd`, `scenes/main/component_demo.tscn`,
  and the stray `component_demo.gd.uid`. The component's own Phase 0
  header already documented it as "deleted or replaced once Phase 1+
  introduces the real ... Farm screens" — this was not a new decision,
  it was carrying out one already made. The four Phase 0 UI components
  it demonstrated (`FarmButton`, `IconButton`, `Toast`, `ToastHost`) are
  untouched; only the standalone demo scene that showcased them is gone.

**Architecture compliance check (per the task's explicit requirements):**
Main owns composition only; FarmWorld owns farm-world content; no
FarmCamera/FarmInput/building-spawning/animal/economy/save logic was
introduced. Verified by re-reading the diff against
docs/ARCHITECTURE.md Section 4.1's `Main -> FarmWorld` tree before
finalizing.

**Test changes:** `tests/integration/test_main_boots.gd` rewritten.
Removed the three tests that asserted `ComponentDemo`/`IconButton`/
`ToastHost` presence (no longer true — those nodes aren't in `main.tscn`
anymore). Added `test_farm_world_is_present` (asserts the child is a
`FarmWorld` instance) and `test_main_does_not_own_farm_world_internals`
(a structural check that `main.gd`'s source never references
`%Backdrop`/`%BuildingSlots` directly, enforcing the ownership rule
above so a future edit can't silently violate it). Kept
`test_main_instantiates_without_error` and
`test_main_boot_leaves_a_sane_window_state` unchanged.

### Verification results (Task 2)

1. **Headless import**: zero errors, zero warnings.
2. **GUT suite**: all passing —
   ```
   res://tests/integration/test_main_boots.gd   4/4 passed.
   res://tests/unit/test_farm_world.gd          6/6 passed.
   res://tests/unit/test_screen_fit.gd          8/8 passed.
   res://tests/unit/test_theme_tokens.gd        7/7 passed.

   Totals: Scripts 4, Tests 25, Passing 25, Asserts 68/68
   ---- All tests passed! ----
   ```
   (Test count dropped from 26 to 25: 3 ComponentDemo-based tests
   removed, 2 FarmWorld-based tests added, net -1; asserts held steady
   at 68 since the new tests assert similarly-sized checks.)
3. **Visual check**: `main.tscn` instantiated and screenshotted at
   390x844. Output is pixel-identical to Task 1's standalone
   `farm_world.tscn` screenshot (sky/meadow backdrop, no
   `ComponentDemo` residue, no composition errors) — exactly the
   expected result for a pure re-wiring task with no new visual content.

**No issues discovered** beyond what Task 1's planning review already
caught and this task resolved (the `ComponentDemo` input-eating
conflict no longer exists, since the scene it would have conflicted
with is deleted).

### Task 3: Building placement foundation — implemented

**Files added:**
* `scenes/farm/buildings/building_view.gd` (`class_name BuildingView
  extends Node2D`) — the base building presentation per
  docs/ARCHITECTURE.md Section 3 and the `AnimalView` pattern in Section
  9.3, adapted for buildings per Section 10.1. Holds only `building_id`
  (set via `bind(id)`); no signals, no economy/production/upgrade logic,
  no input handling. `bind()` selects a body tint from a small
  `id -> Color` table using the five MVP buildings' primary colors from
  docs/DESIGN.md Section 8 (Chicken Coop `#D9A066`, Cow Barn `#C94A32`,
  Pig Pen `#B07D4F`, Feed Storage `#F1D9A0`, Market `#C94A32`), falling
  back to a neutral gray (`#CCCCCC`) for any unrecognized id so an
  unexpected id cannot crash the view. `tap_rect()` returns a fixed
  72x72 `Rect2` in global coordinates, centered on the view's
  `global_position`, per docs/DESIGN.md Section 5's building touch-target
  minimum — added now so Task 5 (`FarmInput`) can hit-test buildings
  later; no input handling is wired up in this task.
* `scenes/farm/buildings/building_view.tscn` — the scene for the above
  script. The placeholder body is a single `Polygon2D` named `Body`
  (unique-named, world-space, matching the Backdrop pattern from Task 1
  — no `ColorRect`/`Control` nodes were used). **Shape decision:** an
  8-vertex octagon (a square with ~12-unit corners cut) rather than a
  plain rectangle, as a cheap approximation of DESIGN.md's "rounded blob"
  shape language (true Bezier corner rounding on a `Polygon2D` placeholder
  was judged more complexity than a Phase 1 placeholder warrants). Sized
  exactly 72x72 (its bounding box), i.e. the design's minimum building
  tap-zone size, since there is no per-building sizing data yet to justify
  varying each placeholder's size (DESIGN.md's "largest"/"only tall
  building" hints for Cow Barn and Feed Storage describe final art
  proportions, not a placeholder requirement, and introducing size
  variation now with no real art to match it against risked inventing
  detail beyond the approved design). All five buildings currently render
  as this same shape, distinguished only by `bind()`'s body tint.

**Files changed:**
* `scenes/farm/farm_world.gd` — added `_ready()` (calls
  `_spawn_building_views()`) and `_spawn_building_views()`: iterates
  `building_slots.get_children()`, and for each `Marker2D` instances the
  base `building_view.tscn` (there are no per-id override scenes yet, so
  every building uses the base view per the architecture's own fallback
  rule), parents it under `buildings` (never under `building_slots`,
  which stays empty position anchors), copies the slot's authored
  `position` exactly, and calls `view.bind(String(slot.name))` (the
  slot's node name is the building id). Written so swapping the
  iteration source to real `BuildingInstance` state is the only change a
  later phase needs to make here (per this section's own forward-compat
  note above). No animal spawning, economy, production, save, or upgrade
  logic was added; `FarmInput` and `FarmCamera` placeholders were left
  untouched.
* `tests/unit/test_farm_world.gd` — appended 5 tests (existing tests and
  `before_each()` unchanged):
  * `test_buildings_container_has_one_view_per_mvp_building`
  * `test_every_building_child_is_a_building_view`
  * `test_spawned_building_views_match_their_slot_id_and_position`
  * `test_every_building_view_tap_rect_is_at_least_72_by_72`
  * `test_building_views_are_not_parented_under_slots_or_farm_world`

### Verification results (Task 3)

1. **Headless import**: zero errors, zero warnings. `BuildingView` and
   `FarmWorld` both registered correctly as global classes.
2. **GUT suite**: all passing —
   ```
   res://tests/integration/test_main_boots.gd   4/4 passed.
   res://tests/unit/test_farm_world.gd          11/11 passed.
   res://tests/unit/test_screen_fit.gd          8/8 passed.
   res://tests/unit/test_theme_tokens.gd        7/7 passed.

   Totals: Scripts 4, Tests 30, Passing 30, Asserts 111
   ---- All tests passed! ----
   ```
   (Test count grew from 25 to 30: 5 new BuildingView/spawning tests
   added to `test_farm_world.gd`; no existing test was changed or
   removed.)

3. **Independent re-verification** (by the main session, not taken on
   the implementing agent's self-report): re-read every changed/created
   file directly, then re-ran both the headless import check and the
   full GUT suite from a clean shell — confirmed the same 30/30 tests,
   111/111 asserts, zero errors/warnings. Also independently captured
   and visually inspected a screenshot of `main.tscn` at 390x844: all 5
   placeholder buildings render as octagons tinted per DESIGN.md Section
   8's colors, positioned exactly at their Task 1 authored slot
   coordinates.

**One minor visual finding** (not a Task 3 defect — a pre-existing Task
1 authoring choice, newly visible now that buildings actually render):
the `cow_barn` slot sits at `y=260`, only 40 units above the Sky/Meadow
boundary at `y=300`. With a 72-unit-tall placeholder (36 half-height),
its body visually straddles the horizon, appearing to float partly in
the sky. The safe-band test (`y: 140-738`) does not catch this because
it only guards HUD/nav clearance, not the sky/meadow line — a
different concern entirely, so the test is not wrong, it just never
claimed to check this. Task 3's instructions were explicit to preserve
Task 1's authored positions and not invent a new placement system, so
this was not changed here. **Tracked as a future task**: nudge
`cow_barn`'s authored `y` position down slightly (or re-check all five
slots against both the safe band and the horizon line together) next
time `farm_world.tscn`'s `BuildingSlots` positions are touched —
cosmetic only, does not block Task 3 or Phase 1.

### Task 4: `FarmCamera` — implemented

**Files added:**
* `scenes/farm/farm_camera.gd` (`class_name FarmCamera extends Camera2D`)
  — a **command API only**, per the Phase 1 planning review's correction
  made before Task 1 was ever written: this node has no
  `_unhandled_input` of its own. `FarmInput` (Task 5) will own tap-vs-drag
  discrimination and pinch detection and drive this camera by calling its
  public methods (`begin_drag()`, `drag_by(screen_delta)`,
  `end_drag(release_velocity)`, `zoom_about(factor, screen_point)`,
  `reset_zoom(duration)`, `focus_on(world_pos, duration)`), exactly the
  signature set the planning review specified. `fit_zoom()` is computed
  from the live logical viewport width (not the 390 project-setting
  constant), so it stays correct after `ScreenFit` adjustments and on
  tablets. Inertia decays over 400 ms in `_process()` (visual only, never
  touches game state — there is none yet). Rubber-band overshoot and
  `focus_on`/`reset_zoom` animation easing reuse Phase 0's existing
  `Motion` helper rather than inventing new curves.

  **The horizontal-inversion case the planning review flagged was
  handled, not just acknowledged**: at the most-zoomed-out level (0.8x
  fit_zoom), the visible world width exceeds the 390-unit authored
  world, so a normal `[min, max]` position clamp would be inverted
  (`min > max`). Verified this by direct calculation before writing any
  code (every phone reference device in DESIGN.md's own table gives
  exactly 487.5 visible world units at 0.8x zoom, vs. the 390-unit
  world) — `compute_clamped_position()` detects this inversion on both
  axes independently and centers instead of clamping when it occurs.
  This is covered by its own test (see below), not left as an assumption.

* `tests/unit/test_farm_camera.gd` — 9 tests: `compute_fit_zoom`'s
  formula at the reference width, at a different device width, and its
  invalid-input fallback; `compute_clamped_position`'s horizontal
  centering when zoomed out past the world width, normal clamping when
  zoomed in, vertical centering when the viewport is taller than the
  world, and rubber-band overshoot actually extending past the hard
  clamp; plus two scene-level tests confirming `FarmWorld`'s `FarmCamera`
  child uses the new script and has a positive, uniform zoom after
  `_ready()`.

**Files changed:**
* `scenes/farm/farm_world.tscn` — attached `farm_camera.gd` to the
  existing `FarmCamera` node Task 1 already authored (no change to its
  authored starting `position`; `_ready()` now clamps that position
  through the same logic as everything else, so it's correct by
  construction rather than by coincidence).

**Explicitly not implemented** (per task scope): no `_unhandled_input`
on `FarmCamera` itself, no connection to `FarmInput` (still the empty
placeholder Task 1 left it as — Task 5's job), no pinch-about-point
visual implementation (the parameter exists on `zoom_about()` for a
stable Task 5 call signature, but is unused this task), no double-tap
detection (FarmInput's job; `reset_zoom()` only exists for it to call).

### Verification results (Task 4)

1. **Headless import**: zero errors, zero warnings.
2. **GUT suite**: all passing, including a fix for one deprecation
   warning caught during the first run (`wait_frames` →
   `wait_process_frames`, GUT 9.6.1's replacement API) —
   ```
   res://tests/integration/test_main_boots.gd   4/4 passed.
   res://tests/unit/test_farm_camera.gd         9/9 passed.
   res://tests/unit/test_farm_world.gd          11/11 passed.
   res://tests/unit/test_screen_fit.gd          8/8 passed.
   res://tests/unit/test_theme_tokens.gd        7/7 passed.

   Totals: Scripts 5, Tests 39, Passing 39, Asserts 124
   ---- All tests passed! ----
   ```
3. **Visual check**: `main.tscn` screenshotted at both 390x844 and
   360x640. At 390x844 (`fit_zoom = 1.0`, matching Task 1's authored
   camera position exactly), the render is pixel-identical to Task 3's
   screenshot — the expected result, since nothing should visually
   change at the exact reference size. At 360x640 (`fit_zoom ≈ 0.923`),
   the world renders proportionally smaller with the shorter screen
   cropping sky at the top, per DESIGN.md Section 12 rule 2 — buildings
   remain fully visible and uncropped at both sizes.

**No issues discovered** beyond the one deprecation warning (fixed
immediately, not deferred).

### Task 5: `FarmInput` — implemented

**Files added:**
* `scenes/farm/farm_input.gd` (`class_name FarmInput extends Node`) —
  `_unhandled_input()` processes only `InputEventScreenTouch` /
  `InputEventScreenDrag`, never raw mouse events. This was deliberate,
  not an oversight: `project.godot`'s `emulate_touch_from_mouse = true`
  makes Godot deliver BOTH a synthetic touch event and the original
  mouse event per desktop click — verified this directly before writing
  the file (not assumed), since handling both event types would have
  double-fired every tap during desktop testing. Implements:
  - Tap-vs-drag at the 8 dp threshold, pinch-start detection on a second
    finger, a 400 ms long-press timer, and a 300 ms / 24 dp double-tap
    window (both values are genuinely unspecified by any design doc —
    OPEN (arch), see the table below — chosen from common platform
    double-tap conventions).
  - Generic, duck-typed hit-testing in priority order (bubbles → animals
    → buildings → ground, nearest-centre wins within a tier), over
    whatever tiers currently have real content. Per the Phase 1 planning
    review ("don't create stub view classes; that's Phase 2/4 work"),
    the bubble and animal tiers are empty lists on purpose — `AnimalView`
    and `StatusBubble` do not exist yet. Only the Buildings tier, wired
    to `FarmWorld.buildings`, has real targets in Phase 1.
  - Drives `FarmCamera`'s command API (`begin_drag`, `drag_by`,
    `end_drag`, `zoom_about`) — `FarmCamera` itself still has no
    `_unhandled_input`, exactly as Task 4 left it.
  - Emits all six intent signals ARCHITECTURE.md Section 10.1 names:
    `animal_tapped`, `bubble_tapped`, `building_tapped`, `ground_tapped`,
    `ground_double_tapped`, `animal_long_pressed`.

  **A real bug was found and fixed during testing, not assumed
  correct:** the first implementation cleared its pinch-tracking flag
  the moment touch count dropped below 2, so ending a two-finger pinch
  by lifting the *second* finger first let the remaining single-finger
  release fall through and fire a false `ground_tapped`. Caught by
  `test_two_touches_start_pinch_and_do_not_fire_ground_tapped`, fixed by
  adding a session-level `_gesture_was_multitouch` flag that persists
  until all fingers lift, not just while 2+ are simultaneously down.

* `tests/unit/test_farm_input.gd` — 13 tests covering tap/drag threshold
  discrimination, pinch-then-release ordering (the bug above), long
  press tier discrimination, hit-test priority and nearest-centre
  selection, double-tap counting and its interaction with the first
  single tap, and two scene-level tests confirming `FarmWorld` re-emits
  `building_tapped` and wires `ground_double_tapped` to
  `FarmCamera.reset_zoom()`.

  **A GDScript language quirk was discovered and had to be worked
  around, not guessed at:** an early draft of these tests used the
  pattern `var flag = false; signal.connect(func(): flag = true)` to
  observe signal emissions, which silently never worked — confirmed by
  a minimal reproduction that GDScript lambdas capture local variables
  **by value**, not by reference, so the lambda's `flag = true` mutates
  a private copy invisible to the outer scope. Rewrote every such test
  to use GUT's own `watch_signals()` / `assert_signal_emitted()` /
  `assert_signal_emitted_with_parameters()` / `assert_signal_emit_count()`
  API instead, which doesn't have this problem. Also discovered (the
  same way, by hitting a real crash) that
  `assert_signal_emitted_with_parameters`'s third positional argument is
  an emission **index**, not a display message — GUT's own source was
  read to confirm the real signature before fixing the one call site
  that had passed a `String` there.

**Files changed:**
* `scenes/farm/farm_world.gd` — added re-emission of all six FarmInput
  signals, and `_wire_farm_input()` (called from `_ready()`) which sets
  `FarmInput.camera`/`buildings_container` and connects
  `ground_double_tapped` to `FarmCamera.reset_zoom()` directly in
  `FarmWorld` (not inside `FarmInput`, which must not know about
  `FarmCamera`'s specific reset behavior) — exactly the wiring the
  Phase 1 planning review specified before Task 1 was written.
* `scenes/farm/farm_world.tscn` — attached `farm_input.gd` to the
  existing `FarmInput` placeholder `Node`; added `unique_name_in_owner`
  to both `FarmCamera` and `FarmInput` so `FarmWorld`'s `%FarmCamera`/
  `%FarmInput` references resolve.

**OPEN (arch) values chosen in this task** (unspecified by any design
doc, each isolated to one constant so the value can change without
touching logic elsewhere — the same pattern ARCHITECTURE.md uses for its
own OPEN items):

| Value | Chosen default | Where |
|---|---|---|
| Double-tap timing window | 300 ms | `FarmInput.DOUBLE_TAP_WINDOW` |
| Double-tap distance tolerance | 24 dp | `FarmInput.DOUBLE_TAP_DISTANCE` |

### Verification results (Task 5)

1. **Headless import**: zero errors, zero warnings. `FarmInput`
   registered correctly as a global class.
2. **GUT suite**: all passing —
   ```
   res://tests/integration/test_main_boots.gd   4/4 passed.
   res://tests/unit/test_farm_camera.gd         9/9 passed.
   res://tests/unit/test_farm_input.gd          13/13 passed.
   res://tests/unit/test_farm_world.gd          11/11 passed.
   res://tests/unit/test_screen_fit.gd          8/8 passed.
   res://tests/unit/test_theme_tokens.gd        7/7 passed.

   Totals: Scripts 6, Tests 52, Passing 52, Asserts 138
   ---- All tests passed! ----
   ```
3. **Visual check**: `main.tscn` screenshotted at 390x844 — pixel-identical
   to Task 4's screenshot, exactly as expected (input logic has no
   visual footprint of its own).
4. **End-to-end interaction smoke test** (beyond the unit tests, run
   directly against the real `main.tscn` composition, not an isolated
   fixture): simulated a tap at the Market building's screen position
   and confirmed `FarmWorld.building_tapped` fires with `"market"` —
   proving the full chain (`FarmInput` hit-test → signal → `FarmWorld`
   re-emission) works in the actual production scene, not just under
   test doubles.

**Issues discovered and fixed, not deferred:** the pinch-release-order
bug and the two test-authoring pitfalls (GDScript's by-value lambda
capture; `assert_signal_emitted_with_parameters`'s real signature) above.

### Task 6: Full verification + final Codex review — complete

**Verification (independent of any task-specific run, across the whole
phase):**
1. **Headless import**: zero errors, zero warnings.
2. **GUT suite** (before the Codex-found fix below): 52/52 tests,
   138/138 asserts.
3. **Visual check at both reference sizes**: `main.tscn` screenshotted
   at 390x844 and 360x640. Both render correctly — 5 tinted building
   placeholders at their authored positions, proportional world
   scaling between sizes, no clipping or cropped buildings.
4. **Full-phase Codex review** (codex-cli 0.158.0, read-only sandbox,
   covering all 5 tasks' files, explicitly told not to trust this
   progress report): 2 findings, full detail in `docs/CODEX_REVIEW.md`.
   - **1 VALID, fixed**: `FarmCamera.end_drag()` was called from
     `FarmInput` with no release-velocity argument, so it always
     defaulted to `Vector2.ZERO` — the 400 ms pan inertia spec
     (ARCHITECTURE.md Section 10.1) was implemented and unit-tested in
     isolation, but never actually activated from a real gesture, since
     nothing computed and passed a real velocity at release. This is a
     genuine gap that slipped past Task 4 and Task 5's own
     verification, because both tasks' tests called `end_drag()`
     directly with a manually-supplied velocity rather than exercising
     the full `_unhandled_input` drag-then-release path with real
     timing. **Fixed**: `FarmInput._TouchState` now tracks
     `last_drag_velocity`, computed from each drag sample's relative
     motion over the elapsed time since the previous sample;
     `_on_touch_ended` passes it to `camera.end_drag(...)`. A new
     regression test sends a realistic two-sample drag stream (a single
     drag event has no prior timestamp to compute a delta against) and
     asserts the camera's `_inertia_velocity` is nonzero after release.
   - **1 OPTIONAL, deferred**: the pinch-then-release test only covers
     one finger-lift ordering; the alternate ordering and
     additional-finger transitions aren't separately tested. The
     underlying flag's logic was read directly and does not
     special-case lift order, so this is a test-depth nicety, not a
     known gap in the logic itself. Tracked as a future task.
5. **Re-verification after the fix** (run independently): headless
   import still zero errors/zero warnings; GUT suite now **53/53
   tests, 139/139 asserts**.

**Phase 1 is complete.** All 5 implementation tasks done, full-phase
verification passed, Codex review passed with the one VALID finding
fixed and re-verified, zero unresolved VALID findings remain.

### Remaining Phase 1 tasks

None. Phase 1 is complete.

### Next action

* Begin Phase 2 (Animals) per CLAUDE.md's phase breakdown, when ready.

---

## Phase 2 — Animals

### Scope and sequencing plan

CLAUDE.md's Phase 2 scope: Animal definitions, Animal instances, Animal
spawning, Animal movement, Animal selection, Animal states. As with
Phase 1, ARCHITECTURE.md ties these to foundational pieces
(`GameCatalog`, runtime state, the `Game` autoload) that no single
CLAUDE.md phase owns, and to things that ARE other phases (feeding,
production, buying). A planning review (Opus, Plan mode) was run before
implementing, covering 7 scoping questions; its decisions, applied
below:

1. **`balance.json`**: write the **full v1 shape** from ARCHITECTURE.md
   Section 7.3 now (it's approved data, not a feature — editing it once
   is cheaper than reopening it every later phase), but `GameCatalog`
   **parses only** `schema`, `products` → `ProductDefinition`, `animals`
   → `AnimalDefinition` (all fields), and `status` → `StatusParams`.
   Every other balance group (`feeding`, `economy`, `buildings`,
   `offline`, etc.) sits in the file unparsed until the phase that
   actually uses it.
2. **Runtime state**: `AnimalInstance` (complete, with `to_dict`/
   `from_dict`), `FarmState` (just `animals` + `get_animal`), `GameState`
   (just `farm`). No save-shaped `to_dict`/`from_dict` on `FarmState`/
   `GameState` yet — Phase 7's job, since those map to root save keys
   whose shape isn't decided until save-the-whole-tree exists.
3. **`Game` autoload**: stood up for real now (not deferred, unlike
   Phase 1's buildings-from-scene seam) — animal state has multiple
   readers (spawning, `AnimalView.refresh()`, later the Animal sheet),
   and `ui/` is allowed to depend on `Game` but not on `scenes/farm/`
   per ARCHITECTURE.md Section 5, so holding state inside `FarmWorld`
   would force a rewrite the moment Phase 3 adds a sheet. Built as a
   **thin slice**: `catalog`, `state`, `state_loaded` signal,
   `new_game_state()`, `begin_session()`. No commands, no clock, no
   SimTick, no other signals — each added when its real emitter/reader
   exists.
4. **Where Phase 2 animals come from**: the real game starts with
   **zero animals** (GDD Section 2/8: the tutorial's second step buys
   the first chicken; UI_SPEC Section 3 has an explicit empty-farm
   state). Automated tests use a `StateFactory` helper; visual checks
   use a separate dev-only preview scene — neither seeds the production
   boot path.
5. **Animal selection**: selection feedback only (a ring +
   `FarmCamera.focus_on`), **no Animal Interaction sheet**. The sheet
   needs `Nav`/`AppShell`/`Overlay`/`BottomSheet`, none of which are
   assigned to any CLAUDE.md phase, and its Feed/Collect buttons would
   have nothing real to do yet. `FarmWorld.animal_tapped` (already
   emitted) is the seam Phase 3 opens the sheet from later — no new
   signal needed then.
6. **Animal movement**: confirmed purely visual (`_process` moves a
   node's `position`, never `AnimalInstance` state), independent of the
   state/catalog work. Needs a `wander_area()` on `BuildingView`
   (doesn't exist yet) and an injectable RNG + pure step function for
   deterministic tests.
7. **Task breakdown** (verified with a direct autoload+GUT compatibility
   check before committing to it — confirmed GUT correctly loads and
   accesses project autoloads in headless CLI mode):
   - T1: Definitions and catalog (`balance.json`, `AnimalDefinition`,
     `ProductDefinition`, `GameCatalog`)
   - T2: Runtime state, `StatusRules`, `StateFactory`
   - T3: `Game` autoload (thin slice) + boot seam in `main.gd`
   - T4: `AnimalView` base + 3 species scenes; `wander_rect()` on
     `BuildingView`
   - T5: `FarmWorld` spawning animal views from `Game.state`
   - T6: Animal selection (ring, camera focus, FarmInput animal tier)
   - T7: Full Phase 2 verification + Codex review

**Explicitly deferred to later phases** (not built in Phase 2, each with
its real reason, not just "later"): `feed_animal`/`ActionResult`/
`ActionGuard`/`FeedingRules` and the Animal sheet/`Nav`/`AppShell`/
`Overlay` UI shell (Phase 3 — feeding is the first real command and
needs a home for its button); `StatusBubble`/`primary_bubble`/bubble
hit-test tier (Phase 3/4 — bubbles only appear when actionable);
`GameClock`/`SimTick`/`_advance_to`/`ProductionRules` (Phase 4 — time
simulation); `buy_animal`/id generation/name pool/`InventoryState`
(Phase 5 — purchasing is how animals enter the game for real);
`BuildingDefinition`/`BuildingInstance`/buildings-from-state/housing
validation (Phase 6); `to_dict`/`from_dict` on `FarmState`/`GameState`,
`SaveCodec`, real boot flow (Phase 7); `OfflineParams` (Phase 8); idle
animations, ring pulse, low-happiness slowdown, `AmbientBudget` (Phase
9).

### Implementation summary (Tasks 1-6)

All 6 tasks from the plan above are implemented. One real wiring bug was
found and fixed mid-implementation (not deferred): `FarmWorld._rebuild_animals()`
assumed `Game.state` was always set, which crashed several pre-existing
Phase 1 tests that instantiate `farm_world.tscn` directly without a
session (they predate Phase 2 and never needed one before). Fixed with
a null guard — `FarmWorld` must not assume a session has begun before
its own `_ready()` runs, since Godot readies children before parents and
`FarmWorld` is a child of `Main`, which is what actually starts the
session.

A second, smaller issue surfaced during visual verification: `queue_free()`
on animal views removed during a rebuild left short-lived orphans (caught
by GUT's own orphan counter in rapid test-triggered rebuilds, not assumed)
— fixed by using `free()` directly, since the nodes are already detached
from the tree via `remove_child` before freeing, so `queue_free()`'s
deferred-timing safety does not apply.

**Files added:** `data/balance.json`, `tests/fixtures/balance_fixture.json`,
`scripts/definitions/{product_definition,animal_definition,game_catalog}.gd`,
`scripts/state/{animal_instance,farm_state,game_state}.gd`,
`scripts/rules/status_rules.gd`, `tests/helpers/state_factory.gd`,
`autoload/game.gd`, `scenes/farm/animals/{animal_view,chicken_view,pig_view,cow_view}.gd/.tscn`,
10 new test files (`test_game_catalog`, `test_balance_data`,
`test_animal_instance`, `test_status_rules`, `test_game_session`,
`test_animal_view`, `test_farm_world_animals`).

**Files changed:** `project.godot` (`[autoload] Game=...`), `scenes/main/main.gd`
(boot seam calling `Game.begin_session`), `scenes/farm/farm_world.gd`
(animal spawning/rebuild, selection, Game.state_loaded wiring),
`scenes/farm/farm_input.gd` (`animals_container` export, animal tier
wired), `scenes/farm/buildings/building_view.gd` (`wander_rect`/
`wander_area()`), `tests/integration/test_main_boots.gd` (Game session
assertion added).

**A real Godot/tooling limitation was hit and worked around during visual
verification, not glossed over:** `godot --script <path>` does not
initialize project autoloads, so any script compiled that way fails with
"Identifier not found: Game" the moment it touches a class that
references the autoload — this affected every scene that now depends on
`Game` (`main.gd`, `farm_world.gd`, `animal_view.gd`). Confirmed directly
(not assumed) by testing a minimal reproduction. GUT tests correctly
initialize autoloads, so unit/integration verification was unaffected,
but the ad-hoc screenshot technique used in Phase 0/1 had to be replaced:
visual checks for Phase 2 launch a real throwaway scene (`godot
<scene.tscn>`, not `-s <script.gd>`), which does initialize autoloads
normally. This is recorded here so a future phase doesn't rediscover it
from scratch.

### Verification results

1. **Headless import**: zero errors, zero warnings.
2. **GUT suite**: all passing —
   ```
   Totals: Scripts 13, Tests 111, Passing 111, Asserts 259
   ---- All tests passed! ----
   ```
3. **Visual check**: a throwaway scene booted `main.tscn`, injected 3
   animals (one per MVP species, via `Game.state.farm.animals` +
   `Game.state_loaded.emit()`, exactly how a later phase's real spawning
   flow will update state) and screenshotted at 390x844. All 5 building
   placeholders and the injected chicken/pig placeholders render
   correctly, positioned near their housing buildings. (Production code
   itself was never modified to support this check — no debug branches
   were added anywhere.)

### Next action

* Run the full-phase independent Codex review.

---

## Review Status — Phase 0

### Claude Implementation

* Status: COMPLETE (implementation and verification both done)

### Codex Review

* Status: **PASS**

### Review Findings

24 findings reported by an independent Codex review pass (codex-cli
0.158.0, read-only sandbox, full scope per CLAUDE.md Section 13). Each
was independently re-verified against the actual code and the governing
design docs before classification — not taken on trust in either
direction. Full detail, per-finding evidence, and the fix record are in
`docs/CODEX_REVIEW.md`.

* **8 VALID** (all fixed, independently re-verified after the fix):
  missing iOS density path in `ScreenFit` (High), missing
  `quit_on_go_back` project setting (Medium), unused `commit_lock_ms` on
  `FarmButton` (Medium), stale `config/features` version string (Medium),
  concurrent tweens on rapid button press/release (Medium), shallow boot
  smoke test (Medium), no test coverage for the mobile `ScreenFit` path
  (High), `add_sibling()` engine error on a parentless `FarmButton`
  (Low).
* **2 INVALID** (Codex's claim did not match the actual governing spec
  on direct re-read): a claim that ARCHITECTURE §2 requires safe-area
  handling in Phase 0 (it assigns that to the later-phase `AppShell`
  instead); a claim that DESIGN §5 specifies a 16 dp toast radius (no
  such row exists there — the actual governing spec, UI_SPEC §15, says
  24 dp, matching the implementation exactly).
* **4 ALREADY_HANDLED**: the button press-animation substitution
  (already documented as deliberate), the "tests use idealized inputs"
  observation (already acknowledged in ARCHITECTURE.md itself as a
  Phase 10 device-verification item), the default-font fallback (already
  the documented, approved Phase 0 behavior), and the `size`→
  `size_variant` rename's underlying cause (a real bug fix, confirmed
  correct; only its architecture-doc alignment was a gap, which the fix
  record addresses).
* **4 OPTIONAL**: deeper theme-token test coverage, independent-axis
  clamp aspect-ratio hardening, a placeholder icon texture for the demo,
  and a more structural demo/boot-scene replacement seam. Deferred —
  reasonable suggestions beyond Phase 0's approved scope, not defects.

### Remaining Work

* None blocking. The 4 OPTIONAL items above may be picked up in a later
  phase if convenient, but do not block Phase 0 completion or Phase 1
  start.

### Next Action

* Begin Phase 1 (Farm) per CLAUDE.md's phase breakdown.

---

## Review Status — Phase 1

### Claude Implementation

* Status: **COMPLETE** (all 6 tasks done; see "Phase 1 — Farm" above)

### Codex Review

* Status: **PASS** (two passes: an interim review of Tasks 1-2 at the
  user's explicit request, and the normal CLAUDE.md Section 13
  full-phase review in Task 6, covering all 5 implementation tasks and
  re-reviewing Tasks 1-2 as part of the whole). Zero unresolved VALID
  findings remain across both passes.

### Review Findings

**Interim review (Tasks 1-2 only):**
* **1 VALID, deferred**: backdrop polygons are a fixed 1200-unit width,
  which cannot guarantee meadow coverage to a tablet's physical screen
  edges (DESIGN.md Section 12 rule 4). Re-verified by calculation: every
  phone reference device's visible world width at maximum zoom-out is a
  constant 487.5 units, well inside the 1200-unit backdrop — the gap is
  tablet-only. Tablet column/backdrop handling is explicitly assigned to
  `AppShell` by both DESIGN.md and ARCHITECTURE.md (Sections 2 and 3),
  which does not exist until a later phase. There is no way to correctly
  close this now without either building `AppShell` early or adding
  speculative tablet-detection logic ahead of the component designed to
  own it. **Tracked as a future task** (see below), not a blocker.
* **1 OPTIONAL**: `test_backdrop_extends_past_the_world_rect` only checks
  coverage against the narrow authored world rect, not the 0.8x-zoom or
  tablet-scale case its own comment describes.
* 0 INVALID, 0 ALREADY_HANDLED.

**Full-phase review (Tasks 1-5, Task 6 of this phase):**
* **1 VALID, fixed and re-verified**: `FarmCamera.end_drag()` was called
  from `FarmInput` with no release-velocity argument, so the 400 ms pan
  inertia spec (ARCHITECTURE.md Section 10.1) never actually activated
  from a real gesture — inertia was implemented and tested in isolation,
  but never wired to a real velocity source. Fixed by having
  `FarmInput` track each drag's velocity from consecutive samples and
  pass it to `end_drag()` on release; a new regression test confirms
  `FarmCamera._inertia_velocity` is nonzero after a fast drag release.
* **1 OPTIONAL, deferred**: pinch-then-release testing only covers one
  finger-lift ordering; the underlying logic doesn't special-case lift
  order, so this is a coverage nicety, not a known gap.
* 0 INVALID, 0 ALREADY_HANDLED. All 16 other review categories: no
  issues found (full detail, including what was independently
  spot-checked rather than taken on trust, in `docs/CODEX_REVIEW.md`).

### Remaining Work

* **Future task (not blocking)**: make the farm-world backdrop's
  coverage dynamic/viewport-aware so it genuinely extends to a tablet's
  physical edges, once `AppShell`'s tablet-column logic exists to
  coordinate with. Revisit `test_backdrop_extends_past_the_world_rect`
  at the same time to assert the real requirement instead of the
  narrower world-rect proxy.
* **Future task (not blocking)**: broaden pinch/multi-touch test
  coverage to the alternate finger-lift ordering and additional-finger
  transitions.

### Next Action

* Begin Phase 2 (Animals) per CLAUDE.md's phase breakdown, when ready.

---

## Phase 3 — Feeding

### Scope and sequencing plan

CLAUDE.md's Phase 3 scope: Feed inventory, Feeding interaction, Hunger,
Happiness, Animal state updates. A planning review (Opus, Plan mode)
covering 9 scoping questions was run before implementing. Its key
decisions:

1. **Feed inventory**: a minimal `PlayerState` (`feed: int` only — no
   `coins`/`xp`/`level` yet, since nothing reads them until Phase 5/7)
   added to `GameState.player`. Seeded from `catalog.start.feed` in
   `new_game_state()`.
2. **Catalog parsing**: `GameCatalog` now also parses `feeding`,
   `happiness`, and `start` as complete inner classes (`FeedingParams`,
   `HappinessParams`, `StartParams`) — unlike mutable runtime state,
   parsing an already-on-disk static group costs nothing even before
   every field has a reader (Phase 2 already did this for
   `AnimalDefinition.price`/`default_names`).
3. **No `_advance_to`/`GameClock.now_ms`/hunger decay**: confirmed this
   does NOT violate CLAUDE.md Section 8. That rule forbids frame-based
   time logic; it doesn't require building real time-based decay early.
   Hunger changes only via feeding until Phase 4 builds
   `ProductionRules`/the single simulation tick. Building a second decay
   path now would violate ARCHITECTURE.md Section 1's "one simulation
   path" rule, not satisfy it.
4. **`ActionGuard` + a minimal `GameClock`** (`mono_ms()` only, real
   wall-clock debounce per ARCHITECTURE.md Section 10.4 — this is UI
   debounce timing, not persistent game time, so it's CLAUDE.md Section
   8-compliant) built now, since GDD Section 4 requires the 300ms
   double-tap guard as core feeding-interaction scope.
5. **`ActionResult`**: the full class built at its final documented
   shape (all 14 `Code` values) now, same "build at final shape, not
   just today's subset" pattern as `AnimalDefinition`.
6. **`feed_animal` command + 5 signals** (`state_changed`,
   `feed_changed`, `animal_changed`, `animal_status_changed`,
   `animal_fed`) added directly to `Game` — each with a real emitter and
   a real test, per the rule "a signal is added in the phase that
   builds its real emitter, when a command's documented contract
   requires it."
7. **Feeding interaction without a UI shell**: the real Phase 3
   interaction is the **wheat-bubble 1-tap path** (GDD Section 4,
   UI_SPEC Section 3/6's approved, final-design shortcut), not a
   stand-in for the Animal Interaction sheet. The sheet needs
   `Nav`/`AppShell`/`Overlay`/`BottomSheet`, none of which exist, and
   — crucially — **no animal can exist in the real game until Phase 5
   (buying)**, so building sheet infrastructure now would be unreachable
   in actual play regardless. This **corrects an inconsistency in this
   phase's own earlier deferred-items note** (the Phase 2 section above
   says "the Animal sheet/Nav/AppShell/Overlay UI shell" belongs to
   Phase 3 — that line was wrong; the UI shell has no assigned phase and
   the right slot is after Phase 4, once Collect/production exist too).
8. **`AnimalView` wired to `Game.animal_changed` only** (not
   `animal_status_changed` — Phase 3 has no code path that changes
   status without also emitting `animal_changed`; Phase 4's tick is the
   first one that does, so Phase 4 adds that connection). Confirmed
   `AnimalView` makes zero calls to `Game.feed_animal` or any mutation —
   the tap→command mapping lives in `FarmWorld` (the temporary
   `FarmScreen` stand-in), matching this phase's explicit instruction to
   keep gameplay-system responsibilities out of presentation classes.
9. **Task breakdown**: T1 core types (`ActionResult`, `ActionGuard`,
   `GameClock`) → T2 catalog parsing → T3 `PlayerState` → T4
   `FeedingRules` → T5 `Game.feed_animal` + signals → T6 `AnimalView`
   reacts → T7 the wheat `StatusBubble` → T8 bubble-tap wiring → T9 full
   verification + Codex review.

**Owner flag (not blocking implementation, recorded per ARCHITECTURE.md
Section 7.3's "inert values must be replaced before the phase that uses
them"):** `happiness.gainOnFeed` in the live `data/balance.json` is
still the GDD's placeholder-inert `0`. Phase 3's code applies it
correctly regardless of its value; the test fixture uses a distinct
non-zero value specifically so the gain-and-clamp logic is actually
exercised, matching the precedent ARCHITECTURE.md Section 19 already
set for progression's inert values. The live file's `0` is a design
decision for the owner to confirm, not an implementation gap.

**Explicitly deferred to later phases** (each with its real reason):
the Animal Interaction sheet/`Nav`/`AppShell`/`Overlay`/`BottomSheet`/HUD
feed pill/`ToastHost`/`ResultMessages`/`strings.csv` (unassigned UI-shell
work — recommend after Phase 4, since the sheet needs Collect too);
out-of-feed toast/pill-shake/"Buy feed" link/"Full" disabled caption
(same UI-shell work); hunger/happiness decay, `GameClock.now_ms`,
`SimTick`, `_advance_to`, `ProductionRules`, `last_seen_ms`,
`simulation_ticked` (Phase 4 — the single simulation path);
`AnimalView`↔`animal_status_changed` (Phase 4); the PRODUCT bubble +
collect branch (Phase 4 — Collect doesn't exist); the CLOUD bubble
(once happiness numbers are non-inert and its tap action is specified);
`PlayerState.coins/xp/level`, feed cap, `buy_feed_pack`, `feed_bought`,
`coins_changed` (Phase 5/6); `to_dict`/`from_dict`/`extra` on
`PlayerState`/`GameState`, `request_autosave` (Phase 7); `play_feed`,
haptics, `AudioService` (Phase 9); tutorial step advancement (unassigned
tutorial work).

### Task 1: Core types — implemented

* `scripts/core/action_result.gd`: `ActionResult` (`Code` enum with all
  13 documented values per ARCHITECTURE.md Section 13.2, `ok()`,
  `missing`, `data`, `ActionResult.of(code)`). Phase 3 only uses a
  subset of the enum now; built at its full documented shape so later
  phases never have to touch this file again.
* `scripts/core/game_clock.gd`: `GameClock.mono_ms()` only (real-time,
  non-persistent UI debounce clock). `now_ms()` (UTC wall-clock
  simulation time) deliberately NOT built yet — that's Phase 4's
  addition to this same class.
* `scripts/core/action_guard.gd`: `ActionGuard.try_commit(key,
  now_mono_ms, lock_ms)` — the 300ms commit-lock/debounce from
  ARCHITECTURE.md Section 10.4. Per-key independence; a refused attempt
  does not extend the lock.
* `tests/helpers/fake_clock.gd`: `FakeClock extends GameClock` per
  ARCHITECTURE.md Section 19, for deterministic debounce tests.
* `tests/unit/test_action_guard.gd`: 6 tests (first commit allowed,
  second commit inside the window refused, exactly-at-boundary allowed,
  just-before-boundary refused, independent keys don't block each
  other, a refused attempt doesn't extend the lock).

**Verification:** headless import clean; full GUT suite passing before
Task 2 began.

### Task 2: Catalog parsing — implemented

* `scripts/definitions/game_catalog.gd`: added `FeedingParams`
  (`feed_per_meal`, `hunger_per_meal`, `hunger_decay_per_minute`,
  `debounce_ms`, `block_when_full`), `HappinessParams` (`gain_on_feed`,
  `gain_on_collect`, `decay_per_minute`), `StartParams` (`coins`,
  `feed`, `xp`, `level`) — parsed from balance.json's `feeding`,
  `happiness`, and `start` groups respectively. Fields with no Phase 3
  reader yet (e.g. `hunger_decay_per_minute`, `gain_on_collect`,
  `start.coins/xp/level`) are parsed now anyway since static read-only
  groups cost nothing to parse in full, unlike mutable runtime state.
* `validate()` extended: `feed_per_meal >= 1`, `hunger_per_meal` in
  `(0, 100]`, `debounce_ms >= 0`, `hunger_decay_per_minute >= 0`, all
  three happiness values `>= 0`, `start.feed >= 0`, `start.coins >= 0`,
  `start.level >= 1`.
* `tests/fixtures/balance_fixture.json`: `happiness.gainOnFeed` changed
  from `0` to `10` (fixture-only) so later `FeedingRules` tests
  genuinely exercise the gain-and-clamp path. Live `data/balance.json`
  unchanged — stays at the GDD's placeholder-inert `0` (owner decision,
  see note above).
* `tests/unit/test_game_catalog.gd`: +12 tests — fixture values parsed
  correctly for all three new groups, and one test per new validation
  rule confirming it actually catches a bad value.

**Verification:**
1. Headless import (`godot --headless --path . --import`) — zero
   errors/warnings.
2. Full GUT suite (`-gdir=res://tests -ginclude_subdirs -gexit`) —
   **131/131 passing, 288/288 asserts** (up from 119/267 before this
   task), including `test_balance_data.gd` against the live
   `data/balance.json`, confirming the real file's inert-but-valid
   feeding/happiness/start values satisfy every new rule cleanly.

### Task 3: `PlayerState` — implemented

* `scripts/state/player_state.gd` (NEW): minimal `PlayerState` with
  only `feed: int = 0`. `coins`, `xp`, `level`, `extra` (the rest of
  ARCHITECTURE.md Section 8.3's documented shape) deliberately NOT
  built yet -- each has no reader or writer until Phase 5/6/7, and a
  field with neither is premature scope per CLAUDE.md Section 16.
* `scripts/state/game_state.gd`: added `var player: PlayerState =
  PlayerState.new()`.
* `autoload/game.gd`: `new_game_state()` now seeds
  `fresh.player.feed = catalog.start.feed` from balance.json's `start`
  group before returning the fresh state.
* `tests/helpers/state_factory.gd`: `game_state_with()` gained an
  optional `feed: int = 0` parameter (default preserves every existing
  caller unchanged -- confirmed via search, all 4 call sites are
  positional with no `feed` argument).
* `tests/integration/test_game_session.gd`: +1 test
  (`test_new_game_state_seeds_feed_from_catalog_start`).

**Verification:** headless import clean (`PlayerState` registered as a
global class); full GUT suite **132/132 passing, 289/289 asserts**.

### Task 4: `FeedingRules` — implemented

* `scripts/rules/feeding_rules.gd` (NEW): pure static functions over
  `(PlayerState, AnimalInstance, GameCatalog)` only -- no autoloads, no
  clock, matching `StatusRules`'s pattern (CLAUDE.md Section 11).
  - `debounce_key(animal_id) -> String`: `"feed:%s"`, the
    `ActionGuard` key from ARCHITECTURE.md Section 17's data flow.
  - `check_feed(player, animal, catalog) -> ActionResult`: refuses
    `NOT_ENOUGH_FEED` (checked first) then `HUNGER_FULL` (only when
    `blockWhenFull` is true and hunger is already 100), else OK.
  - `apply_meal(player, animal, catalog) -> void`: spends
    `feed_per_meal`, raises hunger by `hunger_per_meal` (clamped 100),
    raises happiness by `gain_on_feed` (clamped 100). Does not
    re-validate -- callers must have already confirmed `check_feed()`
    returned OK, same division of responsibility as
    `ProductionRules`/`StatusRules`.
* `tests/unit/test_feeding_rules.gd` (NEW): 9 tests covering the
  debounce key, both refusal paths (including priority when both would
  apply), the exactly-enough-feed boundary, and `apply_meal`'s
  spend/gain/clamp behavior for both hunger and happiness.

**Verification:** headless import clean (`FeedingRules` registered as
a global class); full GUT suite **141/141 passing, 303/303 asserts**.

### Task 5: `Game.feed_animal` — implemented

* `autoload/game.gd`: added `clock: GameClock`, `_guard: ActionGuard`,
  4 new signals (`state_changed`, `feed_changed`, `animal_changed`,
  `animal_fed` -- `animal_status_changed` deliberately not added yet,
  see Phase 3 plan item 8), and `feed_animal(animal_id) ->
  ActionResult`.
* Flow, per ARCHITECTURE.md Section 17: unknown id -> `UNKNOWN_ID`;
  else `FeedingRules.check_feed()` first; only once that would succeed
  does `ActionGuard.try_commit("feed:<id>", clock.mono_ms(), 300)` run
  -> `DEBOUNCED` if locked; else `FeedingRules.apply_meal()` then emit
  `feed_changed`, `animal_fed`, `animal_changed`, `state_changed` in
  that order.
* `tests/integration/test_game_commands.gd` (NEW): 9 tests (unknown id,
  success + mutation, full signal set on success, correct animal id on
  `animal_fed`, debounce refusal emits nothing, lock expiry after
  300ms, both refusal paths leave state untouched, a refused feed does
  not consume the lock). Swaps `Game.clock` for `FakeClock` so the
  debounce window is deterministic; uses `Game.catalog` (the real
  `data/balance.json`) rather than the fixture, since `feed_animal`
  always reads its own catalog -- a test-only catalog swap would not
  exercise production wiring (`happiness.gainOnFeed` is therefore the
  live file's inert `0` here; the non-zero gain-and-clamp path is
  already covered against the fixture in `test_feeding_rules.gd`).

**Two real bugs found and fixed during self-verification** (not
Codex findings -- caught by this session's own first test run):
1. **Debounce ordering.** The first draft called
   `_guard.try_commit()` *before* `FeedingRules.check_feed()`, so a
   `NOT_ENOUGH_FEED`/`HUNGER_FULL` refusal still consumed the 300ms
   lock -- contradicting `ActionGuard`'s own documented contract ("a
   refused attempt does not extend the lock"). Fixed by checking
   `check_feed()` first and only committing the guard once a feed
   would otherwise succeed.
2. **Cross-test guard leakage.** `Game._guard` is a singleton field
   that persists across the whole GUT run; without resetting it, an
   earlier test's commit at `FakeClock` time 0 falsely debounced every
   later test that also starts its `FakeClock` at 0. Fixed by
   `Game._guard = ActionGuard.new()` in `before_each()`, same pattern
   already used for swapping `Game.clock`.

**Verification:** headless import clean; full GUT suite **150/150
passing, 324/324 asserts**.

### Task 6: `AnimalView` reacts to feeding — implemented

* `scenes/farm/animals/animal_view.gd`: `bind()` now connects
  `Game.animal_changed` to a new `_on_animal_changed(changed_id)`
  handler that calls `refresh()` only when `changed_id == animal_id`
  -- every other on-screen view's own connection ignores a different
  animal's change. Not connected to `animal_status_changed` yet (see
  Task 5 note: Phase 3 has no code path that changes status without
  also emitting `animal_changed`). No manual disconnect needed --
  Godot auto-disconnects a signal when the connected object is freed,
  and `FarmWorld._rebuild_animals()` already frees old views with
  `free()`, not `queue_free()`.
* `tests/unit/test_animal_view.gd`: +3 tests -- reacts correctly to its
  own id's change, ignores a different id's change (two animals in
  state, only one view), and a freed view does not error when
  `Game.animal_changed` fires again afterward (confirms the
  auto-disconnect assumption directly rather than trusting it).

**Verification:** headless import clean (`AnimalView` global class
still registers); full GUT suite **153/153 passing, 328/328 asserts**.

### Task 7: wheat `StatusBubble` — implemented

* `scripts/rules/status_rules.gd`: added `enum Bubble { NONE, FEED,
  PRODUCT, CLOUD }` and `primary_bubble(flags) -> Bubble` per
  ARCHITECTURE.md Section 9.2/23 item 16's built default: READY > FEED
  > CLOUD. Phase 3 only ever produces HUNGRY in practice (READY/
  LOW_HAPPINESS have no real trigger until Phase 4), but the full
  priority order is built and tested now since it is cheap, pure, and
  this is `StatusRules`' one designated home for the decision.
* `scenes/farm/animals/animal_view.tscn`: added a `BubbleAnchor`
  (`Marker2D`, `unique_name_in_owner`) appended as the LAST child, at
  local `(0, -56)` (above the body). Non-visual, so it does not
  interact with the sibling-index draw-order rule the per-species
  inherited scenes rely on (confirmed by inspecting all three
  `<species>_view.tscn` overrides before adding it).
* `scenes/farm/world_ui/status_bubble.tscn/.gd` (NEW): a 36dp-visual
  wheat glyph (3 leaf pairs, `UiTokens`' hunger-gold tint) in a 48dp tap
  target, per DESIGN.md Section 11. Exposes `animal_id`,
  `bubble_kind: StatusRules.Bubble`, `bind(id, kind, anchor)`, and
  `tap_rect() -> Rect2` -- the same `tap_rect()`/id duck-type
  `FarmInput._nearest_hit()` already expects for a future bubble tier
  (Task 8's job to actually wire). Tracks its anchor's global_position
  every `_process()` frame (purely visual, never touches
  `AnimalInstance`) since `WorldUi` is a sibling of `Animals`, not a
  child of any one `AnimalView` -- the bubble cannot simply inherit the
  wandering animal's transform.
* `scenes/farm/farm_world.gd`: connects `Game.animal_changed` to a new
  `_refresh_bubble(animal_id)` that computes
  `StatusRules.primary_bubble(StatusRules.flags(...))` and
  spawns/re-tints/frees the one `StatusBubble` for that animal
  accordingly; called once per animal from `_spawn_animal_view()` too.
  `_rebuild_animals()` now also clears `WorldUi`'s children alongside
  `Animals`', so a rebuild does not leak stale bubbles.
* Tests: `tests/unit/test_status_rules.gd` +7 (`primary_bubble`
  priority and single-flag cases); `tests/unit/test_status_bubble.gd`
  (NEW, 4 tests: 48dp tap rect, `bind()` sets id/kind, snaps to the
  anchor immediately, follows the anchor after it moves);
  `tests/unit/test_farm_world_bubbles.gd` (NEW, 7 tests: hungry animal
  gets a bubble on spawn, fed animal gets none, feeding removes it,
  hunger dropping adds it, the bubble tracks its `AnimalView`'s anchor,
  a rebuild clears old bubbles, two hungry animals get independent
  bubbles).

**Verification:**
1. Headless import clean (`StatusBubble` registered as a global class).
2. Full GUT suite: **171/171 passing, 355/355 asserts**.
3. Visual check (throwaway `scratch_scripts/visual_check.tscn`,
   launched via `godot --path . --resolution 390x844`, deleted after):
   a hungry chicken (hunger 5) shows the gold wheat bubble above its
   head at the `BubbleAnchor` position; a fed pig (hunger 100) shows no
   bubble. Confirmed by direct screenshot, not assumed.

### Task 8: bubble-tap feeds the animal — implemented

* `scenes/farm/farm_input.gd`: added `@export var world_ui_container:
  Node2D` and a real `_bubble_targets()` (mirrors
  `_animal_targets()`/`_building_targets()`'s pattern exactly). The
  bubble tier was already first in `_hit_test()`'s priority order
  (bubbles -> animals -> buildings -> ground, per ARCHITECTURE.md
  Section 10.1) from Phase 1/2 -- only the previously-empty target list
  needed filling in. `_target_id()` already duck-typed `bubble_id` as
  its third fallback, but `StatusBubble` exposes `animal_id` (checked
  second), which already resolves correctly: tapping a bubble reports
  *that animal's* id, matching "Tapping a bubble performs that
  bubble's action" (ARCHITECTURE.md Section 9.2).
* `scenes/farm/farm_world.gd`: `_wire_farm_input()` now sets
  `farm_input.world_ui_container = world_ui`; `bubble_tapped` is routed
  through a new `_on_bubble_tapped(id)` that re-emits `bubble_tapped`
  (so a later `FarmScreen` can still react, e.g. a refusal toast,
  matching every other tier) and then calls `Game.feed_animal(id)`
  directly. Documented as a **temporary seam**: this bypasses the
  not-yet-built Animal Interaction sheet, which has no assigned phase
  (see Task 7/plan item 7 -- no animal can exist in real play before
  Phase 5's buying system, so sheet infrastructure now would be
  unreachable regardless).
* Tests: `tests/unit/test_farm_input.gd` +3 -- a bubble tap fires
  `bubble_tapped` with the correct animal id (using a real
  `StatusBubble` instance, not a fake target, since its id property
  differs from the existing `_FakeTarget`'s `building_id`); the bubble
  tier wins over an overlapping building (priority order); and a
  full FarmWorld-level end-to-end test that a real tap on a real
  spawned bubble actually reaches `Game.feed_animal` (feed spent,
  hunger raised, not just a signal assertion).

**Verification:** headless import clean; full GUT suite **174/174
passing, 361/361 asserts**.

### Task 9: full Phase 3 verification + Codex review — complete

**Self-verification (before Codex):**
* Headless import: zero errors, zero warnings.
* Full GUT suite: **174/174 passing, 361/361 asserts**.
* Visual check at both reference sizes (390x844, 360x640): a hungry
  chicken/cow shows the wheat bubble, a fed pig shows none; calling
  `Game.feed_animal()` directly (the same path a bubble tap uses)
  makes the bubble disappear and the face return to normal within the
  same run (before/after screenshots).

**Codex full-phase review** (independent, read-only, explicitly told
not to trust this progress report; full detail and exact scope in
`docs/CODEX_REVIEW.md`):

* **F-01 (Medium, VALID, fixed):** `Game.feed_animal()` hardcoded a
  `FEED_LOCK_MS = 300` constant instead of reading
  `catalog.feeding.debounce_ms` -- a balance.json tuning change to the
  debounce window would have had no effect. Fixed: removed the
  constant, wired the real catalog value, added a regression test
  proving the lock now actually follows a configured value (not just
  that it still equals 300 by coincidence).
* **F-02 (Low, OPTIONAL, not fixed):** fractional JSON values silently
  truncate via `int()` before validation. Confirmed this is a
  pre-existing Phase 2 pattern (`animal_definition.gd`,
  `product_definition.gd` do the same), not a Phase 3 regression --
  recorded as a future cross-cutting task rather than fixed here.
* A second, narrower Codex pass reviewed the F-01 fix alone (material
  change to a command's runtime behavior) and returned **PASS** with no
  new findings.

**Final verification after the fix:** headless import clean; full GUT
suite **175/175 passing, 363/363 asserts** (+1 regression test for
F-01).

**Phase 3 completion criteria met:**
```text
Claude Implementation = COMPLETE
Verification           = PASS
Codex Review            = PASS
Unresolved VALID findings = 0
VALID_DEFERRED/OPTIONAL   = F-02, documented above and in CODEX_REVIEW.md
```

### Next action

Phase 3 (Feeding) is COMPLETE. Phase 4 (Production) is the next phase
per CLAUDE.md's phase order -- not started; awaiting explicit
instruction to begin, per the governing task's own constraint ("Do not
start Phase 4 unless explicitly instructed").

---

## Review Status — Phase 3

### Claude Implementation

* Status: **COMPLETE** (all 9 tasks implemented, independently
  verified, Codex review passed after fixing the one VALID finding;
  see "Phase 3 — Feeding" above)

### Codex Review

* Status: **PASS**

### Review Findings

* **F-01 (Medium): VALID, fixed** -- `Game.feed_animal()` ignored
  `catalog.feeding.debounce_ms`, hardcoding 300ms instead. Fixed and
  covered by a new regression test; re-reviewed by Codex with no new
  findings.
* **F-02 (Low): OPTIONAL, deferred** -- fractional JSON values
  truncate silently before validation. Pre-existing Phase 2 pattern,
  not a Phase 3 regression. Recorded as a future cross-cutting
  validation task across `scripts/definitions/`.

### Remaining Work

* F-02 (optional, cross-cutting JSON validation improvement) --
  unscheduled, not blocking.
* The Animal Interaction sheet / Nav / AppShell / Overlay / BottomSheet
  / HUD feed pill / ToastHost / ResultMessages / strings.csv UI shell --
  unassigned to any phase; recommended after Phase 4 (needs Collect
  too).
* Hunger/happiness decay, `GameClock.now_ms()`, `SimTick`,
  `_advance_to()`, `ProductionRules`, `simulation_ticked`,
  `animal_status_changed` -- Phase 4.
* The PRODUCT/CLOUD status bubbles' real triggers -- Phase 4/5+.
* `PlayerState.coins/xp/level`, feed cap, `buy_feed_pack` -- Phase 5/6.
* Save/load (`to_dict`/`from_dict`/`extra`, `SaveService`) -- Phase 7.

### Next Action

* Begin Phase 4 (Production) when explicitly instructed.

---

## Phase 4 — Production

### Plan (Opus planning pass)

CLAUDE.md's own Phase 4 scope is narrow ("Production timers, Product
generation, Product collection, Production UI"), but
docs/ARCHITECTURE.md Section 14's full production architecture
interdepends on systems not yet built: `BuildingRules`/`BuildingInstance`
(Phase 6), `SaveService`/`last_seen_ms` persistence (Phase 7),
`OfflineRules`/`OfflineReport` (Phase 8), and the tutorial boost
(unassigned). A planning pass resolved each tension, matching the
established pattern from Phases 1-3 of building a correctly-scoped
subset now with every deferral justified and recorded, never silently
skipped.

**Resolved decisions:**

1. **Build now:** `GameClock.now_ms()`, `GameState.last_seen_ms`,
   `ProductionRules` (Params, `advance_animal`, collect check/apply), a
   narrowed `Game._advance_to`, the `SimTick` timer,
   `simulation_ticked` and `animal_status_changed`, a minimal
   `InventoryState`, `Game.collect`, the PRODUCT bubble, and tap-to-collect.
2. **`_advance_to` is built now, narrowed, not deferred whole.**
   Signature: `_advance_to(now_ms: int) -> void`. Computes
   `dt_ms = maxi(0, now_ms - state.last_seen_ms)`, advances every
   animal, re-stamps `last_seen_ms` (which also re-bases a
   backwards-moving clock), emits `animal_status_changed` for animals
   whose flags changed, then `simulation_ticked`. Built narrowed rather
   than deferred whole because ARCHITECTURE.md Section 1/ADR-06 require
   every command to call this function before mutating, and a separate
   Phase-8-only tick would mean either rewriting every caller later or
   running two parallel advancement paths -- exactly what
   ARCHITECTURE.md Section 1's "one simulation path" principle
   forbids. Phase 8 only **extends** this same function (adds
   `is_return: bool = false` with existing callers unaffected, changes
   the return type to `OfflineReport`, swaps the `maxi` line for
   `OfflineRules.elapsed_ms`).
3. **No building-multiplier stand-in.** `ProductionRules.Params.cycle_seconds`
   is set in `Game._production_params_for()` to the catalog's base
   `cycle_seconds` directly, with no multiplier division and no
   `BuildingRules` stub (there is no `BuildingInstance` or level to
   read yet). A comment marks where Phase 6 inserts the division --
   `ProductionRules` and `Params`'s own signature never change. Every
   L1 `productionMultiplier` in balance.json is 1.0, so this is
   behaviorally identical to the full design today.
4. **No tutorial boost.** No `tutorial_step`/`TutorialRules` exist, so
   `boost_active()` cannot be computed; `cycle_seconds` is always the
   catalog base. Recorded as deferred (GDD Section 2's "first sale
   under 2 minutes" depends on it once the tutorial exists).
5. **A minimal `InventoryState` is built now, not deferred to Phase 5.**
   GDD Section 2 says "Product moves to the Bag" and GDD Section 5 says
   products are "never lost" -- a collect with nowhere to store the
   product would effectively delete it, which is not "Product
   collection" as CLAUDE.md Phase 4 names it. Phase 5's own "Inventory"
   scope keeps everything a player actually sees and the removal side:
   the Bag tab/badge, `remove()` (no reader until selling exists),
   `bag_changed` consumers, and selling itself. This mirrors Phase 3's
   own precedent, where "Feed inventory" was built as nothing more than
   `PlayerState.feed`.
6. **Production UI is world-space only, no new UI shell.** `StatusBubble`
   gains PRODUCT tinting and FarmWorld/AnimalView connect to the new
   `animal_status_changed` signal (the tick can now change an animal's
   status with no command involved). The existing Phase 3 bubble-tap
   seam routes PRODUCT taps to `Game.collect` the same way FEED taps
   route to `Game.feed_animal`. No new progress bar -- UI_SPEC's bar
   lives in the (unbuilt) Animal Details sheet/cards; `simulation_ticked`
   is built now so that bar has a real data source once that UI exists.

**Owner flags (non-blocking, recorded per the Phase 3 precedent):**
`happiness.decayPerMinute` and `happiness.gainOnCollect` are still the
GDD's placeholder-inert `0` in the live `data/balance.json` -- Phase 4
is the first phase that actually reads them. `production.pauseWhenReady = true`
(GDD Section 4's OPEN recommended default) goes live in this phase.

**Task breakdown:** T1 time core (`GameClock.now_ms`, `last_seen_ms`,
minimal `InventoryState`) → T2 catalog parsing (`production` group) →
T3 `ProductionRules.Params`/`advance_animal` → T4 collect check/apply →
T5 `Game._advance_to` + SimTick + `feed_animal` retrofit → T6
`Game.collect` → T7 views react to `animal_status_changed` → T8
bubble-tap routing (PRODUCT → collect) → T9 full verification + Codex
review.

### Task 1: Time core + minimal InventoryState — implemented

* `scripts/core/game_clock.gd`: added `now_ms()` (UTC wall-clock
  milliseconds via `Time.get_unix_time_from_system()`), the simulation
  clock `Game._advance_to()` will read. Distinct from `mono_ms()`
  (`Time.get_ticks_msec()`), which resets every process launch and
  cannot represent "time passed while the app was closed."
* `tests/helpers/fake_clock.gd`: added a settable `now_ms()`/`set_now_ms()`;
  `advance(ms)` now advances both clocks together (nothing in this test
  double needs them to drift apart, and keeping one `advance()` call
  keeps every existing Phase 3 debounce test working unchanged).
* `scripts/state/inventory_state.gd` (NEW): minimal `InventoryState`
  with only `quantities: Dictionary`, `get_qty()`, `add()`. `remove()`
  deliberately not built -- no reader until Phase 5's selling.
* `scripts/state/game_state.gd`: added `var inventory: InventoryState`
  and `var last_seen_ms: int = 0`.
* `autoload/game.gd`: `new_game_state()` now seeds one inventory entry
  at 0 per catalog product id, and stamps `last_seen_ms = clock.now_ms()`
  so the first simulation advance has a real baseline instead of
  advancing from epoch 0.
* `tests/helpers/state_factory.gd`: `game_state_with()` gained an
  optional `last_seen_ms: int = 0` parameter (default preserves every
  existing caller).
* Tests: `tests/unit/test_inventory_state.gd` (NEW, 5 tests);
  `tests/integration/test_game_session.gd` +2 (inventory seeded at 0
  for every product, `last_seen_ms` stamped to roughly now).

**Verification:** headless import clean (`InventoryState` registered
as a global class); full GUT suite **182/182 passing, 374/374 asserts**.

### Task 2: Catalog parsing (production group) — implemented

* `scripts/definitions/game_catalog.gd`: added `ProductionParams`
  (`pause_when_ready: bool = true`), parsed from balance.json's
  `production.pauseWhenReady` -- the only key in that group
  (ARCHITECTURE.md Section 14: the `else` continuous-production branch
  is "do not build until confirmed", so there is nothing else to
  parse). No new validation rule needed (a bool has no invalid range).
* `tests/fixtures/balance_fixture.json`: `happiness.gainOnCollect`
  changed from `0` to `15`, `happiness.decayPerMinute` from `0` to `2`
  (fixture-only, matching the established gainOnFeed precedent) so
  `ProductionRules`' collect-gain and decay paths are genuinely
  exercised in later tasks' tests. Live `data/balance.json` unchanged
  -- stays at the GDD's placeholder-inert `0` for both (owner decision,
  same as Phase 3's `gainOnFeed` note).
* `tests/unit/test_game_catalog.gd`: +1 test
  (`test_production_params_match_fixture`); updated
  `test_happiness_params_match_fixture` for the new fixture values.

**Verification:** headless import clean (`GameCatalog` re-registers
cleanly); full GUT suite **183/183 passing, 375/375 asserts**
(including `test_balance_data.gd` against the live file, confirming
`pauseWhenReady: true` validates cleanly there too).

### Task 3: `ProductionRules.advance_animal()` — implemented

* `scripts/rules/production_rules.gd` (NEW): `Params`
  (`cycle_seconds`, `hunger_decay_per_second`, `happiness_decay_per_second`,
  `pause_when_ready`) and `advance_animal(a, dt, p) -> int`, exactly
  per ARCHITECTURE.md Section 14's pseudocode: fed-time computation,
  wall-time hunger/happiness decay regardless of feeding state,
  progress advancing only during fed time, pause-at-1.0 returning one
  completion. `Params.cycle_seconds` is the only production-speed knob
  this class reads -- no building-multiplier field and no
  tutorial-boost field, per the Phase 4 plan (both apply outside this
  class, in `Game._production_params_for()`, so `ProductionRules`'s
  own signature never changes when Phase 6/tutorial arrive).
* `tests/unit/test_production_rules.gd` (NEW): 12 tests covering every
  guaranteed property from ARCHITECTURE.md Section 14/19: zero/negative
  dt no-ops, fed progress proportional to dt, hunger running out
  mid-interval only credits the fed portion, a starving animal never
  progresses, hunger/happiness decay on wall time regardless of feeding
  state, both floors clamp at 0, pause-at-1.0 returns exactly one
  completion and does not accumulate further, one meal (+50 hunger)
  gives ~50 minutes of production, and **split invariance** both for a
  fixed split (1 x 8h vs 28,800 x 1s) and for random splits (seeded
  RNG, variable-length steps) -- confirmed both give identical results
  within float epsilon.

**Verification:** headless import clean (`ProductionRules` registered
as a global class); full GUT suite **195/195 passing, 394/394
asserts**.

### Task 4: collect check/apply — implemented

* `scripts/rules/production_rules.gd`: added `check_collect(a) ->
  ActionResult` (refuses `NOT_READY` when `progress < 1.0`, else OK)
  and `apply_collect(a, inventory, catalog) -> String` (adds 1 of the
  animal's product to the inventory, resets progress to 0, raises
  happiness by `gain_on_collect` clamped to 100, returns the collected
  product id so the caller can emit `product_collected` without a
  second species lookup).
* `tests/unit/test_production_rules.gd`: +8 tests covering both
  refusal/OK boundaries, the inventory actually receiving the right
  product, the returned product id, the progress reset, the
  happiness gain and its 100 clamp, and accumulation across repeated
  collects.

**Verification:** headless import clean; full GUT suite **203/203
passing, 403/403 asserts**.

### Task 5: `Game._advance_to`, SimTick, command retrofit — implemented

* `autoload/game.gd`: added `simulation_ticked`, `animal_status_changed`,
  `product_collected` signals; a child `SimTick` `Timer` (1.0s,
  `autostart = false`, created in `_ready()`, started by
  `begin_session()`) whose `timeout` calls `_advance_to(clock.now_ms())`.
* `_advance_to(now_ms: int) -> void`: computes `dt_ms = maxi(0, now_ms -
  state.last_seen_ms)`, advances every animal via
  `ProductionRules.advance_animal`, re-stamps `last_seen_ms`, emits
  `animal_status_changed` for any animal whose `StatusRules.flags()`
  changed, then `simulation_ticked`. Built in this narrowed shape
  (no `is_return`/`OfflineReport`) per the Phase 4 plan -- Phase 8 only
  extends this exact function, never adds a second advancement path.
* `_production_params_for(a)`: `cycle_seconds` is the catalog's base
  value directly (no building-multiplier division, no tutorial-boost
  substitution -- both deferred per the plan).
* `begin_session()`: now calls `_advance_to(clock.now_ms())` before
  emitting `state_loaded` (so a held/loaded state is never stale) and
  starts `_sim_tick`.
* `feed_animal()`: retrofitted to call `_advance_to(clock.now_ms())`
  first (ARCHITECTURE.md Section 14: "Order matters").
* `Game.collect(animal_id) -> ActionResult` (NEW): `_advance_to(now)` ->
  `ProductionRules.check_collect()` -> `apply_collect()` -> emit
  `product_collected`, `animal_changed`, `[animal_status_changed]`,
  `state_changed`. No `ActionGuard` debounce (collecting spends
  nothing; a repeat attempt refuses on its own via `NOT_READY` once
  progress has reset -- ADR-13 exists to stop double-spends, which
  does not apply here).
* Tests: `tests/integration/test_game_commands.gd` +12 (production
  advances before a feed's own mutation; `simulation_ticked` fires on
  every command; `collect`'s full success/refusal/signal/no-debounce
  behavior; `animal_status_changed` emitted correctly from both
  `feed_animal` and `collect`). `tests/integration/test_game_session.gd`
  +2 (`begin_session` starts `SimTick`; `begin_session` advances a
  stale held state before anything else reads it).

**Real bug found and fixed during self-verification** (not a Codex
finding -- caught by this session's own first test run): `feed_animal`
called `_advance_to` first (correct), but never re-checked
`StatusRules.flags()` after its OWN mutation (the meal itself), so a
feed that cleared HUNGRY never emitted `animal_status_changed` --
contradicting ARCHITECTURE.md Section 17's data flow, which explicitly
lists `[animal_status_changed]` in `feed_animal`'s own emit set, not
just `_advance_to`'s. Fixed by comparing flags before/after
`apply_meal()` inside `feed_animal` itself (the same pattern already
used in `collect()`), with a regression test that would have failed
against the old code.

**Also fixed:** `tests/unit/test_farm_input.gd`'s
`test_tapping_a_wheat_bubble_feeds_that_animal` used a
`StateFactory.game_state_with(...)` with the default `last_seen_ms = 0`
and the REAL `Game.clock` (not swapped) -- once `feed_animal` started
calling `_advance_to(clock.now_ms())`, the huge real-epoch gap fully
decayed hunger to 0 before the feed landed, breaking the test's
assumed arithmetic. Fixed by seeding `last_seen_ms` to
`Game.clock.now_ms()` at state-creation time, matching how every other
real-clock test in the suite already avoids this trap.

**Verification:** headless import clean; full GUT suite **216/216
passing, 423/423 asserts**.

### Task 7: views react to `animal_status_changed` — implemented

* `scenes/farm/world_ui/status_bubble.gd`: `bind()` gained a
  `product_id: String = ""` parameter, read only when
  `kind == Bubble.PRODUCT`. New `PRODUCT_COLORS` dictionary maps each
  MVP product to its DESIGN.md Section 2 resource color (egg
  `#FFF3D6`, milk `#E6F3FF`, pork `#F4909A` -- the same tokens already
  defined in `UiTokens`). Added the DESIGN.md Section 11 bob ("Product
  bubble bobs 4 dp on a 1.6 s loop"): `_process()` now adds a
  `sin(time / 1.6s * TAU) * 4dp` vertical offset on top of the
  anchor-tracking position, but ONLY for `Bubble.PRODUCT` -- FEED has
  no documented bob and stays static.
* `scenes/farm/farm_world.gd`: connects `Game.animal_status_changed`
  to a new `_on_animal_status_changed` that calls the existing
  `_refresh_bubble()` (now the second real trigger alongside
  `Game.animal_changed`); `_refresh_bubble()` passes the animal's
  `catalog.animal(species).product_id` to `bind()` when the computed
  kind is PRODUCT.
* `scenes/farm/animals/animal_view.gd`: `bind()` also connects
  `Game.animal_status_changed` to a new `_on_animal_status_changed`
  handler (same own-id filter as the existing `animal_changed`
  handler), so the placeholder face updates even when the SimTick (not
  a command) changes an animal's status with nothing else involved.
* Tests: `tests/unit/test_status_bubble.gd` +4 (product id accepted,
  FEED does not bob, PRODUCT bobs correctly at the quarter-cycle point,
  PRODUCT returns to the anchor after a full 1.6s cycle);
  `tests/unit/test_farm_world_bubbles.gd` +4 (a READY animal spawns a
  PRODUCT bubble, READY wins priority over HUNGRY, collecting removes
  the product bubble, `animal_status_changed` alone -- with no
  `animal_changed` -- still refreshes the bubble); `tests/unit/
  test_animal_view.gd` +2 (reacts to its own id's status change,
  ignores a different id's).

**Verification:**
1. Headless import clean.
2. Full GUT suite: **226/226 passing, 438/438 asserts**.
3. Visual check (throwaway scratch scene, deleted after): a READY
   chicken shows the pale egg-colored bubble, a READY cow shows the
   pale milk-colored bubble, a hungry pig shows the gold wheat bubble;
   calling `Game.collect("a1")` directly removes only that animal's
   product bubble, leaving the others untouched -- confirmed by
   before/after screenshots, not assumed.

### Task 8: bubble-tap routing (collect + feed) — implemented

* `scenes/farm/farm_world.gd`: `_on_bubble_tapped(id)` now recomputes
  `StatusRules.primary_bubble(StatusRules.flags(animal, catalog))`
  from CURRENT state (not the tapped `StatusBubble`'s own stored
  `bubble_kind`, which can be stale between spawn and tap -- e.g. a
  SimTick in between) and routes PRODUCT -> `Game.collect(id)`, FEED ->
  `Game.feed_animal(id)`. Still re-emits `bubble_tapped` first so a
  later `FarmScreen` can react too, matching every other `FarmInput`
  tier. Same documented TEMPORARY-seam status as the Phase 3 feed-tap
  wiring (bypasses the not-yet-built Animal Interaction sheet).
* Tests: `tests/unit/test_farm_input.gd` +1
  (`test_tapping_a_product_bubble_collects_that_animal` -- a real tap
  on a real spawned PRODUCT bubble reaches `Game.collect`, confirmed by
  the inventory actually gaining an egg and progress resetting, not
  just a signal assertion). The existing Phase 3 FEED-tap test
  continues to pass unchanged, confirming the `match` routing didn't
  regress the original path.

**Verification:** headless import clean; full GUT suite **227/227
passing, 442/442 asserts**.

### Task 9: full Phase 4 verification + Codex review — complete

**Self-verification (before Codex):**
* Headless import: zero errors, zero warnings.
* Full GUT suite: **227/227 passing, 442/442 asserts**.
* Visual check at both reference sizes (390x844, 360x640), using the
  REAL `SimTick` `Timer` (not a direct function call) to prove the
  online tick end to end: a chicken at progress 0.99 crosses to READY
  purely from the real 1-second timer firing over 2.2 real seconds, its
  egg-colored product bubble appears and bobs; `Game.collect()` then
  removes only that bubble.

**Codex full-phase review** (independent, read-only, explicitly told
not to trust this progress report and specifically asked to
independently re-verify the two bugs this session had already found
and fixed during its own self-verification; full detail and exact
scope in `docs/CODEX_REVIEW.md`):

* Both self-reported bugs (feed_animal's missing own
  `animal_status_changed` emission; the stale-`last_seen_ms` test
  fix) were independently confirmed genuinely fixed, not just claimed.
* **F-01 (Medium, INVALID):** Codex flagged `_advance_to()`'s
  unconditional `last_seen_ms = now_ms` re-basing on a backwards clock
  as a potential re-simulation bug. Classified INVALID after
  re-reading ARCHITECTURE.md Section 12.1 directly -- that section
  specifies this EXACT behavior as the intended design ("also re-bases
  a backwards clock... Otherwise a moved-back clock would freeze
  production until real time caught up"). Codex's suggested fix would
  contradict the documented design. No code change made; reasoning
  recorded in `docs/CODEX_REVIEW.md`.
* **F-02 (Low, VALID, fixed):** a test named "zero_or_negative_dt"
  only tested `dt=0`, and no test directly proved `_advance_to()`
  advances multiple animals independently in one call. Fixed with 2
  new tests (negative dt confirmed to touch nothing; a two-animal,
  different-species state confirmed both animals advance correctly
  from one shared call). Purely additive test coverage, no production
  code changed, so no re-review was required.

**Final verification after the fixes:** headless import clean; full
GUT suite **229/229 passing, 449/449 asserts** (+2 for F-02).

**Phase 4 completion criteria met:**
```text
Claude Implementation = COMPLETE
Verification           = PASS
Codex Review            = PASS
Unresolved VALID findings = 0
VALID_DEFERRED/OPTIONAL   = none this phase (F-01 INVALID, F-02 fixed)
```

### Next action

Phase 4 (Production) is COMPLETE. Phase 5 (Economy) is the next phase
per CLAUDE.md's phase order -- not started; awaiting explicit
instruction to begin, matching the same constraint Phase 3 was given
("Do not start Phase N+1 unless explicitly instructed").

---

## Review Status — Phase 4

### Claude Implementation

* Status: **COMPLETE** (all 9 tasks implemented, independently
  verified, Codex review passed; see "Phase 4 — Production" above)

### Codex Review

* Status: **PASS**

### Review Findings

* **F-01 (Medium): INVALID** -- the flagged backwards-clock re-basing
  behavior is ARCHITECTURE.md Section 12.1's explicit, documented
  design, not a defect. No code change.
* **F-02 (Low): VALID, fixed** -- test coverage gaps (negative dt,
  multi-animal advance). Fixed with 2 new tests, no production code
  change.

### Remaining Work

* The Animal Interaction sheet / Nav / AppShell / Overlay / BottomSheet
  / HUD / ToastHost wiring / ResultMessages / strings.csv UI shell --
  still unassigned to any phase; still recommended after Phase 4 is
  done (it now is), since the sheet needs both Feed and Collect, which
  now both exist.
* Building-multiplier division in `_production_params_for` -- Phase 6.
* Tutorial-boost substitution in `_production_params_for` -- unassigned
  tutorial work.
* `is_return`/`OfflineReport` extension to `_advance_to`, `OfflineRules`,
  `offline_progress_applied`, `on_app_backgrounded`/`on_app_resumed` --
  Phase 8.
* `InventoryState.remove()`, `bag_changed`, selling, Market, coins --
  Phase 5.
* Save/load (`to_dict`/`from_dict`/`extra`, `SaveService`) -- Phase 7.

### Next Action

* Begin Phase 5 (Economy) when explicitly instructed.

---

## Phase 5 — Economy

### Plan (Opus planning pass)

CLAUDE.md's Phase 5 scope ("Inventory, Product selling, Coins, Shop,
Basic economy rules") again interdepends on systems not yet built:
`BuildingRules`/`BuildingInstance` (Phase 6 -- housing capacity, feed
storage cap, Market sell bonus) and `SaveService` (Phase 7 -- the
synchronous save-on-sell with rollback). A planning pass resolved each
tension the same way Phases 3/4 did: build a correctly-scoped subset
now, with every deferral justified and recorded.

**Resolved decisions:**

1. **Build now:** `PlayerState.coins`/`level`, `InventoryState.remove()`,
   catalog parsing for `economy`/`newAnimal`, `EconomyRules`
   (`missing_coins`, `check_buy_animal`, `check_buy_feed_pack`,
   `sale_total`, `sell_all_total`), `Game.rng`, `Game.buy_animal()`,
   `buy_feed_pack()`, `sell_product()`, `sell_all()`, 5 new signals
   (`coins_changed`, `bag_changed`, `animal_added`, `feed_bought`,
   `products_sold`), `FarmWorld` spawning a view for a newly bought
   animal, and a temporary building-tap seam. **Deferred:** Phase 6
   (`BuildingInstance`, `FarmState.buildings`, `BuildingRules`, the
   `buildings` catalog group, `BUILDING_FULL`/`STORAGE_FULL`); Phase 7
   (`SaveService`, the sync save+rollback on sell, `to_dict`/`from_dict`);
   Phase 8 (`offline_coin_value`); unassigned (`xp`, `ProgressionRules`
   -- GDD's XP-source numbers are still the inert placeholder 0); Phase
   9 (`play_drop_in`); unassigned UI shell (Market screen, Bag, HUD
   pills, `Nav`, `ResultMessages`, the buy confirm dialog).
2. **`check_buy_animal` never returns `BUILDING_FULL` in Phase 5, but
   DOES enforce `LOCKED_BY_LEVEL`.** Housing capacity has no real
   source yet (no `BuildingInstance`), so leaving it unbounded is safe
   -- nothing can be saved before Phase 7, so an over-capacity farm
   only ever lives in memory. But `LOCKED_BY_LEVEL` needs only
   `PlayerState.level` (now built) and the already-existing
   `AnimalDefinition.unlock_level` -- skipping it would let a level-1
   player buy pigs/cows through the building-tap seam, contradicting
   GDD Section 8 and ARCHITECTURE.md Section 23 item 9's documented
   default ("the player stays at level 1, so Pig and Cow stay
   locked"). Housing placement already works with no Phase 6 system:
   `FarmWorld._spawn_animal_view` already finds a bought animal's
   `BuildingView` purely from the authored `BuildingSlots` scene
   content via `definition.housing_building_id`.
3. **`STORAGE_FULL` never checked in Phase 5** -- same unbounded-until-
   Phase-7 reasoning; feed accumulates without limit in
   `PlayerState.feed` until a real cap exists. `refuseOverflowingFeedPack`
   is still parsed in full (static groups are always parsed in full),
   just unread until Phase 6.
4. **Market sell bonus uses the exact Phase 4 pattern**:
   `EconomyRules.sale_total(unit_price, qty, bonus_percent)` and
   `sell_all_total(bag, farm, c)` keep their full documented
   signatures (never need to change later), with `Game` always
   passing `bonus_percent = 0.0` for now -- identical to how
   `ProductionRules.Params.cycle_seconds` took the catalog's base
   value directly in Phase 4 with no multiplier division yet.
   Rounding: round the TOTAL half-up (GDD Section 7's OPEN
   recommendation), not each item.
5. **Synchronous save-on-sell is skipped entirely in Phase 5** --
   there is no `SaveService` to call and nothing to roll back to. A
   comment marks exactly where Phase 7 inserts the snapshot/
   `save_now()`/rollback sequence between apply and emit.
   `ActionResult.Code.SAVE_FAILED` stays unreachable until then (it
   already exists in the enum from Phase 3 Task 1).
6. **`PlayerState.coins` added now**, seeded from `catalog.start.coins`,
   mirroring exactly how `feed` was seeded in Phase 2/3 -- GDD Section
   7 names Coins as the Phase 5 resource.
7. **`PlayerState.level` added now** (seeded from `catalog.start.level`),
   since it has a genuine Phase 5 reader (`LOCKED_BY_LEVEL`, item 2
   above). **`xp` stays deferred** -- no `ProgressionRules` exists and
   `xpPerEvent` is still all zeros, so an `xp` field would have no
   reader, exactly the premature scope CLAUDE.md Section 16 warns
   against. In real play, `level` stays fixed at 1 (XP is inert), so
   only chickens are actually buyable; pigs/cows are exercised in
   tests via `StateFactory`'s level override.
8. **`InventoryState.remove(id, n) -> bool`** (refuses to go negative,
   makes no change on refusal) is the only new `InventoryState` method
   this phase needs. `to_dict`/`from_dict` wait for Phase 7.
9. **Shop: a documented temporary building-tap seam in `FarmWorld`**,
   explicitly asked to the user and approved: tapping a housing
   building (Coop/Barn/Pen) buys that species if affordable, tapping
   Feed Storage buys a feed pack, tapping Market sells everything.
   `building_tapped` already exists with no consumer. Unlike the
   Phase 3/4 bubble-tap seams (which matched approved design), this
   one has **no design-doc counterpart** -- UI_SPEC routes a building
   tap to Building Details, and GDD Section 7 requires a confirm
   dialog for every animal purchase, which this seam skips. Approved
   anyway as the only way to exercise the full phase end-to-end in
   real play before the Shop UI exists (otherwise Phases 3/4's own
   feed/collect work stays unreachable too, since `new_game_state()`
   always starts with zero animals and buying is the only way to get
   one).
10. **Animal sell-back: not built.** GDD Section 7's own OPEN item
    recommends "no selling of animals in the MVP"; ARCHITECTURE.md
    Section 23 item 8 already states this as the built default.
    Adopted directly, not escalated.

**Smaller resolved points:** `ActionGuard` keys: `"purchase"` shared by
both buy commands (so a double tap cannot buy two different things,
per ADR-13's existing "purchase" key), `"sell"` for both sell commands
-- both using `catalog.economy.purchase_lock_ms`. Unknown species/
product -> `UNKNOWN_ID`. Selling a 0 quantity or `sell_all` on an empty
bag -> `NOTHING_TO_SELL`. A new animal's `hunger`/`happiness`/`health`
come from the catalog's `newAnimal` group; its name is drawn from
`default_names` via `Game.rng` (empty string if the pool is empty --
true for pig/cow today, an existing OPEN item). `result.data` carries
`animal_id` for buys, `coins_earned`/`sold` for sells. Every command
follows `feed_animal`'s established order (`_advance_to` -> check ->
guard -> apply -> emit), the reverse of ARCHITECTURE.md Section 10.4's
listed order -- intentional, since a refused action must never consume
the debounce lock (ActionGuard's own documented contract), matching
Phase 3/4's precedent exactly.

**Task breakdown:** T1 state additions (`coins`/`level`,
`InventoryState.remove`) → T2 catalog parsing (`economy`/`newAnimal`)
→ T3 `EconomyRules` part 1 (buy checks) → T4 `EconomyRules` part 2
(sell totals) → T5 `Game` buy commands → T6 `Game` sell commands → T7
`FarmWorld` reacts to `animal_added` → T8 building-tap seam → T9 full
verification + Codex review.

### Task 1: State additions — implemented

* `scripts/state/player_state.gd`: added `coins: int = 0` and
  `level: int = 1`. `xp` remains deliberately absent (no
  `ProgressionRules` reader exists yet).
* `scripts/state/inventory_state.gd`: added `remove(product_id, amount)
  -> bool`, refusing (and making no change) when that would take the
  quantity below zero.
* `autoload/game.gd`: `new_game_state()` now also seeds
  `fresh.player.coins = catalog.start.coins` and
  `fresh.player.level = catalog.start.level`.
* `tests/helpers/state_factory.gd`: `game_state_with()` gained optional
  `coins: int = 0, level: int = 1` trailing parameters (defaults
  preserve every existing positional caller unchanged).
* Tests: `tests/unit/test_inventory_state.gd` +4 (`remove` succeeds and
  reduces quantity, removing exactly all leaves zero, refuses to go
  negative without mutating, refuses from an unseeded/zero product);
  `tests/integration/test_game_session.gd` +2 (`new_game_state` seeds
  coins/level from `catalog.start`).

**Verification:** headless import clean (`InventoryState`/`PlayerState`
re-register cleanly); full GUT suite **235/235 passing, 459/459
asserts**.

### Task 2: Catalog parsing (economy, newAnimal) — implemented

* `scripts/definitions/game_catalog.gd`: added `EconomyParams`
  (`purchase_lock_ms`, `feed_pack_feed`, `feed_pack_price`,
  `refuse_overflowing_feed_pack` -- the last has no Phase 5 reader,
  parsed now anyway per the established pattern) and `NewAnimalParams`
  (`hunger`, `happiness`, `health` -- a freshly bought animal's
  starting stats), parsed from balance.json's `economy`/`newAnimal`
  groups.
* `validate()` extended: `purchase_lock_ms >= 0`, `feed_pack_feed >= 1`,
  `feed_pack_price >= 0`, every `newAnimal` value in `0..100`.
* `tests/unit/test_game_catalog.gd`: +7 tests (fixture values parsed
  correctly for both new groups; one test per new validation rule).

**Verification:** headless import clean; full GUT suite **241/241
passing, 470/470 asserts** (including `test_balance_data.gd` against
the live file).

### Task 3+4: `EconomyRules` (buy checks + sell totals) — implemented

Combined into one task: both are small, cohesive pure functions in the
same new file, naturally tested together rather than as two separate
PLAN/IMPLEMENT/TEST cycles.

* `scripts/rules/economy_rules.gd` (NEW): `missing_coins(coins, cost)`;
  `check_buy_animal(player, species, catalog)` -- refuses `UNKNOWN_ID`,
  then `LOCKED_BY_LEVEL` (`player.level < unlock_level`), then
  `NOT_ENOUGH_COINS` with `missing` filled in; never returns
  `BUILDING_FULL` (no `BuildingInstance`/capacity exists yet -- Phase 6
  inserts that check between level and coins, per
  ARCHITECTURE.md Section 10.4's documented priority order);
  `check_buy_feed_pack(player, catalog)` -- refuses `NOT_ENOUGH_COINS`
  only; never returns `STORAGE_FULL` (Phase 6); `sale_total(unit_price,
  qty, bonus_percent)` -- rounds the TOTAL half-up (GDD Section 7's
  OPEN recommendation), `bonus_percent` always `0.0` from `Game` until
  Phase 6's `BuildingRules.sell_bonus_percent` exists (same pattern as
  Phase 4's `cycle_seconds`, signature never needs to change later);
  `sell_all_total(bag, catalog, bonus_percent)` -- sums every catalog
  product's quantity × price, rounds once on the grand total.
* `tests/unit/test_economy_rules.gd` (NEW): 18 tests -- `missing_coins`
  both branches; `check_buy_animal`'s full priority order (unknown
  species, locked-by-level over not-enough-coins, exact-affordability
  boundary, unlocked-at-higher-level); `check_buy_feed_pack`'s refusal
  with the correct shortfall; `sale_total`'s no-bonus/with-bonus/
  half-up-rounding cases, including a case proving the TOTAL is
  rounded rather than each item (1 coin × 3 qty × 50% bonus: 4.5 → 5,
  not 1.5→2 per item × 3 = 6); `sell_all_total` summing multiple
  products, ignoring zero-quantity entries, an empty bag, and the
  bonus applied to the grand total.

**Verification:** headless import clean (`EconomyRules` registered as
a global class); full GUT suite **259/259 passing, 495/495 asserts**.

### Task 5: `Game.buy_animal()`/`Game.buy_feed_pack()` — implemented

* `autoload/game.gd`: added `rng: RandomNumberGenerator`, 5 new signals
  (`coins_changed`, `bag_changed`, `animal_added`, `feed_bought`,
  `products_sold`), `_generate_animal_id()` (exactly
  ARCHITECTURE.md Section 8.1's `"a_%d_%04x" % [now_ms, rng.randi() &
  0xFFFF]`), `buy_animal(species) -> ActionResult`, and
  `buy_feed_pack() -> ActionResult`.
* Both follow `feed_animal`'s established order:
  `_advance_to(now)` -> `EconomyRules.check_*()` -> `ActionGuard`
  debounce (checked only once the purchase would otherwise succeed) ->
  apply -> emit. Both share the single `"purchase"` debounce key
  (ARCHITECTURE.md Section 10.4 ADR-13: buy animal, buy feed pack, and
  upgrade all share one key so a double tap cannot buy two different
  things).
* `buy_animal`: spends `definition.price`, appends a new
  `AnimalInstance` housed at `definition.housing_building_id`
  (ARCHITECTURE.md Section 8.1: "Building ids are the definition ids in
  the MVP"), seeded from `catalog.new_animal`'s hunger/happiness/
  health, named from `definition.default_names` via `Game.rng` (empty
  string when the pool is empty -- true for pig/cow today, an existing
  OPEN item), `result.data.animal_id` set for the future "Meet Pip"
  card.
* `buy_feed_pack`: spends `catalog.economy.feed_pack_price`, adds
  `catalog.economy.feed_pack_feed` to the wallet. GDD Section 7:
  "Bought instantly, no confirm dialog" -- this command has no
  UI-level step to skip; it is itself the instant-purchase path.
* `tests/integration/test_game_commands_buy.gd` (NEW): 19 tests --
  success + full mutation (housing, starting stats, name-from-pool,
  empty-pool name), `result.data.animal_id`, full signal sets on
  success, every refusal code (`UNKNOWN_ID`, `LOCKED_BY_LEVEL`,
  `NOT_ENOUGH_COINS` with the correct `missing`) leaving state
  untouched, the shared `"purchase"` debounce key across both commands
  (buying an animal locks out an immediate feed-pack buy), the
  debounce window's full refused/expired/non-consuming-on-refusal
  behavior (same 3-test pattern as Phase 3's `feed_animal` coverage),
  and `_advance_to` running before either command's own mutation.

**Verification:** headless import clean; full GUT suite **278/278
passing, 540/540 asserts**.

### Task 6: `Game.sell_product()`/`Game.sell_all()` — implemented

* `autoload/game.gd`: `sell_product(product_id) -> ActionResult` --
  `_advance_to(now)` -> refuse `NOTHING_TO_SELL` if the stack is empty
  -> `ActionGuard("sell")` debounce -> remove the WHOLE stack
  (UI_SPEC Section 8.1/9: per-row Sell always sells everything), credit
  `EconomyRules.sale_total()`'s coins -> emit `coins_changed`,
  `bag_changed`, `products_sold`, `state_changed`.
  `sell_all() -> ActionResult` -- same order, refuses `NOTHING_TO_SELL`
  only when every product is at 0, credits
  `EconomyRules.sell_all_total()`'s coins. Both use the `"sell"`
  debounce key (separate from `buy_animal`/`buy_feed_pack`'s shared
  `"purchase"` key -- confirmed with a dedicated test that a sale does
  not lock out an immediately-following buy). `bonus_percent` is always
  `0.0` until Phase 6. No synchronous save/rollback yet -- a comment in
  both functions marks exactly where Phase 7 inserts the snapshot/
  `save_now()`/rollback sequence between apply and emit;
  `ActionResult.Code.SAVE_FAILED` stays unreachable until then.
* `tests/integration/test_game_commands_sell.gd` (NEW): 13 tests --
  whole-stack selling (not partial), full signal sets including the
  exact `products_sold` payload shape (`{product_id: qty}` for
  `sell_product`, the full multi-product dict for `sell_all`), both
  `NOTHING_TO_SELL` paths (a zero-quantity product, an unknown
  product), an empty-bag `sell_all` refusal, the debounce window's full
  refused/expired/non-consuming-on-refusal behavior, confirmation that
  `"sell"` and `"purchase"` are genuinely independent debounce keys,
  and a full end-to-end integration test (`test_full_loop_buy_feed_
  collect_sell`) exercising buy → feed → wait a full production cycle
  via `FakeClock` → collect → sell in one continuous run.

**Bug found and fixed during this task's own test authoring** (not a
production-code bug -- a pre-existing test-isolation gap in two
earlier test files, surfaced by this task's new full-loop test being
the first to run a `FakeClock` across a multi-minute span while real
wall-clock time also elapses during test execution):
`tests/integration/test_game_session.gd`'s
`test_begin_session_sets_state_and_emits_state_loaded` and
`tests/integration/test_main_boots.gd` both called/triggered
`Game.begin_session()`, which starts the real repeating `SimTick`
`Timer` on the `Game` singleton, but neither stopped it afterward --
unlike the other two tests in `test_game_session.gd`, which already
did. Since `Game` is a singleton that outlives any single test file
across the whole suite run, a left-running timer could fire
`_advance_to()` against whatever `Game.clock`/`Game.state` a LATER
test happens to be using at that moment. Fixed by adding the missing
`Game._sim_tick.stop()` calls. (This session's actual new-test failure
during development turned out to be a separate, simpler test-authoring
mistake: `test_full_loop_buy_feed_collect_sell` didn't account for
`before_each()`'s 12-egg bag baseline seeded for the file's other
tests; fixed by resetting the bag to zero at the start of that one
test. The SimTick fix is a real, independent robustness improvement
kept regardless.)

**Verification:** headless import clean; full GUT suite **291/291
passing, 577/577 asserts**.

### Task 7: `FarmWorld` reacts to `animal_added` — implemented

* `scenes/farm/farm_world.gd`: connects `Game.animal_added` to a new
  `_on_animal_added(animal_id)` that looks up the new
  `AnimalInstance` and calls the existing `_spawn_animal_view()` for
  it alone -- does NOT rebuild every existing view (that would
  needlessly re-roll every other animal's wander position and
  recreate their `StatusBubble`s). No drop-in animation
  (`play_drop_in`) yet -- that is Phase 9 polish.
* `tests/unit/test_farm_world_animals.gd`: +3 tests -- a new animal
  gets its own view without disturbing the existing one's identity
  (same `AnimalView` instance, not a replacement), the new view uses
  the correct per-species scene, and an `animal_added` for an id not
  actually in `Game.state` is tolerated without crashing.

**Verification:** headless import clean; full GUT suite **294/294
passing, 584/584 asserts**.

### Task 8: building-tap seam (buy/sell) — implemented

* `scenes/farm/farm_world.gd`: `building_tapped`'s FarmInput connection
  now routes through a new `_on_building_tapped(id)` (previously a
  bare re-emit with no consumer). Still re-emits `building_tapped`
  first. Tolerates `Game.state == null` (same guard pattern as
  `_rebuild_animals`) -- a building tap is always reachable, unlike
  the bubble taps which only exist once an animal does. Routing: a new
  `_species_housed_in(building_id)` reverse lookup (a linear scan over
  the 3-entry animal catalog, per ARCHITECTURE.md Section 8.1:
  "Building ids are the definition ids in the MVP") maps a housing
  building tap to `Game.buy_animal(species)`; `"feed_storage"` ->
  `Game.buy_feed_pack()`; `"market"` -> `Game.sell_all()`. Documented
  as a temporary seam with **no design-doc counterpart** (unlike the
  Phase 3/4 bubble-tap seams, which matched approved design) -- UI_SPEC
  routes a building tap to Building Details, and GDD Section 7 requires
  a confirm dialog for every animal purchase, which this seam skips.
  Explicitly asked to the user and approved before implementation (see
  the Phase 5 plan above).
* `tests/unit/test_farm_input.gd`: +3 end-to-end tests -- a real tap on
  the authored `chicken_coop` slot buys a chicken (coins spent, animal
  added, correct species); a real tap on `feed_storage` buys a feed
  pack; a real tap on `market` sells the whole bag. Each resets
  `Game._guard` (this file's other building/bubble tests share the
  singleton guard and would otherwise debounce-lock each other's
  purchases).

**Bug found and fixed during this task's own test authoring**: the
pre-existing `test_farm_world_reemits_building_tapped` test (Phase 1)
never sets `Game.state`, and crashed once `_on_building_tapped` started
unconditionally calling `Game.buy_animal()` for a chicken-coop tap --
`_advance_to()` dereferenced a null `state.last_seen_ms`. Fixed by
adding the `Game.state == null` guard described above, which also
protects every other building-tap route the same way.

**Verification:** headless import clean; full GUT suite **297/297
passing, 591/591 asserts**.

### Task 9: full Phase 5 verification + Codex review — complete

**Self-verification (before Codex):**
* Headless import: zero errors, zero warnings.
* Full GUT suite: **297/297 passing, 591/591 asserts**.
* Visual check at both reference sizes (390x844, 360x640), using the
  real building-tap seam handler (not direct function calls) to prove
  the end-to-end flow: tapping the Coop buys a chicken (200 → 100
  coins), feeding it, fast-forwarding one production cycle, collecting
  the egg, tapping Market to sell it (100 → 105 coins) -- the
  wheat/product status bubbles appeared and disappeared correctly
  throughout.

**Codex full-phase review** (independent, read-only, explicitly told
not to trust this progress report and specifically asked to
independently re-verify the three bugs this session had already found
and fixed during its own self-verification; full detail and exact
scope in `docs/CODEX_REVIEW.md`):

* All three self-reported bugs (`SimTick` timer leak across two
  pre-existing test files; `_on_building_tapped`'s null-state crash;
  three new tests sharing the real `ActionGuard` singleton) were
  independently confirmed genuinely fixed, not just claimed.
* **F-01 (Low, VALID, fixed):** a sell-all signal test only checked
  that `bag_changed` fired at all, never verifying each sold product's
  own before/after quantities or the exact emission count. Fixed with
  one new regression test; no production code changed, so no
  re-review was required.
* Codex also explicitly confirmed: economy refusal priority order and
  half-up total-rounding are correct; every command's debounce-after-
  check ordering is correct; the `"purchase"`/`"sell"` key separation
  is correct; the animal-id format matches ARCHITECTURE.md exactly;
  static-definition/runtime-state separation holds; the 3-species
  building-tap routing is correct and unmapped building ids safely do
  nothing; no out-of-scope system was implemented.

**Final verification after the fix:** headless import clean; full GUT
suite **298/298 passing, 594/594 asserts** (+1 for F-01).

**Phase 5 completion criteria met:**
```text
Claude Implementation = COMPLETE
Verification           = PASS
Codex Review            = PASS
Unresolved VALID findings = 0
VALID_DEFERRED/OPTIONAL   = none this phase
```

### Next action

Phase 5 (Economy) is COMPLETE. Phase 6 (Buildings) is the next phase
per CLAUDE.md's phase order -- not started; awaiting explicit
instruction to begin, matching the same constraint every prior phase
was given ("Do not start Phase N+1 unless explicitly instructed").

---

## Review Status — Phase 5

### Claude Implementation

* Status: **COMPLETE** (all 9 tasks implemented, independently
  verified, Codex review passed; see "Phase 5 — Economy" above)

### Codex Review

* Status: **PASS**

### Review Findings

* **F-01 (Low): VALID, fixed** -- `sell_all()`'s `bag_changed` signal
  test lacked per-product parameter/count assertions. Fixed with one
  new regression test, no production code change.

### Remaining Work

* `BuildingRules`/`BuildingInstance`/`FarmState.buildings`, the
  `buildings` catalog group, `BUILDING_FULL`/`STORAGE_FULL`, the
  building-multiplier division in `_production_params_for`, the Market
  sell-bonus division in `EconomyRules` callers -- Phase 6.
* The building-tap seam is explicitly temporary: once the real Shop UI
  (Market screen, buy confirm dialog, Animal Interaction sheet) exists,
  it replaces this seam entirely -- still unassigned to any phase.
* `xp`/`ProgressionRules` -- unassigned (GDD's XP-source numbers are
  still the inert placeholder 0).
* Synchronous save-on-sell with snapshot/rollback, `SaveService`,
  `to_dict`/`from_dict` -- Phase 7.
* `offline_coin_value` -- Phase 8.
* `play_drop_in` and other Phase 9 polish.

### Next Action

* Begin Phase 6 (Buildings) when explicitly instructed.

---

## Phase 6 — Buildings

### Plan (Opus planning pass)

Unlike Phase 4/5, Phase 6's own system (`BuildingDefinition`/
`BuildingInstance`/`BuildingRules`) has no forward dependency on an
unbuilt system -- ARCHITECTURE.md Section 10.2 is fully self-contained
and buildable now. But Phase 6 is also the phase that FILLS IN three
placeholder seams Phases 4/5 deliberately left pointing here: the
production-speed multiplier, `BUILDING_FULL`/`STORAGE_FULL` refusals,
and the Market sell bonus. A planning pass confirmed the exact shape
and found two corrections to the initial brief: `EconomyRules.
check_buy_animal`/`check_buy_feed_pack` must change their first
parameter from `PlayerState` to `state: GameState` (they need `farm`
to reach `BuildingRules.is_full`/`feed_capacity` -- this does NOT
violate the "pure function signatures never change" principle, since
that principle was about `ProductionRules.Params`/`EconomyRules.
sale_total`/`sell_all_total`, which do keep their exact signatures; the
buy-check functions were always documented in ARCHITECTURE.md Section
10.4 as taking `state: GameState`, and Phase 5's narrower
`PlayerState`-only signature was the interim shape).

**Resolved decisions:**

1. **Classes, exactly per ARCHITECTURE.md Section 7.2/10.2:**
   `UpgradeDefinition` (level, cost, capacity, production_multiplier,
   feed_capacity, sell_bonus_percent -- neutral defaults for fields
   that don't apply to a kind), `BuildingDefinition` (id, `Kind` enum
   {HOUSING, FEED_STORAGE, MARKET}, starts_built, levels,
   max_level(), level_def()), `BuildingInstance` (id, level only --
   `extra`/`to_dict`/`from_dict` wait for Phase 7, same as
   PlayerState/InventoryState's own deferrals), `BuildingRules` (all 9
   functions). `GameCatalog` gains `building()`, `building_ids()`,
   `building_of_kind()`, and `validate()` gains Section 7.2's exact
   checks (housing id exists and is HOUSING kind, every building has
   >=1 level, costs >=0, exactly one FEED_STORAGE/MARKET -- "no
   duplicate ids" needs no check since JSON object keys are already
   unique) plus two extra checks with real Phase 6 readers: an
   unrecognized `kind` string, and a non-positive
   `production_multiplier` on a HOUSING building (Game divides by it).
2. **"Construction" = starting buildings, not a build flow.**
   `new_game_state()` creates a level-1 `BuildingInstance` for every
   `starts_built` building. GDD Section 6's own OPEN item already
   recommends this (all five exist at L1, no purchase step) and
   ARCHITECTURE.md Section 10.1 already says "a construction flow is
   not designed in UI_SPEC and is not built" -- the same kind of
   CLAUDE.md-wording-to-approved-design mapping Phase 1 did for
   "Building placement foundation".
3. **All four Phase 4/5 placeholder seams are retrofitted now:**
   (a) `_production_params_for` divides `cycle_seconds` by
   `BuildingRules.production_multiplier(state.farm, a.building_id,
   catalog)` -- since every command calls `_advance_to` first, an
   upgrade never retroactively speeds up already-elapsed time.
   (b) `check_buy_animal` (now taking `state: GameState`) inserts
   `BUILDING_FULL` between the level check and the coins check, per
   ARCHITECTURE.md Section 10.4's documented order.
   (c) `check_buy_feed_pack` (also now `state: GameState`) inserts
   `STORAGE_FULL` after the coins check. When
   `economy.refuse_overflowing_feed_pack` is true (the live/fixture
   default), the whole pack is refused if `feed + feed_pack_feed >
   feed_capacity` (GDD Section 6: "a pack that would partially
   overflow is refused, not partially applied"). The `false` branch
   (refuse only when already at cap, then clamp on apply) is this
   plan's own reasonable assumption, since GDD only specifies the
   `true`/default behavior -- recorded as a minor owner flag, not
   escalated. Buildings with no `BuildingInstance` yet (should not
   happen in practice) default to capacity 0/full-true/multiplier
   1.0/feed_capacity 0/bonus 0.0 -- safe, inert fallbacks for a
   programmer-error state.
   (d) `sell_product`/`sell_all` pass
   `BuildingRules.sell_bonus_percent(state.farm, catalog)` instead of
   the Phase 5 placeholder `0.0`.
4. **`Game.upgrade_building(building_id) -> ActionResult`** (NEW):
   same transaction order as every other command --
   `_advance_to` -> `BuildingRules.check_upgrade` (refuses `UNKNOWN_ID`,
   then `MAX_LEVEL`, then `NOT_ENOUGH_COINS` with `missing`) ->
   `ActionGuard` debounce -> apply (spend `next_upgrade.cost`,
   increment `level`) -> emit `coins_changed`, `building_upgraded(id,
   new_level)` (new signal), `state_changed`. Uses the EXISTING
   `"purchase"` debounce key (ARCHITECTURE.md Section 10.4 ADR-13
   already lists "buy animal, buy feed pack, upgrade" as sharing one
   key). No XP awarded (`xpPerEvent.upgrade` is still the inert 0;
   unassigned progression work). `play_upgrade`'s 1.2s animation is
   Phase 9.
5. **`FarmWorld` building views now spawn from state**, per
   ARCHITECTURE.md Section 10.1's "Building views from state" (already
   anticipated in `_spawn_building_views()`'s own doc comment). Iterates
   `Game.state.farm.buildings`, looks up each id's authored
   `BuildingSlots` marker for POSITION ONLY (not as the iteration
   source), skips with `push_warning` if no marker exists. Spawning
   buildings and animals must now run in one ordered `rebuild()`
   reacting to `Game.state_loaded` (buildings first, since animal
   wander areas read the housing view), tolerating a null state the
   same way `_rebuild_animals()` already does -- `FarmWorld._ready()`
   runs before `Main._ready()`'s `begin_session()` call, so the first
   in-tree pass has no session yet. Real-play visuals are identical
   (same 5 buildings, same positions) since the fixture/live building
   ids already match the authored marker names exactly.
6. **Upgrade trigger: a long-press (400ms) on any building**, added to
   the existing temporary building-tap seam -- explicitly asked to and
   approved by the user (same framing as Phase 5's buy/sell seam: no
   design-doc counterpart, UI_SPEC routes a building tap to Building
   Details with a confirm dialog, which this skips). Needed because
   once (b)/(c) above are live, a real playthrough can hit a genuine
   dead end (coop full, feed capped) with no way to progress before
   the real Shop UI exists. Requires a new `FarmInput.
   building_long_pressed(id)` signal (today long-press only fires for
   animals) and a `FarmWorld` route to `Game.upgrade_building`.
7. **Building capacity/level UI (the "Coop Lv 1 - 2/4" tag, amber full
   state, affordable-upgrade badge) is explicitly deferred** --
   confirmed with the user. CLAUDE.md's Phase 6 list has no UI item;
   this is the same unassigned-UI-shell bucket as Phase 5's Market
   screen. Capacity/level are verified via tests and direct state
   inspection in visual checks this phase, not on-screen text.
8. **`FarmState.buildings: Array[BuildingInstance]`** plus a
   `get_building(id)` helper mirroring `get_animal()` is the only new
   state field needed. `unrecognized_buildings`/`unrecognized_animals`
   wait for Phase 7's `SaveCodec` -- the only thing that could ever
   produce or read a save-round-trip entry whose id isn't in the
   catalog; building the field now would have no reader (CLAUDE.md
   Section 16).

**Task breakdown:** T1 definitions + catalog parsing/validation → T2
state + starting buildings → T3 `BuildingRules` (capacity/multiplier/
housed_count/feed_capacity/sell_bonus_percent + upgrade helpers,
merged per the Phase 5 precedent of combining small cohesive rules
tasks) → T4 `EconomyRules` retrofit (`state: GameState` signature,
`BUILDING_FULL`/`STORAGE_FULL`) → T5 `Game` retrofit (production
multiplier, sell bonus) → T6 `Game.upgrade_building` → T7 `FarmWorld`
building views from state → T8 long-press upgrade input seam → T9 full
verification + Codex review.

### Task 1: Definitions + catalog parsing/validation — implemented

* `scripts/definitions/upgrade_definition.gd` (NEW): `level`, `cost`,
  `capacity`, `production_multiplier`, `feed_capacity`,
  `sell_bonus_percent`, each defaulting to its kind-neutral value.
* `scripts/definitions/building_definition.gd` (NEW): `id`, `kind`
  (`Kind` enum), `starts_built`, `levels`, `max_level()`,
  `level_def()`. Also keeps `raw_kind` (the as-parsed string) so
  `validate()` can detect a genuinely unrecognized kind -- the enum
  parser itself tolerantly falls back to HOUSING for an unknown string
  rather than crashing, matching the project's error-handling pattern
  (ARCHITECTURE.md Section 18: "Programmer errors ... never crash in
  release").
* `scripts/definitions/game_catalog.gd`: parses the `buildings` group
  into `BuildingDefinition`s; added `building()`, `building_ids()`,
  `building_of_kind(kind)`. `validate()` extended: every animal's
  `housing_building_id` exists AND is a HOUSING-kind building; every
  building has at least one level; every level's cost is
  non-negative; every HOUSING level's `production_multiplier` is
  positive; an unrecognized `kind` string is a problem; exactly one
  FEED_STORAGE and exactly one MARKET building exist.
* `tests/unit/test_game_catalog.gd`: +28 tests (all 5 buildings
  parsed; Coop/Feed Storage/Market level fields match GDD exactly;
  `building_of_kind()` for both singleton kinds; unknown building id;
  one test per new validation rule, using a shared minimal
  `_valid_buildings()` helper so each test breaks exactly the one rule
  it targets). Fixed one pre-existing test
  (`test_unknown_top_level_keys_are_ignored_not_errors`) that built a
  catalog with no `buildings` block at all -- now correctly flagged by
  the new FEED_STORAGE/MARKET-count rules, so the test was given a
  minimal valid `buildings` block to isolate its own actual concern
  (unknown keys being ignored) from the newly-enforced building rules.

**Verification:** headless import clean (`BuildingDefinition`/
`UpgradeDefinition` registered as global classes); full GUT suite
**316/316 passing, 637/637 asserts** (including `test_balance_data.gd`
against the live file, confirming the real `buildings` block already
satisfies every new rule).

### Task 2: State + starting buildings — implemented

* `scripts/state/building_instance.gd` (NEW): minimal `BuildingInstance`
  with only `id`, `level: int = 1` -- `extra`/`to_dict`/`from_dict`
  deliberately absent (no reader until Phase 7's SaveCodec).
* `scripts/state/farm_state.gd`: added `var buildings:
  Array[BuildingInstance]` and `get_building(id)` mirroring
  `get_animal()`.
* `autoload/game.gd`: `new_game_state()` now creates a level-1
  `BuildingInstance` for every catalog building with `starts_built`
  true ("Construction" per CLAUDE.md Phase 6 maps to this seeding, not
  a player-facing build flow -- see the Phase 6 plan above).
* `tests/helpers/state_factory.gd`: new `building(id, level)` helper;
  `game_state_with()` gained an optional `building_levels: Dictionary`
  parameter and now seeds all 5 MVP buildings at level 1 by default
  (overridable per-building), so `BuildingRules` always has a real
  instance to read in existing/future tests instead of falling back to
  the "missing instance" default.
* Tests: `tests/integration/test_game_session.gd` +2 (every
  `starts_built` building gets a level-1 instance; exactly 5 buildings
  are created, matching GDD Section 6: "Six buildings... the other
  five have three levels").

**Verification:** headless import clean (`BuildingInstance` registered
as a global class); full GUT suite **318/318 passing, 648/648
asserts**.

### Task 3: `BuildingRules` — implemented

* `scripts/rules/building_rules.gd` (NEW): all 9 functions per
  ARCHITECTURE.md Section 10.2 -- `housed_count`, `capacity`,
  `is_full`, `production_multiplier`, `feed_capacity`,
  `sell_bonus_percent` (the last two each read the single
  FEED_STORAGE/MARKET building via `GameCatalog.building_of_kind`),
  `is_max_level`, `next_upgrade` (null at max, per GDD Section 6's
  "the Upgrade button is hidden" at L3), `check_upgrade` (refuses
  `UNKNOWN_ID`, then `MAX_LEVEL`, then `NOT_ENOUGH_COINS` with
  `missing` -- GDD Section 6: "Upgrade requires coins only"). A
  missing `BuildingInstance` (a programmer-error state that should
  never occur in real play) returns safe, inert fallbacks rather than
  crashing (capacity/feed_capacity 0, is_full true, multiplier/bonus
  neutral) per ARCHITECTURE.md Section 18.
* `tests/unit/test_building_rules.gd` (NEW): 21 tests covering every
  function against the fixture's real per-level values (Coop capacity
  4/8/12 and multiplier 1.0/1.25/1.5, Feed Storage 100/250/500, Market
  0%/5%/10%), the exact-capacity boundary, a stale is-full check not
  surviving an upgrade, and `check_upgrade`'s full refusal priority
  order with the correct cost/shortfall math.

**Verification:** headless import clean (`BuildingRules` registered as
a global class); full GUT suite **339/339 passing, 675/675 asserts**.

### Task 4: `EconomyRules` retrofit — implemented

* `scripts/rules/economy_rules.gd`: `check_buy_animal`/
  `check_buy_feed_pack` now take `state: GameState` (not just
  `PlayerState`), matching ARCHITECTURE.md Section 10.4's own
  documented signatures -- Phase 5's narrower signature was the
  interim shape before `BuildingRules` existed to check against.
  `check_buy_animal` inserts `BUILDING_FULL` (via
  `BuildingRules.is_full`) between the level check and the coins
  check, per ARCHITECTURE.md Section 10.4's documented priority order.
  `check_buy_feed_pack` inserts `STORAGE_FULL` after the coins check:
  when `economy.refuse_overflowing_feed_pack` is true (the default),
  refuses the WHOLE pack if `feed + feed_pack_feed > feed_capacity`
  (GDD Section 6: "a pack that would partially overflow is refused,
  not partially applied"); when false, refuses only once feed has
  already reached the cap.
* `autoload/game.gd`: `buy_animal`/`buy_feed_pack` updated to pass
  `state` instead of `state.player`. `buy_feed_pack`'s apply step now
  clamps the resulting feed to `BuildingRules.feed_capacity()` (GDD
  Section 6: "Feed beyond Feed Storage capacity cannot be held" --
  still enforced even when the overflow switch allowed a
  partially-overflowing purchase through check_buy_feed_pack).
* `tests/unit/test_economy_rules.gd`: retrofitted every `PlayerState`-
  only call to build a full `GameState` via `StateFactory`; +10 new
  tests for the newly-reachable `BUILDING_FULL`/`STORAGE_FULL` paths
  (refusal, the exact-capacity boundary, allowed again after an
  upgrade, and both codes' priority relative to the pre-existing
  refusal checks).

**Caught during this task's own verification** (not a Codex finding):
the signature change initially made `test_economy_rules.gd` a GDScript
parse error, which GUT silently SKIPPED rather than failing loudly --
the run still reported "All tests passed" with a suspicious drop in
script count (23 instead of the expected 24) and a buried `[WARNING]`
line, easy to miss. Caught by noticing the warning and the reduced
script count, not by a failing assertion. Fixed by retrofitting the
whole file to build real `GameState`s via `StateFactory` instead of
bare `PlayerState`s.

**Verification:** headless import clean; full GUT suite **346/346
passing, 682/682 asserts**, 24 scripts loaded (confirming no file is
silently skipped).

### Task 5: `Game` retrofit (production multiplier, sell bonus) — implemented

* `autoload/game.gd`: `_production_params_for()` now divides
  `cycle_seconds` by `BuildingRules.production_multiplier(state.farm,
  a.building_id, catalog)`, per ARCHITECTURE.md Section 14's exact
  formula. `sell_product`/`sell_all` now pass
  `BuildingRules.sell_bonus_percent(state.farm, catalog)` instead of
  the Phase 5 placeholder `0.0`.
* Tests: `tests/integration/test_game_commands.gd` +2 (a chicken housed
  in an L2 Coop (1.25x multiplier) produces 25% more progress than L1
  over the same elapsed time; an upgrade mid-session does NOT
  retroactively speed up time that was already simulated at the old
  level before the upgrade -- only time elapsed after it uses the new
  multiplier, confirming `_advance_to`'s "order matters" guarantee
  extends correctly through this retrofit).
  `tests/integration/test_game_commands_sell.gd` +2 (`sell_product`
  applies the live Market L2 5% bonus; `sell_all` applies the L3 10%
  bonus to the grand total, both via the real `Game` command, not just
  the pure `EconomyRules` function in isolation).

**Verification:** headless import clean; full GUT suite **350/350
passing, 689/689 asserts**.

### Task 6: `Game.upgrade_building` — implemented

* `autoload/game.gd`: added `building_upgraded(building_id, new_level)`
  signal and `upgrade_building(building_id) -> ActionResult`, following
  the established transaction order: `_advance_to` ->
  `BuildingRules.check_upgrade` -> `ActionGuard("purchase")` debounce
  (checked only once the upgrade would otherwise succeed) -> spend
  `next_upgrade.cost`, increment `level` -> emit `coins_changed`,
  `building_upgraded`, `state_changed`. Shares the `"purchase"`
  debounce key with `buy_animal`/`buy_feed_pack`, per ARCHITECTURE.md
  Section 10.4 ADR-13. No XP awarded (`progression.xpPerEvent.upgrade`
  is still inert). No synchronous save (Phase 7).
* `tests/integration/test_game_commands_upgrade.gd` (NEW): 11 tests --
  success + full mutation, the full signal set (confirming the exact
  `building_upgraded` payload), every refusal code (`UNKNOWN_ID`,
  `MAX_LEVEL`, `NOT_ENOUGH_COINS` with the correct shortfall) leaving
  state untouched, reaching L3 via two sequential upgrades, the shared
  `"purchase"` debounce key locking out an immediate `buy_animal`, the
  debounce window's full refused/expired/non-consuming behavior, and
  `_advance_to` running before the upgrade's own mutation. One test
  design mistake caught and fixed during this task's own
  verification: the debounce test initially used the same starting
  coins as every other test, so the second upgrade attempt was
  correctly refused with `NOT_ENOUGH_COINS` (not enough coins left for
  a THIRD level) before the debounce check was ever reached -- not a
  production bug, just insufficient coins seeded for what the test
  intended to isolate. Fixed by seeding enough coins for two attempts.

**Verification:** headless import clean; full GUT suite **361/361
passing, 714/714 asserts**.

### Task 7: `FarmWorld` building views from state — implemented

* `scenes/farm/farm_world.gd`: `_spawn_building_views()` and
  `_rebuild_animals()` merged into one ordered `_rebuild()` (buildings
  spawned first, since `_spawn_animal_view()` reads the housing
  building's own view for its wander area), reacting to
  `Game.state_loaded`, tolerating a null `Game.state` the same way the
  old `_rebuild_animals()` already did. New `_spawn_building_view(instance)`
  iterates `Game.state.farm.buildings` (not `BuildingSlots`' scene
  children directly) and looks up each id's authored
  `BuildingSlots/<id>` marker for POSITION ONLY -- skips with a
  `push_warning` if no marker exists or the catalog has no matching
  definition, per ARCHITECTURE.md Section 10.1's "Building views from
  state" and Section 18's "never crash" error-handling pattern.
* `tests/unit/test_farm_world.gd`: now sets up a real `Game.state`
  (previously relied on test-order leakage from other files, which
  happened to work before this retrofit but was never a deliberate,
  deterministic setup); +3 tests (removing a building from state means
  no view spawns for it even though its authored slot marker still
  exists; a `state_loaded` rebuild replaces views rather than
  duplicating them; a null `Game.state` leaves the Buildings container
  empty rather than crashing).

**Verification:**
1. Headless import clean.
2. Full GUT suite: **364/364 passing, 721/721 asserts**.
3. Visual check (throwaway scratch scene, deleted after): all 5
   buildings render at their exact original authored positions through
   a full real boot (`Main._ready()` -> `Game.begin_session()` ->
   `FarmWorld.state_loaded` rebuild), confirming the retrofit is
   visually identical in real play, not just passing tests.

### Task 8: long-press-to-upgrade input seam — implemented

* `scenes/farm/farm_input.gd`: added `building_long_pressed(id)` signal;
  `_on_long_press_timer_timeout()` now matches on hit tier (`"animal"`
  -> `animal_long_pressed`, `"building"` -> `building_long_pressed`,
  same 400ms `LONG_PRESS_DURATION` -- GDD Section 6 specifies no
  separate duration for buildings).
* `scenes/farm/farm_world.gd`: re-emits `building_long_pressed`, routed
  through a new `_on_building_long_pressed(id)` that calls
  `Game.upgrade_building(id)`. Documented as a second TEMPORARY seam
  with no design-doc counterpart (same caveat as the Phase 5 buy/sell
  tap seam), explicitly asked to and approved by the user: once
  `BUILDING_FULL`/`STORAGE_FULL` refusals went live in Task 4, a real
  playthrough could otherwise hit a genuine dead end (coop full, feed
  capped) with no way to progress before the real Shop UI exists.
* `tests/unit/test_farm_input.gd`: +3 (a long press on a building fires
  `building_long_pressed` with the correct id; a fired long press
  suppresses the eventual tap-on-release, same pattern already proven
  for animals; a real end-to-end long press on the authored
  `chicken_coop` slot reaches `Game.upgrade_building`, confirmed by the
  building's level and the player's coins actually changing, not just
  a signal assertion).

**Bug found and fixed during this task's own verification** (not a
Codex finding): `test_farm_world_reemits_building_tapped` (Phase 1)
never set up `Game.state`, relying on leftover state from a previous
test in the file -- a latent fragility exposed by Task 7's retrofit
(building views now spawn from `Game.state.farm.buildings`, so a test
with no state spawns zero building views and every "building" tap
silently falls through to "ground"). Fixed by giving the test its own
explicit `Game.state`/`Game.catalog` setup and teardown, matching every
other state-dependent test in the file.

**Verification:** headless import clean; full GUT suite **367/367
passing, 725/725 asserts**.

### Task 9: full Phase 6 verification + Codex review — complete

**Self-verification (before Codex):**
* Headless import: zero errors, zero warnings.
* Full GUT suite: **367/367 passing, 725/725 asserts**.
* Visual check at both reference sizes (390x844, 360x640), using the
  real building-tap AND long-press seams (not direct function calls):
  buying 4 chickens fills the Coop (1200 → 800 coins), a 5th buy
  attempt is refused with `BUILDING_FULL`, a real long-press upgrade
  brings the Coop to L2 (800 → 300 coins), and the 5th chicken then
  succeeds -- the full capacity/upgrade loop confirmed end to end.

**Codex full-phase review** (independent, read-only, explicitly told
not to trust this progress report and specifically asked to
independently re-verify the four bugs this session had already found
and fixed during its own self-verification; full detail and exact
scope in `docs/CODEX_REVIEW.md`):

* All four self-reported bugs (the `test_economy_rules.gd` silent
  parse-error skip; `test_farm_world.gd`'s and
  `test_farm_world_reemits_building_tapped`'s leaked-state fragility;
  the under-seeded-coins test design mistake in
  `test_game_commands_upgrade.gd`) were independently confirmed
  genuinely fixed, not just claimed.
* **F-01 (Medium, VALID, fixed):** `buy_feed_pack()`'s `feed_bought`
  signal always reported the nominal pack size, even when the capacity
  clamp meant fewer units were actually added. Fixed to emit the
  actual delta (`new_feed - old_feed`); covered by a new regression
  test that exercises the `refuse_overflowing_feed_pack = false`
  partial-overflow path directly.
* **F-02 (Medium, INVALID):** the long-press-to-upgrade seam spends
  coins/changes level with no confirmation, which GDD Section 6
  requires. Classified INVALID -- this is the identical,
  already-approved tradeoff as the Phase 5 building-tap buy/sell seam;
  re-confirmed with the user before classifying rather than assuming
  the prior approval covered it automatically. No code change;
  reasoning recorded in `docs/CODEX_REVIEW.md`.
* Codex also explicitly confirmed: no out-of-scope system was
  implemented (no `SaveService`, `BuildingInstance.extra`, XP awards,
  building-level UI, Shop UI, upgrade animation, tutorial boost, or
  construction/placement flow); building levels/effects, exact-capacity
  detection, economy refusal priorities, production-multiplier and
  sell-bonus wiring, upgrade transaction order, and state-driven
  building spawning all match the documented behavior.

**Final verification after the fix:** headless import clean; full GUT
suite **368/368 passing, 727/727 asserts** (+1 for F-01).

**Phase 6 completion criteria met:**
```text
Claude Implementation = COMPLETE
Verification           = PASS
Codex Review            = PASS
Unresolved VALID findings = 0
VALID_DEFERRED/OPTIONAL   = none this phase (F-02 INVALID, documented)
```

### Next action

Phase 6 (Buildings) is COMPLETE. Phase 7 (Save) is the next phase per
CLAUDE.md's phase order -- not started; awaiting explicit instruction
to begin, matching the same constraint every prior phase was given
("Do not start Phase N+1 unless explicitly instructed").

---

## Review Status — Phase 6

### Claude Implementation

* Status: **COMPLETE** (all 9 tasks implemented, independently
  verified, Codex review passed; see "Phase 6 — Buildings" above)

### Codex Review

* Status: **PASS**

### Review Findings

* **F-01 (Medium): VALID, fixed** -- `buy_feed_pack()`'s `feed_bought`
  signal reported the nominal pack size instead of the actual (clamped)
  amount added. Fixed, covered by a new regression test.
* **F-02 (Medium): INVALID** -- the long-press-to-upgrade seam's lack
  of a confirm dialog is the identical, already-approved tradeoff as
  the Phase 5 building-tap seam. No code change.

### Remaining Work

* Both temporary input seams (building-tap buy/sell, long-press
  upgrade) are explicitly replaced once the real Shop UI (Market
  screen, Building Details, confirm dialogs) exists -- still
  unassigned to any phase.
* Building capacity/level UI (the "Coop Lv 1 - 2/4" tag, amber
  full-state, affordable-upgrade badge) -- explicitly deferred,
  unassigned.
* `xp`/`ProgressionRules`, tutorial-boost substitution -- unassigned.
* `BuildingInstance.extra`, `to_dict`/`from_dict`, `SaveService`, sync
  save/rollback on sell -- Phase 7.
* `play_upgrade`'s 1.2s animation and other Phase 9 polish.

### Next Action

* Begin Phase 7 (Save) when explicitly instructed.

---

## Phase 7 — Save

### Plan (Opus planning pass)

ARCHITECTURE.md Section 8 (save format) and Section 10.4 (save
triggers) are fully specified, but Section 8.1's save shape depends on
fields no system currently reads (`settings`, `tutorialStep`,
`PlayerState.xp`). Unlike a `balance.json` tunable that can wait for
its owning phase, these are **structural**: `SaveCodec.decode()` must
itself reject a save whose `settings` key is not a Dictionary, so the
shape has a real reader (SaveCodec) starting in this phase even though
no gameplay system reads the values yet. The planning pass also
surfaced three genuine product-shape questions with no documented
answer, resolved by the user via `AskUserQuestion` before implementation
began:

1. **Scope: save/load engine only, no UI this phase.** Main
   Menu/Splash/Settings screens are UI_SPEC-documented but not required
   to exercise the save engine; building them now would mix Phase 7
   with unrelated UI work. *User selected: "Save/load engine only, no
   UI."*
2. **Damaged-save handling with no confirm-dialog UI yet.** On
   `DAMAGED`/`TOO_NEW`, start a fresh game in memory only and leave the
   on-disk file untouched (no silent overwrite, no UI that doesn't
   exist yet to ask the player). *User selected: "Start fresh in
   memory only, don't touch the file."*
3. **Autosave/persistence is always-on from boot**, not gated behind a
   "tap Play" step that doesn't exist in the no-UI scope. *User
   selected: "Yes, saving is on immediately from boot."*

**Resolved task breakdown (T1-T10):**

* **T1 — State shape.** `SettingsState` (new); `GameState.
  tutorial_step`/`settings`/`extra`; `PlayerState.xp`/`extra`;
  `BuildingInstance.extra`; `InventoryState.to_dict`/`from_dict`;
  `FarmState.unrecognized_buildings`/`unrecognized_animals` +
  `to_buildings_array()`/`to_animals_array()` (two save root keys, so no
  single `to_dict()`); `to_dict`/`from_dict` on every runtime class.
  `GameState` itself gets no `to_dict`/`from_dict` -- the full root
  composition (`version`, `lastSeen`, nested groups) is `SaveCodec`'s
  job alone, per ARCHITECTURE.md's save table ("`version` is handled by
  SaveCodec and is not stored on state").
* **T2 — SaveFileIO.** Atomic write (tmp -> verify-by-parsing -> copy
  main to `.bak.json` -> rename tmp over main), `read_candidates()`,
  `quarantine_damaged()`.
* **T3 — SaveMigrator.** Empty `STEPS` dict + `migrate()` loop (no
  real migration exists yet at v1; the mechanism is built, not
  exercised).
* **T4/T5 — SaveCodec.** `encode()`; `DecodeResult`; decode steps:
  structure check (-> DAMAGED), version check (-> TOO_NEW or
  `SaveMigrator.migrate()`), field-type check (-> DAMAGED), range
  clamps (logged, not failures), unknown fields preserved to
  `extra`/unrecognized arrays, missing starting buildings re-added.
* **T6 — SaveService autoload.** Registered after `Game`;
  `load_game()` in the documented order -> `LoadResult`;
  `request_autosave()` (2s debounce, not restarted if already
  pending); `save_now(manual)`; retry schedule at 5s/15s/60s;
  `start_new_farm_after_damage()`; `persistence_enabled` guard (saving
  disabled is a no-op returning `true`); replaceable `io: SaveFileIO`
  field for test isolation.
* **T7 — Autosave retrofit.** `request_autosave()` after
  `state_changed.emit()` on `feed_animal`/`collect`/`buy_animal`/
  `buy_feed_pack`/`upgrade_building`'s success paths.
* **T8 — Sell synchronous-save retrofit.** `sell_product`/`sell_all`
  snapshot coins + inventory before applying, call `SaveService.
  save_now()` after, roll back both and return `ActionResult.
  of(SAVE_FAILED)` with no signals on failure (still emits
  `save_failed(false)` and starts the retry schedule); normal signals
  on success.
* **T9 — Main boot + backgrounding.** Three-branch boot decision tree
  (OK / NO_SAVE / DAMAGED-TOO_NEW) per decision 2 above;
  `Game.on_app_backgrounded()`; `Main._notification()` wired to
  `NOTIFICATION_APPLICATION_PAUSED`/`FOCUS_OUT`/`WM_CLOSE_REQUEST`.
  `on_app_resumed()`/`is_return` explicitly deferred to Phase 8.
* **T10 — Full verification.** Full suite, headless import, a real
  launch/save/kill/relaunch check, independent Codex review, fix VALID
  findings, update docs.

### Task 1: State shape — implemented

* `scripts/state/settings_state.gd` (NEW): `sound`, `music`,
  `vibration`, `reminders` (defaults false per GDD Section 9),
  `language` ("en" default), `extra`; `to_dict()`/`from_dict()`.
* `PlayerState`: added `xp: int = 0`, `extra: Dictionary = {}`,
  `to_dict()`/`from_dict()`.
* `BuildingInstance`: added `extra: Dictionary = {}`,
  `to_dict()`/`from_dict()`.
* `InventoryState`: added `to_dict()`/`from_dict()` -- no separate
  `extra`; per ARCHITECTURE.md Section 10.3 the whole `quantities`
  dict is the save-shaped data, unknown product keys kept as-is.
* `FarmState`: added `unrecognized_buildings`/
  `unrecognized_animals: Array[Dictionary]`, `to_buildings_array()`,
  `to_animals_array()` (populated by `SaveCodec.decode()`, which has
  the catalog to check ids/species against -- not by `FarmState`
  itself).
* `GameState`: added `tutorial_step: int = 0`, `settings:
  SettingsState = SettingsState.new()`, `extra: Dictionary = {}`. No
  `to_dict`/`from_dict` of its own (see Plan above).
* `Game.new_game_state()`: also seeds `fresh.player.xp =
  catalog.start.xp`.
* New tests: `tests/unit/test_settings_state.gd` (5),
  `tests/unit/test_player_state.gd` (4),
  `tests/unit/test_building_instance.gd` (4); `tests/unit/
  test_inventory_state.gd` +2 (round-trip, unrecognized-key
  preservation).

**Verification:** headless import clean (`SettingsState` registered as
a new global class); full GUT suite **383/383 passing, 760/760
asserts** (28 scripts, +15 tests / +1 script over Phase 6's 368/368).
No regressions.

### Task 2: SaveFileIO — implemented

* `scripts/save/save_file_io.gd` (NEW): `SaveFileIO extends RefCounted`
  per ARCHITECTURE.md Section 11.5's exact signatures. `_init(dir)`
  creates `dir` recursively (so throwaway test dirs work).
  `write_atomic(json_text)` follows the documented 4-step sequence
  (write `.tmp` -> verify by reading back and `JSON.parse_string` ->
  copy main to `.bak.json` if main exists -> rename `.tmp` over main,
  with a remove-then-rename fallback for desktop/editor use).
  `read_candidates()` surfaces raw `{source, text}` for whichever of
  main/tmp/backup exist, in that order, with no parsing/decision-making
  (that is `SaveService.load_game()`'s job next task).
  `quarantine_damaged()` renames main to `farmora_save.damaged.json`,
  no-op returning `OK` if main is absent.
* `tests/helpers/failing_save_file_io.gd` (NEW): `FailingSaveFileIO
  extends SaveFileIO` with a settable `fail_write: bool` so a later
  `SaveService` retry/backoff test can force a deterministic write
  failure without real disk-full conditions.
* `tests/integration/test_save_file_io.gd` (NEW, 8 tests): fresh-dir
  write + round-trip; two writes -> backup holds the first write's
  content, main holds the second; a successful write always leaves
  main as valid JSON equal to the input; `read_candidates()` on an
  empty dir, after one write, and surfacing directly-placed `.tmp`/
  `.bak.json` files with main absent (simulating a crash mid-save);
  `quarantine_damaged()`'s rename and its main-absent no-op.

**Verification:** headless import clean (`SaveFileIO`/
`FailingSaveFileIO` registered as global classes); full GUT suite
**391/391 passing, 785/785 asserts** (29 scripts, +8 tests / +1 script
over Task 1's 383/383). No regressions. Independently re-run by the
orchestrator after the implementing agent's own report, not taken on
summary alone.

### Task 3: SaveMigrator — implemented

* `scripts/save/save_migrator.gd` (NEW): `const STEPS: Dictionary = {}`
  (empty -- no v2 schema exists yet) and `migrate(d: Dictionary, steps:
  Dictionary = STEPS) -> Dictionary`, which duplicates `d`, then loops
  while `steps.has(version)`, applying each pure step and advancing
  `version` from the step's own result. The `steps` parameter defaults
  to the real `STEPS` for every production call site
  (`SaveCodec.decode()`, next task); it exists only so a test can
  exercise the loop without mutating the `const STEPS` in place --
  GDScript's static analyzer genuinely rejects
  `SaveMigrator.STEPS[1] = ...` from outside the class ("Cannot assign
  a new value to a constant"), discovered while writing the first
  version of the test and fixed by adding the seam rather than
  weakening `STEPS` to a `var`.
* `tests/unit/test_save_migrator.gd` (NEW, 5 tests): empty-`STEPS`
  no-op; non-mutation of the input dict; a single fake v1->v2 step;
  chained v1->v2->v3 steps; unknown-key preservation through a step.

**Verification:** headless import clean; full GUT suite **396/396
passing, 791/791 asserts** (30 scripts, +5 tests / +1 script over Task
2's 391/391). No regressions, no warnings.

### Task 4+5: SaveCodec — implemented

Combined into one task since both parts land in the same file.

* `scripts/save/decode_result.gd` (NEW): `DecodeResult extends
  RefCounted`, mirroring `ActionResult`'s shape (enum + plain fields +
  `static func of(...)`). `enum Status { OK, NO_SAVE, DAMAGED,
  TOO_NEW }`; `status`, `state: GameState` (null unless OK),
  `problems: Array[String]` (one short note per clamp/fixup).
* `scripts/save/save_codec.gd` (NEW): `CURRENT_VERSION := 1`,
  `encode(state) -> Dictionary` (composes the full root per
  ARCHITECTURE.md Section 11.2, merging `state.extra`'s unknown
  root-level keys without overwriting known ones), `decode(d, c) ->
  DecodeResult` implementing Section 11.3's 6 ordered steps exactly:
  (1) structure check -> DAMAGED; (2) version check -> TOO_NEW, or
  `SaveMigrator.migrate()` + re-check structure for `version <
  CURRENT_VERSION`; (3) known-field type checks -> DAMAGED; (4) range
  clamps on coins/feed/bag quantities/hunger/happiness/health/progress/
  building level, each logged to `problems`; (5) unrecognized building
  ids / animal species preserved verbatim into
  `FarmState.unrecognized_buildings`/`unrecognized_animals` rather than
  parsed, written back unchanged by a later `encode()`; (6) any
  `starts_built` catalog building missing from the save is added at
  level 1 (ARCHITECTURE.md Section 10.2). A missing-but-present field
  defaults via each class's own `from_dict()`; only a PRESENT field
  with the wrong type is DAMAGED.
* `tests/unit/test_save_codec.gd` (NEW, 12 tests): full round-trip
  (wallet/bag/buildings/animals/tutorial_step/settings/last_seen_ms);
  DAMAGED on a non-Dict `wallet` and a non-Array `buildings`; TOO_NEW
  on `version > CURRENT_VERSION`; DAMAGED on a wrong-typed known field;
  clamp + logged problem for negative coins, out-of-range
  hunger/happiness, and an above-max building level; unrecognized
  building/animal preserved and round-tripped through a subsequent
  `encode()`; a missing `starts_built` building added at level 1; a
  `version < CURRENT_VERSION` save reaching `SaveMigrator.migrate()`
  without being rejected; the committed fixture parsing end-to-end.
* `tests/fixtures/saves/v1_valid.json` (NEW): a realistic save matching
  ARCHITECTURE.md Section 11.2's documented example exactly.

**Verification:** headless import clean (`SaveCodec`/`DecodeResult`
registered as global classes); full GUT suite **408/408 passing,
849/849 asserts** (31 scripts, +12 tests / +1 script over Task 3's
396/396). No regressions, no warnings. Independently re-run by the
orchestrator after the implementing agent's own report and the
production code read end-to-end before accepting the claim.

### Task 6+7+8: SaveService autoload, autosave retrofit, sell sync-save — implemented

Combined into one delegation since SaveService's contract and its only
caller (`Game`) had to land together to stay consistent.

* `scripts/save/load_result.gd` (NEW): `LoadResult extends RefCounted`,
  `{status: DecodeResult.Status, state: GameState, source: String}` +
  `static of(...)` -- reuses `DecodeResult.Status` directly rather than
  inventing a parallel enum.
* `autoload/save_service.gd` (NEW): `persistence_enabled: bool = false`
  (only ever read here, never set true on its own initiative -- Task 9
  owns flipping it after a successful boot); `io: SaveFileIO`
  (replaceable per-test); `configure(snapshot_provider, catalog)`;
  `request_autosave()` (2s one-shot timer, started only if not already
  running, no-op while persistence disabled); `save_now(manual = false)
  -> bool` (no-op returning `true` while disabled; otherwise calls the
  snapshot provider, `JSON.stringify`s it, `io.write_atomic()`s it;
  success resets the retry schedule and emits `save_succeeded(manual)`;
  failure emits `save_failed(manual)` and schedules a retry);
  `retry_now()`; `start_new_farm_after_damage()` (quarantine then
  enable persistence); `load_game() -> LoadResult` implementing
  ARCHITECTURE.md Section 11.5's Load order table exactly (`NO_SAVE` on
  no candidates; a `TOO_NEW` main short-circuits without trying
  tmp/backup; otherwise main, then tmp, then backup, first to decode OK
  wins; `DAMAGED` if nothing decodes). Retry schedule is 5s/15s/60s via
  one reused one-shot timer + an index into
  `RETRY_DELAYS_SECONDS`, matching ARCHITECTURE.md Section 24 item 9
  ("after the third retry no more timed retries run; the next trigger
  tries again"). Never imports `Game` -- gets data only through the
  `snapshot_provider` Callable. No `class_name` (same autoload
  convention as `Game`).
* `project.godot`: `SaveService` added to `[autoload]` immediately
  after `Game`.
* `autoload/game.gd`: `_ready()` now calls
  `SaveService.configure(_save_snapshot, catalog)`; new
  `_save_snapshot() -> Dictionary` (advances to now, returns
  `SaveCodec.encode(state)`). `SaveService.request_autosave()` added
  right after `state_changed.emit()` in `feed_animal`, `collect`,
  `buy_animal`, `buy_feed_pack`, `upgrade_building`. `sell_product`/
  `sell_all` retrofitted per ARCHITECTURE.md Section 10.4: snapshot
  `player.coins` and `inventory.quantities.duplicate()` before
  mutating, apply the sale, call `SaveService.save_now()` -- on
  failure, roll back both snapshotted values and return
  `ActionResult.of(SAVE_FAILED)` with **no** signals emitted at all
  (not even `state_changed`); on success, emit the full existing signal
  set unchanged (no extra `request_autosave()`, since the synchronous
  save already covers the change). `SAVE_FAILED` is reachable for the
  first time since the enum was built in Phase 3.
* Real production fix found while testing: `_try_decode()` uses the
  instance `JSON.new()`/`.parse()` API instead of the static
  `JSON.parse_string()` convenience method, because the static method
  logs a noisy engine-level error on invalid input even when the
  caller handles the null return correctly -- relevant in production
  too, since a genuinely damaged save file is an expected, handled
  case, not a bug to spam logs over.
* New/modified tests: `tests/integration/test_save_service.gd` (NEW,
  17 tests: `save_now` disabled/success/manual-flag/failing-io;
  `request_autosave` disabled/starts-timer/no-restart-on-double-call;
  `load_game` NO_SAVE/OK-from-main/backup-fallback-on-damaged-main/
  DAMAGED-when-nothing-decodes, plus `load_finished` signal;
  `start_new_farm_after_damage`). `test_game_commands.gd`/
  `test_game_commands_buy.gd`/`test_game_commands_upgrade.gd`: added
  SaveService timer/persistence reset to setup/teardown plus one test
  per retrofitted command asserting the autosave timer starts after
  success (a deterministic proxy for "request_autosave() was called"
  without a real 2s wait). `test_game_commands_sell.gd`: before_each
  now points `SaveService.io` at a throwaway directory and configures
  it against `Game.state`/`Game.catalog`; 5 new tests cover the
  synchronous save actually happening before the call returns, both
  sell commands' full rollback-and-SAVE_FAILED path under a forced
  `FailingSaveFileIO` write failure (coins, inventory, and all four
  signals checked), and that a failed synchronous sell-save still lets
  `SaveService` itself emit `save_failed(false)` and start its own
  retry timer.

**Verification:** headless import clean (`SaveService` registered as
an autoload, `LoadResult` as a global class); full GUT suite
**432/432 passing, 907/907 asserts** (32 scripts, +24 tests / +1 script
over Task 4+5's 408/408). No regressions, no warnings. Independently
re-verified by the orchestrator: re-ran the full suite directly, read
`save_service.gd` end-to-end, read both sell commands' full rollback
logic in `game.gd`, and read the `FailingSaveFileIO`-forced-failure
tests and the before_each/after_each autoload-state cleanup before
accepting the claim.

### Task 9: Main boot + backgrounding — implemented

Implemented directly (not delegated) given the product-decision
sensitivity of the boot tree and the risk of a singleton-wide
regression in a pre-existing, widely-depended-on test premise.

* `autoload/game.gd`: new `on_app_backgrounded() -> void` -- a no-op
  when `state == null` (backgrounded before any session has started),
  otherwise `_advance_to(clock.now_ms())` then `SaveService.save_now()`
  (synchronous, like sell, not the 2s debounce -- the process may not
  get another chance to run before the OS suspends/kills it). File
  header updated to reflect this is no longer "deliberately absent."
* `scenes/main/main.gd`: replaced the Phase 2-6 "always start a fresh
  session" seam with the real three-branch boot tree against
  `SaveService.load_game()`, matching the three answers the user
  approved during Phase 7 planning exactly: **OK** -> `begin_session`
  with the loaded state, `persistence_enabled = true` immediately (no
  Play-gate -- this phase has no Main Menu UI to gate behind); **NO_SAVE**
  -> `begin_session(Game.new_game_state())`, `persistence_enabled =
  true` immediately (same no-Play-gate answer); **DAMAGED/TOO_NEW** ->
  `begin_session(Game.new_game_state())` IN MEMORY ONLY,
  `persistence_enabled` stays at `SaveService`'s own default `false`
  (nothing overwrites the bad file), `push_error()` so the condition is
  visible in development even with no damaged-save menu to show a
  player yet (matches the user's approved answer: "start fresh in
  memory only, don't touch the file" -- no automatic quarantine either,
  since that requires a player-facing "Start new farm" confirmation
  this phase doesn't build). `_notification()` extended to also handle
  `NOTIFICATION_APPLICATION_PAUSED`/`FOCUS_OUT`/`WM_CLOSE_REQUEST`,
  calling `Game.on_app_backgrounded()`.
* `tests/integration/test_main_boots.gd`: rewritten. The old
  `test_main_boot_starts_a_game_session` test asserted the Phase 2-6
  "always empty farm" premise, which Task 9 deliberately replaces --
  not a regression, an intentional behavior change per the approved
  design. `before_each`/`after_each` now point `SaveService.io` at a
  throwaway directory and fully reset `SaveService`'s
  persistence/timers/retry-index (the exact leaked-autoload-state
  pattern Phase 6's postmortem warned about, now applying to a second
  autoload). New tests cover all 3 boot branches (NO_SAVE enables
  persistence on an empty farm; OK loads a real pre-written save's
  wallet and enables persistence; DAMAGED and TOO_NEW both start a
  fresh in-memory session, leave `persistence_enabled` false, leave the
  bad file untouched on disk, and assert the expected `push_error` via
  GUT's `assert_push_error()`) plus one test confirming
  `NOTIFICATION_APPLICATION_FOCUS_OUT` triggers a real synchronous save
  that `SaveService.load_game()` can then read back.
* **Real-engine verification (not just unit tests):** ran the actual
  compiled scene via `godot --headless --path . res://scenes/main/main.tscn`
  with a temporary throwaway probe autoload (removed afterward, along
  with the real `user://` save directory it created): first run booted
  NO_SAVE, called `Game.buy_feed_pack()`, waited out the real 2-second
  autosave debounce, and confirmed `user://save/farmora_save.json` was
  written to the real OS filesystem with the correct mutated
  `coins`/`feed` values in the documented JSON shape; a second,
  completely separate process launch of the same scene then loaded
  that real file back (`coins=125, feed=15, persistence=true`),
  confirming the full launch -> mutate -> autosave -> kill -> relaunch
  -> restore round trip genuinely works end-to-end, not merely inside
  GUT's test harness.

**Verification:** headless import clean; full GUT suite **436/436
passing, 922/922 asserts** (32 scripts, +4 tests over Task 6-8's
432/432 -- net of 9 new boot tests replacing 5 old ones). No
regressions. Plus the real-engine round-trip above.

### Task 10: Full Phase 7 verification — complete

* Final headless import: clean, zero errors/warnings.
* Final full GUT suite: **436/436 passing, 922/922 asserts** (32
  scripts) -- unchanged from Task 9, confirming Task 10 introduced no
  further code changes before review.
* Independent full-phase Codex review (codex-cli 0.158.0, read-only
  sandbox, explicitly told not to trust any implementation summary).
  **Result: PASS, 0 findings** across all 10 requested checks (write
  sequence, decode steps, load order, the sell-rollback path flagged as
  highest-risk, autoload test isolation, static typing, the boot tree,
  scope discipline, test quality). Full detail in
  `docs/CODEX_REVIEW.md`'s "Phase 7 Full-Phase Review" section,
  including a process note: the first review attempt was given the
  full `CLAUDE.md`/`ARCHITECTURE.md`/`PROGRESS.md` to read and
  exhausted its budget before producing any findings; re-run with
  small, purpose-built excerpts per CLAUDE.md Section 20.11, it
  completed normally. Worth remembering for future full-phase reviews
  as the docs keep growing.
* No VALID findings to fix. No VALID_DEFERRED. Nothing to re-review.

**Phase 7 completion criteria met:**
```text
Claude Implementation = COMPLETE
Verification           = PASS
Codex Review            = PASS
Unresolved VALID findings = 0
VALID_DEFERRED/OPTIONAL   = none this phase
```

### Next action

Phase 7 (Save) is COMPLETE. Phase 8 (Offline Progression) is the next
phase per CLAUDE.md's phase order -- not started; awaiting explicit
instruction to begin, matching the standing constraint every prior
phase was given.

---

## Review Status — Phase 7

### Claude Implementation

* Status: **COMPLETE** (all 10 tasks implemented, independently
  verified, Codex review passed with 0 findings; see "Phase 7 — Save"
  above)

### Codex Review

* Status: **PASS**

### Review Findings

* None.

### Remaining Work

* Phase 7's own explicit out-of-scope items, unassigned to any phase
  yet: Main Menu/Splash/Settings UI, the damaged-save menu, "Start new
  farm"/"Save now"/"Try now" UI wiring (the methods exist on
  `SaveService`, just no caller).
* `on_app_resumed()`, the `is_return`/`OfflineReport` extension to
  `_advance_to()`, and the Phase 8-owned "load the backup
  automatically" policy's own OPEN item in ARCHITECTURE.md Section
  11.5 -- Phase 8.
* The two temporary input seams from Phases 5/6 (building-tap buy/sell,
  long-press upgrade) remain explicitly pending replacement once the
  real Shop/Building-Details UI exists -- still unassigned.
* Building capacity/level UI, `xp`/`ProgressionRules`,
  `play_upgrade`'s animation, and other Phase 9 polish -- unassigned,
  carried over from Phase 6.

### Next Action

* Begin Phase 8 (Offline Progression) when explicitly instructed.

---

## Phase 8 — Offline Progression

### Plan (Opus planning pass)

ARCHITECTURE.md Section 12 is fully specified, but CLAUDE.md's Phase 8
list names "Offline reward UI" as in-scope while no Nav/AppShell/modal
component exists yet -- the same kind of UI-less-phase tension Phase 7
navigated for its save engine. A planning pass confirmed the ENGINE-only
scope and surfaced one genuine product question, put to the user via
AskUserQuestion before implementation:

**Resolved decision:** what happens at runtime when a return qualifies
for a reward, given no UI exists. *User selected: "Engine only, no
runtime effect."* Main computes and holds the report
(`pending_offline_report`, logged for dev visibility); offline products
stay on their animals as READY bubbles, collectible through the
existing tap-to-collect seam; `Game.collect_offline_reward()` is fully
built and tested but has no runtime caller yet -- the same precedent as
Phase 7's `SaveService.start_new_farm_after_damage()`.

**Other findings from the planning pass:**
- `EconomyRules.offline_coin_value()`'s signature follows the
  already-built `sell_all_total(bag, catalog, bonus_percent)`
  convention (a plain `product_id -> qty` Dictionary, not an
  `InventoryState`) rather than ARCHITECTURE.md Section 10.4's own
  loosely-sketched `(products, farm, c)` -- recorded as a minor,
  intentional deviation.
- `OfflineReport` lives in its own top-level file
  (`scripts/rules/offline_report.gd`), not nested inside `OfflineRules`
  or `Game` -- GDScript allows one `class_name` per file, same
  precedent as `DecodeResult`/`LoadResult` living apart from
  `SaveCodec`/`SaveService`.
- `on_app_resumed()` is real, in-scope work with no UI dependency (a
  `Main._notification` branch + a `Game` method) -- it does not wait
  for a later phase.
- The SimTick's own 1s gap passing `is_return` conditionally (trigger
  table row 6) is built now: it closes a real race where the OS may
  fire `NOTIFICATION_APPLICATION_RESUMED` and the next SimTick timeout
  in either order after a suspend/resume, and whichever runs first
  would otherwise silently consume the whole offline window with
  `is_return=false`.
- The GDD Section 9 coins-in-the-reward OPEN item is already resolved
  by ARCHITECTURE.md Section 12.3's own "Built default: display only"
  -- `coin_value` is informational only, never credited by
  `collect_offline_reward()`.
- `ProductionRules.pauseWhenReady`'s own OPEN item needs no revisiting
  -- Phase 8 only consumes `advance_animal()` as Phase 4 already built
  it.

**Explicitly out of scope:** `Nav`, `UiScenes`, `AppShell`,
`AudioService`, the Offline Reward modal scene, input blocking, Nav's
toast/banner holding, tutorial resumption, `collect_all`,
`rename_animal`, `set_setting`/`set_tutorial_step`/`skip_tutorial`,
tutorial boost on offline time, the `readyCount`/continuous-production
path.

### Task 1: OfflineParams in the catalog — implemented

* `scripts/definitions/game_catalog.gd`: new `OfflineParams` inner
  class (`cap_hours: float = 8.0`, `reward_modal_min_minutes: float =
  5.0`, plus `cap_ms()`/`reward_modal_min_ms()` millisecond-conversion
  helpers so every caller reads pre-converted values instead of
  repeating the `* 3600000`/`* 60000` math). Parsed from the already-
  on-disk `offline` balance.json group (`capHours`, `rewardModalMinMinutes`
  -- present in both the live file and the test fixture since Phase 2,
  unparsed until now). `validate()` gains two checks: `cap_hours > 0`,
  `reward_modal_min_minutes >= 0`.
* Tests: `tests/unit/test_game_catalog.gd` +4 (fixture values round
  through `cap_ms()`/`reward_modal_min_ms()`; defaults when the group
  is missing; both new validate() failure paths).

**Verification:** 440/440 passing (32 scripts), +4 over Phase 7's
436/436. No regressions.

### Task 2: OfflineRules, OfflineReport, EconomyRules.offline_coin_value — implemented

* `scripts/rules/offline_rules.gd` (NEW): `elapsed_ms(now, last_seen,
  cap_ms)` (0 on a backwards clock, else capped at `cap_ms`),
  `exceeds_modal_threshold(elapsed_ms, catalog)` (strictly greater
  than, per GDD Section 9 rule 4), `should_show_modal(report, catalog)`
  (threshold exceeded AND something was produced).
* `scripts/rules/offline_report.gd` (NEW): `OfflineReport { elapsed_ms,
  capped, ready_animal_ids, products, coin_value }` +
  `static build(completed, state, elapsed_ms, capped, catalog)`, which
  aggregates each READY-transitioned animal's species into a product
  tally and prices the informational `coin_value` through
  `BuildingRules.sell_bonus_percent()`.
* `scripts/rules/economy_rules.gd`: new `offline_coin_value(products,
  catalog, bonus_percent)`, sharing `sell_all_total`'s "round the
  total once, half up" rule.
* Tests: `tests/unit/test_offline_rules.gd` (NEW, 15 tests: elapsed_ms's
  normal/capped/backwards/equal-timestamps cases; the strictly-greater
  modal threshold at/over/under; should_show_modal's three cases;
  `OfflineReport.build`'s aggregation across same-species animals,
  zero-completed exclusion, elapsed/capped passthrough, and the Market-
  bonus-inclusive coin value). `tests/unit/test_economy_rules.gd` +4
  (empty dict, zero-qty exclusion, parity with `sell_all_total` for the
  same quantities, bonus rounding).

**Verification:** 459/459 passing (33 scripts), +19 over Task 1's
440/440. No regressions.

### Task 3+4: Game._advance_to() extension, session/lifecycle entry points — implemented

Combined into one delegation since the signature change and its
callers had to land together.

* `autoload/game.gd`: `_advance_to(now_ms, is_return: bool = false) ->
  OfflineReport` -- extended IN PLACE, never a parallel path. Now uses
  `OfflineRules.elapsed_ms()` (8h cap + backwards-clock handling)
  instead of the Phase 4-7 plain `maxi(0, now_ms - last_seen_ms)`;
  collects each animal's `advance_animal()` return value into a
  `completed: Dictionary`; builds an `OfflineReport` via
  `OfflineReport.build()`; emits the new `offline_progress_applied`
  signal whenever `is_return` is true -- **unconditionally**, matching
  ARCHITECTURE.md Section 12.2's own pseudocode exactly (deciding
  whether to actually SHOW a modal for that report is the caller's job
  via `should_show_modal()`, not `_advance_to()`'s). Every existing
  command keeps calling the untouched `_advance_to(now)` default
  (`is_return = false`), so none of their behavior changed -- confirmed
  by the full regression suite staying green through this change.
  `begin_session()` now calls `_advance_to(now, true)` (a launch is
  always a return). New `on_app_resumed()` (no-op if `state == null`,
  else `_advance_to(now, true)`). The SimTick's lambda callback was
  replaced with a named `_on_sim_tick_timeout()` that computes the gap
  itself and passes `is_return = OfflineRules.exceeds_modal_threshold(...)`
  -- closing the real race from the plan above.
* Tests: `tests/integration/test_offline_progression.gd` (NEW, 9
  tests): the 24h-gap-capped-at-8h case; backwards-clock zero-elapsed +
  rebase; `is_return` false/true signal emission; a hungry animal
  produces nothing; an already-READY animal is not re-counted; a fed
  animal completes and is reported; **split invariance** -- a one-shot
  2h advance matches 7,200 one-second ticks within float epsilon,
  proving the offline and online paths are genuinely the same code;
  `_save_snapshot()` encodes `lastSeen` at the advance time.
  `tests/integration/test_game_session.gd` +8: `begin_session` emits
  the report as a return; `on_app_resumed`'s null-state no-op, its
  qualifying-gap emission, and its no-further-gap non-re-qualifying
  case; the SimTick callback's normal/qualifying/backwards-clock cases.

**Bug caught during test-writing, not production code:** GUT's
`SignalWatcher._add_watched_signal()` silently no-ops on a second
`watch_signals(Game)` call for an object/signal pair already being
watched (a "SHORTCIRCUIT - ignore dupes" check in
`addons/gut/signal_watcher.gd`), so a test that calls `watch_signals`
in `before_each()` and again mid-test (to "reset" before an action
under test) does NOT actually discard earlier emissions -- an
assertion can then pass or fail for the wrong reason (counting
`begin_session()`'s own emission instead of the one the test meant to
trigger). Fixed by calling `clear_signal_watcher()` before the second
`watch_signals()` wherever this pattern was needed. Worth remembering:
re-calling `watch_signals()` on an already-watched object is a no-op in
this GUT version, not a reset.

**Verification:** 475/475 passing (34 scripts), +16 over Task 2's
459/459. No regressions.

### Task 5: Game.collect_offline_reward() — implemented

* `autoload/game.gd`: extracted the per-animal apply-and-emit block
  from `collect()` into a private `_collect_one(animal)` helper
  (`product_collected`, `animal_changed`, `animal_status_changed` only
  on a flag change) -- `collect()`'s own behavior is unchanged, now
  just calling the shared helper. New `collect_offline_reward(report:
  OfflineReport) -> ActionResult`: `_advance_to(now)` first; for each
  id in `report.ready_animal_ids`, skips a missing animal or one whose
  `check_collect()` is not OK (a stale report, or the player already
  collected it by hand) rather than failing the whole batch; no
  debounce; one `state_changed` + synchronous `SaveService.save_now()`
  if anything was actually collected. Coins are never credited (GDD
  Section 9 rule 6) -- `report.coin_value` stays informational only.
  Rule 7 ("if saving the rewards fails, hold them and show the modal
  again on the next launch") needs no extra code: a failed `save_now()`
  leaves the in-memory collection exactly where it is (there is nothing
  to roll back TO, unlike sell's snapshot pattern), `SaveService`'s own
  retry schedule and `save_failed` signal already run, and because the
  reward is defined by which animals are READY, a restart before the
  next successful save simply recomputes and re-reports the same still-
  READY animals. Still returns `OK` even on a save failure, matching
  "play continues" -- `SAVE_FAILED` stays reserved for sell's own
  snapshot/rollback contract, which does not apply here.
* Tests: `tests/integration/test_game_commands_offline.gd` (NEW, 9
  tests): a ready animal is credited to the bag and its progress
  resets; coins are never credited even though `coin_value > 0`; the
  same report collected twice only credits once; a stale/unknown id is
  skipped without failing the batch; a not-actually-ready animal is
  skipped and left unmutated; the save is genuinely on disk when the
  call returns (`load_game()` reads it back); a forced
  `FailingSaveFileIO` failure still returns OK, keeps the collected
  products in memory, and emits `save_failed(false)`; the full signal
  set fires on success; an empty ready list neither saves nor emits
  `state_changed`.

**Verification:** 484/484 passing (35 scripts), +9 over Task 3+4's
475/475. No regressions.

### Task 6: Main wiring (engine only, no UI) — implemented

* `scenes/main/main.gd`: `Game.offline_progress_applied` connected in
  `_ready()` BEFORE `_boot()` calls `begin_session()`, matching
  ARCHITECTURE.md Section 12.4's ordering rule ("before any other
  prompt") even though there is no prompt to order against yet. New
  `pending_offline_report: OfflineReport = null` field and
  `_on_game_offline_progress_applied(report)` handler: holds the
  report only when `OfflineRules.should_show_modal()` is true, with a
  dev-visibility `print()` (product tally, coin value, minutes away) --
  no Nav, no modal, no input blocking. New `_notification` branch for
  `NOTIFICATION_APPLICATION_RESUMED` (mobile only -- there is no
  desktop "un-suspend" counterpart the way `FOCUS_OUT` stands in for
  `PAUSED`) calling `Game.on_app_resumed()`.
* Tests: `tests/integration/test_main_boots.gd` +6: a stale-`lastSeen`
  OK boot holds a pending report naming the right animal; a recent-
  `lastSeen` boot holds none; a NO_SAVE boot holds none; a RESUMED
  notification after a qualifying gap holds a report; a second RESUMED
  with no further gap does not clobber the still-pending report with
  an empty one.

**Verification:** 489/489 passing (35 scripts), +5 over Task 5's
484/484. No regressions.

### Task 7: Real-engine verification — complete

Beyond the GUT suite: wrote a real save file by hand directly to the
actual OS `user://save/farmora_save.json` path (bypassing SaveService
entirely) with `lastSeen` stamped 3 hours in the past and a fully-fed
chicken housed in the coop, matching GDD Section 9's documented save
shape exactly. Launched the real compiled `main.tscn` via `godot
--headless --path . res://scenes/main/main.tscn`:
- Boot correctly loaded the stale save (coins=150, 1 animal), advanced
  production for the real 3-hour gap, and held a `pending_offline_report`
  on `Main` with `products={"egg": 1}`, `coin_value=5`,
  `elapsed_min≈180.1` -- confirmed by direct inspection of
  `Main.pending_offline_report`'s fields, not merely "it didn't crash."
- The chicken's `hunger` correctly dropped to 0 (only ~50 minutes of
  the 3-hour window had feed, per GDD's "no free production") while
  `progress` correctly stayed paused at 1.0, confirming the
  `pauseWhenReady` behavior holds for a genuinely long offline window,
  not just the short windows the GUT suite's FakeClock-driven tests
  exercise.
- Called the real `Game.collect("a1")` command (not a direct state
  mutation) and confirmed it succeeded and credited the bag (`egg` qty
  1 -> the product produced while away is genuinely collectible
  through the same tap-to-collect path a normal in-session product
  uses, exactly as the engine-only scope promised).

### Task 7 (continued): Codex review and fixes — complete

Independent full-phase Codex review (codex-cli 0.158.0, read-only
sandbox, explicitly told not to trust any implementation summary, given
small purpose-built excerpts per Phase 7's own documented lesson about
mega-doc context exhaustion). **Result: 2 findings (1 Medium, 1 Low),
both VALID, both test-coverage gaps rather than production bugs, both
fixed.** Full detail in `docs/CODEX_REVIEW.md`'s "Phase 8 Full-Phase
Review" section:

* **F-01 (Medium, fixed):** the split-invariance test's original 2h
  window let a cow's progress/hunger saturate at the clamped
  READY/zero-hunger endpoint well before the window ended, so a real
  mid-window divergence between the one-shot and ticked paths could
  have passed undetected. Fixed by shrinking the window to 2 minutes
  (strictly under the cow's 6-minute cycle and 100-minute
  hunger-to-zero time) plus two setup-sanity assertions guarding against
  future saturation.
* **F-02 (Low, fixed):** the coin-value test computed its own
  "expected" result by calling the very function under test
  (`EconomyRules.offline_coin_value()`), so it only proved argument
  passthrough, not the arithmetic. Fixed with a hand-computed expected
  value (5 coins) verified against the fixture's real Market-bonus
  table.

**Final verification after both fixes:** headless import clean; full
GUT suite **489/489 passing, 1008/1008 asserts** (35 scripts, +2
asserts over the pre-fix 1006). No regressions. Re-review not required
(CLAUDE.md Section 7/11: both fixes are test-only, narrow, and do not
touch architecture or public behavior).

**Phase 8 completion criteria met:**
```text
Claude Implementation = COMPLETE
Verification           = PASS
Codex Review            = PASS
Unresolved VALID findings = 0
VALID_DEFERRED/OPTIONAL   = none this phase
```

### Next action

Phase 8 (Offline Progression) is COMPLETE. Phase 9 (Polish) is the next
phase per CLAUDE.md's phase order -- not started; awaiting explicit
instruction to begin, matching the standing constraint every prior
phase was given.

---

## Review Status — Phase 8

### Claude Implementation

* Status: **COMPLETE** (all 7 tasks implemented, independently
  verified, Codex review passed with 2 VALID findings fixed; see "Phase
  8 — Offline Progression" above)

### Codex Review

* Status: **PASS**

### Review Findings

* **F-01 (Medium): VALID, fixed** -- the split-invariance test's 2h
  window let both paths saturate before the comparison, masking a
  potential mid-window divergence. Fixed with a non-saturating 2-minute
  window plus setup-sanity assertions.
* **F-02 (Low): VALID, fixed** -- the coin-value test computed its
  expected result via the function under test. Fixed with a
  hand-computed expected value.

### Remaining Work

* The Offline Reward modal UI, Nav/AppShell/the modal component, input
  blocking, Android-back-as-Collect, and `collect_offline_reward()`'s
  real runtime caller -- all explicitly deferred to the UI-shell phase,
  per the user's approved engine-only scope for this phase.
* `on_app_resumed()`'s mobile-only `NOTIFICATION_APPLICATION_RESUMED`
  path has no desktop-testing equivalent the way `FOCUS_OUT` stands in
  for `PAUSED` -- noted, not a gap to close (there genuinely is no
  desktop "un-suspend" notification).
* Every item already carried over from Phases 6/7 (temporary input
  seams, building capacity/level UI, `xp`/`ProgressionRules`, Main
  Menu/Settings UI, the damaged-save menu, "Start new farm"/"Save
  now"/"Try now" UI wiring, `play_upgrade`'s animation) remains
  unassigned.

### Next Action

* Begin Phase 9 (Polish) when explicitly instructed.

---

## Phase 9 — Polish

### Plan (Opus planning pass)

Unlike every prior phase, CLAUDE.md's Phase 9 list ("Animations,
Feedback, Audio, Better transitions, Juice, UI polish, Performance
optimization") cannot be built in full: no UI shell exists yet (no
`Nav`, `AppShell`, screens, overlays), and `AudioService` -- one of only
4 architectural autoloads per ADR-02 -- had never been built. A planning
pass classified each CLAUDE.md item against what actually exists
(farm world + two temporary input seams, nothing else) and surfaced 3
genuine product questions, put to the user via `AskUserQuestion` before
implementation:

1. **Scope: farm-world-scoped Phase 9.** Build everything genuinely
   buildable against existing farm-world code (AudioService wired into
   farm interactions, animal/building animations, floaters, ambient
   life, zoom-clamped indicators, a performance baseline); explicitly
   defer every UI-shell-dependent item (screen transitions, refusal
   toasts, most UI polish) with a written rationale, same pattern as
   Phase 7/8's engine-only scoping. *User selected: "Farm-world-scoped
   Phase 9."*
2. **Audio assets: build the API silent for now.** No sound/music files
   exist in the repo; `AudioService` ships fully functional (gating
   logic, haptics) but every `play()`/`play_music()` call is a safe,
   warn-once no-op until real files land at the documented paths --
   zero code changes needed when they do. *User selected: "Build the
   API silent for now."*
3. **Floater text: text-free.** A collect/feed reward floater shows
   just "+N" plus a product-colored disc, no product name string --
   avoids building `tr()`/`strings.csv` ahead of the UI-shell phase
   that would otherwise own it. *User selected: "Text-free floater for
   now."*

**Classification summary** (full detail in the planning pass, not
reproduced here): Animations/Juice/Feedback were split into a
farm-world-buildable majority (tap/feed/collect/drop-in/upgrade
reactions, ambient idle life) and a UI-shell-blocked remainder (sheet/
modal animations, refusal toasts -- deferred); Audio was buildable as
an engine+wiring task with the assets question resolved above; Better
transitions was entirely blocked (no screens to transition between);
UI polish was mostly blocked, with the zoom-clamped indicator scale and
bubble glow/pop polish buildable now; Performance optimization was
narrowly buildable (a measured baseline, `max_fps`, pool/particle caps)
with real device measurement left to Phase 10.

**Explicitly deferred, not built this phase** (carried forward,
unassigned): the Offline Reward modal, Nav/AppShell/any screen, refusal
feedback for the two temporary input seams (silent, accepted known
gap), the building capacity/level tag and upgrade badge (needs a
screen to open on tap), Main Menu/Settings/damaged-save UI,
`tr()`/`strings.csv`, final fonts/icons, pausing ambient effects while
the world is covered (needs `Nav.world_coverage_changed`), real sound/
music asset files, on-device haptic/performance validation (Phase 10).

### Task 1: Performance baseline + config — implemented

* `project.godot`: added `run/max_fps=60` (ARCHITECTURE.md Section 21,
  previously missing).
* Measured baseline via a throwaway scratch probe: 27 animals (max
  capacity across all 3 housing buildings at level 3) all showing
  PRODUCT bubbles, injected into a real running `main.tscn` via
  `Game.state`/`state_loaded`. Headless (no GPU context, so FPS/frame-
  time numbers are not meaningful cross-platform) counts: **object_count
  ≈ 2369, node_count ≈ 707** at 27 animals + 5 buildings + full UI. No
  scratch files left behind.

### Task 2: AudioService autoload — implemented

* `autoload/audio_service.gd` (NEW): registered after `SaveService` (no
  `class_name`, matching the autoload convention). `SOUND_PATHS`/
  `MUSIC_PATHS` registries covering every DESIGN.md Section 10 event
  (`button_press`, `purchase`, `sell`, `feed`, `collect`, `level_up`,
  `upgrade`, `error`, `product_ready`, `ambience`). `play(id)`/
  `play_music(id)` gated on `Game.state.settings.sound`, a pooled
  `AudioStreamPlayer` (size 4, covers the event table's "up to 3" coin
  clinks), silent/warn-once no-op when no stream file exists yet at the
  resolved path (per the user's approved "build the API silent" answer
  -- no asset files exist, every call is safe and becomes audible the
  moment real files are added, no code change needed). `haptic(kind)`
  (`Haptic.LIGHT/MEDIUM/SUCCESS/ERROR_DOUBLE`) gated on
  `Game.state.settings.vibration`, via `Input.vibrate_handheld()` (a
  real no-op on desktop/editor, so fully testable today even without a
  device). Reads `Game.state.settings` fresh on every call rather than
  caching (no `set_setting()`/settings-changed signal exists yet to
  react to).
* Tests: `tests/unit/test_audio_service.gd` (NEW, 11 tests): sound/
  vibration off correctly block `play()`/`haptic()`; unknown ids are
  safely rejected; null `Game.state` is safe; every DESIGN Section 10
  event has a registered sound id; the sfx pool has the documented
  size; haptics return true (gating logic, not real device buzz) for
  all 4 patterns.

**Verification:** headless import clean (`AudioService` registered as
an autoload); full GUT suite **500/500 passing, 1030/1030 asserts** (36
scripts, +11 tests / +1 script over Phase 8's 489/489). No regressions.

### Task 3+4+5: Zoom-clamped indicators, StatusBubble polish, Floater+pool — implemented

* `scenes/farm/farm_camera.gd`: new `zoom_changed(player_zoom)` signal
  (emitted on `_ready()`, `zoom_about()`, and at both the start/end of
  `reset_zoom()`'s tween); `indicator_scale(player_zoom) -> float`
  (pure static, `clamp(player_zoom, 0.9, 1.2) / player_zoom`, exactly
  per ARCHITECTURE.md Section 10.1); `_player_zoom()` helper
  (`zoom.x / fit_zoom`, divide-by-zero guarded).
* `scenes/farm/world_ui/status_bubble.gd`: `play_pop_in(target_scale)`
  (120ms overshoot pop-in ending at the CURRENT zoom-clamped scale, not
  always 1.0; snaps under `Motion.reduced`), `set_indicator_scale(...)`
  (instant rescale on a live zoom change, interrupting any in-progress
  pop-in so the bubble always reflects current zoom), `despawn()` (120ms
  pop-out then `queue_free()`; marks `_despawning = true` IMMEDIATELY,
  before the animation even starts, so `tap_rect()` returns an empty
  Rect2 and `FarmInput`'s hit-testing excludes it at once, not only
  once the animation finishes); `%Glow` ring (translucent, PRODUCT
  bubbles only). `tap_rect()` now scales with `scale.x` so the tappable
  area stays in sync with the visual.
* `scenes/farm/world_ui/floater.gd`/`.tscn` (NEW): `class_name Floater`.
  Text-free per the approved decision (a product-tinted disc + a plain
  "+N" label, no `tr()`). `show_at(world_pos, product_id, amount)`:
  600ms rise (40 units) + fade, or a 150ms fade-only under
  `Motion.reduced`. `is_idle()` for pool bookkeeping. Never
  `queue_free()`s -- pooled and reused. Exposes no `tap_rect()`/
  `bubble_id`/`animal_id` so `FarmInput`'s duck-typed hit-testing
  naturally skips it.
* `scenes/farm/farm_world.gd`: owns an 8-instance `Floater` pool
  (`_init_floater_pool()`, parented under `world_ui`, survives
  `_rebuild()` -- the world_ui-clearing loop explicitly skips `Floater`
  children); `_spawn_floater()` reuses an idle pooled instance or
  recycles the oldest-used one via move-to-end ordering (never drops a
  request); wired to `Game.product_collected` (a "+amount" floater at
  the collected animal's position). `_refresh_bubble()` now computes
  the current zoom-clamped scale for every spawn/rebind and calls
  `play_pop_in()`/`set_indicator_scale()` accordingly; the product-ready
  chime (`AudioService.play("product_ready")`) is gated by a new pure
  `_should_chime_on_ready(kind, previous_kind, is_new, rebuilding)`
  decision function -- true only for a genuine LIVE transition to
  PRODUCT, false during any `_rebuild()` (boot, `begin_session`,
  `on_app_resumed`), so a full-farm rebuild never fires a chime storm
  for animals that were already READY before the rebuild.
* Tests: `tests/unit/test_farm_camera.gd` +6 (`indicator_scale()` at
  player zoom 0.8/1.0/1.2/1.4; `zoom_about()` emits `zoom_changed`;
  fires once on `_ready()`). `tests/unit/test_farm_world_bubbles.gd`
  +16 (spawned-bubble scale matches current zoom; a live zoom change
  rescales existing bubbles; a freshly spawned bubble picks up the
  CURRENT scale, not the next signal; `tap_rect()` scales with
  `scale.x`; a despawning bubble is immediately excluded from both
  `_find_bubble()` and its own `tap_rect()`; 5 tests on the pure
  `_should_chime_on_ready()` decision function; 5 floater-pool tests
  including oldest-recycling and pool survival across a rebuild).
  `tests/unit/test_floater.gd` (NEW, 6 tests): position/visibility on
  `show_at()`; `is_idle()` during/after animation; reduced-motion
  short-fade-no-rise vs. normal 600ms rise-and-fade (using real
  `await wait_seconds()` timing, not a mocked clock); no `tap_rect()`
  method; no bubble/animal/building id properties.

**Verification:** headless import clean (`Floater` registered as a
global class); full GUT suite **528/528 passing, 1089/1089 asserts**
(37 scripts, +28 tests / +1 script over Task 2's 500/500). No
regressions. Real visual check (throwaway scratch scene, deleted
after): instantiated `farm_world.tscn` directly with injected animals
at 0.8x player zoom -- confirmed bubbles render at `scale =
(1.125, 1.125)` matching `indicator_scale(0.8) = 0.9/0.8` exactly, the
glow ring shows behind the PRODUCT bubble, and a fired floater renders
correctly with no crash.

### Task 6+7+8+9: Animal/building reactions, purchase drop-in, upgrade flourish, ambient life — implemented

**Structural-risk note (read before touching any species `.tscn`):**
`animal_view.tscn`'s root children have a fixed order (`Shadow`,
`Outline`, `Body`, `Cheek`, `Eyes`, `SelectionRing`, `BubbleAnchor`) that
every species scene (`chicken_view.tscn`/`cow_view.tscn`/
`pig_view.tscn`) hardcodes against via `parent="." index="N"`
overrides for its own species-specific parts (Wing/Comb/Beak,
Patch/Horn/Bell, Snout/Ear). Adding ANY new child to the base scene's
root would silently shift every species' indices and misdraw their
parts -- the exact bug Phase 2's own Codex review already caught and
fixed once. This task deliberately added **zero new nodes** to
`animal_view.tscn`'s root; per-species reactions are instead delegated
through overridable GDScript hooks (`_tap_reaction()`/
`_ambient_flourish()`), with each species scene getting only a NEW
`script =` line pointing at a thin `extends AnimalView` subclass
(`chicken_view.gd`/`cow_view.gd`/`pig_view.gd`) -- a script attachment
never touches a `.tscn`'s node tree or `index=` overrides. Verified by
new regression tests asserting every species scene's exact child name
at every existing index (and the base scene's own), re-confirmed
passing after every subsequent edit.

* `scenes/farm/animals/animal_view.gd`: `play_tap()` (delegates to the
  overridable `_tap_reaction()`; base default a generic squash),
  `play_feed()` (squash/bounce + `heart_requested(world_pos)` signal so
  `FarmWorld` -- which owns the pooled `Floater` -- can show a heart
  without `AnimalView` reaching into `world_ui` directly), `play_collect()`
  (a small pop; the reward floater and collect sound/haptic are already
  owned by `FarmWorld._on_product_collected()` from Task 5, not
  duplicated here), `play_drop_in(from_pos)` (purchase-only entrance
  animation). Shared `_squash_bounce()`/`_hop()`/`_tilt()` tween helpers
  (each kills any in-flight reaction tween first). Blink loop (every
  4-6s, exempt from the ambient budget -- a status cue, not a
  discretionary flourish) and a selection-ring pulse while selected
  (also exempt -- tied to a deliberate player action). Species idle
  flourish loop gated by an injected `AmbientBudget` (at most 2 animals
  farm-wide mid-flourish at once, per the planning pass's approved
  interpretation of DESIGN.md Section 9's "at most 2 ambient animations
  at once" -- wandering/blink/the product bubble's bob are exempt,
  only the OPTIONAL peck/wiggle/swish-style flourishes are capped), with
  `compute_flourish_interval_multiplier(low_happiness)` (pure,
  testable) slowing the interval 2.5x at low happiness.
  `_exit_tree()` releases a held budget slot if the view is freed
  mid-flourish (`FarmWorld._rebuild()` uses `free()`, not `queue_free()`
  -- without this the slot would leak permanently on every rebuild).
  Every animation path checks `Motion.reduced` and is non-mutating
  (never touches `Game.state`).
* `scenes/farm/animals/chicken_view.gd`/`cow_view.gd`/`pig_view.gd`
  (NEW, thin subclasses, script-only, no `.tscn` node changes): chicken
  squashes 90%->110%->100% over 160ms; pig hops 8 units over 300ms; cow
  tilts 8 degrees over 400ms (an approximated head-tilt via whole-body
  rotation -- there is no separate head node to animate).
* `scenes/farm/ambient_budget.gd` (NEW): `AmbientBudget`, `MAX_SLOTS =
  2`, `request_slot() -> bool`/`release_slot() -> void`. One shared
  instance owned by `FarmWorld`, injected into every spawned
  `AnimalView`.
* `scenes/farm/buildings/building_view.gd`: `play_upgrade(level)` --
  squash (overshoot) + a `sparkle_requested` signal (FarmWorld spawns a
  runtime-only `CPUParticles2D`, capped at 12) + three staggered
  `AudioService.play("upgrade")` beats across the ~1.2s animation (DESIGN
  Section 10: "Three hammer taps") + one medium haptic. Per-level art
  swap is an explicit no-op (`BuildingView` is still a placeholder tint
  block with no L2/L3 art). No `.tscn` changes needed -- `BuildingView`
  has no inherited-scene-with-indices pattern, confirmed before adding
  anything.
* `scenes/farm/farm_world.gd`: `select_animal()` now also calls
  `view.play_tap()`. `_on_animal_added()` plays drop-in + confetti
  (`CPUParticles2D`, capped at 20, DESIGN's own number) + the purchase
  sound/haptic, gated by a new pure `_should_play_drop_in(rebuilding)`
  decision function (same established pattern as
  `_should_chime_on_ready` -- true only outside `_rebuild()`, so a
  boot/offline-return never replays a "just bought" flourish for a
  pre-existing animal). Drop-in's "door" point is the housing
  building's own position (no authored door marker exists). New
  `_on_building_upgraded()` routes `Game.building_upgraded` to the
  matching `BuildingView.play_upgrade()`. New `_spawn_confetti()`/
  `_spawn_sparkle()` runtime-only particle helpers, both skipped
  entirely (not just shortened) under `Motion.reduced`. New
  `_on_heart_requested()` reuses the pooled `Floater` for the feed
  heart indicator.
* `scenes/farm/farm_world.tscn`: added a new `Ambient` Node2D under the
  existing `Backdrop` node (two drifting cloud `Polygon2D`s at ~8 dp/s,
  two swaying grass-tuft `Polygon2D`s) -- confirmed `farm_world.tscn`
  is the one authored instance (never itself inherited elsewhere), so
  this carries none of `AnimalView`'s structural risk. Driven by a new
  `scenes/farm/ambient_backdrop.gd` (`AmbientBackdrop`), gated on
  `Motion.reduced`.
* Tests: `tests/unit/test_animal_view.gd` (large addition): the species
  child-order regression tests described above; `play_tap`/`play_feed`/
  `play_collect` non-mutation, retrigger-kills-previous-tween, and
  `Motion.reduced` behavior; per-species subclass type checks;
  `AmbientBudget` cap/release tests; the low-happiness interval
  multiplier test. `tests/unit/test_building_view.gd` (NEW): `play_upgrade()`
  tests. `tests/unit/test_farm_world_animals.gd` additions:
  `_should_play_drop_in` pure-function tests, a live-purchase
  end-to-end smoke test (confetti appears, no crash), a
  rebuild-spawn-has-no-confetti test, ambient-budget-sharing test,
  `heart_requested` wiring test, `building_upgraded` routing test.
  `tests/unit/test_farm_world.gd`: one pre-existing test
  (`test_backdrop_extends_past_the_world_rect`) adjusted to skip the
  new non-`Polygon2D` `Ambient` sibling while still enforcing its
  original intent on the real background polygon layers.

**Verification:** headless import clean; full GUT suite **559/559
passing, 1172/1172 asserts** (38 scripts, +31 tests / +1 script over
Task 3-5's 528/528). No regressions. Species child-order regression
tests confirmed passing (zero structural risk introduced -- verified
independently by the orchestrator, not just the implementing agent's
own report). Real visual check (throwaway scratch scene, deleted
after): drove `select_animal()`, `Game.feed_animal()`, `Game.collect()`,
`Game.buy_animal()`, `Game.upgrade_building()` as REAL commands through
the real farm world (not direct state mutation) -- all real signals
fired correctly (confirmed via the expected `AudioService` silent-no-op
warnings appearing at exactly the right call sites), no crashes, farm
rendered correctly with no misdrawn/reordered polygons.

### Task 10: Re-measure, final verification — complete (pre-Codex)

* Re-ran Task 1's 27-animal performance probe after Tasks 3-9 landed:
  `object_count` 2369 -> 2469, `node_count` 707 -> 763 (the permanent
  8-floater pool, the ambient backdrop's cloud/grass nodes, and the
  per-view `AmbientBudget` reference account for the modest increase).
  No regression of concern -- these are small, fixed-size additions,
  not a per-animal or per-frame growth. Real device/FPS measurement
  remains Phase 10 scope (headless frame-time numbers are not
  meaningful without a real GPU context).
* Final headless import: clean, zero errors/warnings.
* Final full GUT suite: **559/559 passing, 1172/1172 asserts** (38
  scripts) -- unchanged from Task 9, confirming no further code changes
  before review.

### Task 10 (continued): Codex review and fix — complete

Independent full-phase Codex review (codex-cli 0.158.0, read-only
sandbox, explicitly told not to trust any implementation summary, given
a small purpose-built excerpt per the now-twice-reconfirmed Phase 7/8
lesson about mega-doc context exhaustion). Specifically tasked with
independently verifying the species-scene structural-risk claim (zero
new nodes added to `animal_view.tscn`'s root) by reading the raw
`.tscn` files directly, not trusting any description of them. **Result:
1 finding (Low), VALID, a test-coverage gap rather than a production
bug, fixed.** Full detail in `docs/CODEX_REVIEW.md`'s "Phase 9
Full-Phase Review" section:

* **F-01 (Low, fixed):** `test_building_view.gd`'s upgrade-sound test
  asserted only `assert_true(true)` -- it would have passed even if
  `play_upgrade()` stopped calling `AudioService` entirely. Fixed by
  asserting `AudioService`'s own gating logic instead (sound/vibration
  explicitly disabled -> `play()`/`haptic()` return `false`), confirming
  `play_upgrade()`'s calls genuinely reach the real, correctly-gated
  API. The natural first fix attempt (assert `true` returns with
  settings enabled) itself failed and revealed a useful reminder: with
  no audio asset files yet (this phase's own "ship silent" scope),
  `AudioService.play()` correctly returns `false` even with sound
  enabled, since no file exists at the resolved path.
* The structural-risk claim was independently confirmed TWICE: once by
  the orchestrator reading `animal_view.tscn`/`chicken_view.tscn`'s raw
  contents directly before accepting the implementing agent's report,
  and again by Codex doing the same independently during review. Both
  confirm: 7 fixed root children in the base scene, every species
  scene's `index=` overrides untouched, only a `script =` line added
  per species scene.

**Final verification after the fix:** headless import clean; full GUT
suite **559/559 passing, 1173/1173 asserts** (38 scripts, +1 assert
over the pre-fix 1172). No regressions. Re-review not required
(CLAUDE.md Section 7/11: the fix is test-only, narrow, and does not
touch architecture or public behavior).

**Phase 9 completion criteria met:**
```text
Claude Implementation = COMPLETE
Verification           = PASS
Codex Review            = PASS
Unresolved VALID findings = 0
VALID_DEFERRED/OPTIONAL   = none this phase
```

### Next action

Phase 9 (Polish) is COMPLETE. Phase 10 (Mobile Validation) is the next
phase per CLAUDE.md's phase order -- not started; awaiting explicit
instruction to begin, matching the standing constraint every prior
phase was given.

---

## Review Status — Phase 9

### Claude Implementation

* Status: **COMPLETE** (all 10 tasks implemented, independently
  verified, Codex review passed with 1 VALID finding fixed; see "Phase
  9 — Polish" above)

### Codex Review

* Status: **PASS**

### Review Findings

* **F-01 (Low): VALID, fixed** -- a `BuildingView.play_upgrade()` test
  asserted only `true`, proving nothing. Fixed by asserting
  `AudioService`'s own gating logic instead.

### Remaining Work

* Every item this phase explicitly deferred (farm-world-scoped Phase 9
  was the user's own approved scope, not a gap discovered after the
  fact): the Offline Reward modal, Nav/AppShell/any screen, refusal
  feedback for the two temporary input seams, the building capacity/
  level tag and upgrade badge, Main Menu/Settings/damaged-save UI,
  `tr()`/`strings.csv`, final fonts/icons, pausing ambient effects
  while the world is covered (needs `Nav.world_coverage_changed`), real
  sound/music asset files, on-device haptic/performance validation.
* Every item already carried over from Phases 6/7/8 (temporary input
  seams needing the real Shop UI, `xp`/`ProgressionRules`, Main Menu/
  Settings UI, the damaged-save menu, "Start new farm"/"Save now"/"Try
  now" UI wiring) remains unassigned.

### Next Action

* Begin Phase 10 (Mobile Validation) when explicitly instructed.

---

## Phase 10 — Mobile Validation

### Scope note (read before anything else in this section)

CLAUDE.md's Phase 10 list ("Android build, iOS compatibility, Portrait
layout, Touch interactions, Different screen sizes, Performance, Memory
usage, Save/load reliability") is a **validation** phase, not an
**implementation** phase — every prior phase (0-9) wrote new code; this
one checks what already exists against real devices and real builds.
That distinction matters because this session's environment has real,
hard limits that make part of this phase genuinely impossible to do
here:

* **No Android SDK, no `adb`, no Gradle** are installed in this
  environment (`which adb`/`which gradle` both report nothing, no
  `ANDROID_HOME`/`ANDROID_SDK_ROOT` is set).
* **No Godot export templates** are installed (`godot --export-list`
  with no preset fails immediately; templates are a separate ~1GB+
  download this environment does not have).
* **No physical or emulated device** of any kind is available.
* `docs/ARCHITECTURE.md` Section 19 itself already scopes "layout,
  animation and touch feel" as **not automatable** in the MVP — "These
  are checked by running the game ... and in Phase 10 on devices,"
  i.e. the architecture's own authors already anticipated this phase
  needs a human with a device, not more code.

Put to the user via `AskUserQuestion` before doing anything: do what's
genuinely achievable from this desktop/headless environment, and
clearly document the rest as blocked pending the user's own
hardware/SDKs, rather than silently skipping it or fabricating results.
*User selected: "Do what's achievable here, document the rest as
blocked."*

### What was done (achievable from this environment)

1. **`export_presets.cfg` created** (did not exist before this phase).
   Android and iOS presets with real, valid Godot 4.7 preset syntax --
   confirmed the project still imports cleanly with this file present.
   Package name/bundle id (`com.farmora.placeholder`) and version
   (`0.1.0`) are explicit PLACEHOLDERS, called out in the file's own
   header comment -- these are product/publishing decisions (the real
   app id, signing identity, Apple team id, etc.) that belong to the
   project owner, not something to invent. VIBRATE permission is
   enabled on Android (the one real permission this project's
   `AudioService.haptic()` genuinely needs). This file itself cannot be
   used to actually EXPORT anything in this environment (no templates
   installed -- see above), but it is a real, correct artifact ready
   for the owner's own machine once they have the Android SDK/Xcode
   and export templates installed.
2. **Portrait layout at all 4 DESIGN.md Section 12 reference dp
   sizes**, verified with real screenshots (not assumed): 360x640
   (Small Android), 390x844 (the project's own base/iPhone 15
   reference, already exercised throughout every prior phase), 412x915
   (Modern Android), 430x932 (iPhone Pro Max). A representative farm
   (3 animals in different states across all 3 housing buildings) was
   seeded via a throwaway scratch scene and screenshotted at each size.
   Confirmed at every size: buildings and animals are never cropped
   (DESIGN Section 12 rule 2); taller/narrower aspect ratios correctly
   add ground at the bottom rather than cropping sky or world content;
   no layout breakage. **What this does NOT verify:** the actual
   per-platform DPI/density-detection code paths in
   `ScreenFit._compute_mobile_dp_size()` (the `OS.get_name() == "iOS"`
   branch calling `DisplayServer.screen_get_scale()`, and the Android
   branch calling `DisplayServer.screen_get_dpi()`) never run on this
   desktop environment -- `ScreenFit.apply()` takes the `OS.has_feature
   ("pc")` early-return branch unconditionally here, so only the
   ALREADY-unit-tested pure math (`compute_fit_size`/
   `compute_fit_size_from_scale` in `test_screen_fit.gd`) is exercised,
   never the real `DisplayServer` calls against real device hardware.
   This is exactly the gap ARCHITECTURE.md Section 2 itself flags:
   "Verify it on real devices in Phase 10."
3. **Full GUT suite re-run clean**: **559/559 passing, 1173/1173
   asserts** (38 scripts) -- the same suite that exercises every
   production/economy/save/offline-progression rule the game has,
   confirming nothing regressed going into this phase.
4. **A real save/load reliability round trip**, repeated once more
   specifically for this phase's own "Save/load reliability" item (on
   top of the equivalent checks already done in Phases 7/8): launched
   the real compiled game, bought a chicken and a feed pack through
   real `Game` commands, waited out the real 2s autosave debounce,
   killed the process, and relaunched -- confirmed `coins`, `animals`,
   and `feed` all round-tripped exactly through a genuine process
   restart, matching the same pattern used to validate Phase 7/8.
5. **A performance/object-count baseline carried over from Phase 9's
   own 27-animal probe** (object_count ~2469, node_count ~763 at
   maximum building capacity) -- no further headless performance work
   is meaningful beyond what Phase 9 already measured, since frame-time
   numbers without a real GPU context (headless) or a real device don't
   reflect actual mobile performance.

### What remains genuinely blocked (needs the user's own hardware/SDKs)

* **An actual Android `.apk`/iOS `.ipa` build.** `export_presets.cfg`
  now exists and is ready, but exporting requires Godot's export
  templates (a separate download) plus, for Android, a configured
  Android SDK/NDK/Gradle, and for iOS, a Mac with Xcode and a real
  Apple developer identity. None of this is available in this session's
  environment.
* **Real device touch interaction feel.** Tap-target accuracy, the
  300ms debounce lock's real-world feel, pinch-to-zoom gesture
  recognition, and the long-press-to-upgrade seam's timing all need a
  finger on real glass -- the desktop mouse-based testing used
  throughout Phases 0-9 cannot substitute for this.
* **Real device performance/memory/battery/thermal behavior.** GDD/
  DESIGN's own target ("60 fps on a three-year-old phone") can only be
  measured on that phone. Headless object/node counts are a proxy, not
  a measurement.
* **Real per-platform `ScreenFit` density detection**, per item 2
  above -- the `DisplayServer.screen_get_dpi()`/`screen_get_scale()`
  code paths have genuinely never executed against real hardware.
  ARCHITECTURE.md Section 2 already names the fallback plan if density
  detection proves unreliable on some device family ("the fallback is
  the 390-wide base... record that in docs/PROGRESS.md as a known
  issue") -- that determination itself requires a real device to make.
* **Accessibility gaps** ARCHITECTURE.md Section 23 item 13 already
  flags as needing Phase 0/10 verification (reading the OS reduced-
  motion setting and OS font scale, screen-reader labels/announcements)
  -- these may need engine-version-dependent accessibility support or a
  platform plugin neither of which can be evaluated without a device.

### Next action

Phase 10's environment-achievable work is complete. The remaining items
above are not implementation tasks for a future coding session -- they
are the project owner's own device/SDK-dependent validation to run on
their own machine, using the now-real `export_presets.cfg` as the
starting point. No further phase is defined past Phase 10 in CLAUDE.md;
this is the end of the originally-scoped phase list.

---

## Review Status — Phase 10

### Claude Implementation

* Status: **COMPLETE for the environment-achievable scope** (see "Phase
  10 — Mobile Validation" above). The remainder of this phase is
  explicitly out of reach of this session's environment (no Android
  SDK/export templates/device) and is documented as such, not silently
  skipped or faked.

### Codex Review

* Status: **NOT_APPLICABLE** -- this phase produced one new
  configuration file (`export_presets.cfg`) and no new game logic/
  tests; a code review adds no value here. (No gameplay code was
  written, so there is nothing for an independent code reviewer to
  check beyond what Phases 0-9's own reviews already covered.)

### Review Findings

* None.

### Remaining Work

* Everything listed under "What remains genuinely blocked" above --
  all of it requires hardware/SDKs this environment does not have, not
  further coding work.

### Next Action

* The project owner runs the remaining Phase 10 validation on their own
  Android/iOS devices, using `export_presets.cfg` (now a real, ready
  artifact) as the starting point, and updates this file with the
  results.

---

### Claude Implementation

* Status: **COMPLETE** (all 6 tasks implemented, independently verified,
  Codex review passed with the VALID finding fixed; see "Phase 2 —
  Animals" above)

### Codex Review

* Status: **PASS**

### Review Findings

Independent full-phase Codex review (codex-cli 0.158.0, read-only
sandbox, explicitly told not to trust this progress report). Full
detail in `docs/CODEX_REVIEW.md`.

* **1 VALID, fixed**: the animal placeholder scenes omitted DESIGN.md
  Section 7's shared family features (3-unit outline, 6-unit eyes with
  a 2-unit highlight, blush cheek) — re-verified directly against the
  design doc and the actual `.tscn` files before accepting. Fixed in
  `animal_view.tscn`, which surfaced a second, self-discovered bug: the
  new nodes shifted sibling indices in the three per-species inherited
  scenes, causing species-specific parts (wing, comb, snout, etc.) to
  draw in the wrong order. Verified the fix by instantiating
  `chicken_view.tscn` and checking the actual resulting child order,
  not by assumption.
* **1 OPTIONAL, fixed anyway** (cheap enough not to defer): added direct
  regression tests for the `Game.state == null` guard and the `free()`
  vs `queue_free()` lifecycle fix, both previously only indirectly
  exercised.
* **0 INVALID, 0 ALREADY_HANDLED.** All 20 other review categories: no
  issues found (API correctness, scene syntax, catalog/balance values
  against GDD, state round-trip, `Game`'s thin-slice claim, `StatusRules`
  threshold logic, `AnimalView` correctness, `FarmWorld` spawning/
  selection, `FarmInput` wiring, dependency direction, the time-based-
  systems rule, test quality, lifecycle, naming, complexity, phase
  scope).

**Re-verification after both fixes** (run independently): headless
import zero errors/warnings; GUT suite **113/113 tests, 261/261
asserts** (up from 111/111, 259/259). Fresh screenshot confirms the
visual fix.

### Remaining Work

* None blocking. Phase 2 is complete.

### Next Action

* Begin Phase 3 (Feeding) per CLAUDE.md's phase breakdown, when ready.
