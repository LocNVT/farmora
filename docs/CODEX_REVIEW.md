# Farmora — Codex Review Log

## Phase 2 Full-Phase Review (Tasks 1-6) — [session date per environment: 2026-10-02]

**Reviewer:** Codex CLI (codex-cli 0.158.0), independent pass, read-only
sandbox, no implementation access, explicitly instructed not to trust
the implementing agent's progress summary.

**Scope reviewed:** `data/balance.json`, `tests/fixtures/balance_fixture.json`,
`scripts/definitions/{product_definition,animal_definition,game_catalog}.gd`,
`scripts/state/{animal_instance,farm_state,game_state}.gd`,
`scripts/rules/status_rules.gd`, `tests/helpers/state_factory.gd`,
`autoload/game.gd`, `project.godot` ([autoload] section),
`scenes/main/main.gd` (Phase 2 boot seam), `scenes/farm/animals/*`,
the Phase 2 additions to `scenes/farm/farm_world.gd`,
`scenes/farm/farm_input.gd`, `scenes/farm/buildings/building_view.gd`,
and all Phase 2 test files.

**Source of truth given to Codex:** `CLAUDE.md`, `docs/GDD.md`,
`docs/DESIGN.md`, `docs/ARCHITECTURE.md`, `docs/PROGRESS.md`,
`docs/CODEX_REVIEW.md` (for prior-phase context).

### Findings and classification

Codex reported 2 findings.

**F1 (Codex: Medium, VALID) — Animal placeholder scenes omit DESIGN.md
Section 7's shared family features: the 3-unit warm-brown outline, the
6-unit eyes with a 2-unit highlight, and the blush cheek.**

Independently re-verified before accepting: re-read DESIGN.md Section 7
directly and confirmed it explicitly specifies these three features as
shared across all three animals "so any new animal drops in" — then
inspected the actual `animal_view.tscn` and found no outline node, 3×3
unit eyes (not 6-unit with a highlight), and no cheek element. A real,
accurate gap — the placeholder captured correct body colors, sizes, and
tap zones, but missed the shared visual-family details.

**Classification: VALID. Fixed.** Added an `Outline` polygon (behind
the body, in the DESIGN.md `#3B2A1A` ink color), resized eyes to 6
units with a 2-unit white highlight dot each, and added a `Cheek`
polygon, all in the base `animal_view.tscn`. Fixing this surfaced a
second, self-discovered issue: inserting new nodes into the base scene
shifted the sibling `index` every per-species inherited scene
(`chicken_view.tscn`/`pig_view.tscn`/`cow_view.tscn`) used to override
`Body` and insert species-specific parts — the stale indices caused
species parts to draw in the wrong order (verified directly by
instantiating `chicken_view.tscn` and printing the actual child order,
not assumed: `Wing`/`Comb`/`Beak` were drawing *before* `Body`,
underneath the body fill). Fixed by recomputing every affected `index`
value and re-verifying the resulting draw order is correct in all three
species scenes.

**F2 (Codex: Low, OPTIONAL) — the rebuild test doesn't directly verify
the claimed `free()` lifecycle fix or the `Game.state == null` guard
fix, despite both being described as real-crash fixes.**

**Classification: OPTIONAL**, matching Codex's own classification — but
cheap enough to add immediately rather than defer. Added
`test_rebuild_tolerates_null_game_state` (instantiates `farm_world.tscn`
with `Game.state = null`, confirms no crash and an empty Animals
container) and `test_rebuild_frees_the_old_view_not_just_detaches_it`
(captures the old view reference before a rebuild, asserts
`is_instance_valid()` is false afterward — directly exercising the
`free()` vs `queue_free()` distinction, not just the replacement
behavior the existing test already covered).

### Codex Review Result (full phase, Tasks 1-6)

* Findings count: 2
* Valid findings: 1 (F1 — **fixed and independently re-verified**,
  including a second self-discovered node-ordering bug the fix itself
  introduced)
* Invalid findings: 0
* Already handled: 0
* Optional: 1 (F2 — **also fixed**, not deferred, since it was cheap)
* **Overall result: PASS.** All 20 other review categories (Godot API
  correctness, `.tscn`/inherited-scene syntax, catalog parsing and
  balance values against GDD, runtime state round-trip and unknown-key
  preservation, the `Game` autoload's thin-slice claim, `StatusRules`
  threshold logic, `AnimalView`'s state/tap-rect/wander correctness,
  `FarmWorld` spawning/fallback/selection logic, `FarmInput`'s animal
  tier wiring, dependency direction, the time-based-systems rule,
  test quality, null-reference risks beyond the already-fixed case,
  resource lifecycle beyond the already-fixed case, naming, complexity,
  phase scope, and the `--script`-doesn't-initialize-autoloads claim):
  **no issues found**, independently spot-checked above wherever a
  concrete claim was made.

**Re-verification after both fixes** (run independently): headless
import — zero errors, zero warnings. GUT suite — 113/113 tests passing,
261/261 asserts (up from 111/111, 259/259 before the two new regression
tests). A fresh screenshot confirms the visual fix: chicken and pig
placeholders now show a visible outline, correctly sized eyes with
highlights, and a blush cheek, reading as a cohesive visual family per
DESIGN.md's intent.

---

## Phase 1 Full-Phase Review (Tasks 1-5) — [session date per environment: 2026-10-02]

**Reviewer:** Codex CLI (codex-cli 0.158.0), independent pass, read-only
sandbox, no implementation access, explicitly instructed not to trust
the implementing agent's progress summary. This is the normal
CLAUDE.md Section 13 per-phase review, run after all 5 Phase 1 tasks
were implemented (Tasks 1-2 had already received an earlier interim
review at the user's explicit request — see "Phase 1 Tasks 1-2 Review"
below — but were re-reviewed here as part of the full phase too).

**Scope reviewed:** `scenes/farm/farm_world.gd`, `scenes/farm/farm_world.tscn`,
`scenes/farm/farm_camera.gd`, `scenes/farm/farm_input.gd`,
`scenes/farm/buildings/building_view.gd`,
`scenes/farm/buildings/building_view.tscn`, `scenes/main/main.gd`,
`scenes/main/main.tscn`, `tests/unit/test_farm_world.gd`,
`tests/unit/test_farm_camera.gd`, `tests/unit/test_farm_input.gd`,
`tests/integration/test_main_boots.gd`.

**Source of truth given to Codex:** `CLAUDE.md`, `docs/GDD.md`,
`docs/DESIGN.md`, `docs/UI_SPEC.md`, `docs/ARCHITECTURE.md`,
`docs/PROGRESS.md`, `docs/CODEX_REVIEW.md` (for the prior interim
review's context).

### Findings and classification

Codex reported 2 findings.

**F1 (Codex: Medium, VALID) — `FarmCamera.end_drag()` is called from
`FarmInput` with no release-velocity argument, so it always defaults to
`Vector2.ZERO` and the 400 ms pan inertia spec (ARCHITECTURE.md Section
10.1) never actually activates from a real touch gesture.**

Independently re-verified before accepting: confirmed directly in
`farm_input.gd` that `camera.end_drag()` was called with zero
arguments, and in `farm_camera.gd` that `end_drag(release_velocity:
Vector2 = Vector2.ZERO)`'s default parameter exactly matches the bug
description. This is a real gap — inertia was implemented and unit
tested in isolation (calling `end_drag()` directly with a manual
velocity argument), but the one piece of code that was supposed to
supply a real velocity from an actual gesture never did so.

**Classification: VALID. Fixed.** `FarmInput._TouchState` now tracks a
`last_drag_velocity`, computed from each drag sample's relative motion
over the elapsed time since the previous sample, and `_on_touch_ended`
passes it to `camera.end_drag(state.last_drag_velocity)`. A new
regression test (`test_releasing_a_fast_drag_gives_the_camera_a_nonzero_inertia_velocity`)
sends a realistic two-sample drag stream (a single drag event has no
prior timestamp to measure a delta against, matching how real touch
input actually arrives) and asserts `FarmCamera._inertia_velocity` is
nonzero after release.

**F2 (Codex: Low, OPTIONAL) — the pinch-then-release test only covers
one finger-lift ordering (second finger first); the alternate ordering
(first finger first) and additional-finger transitions aren't
separately tested.**

**Classification: OPTIONAL**, matching Codex's own classification.
Reasonable test-depth suggestion; the underlying `_gesture_was_multitouch`
flag's logic was read directly and does not special-case lift order (it
persists until `_touches` is empty regardless of which index lifts
first), so the risk this finding flags is low. Deferred as a future
test-coverage task, not required to close out Phase 1.

### Codex Review Result (full phase, Tasks 1-5)

* Findings count: 2
* Valid findings: 1 (F1 — **fixed and independently re-verified**)
* Invalid findings: 0
* Already handled: 0
* Optional: 1 (F2 — deferred)
* **Overall result: PASS.** All 16 other review categories (Godot API
  correctness, scene/resource syntax, ownership and dependency
  direction, FarmWorld hierarchy, BuildingView correctness and color
  values, FarmCamera's fit-zoom/clamp/inversion math and reduced-motion
  handling, FarmInput's gesture discrimination and hit-testing, the
  touch-vs-mouse-event handling claim, test quality, null-reference
  safety, tween/timer lifecycle, naming, complexity, design/architecture
  compliance, phase scope, and Phase 2 compatibility): **no issues
  found**, independently spot-checked above wherever a concrete claim
  was made (the fit-zoom/inversion math, the touch-only event handling,
  and the GDScript lambda-capture-by-value claim were each verified
  directly, not taken on trust).

**Re-verification after the F1 fix** (run independently, not taken from
a self-report): headless import — zero errors, zero warnings. GUT
suite — 53/53 tests passing, 139/139 asserts (up from 52/52, 138/138
before the fix — one new regression test added, all pre-existing tests
still green).

---

## Phase 1 Tasks 1-2 Review — [session date per environment: 2026-10-02]

**Reviewer:** Codex CLI (codex-cli 0.158.0), independent pass, read-only
sandbox, no implementation access, explicitly instructed not to trust
the implementing agent's progress summary.

**Scope reviewed:** `scenes/farm/farm_world.gd`, `scenes/farm/farm_world.tscn`,
`scenes/main/main.gd`, `scenes/main/main.tscn`,
`tests/unit/test_farm_world.gd`, `tests/integration/test_main_boots.gd`.
Explicitly out of scope: anything belonging to Tasks 3-6 (FarmCamera
behavior, FarmInput, building spawning) or already reviewed in the
Phase 0 pass.

**Source of truth given to Codex:** `CLAUDE.md`, `docs/GDD.md`,
`docs/DESIGN.md`, `docs/UI_SPEC.md`, `docs/ARCHITECTURE.md`,
`docs/PROGRESS.md`.

### Findings and classification

Codex reported 2 findings. Both independently re-verified against the
actual code and the governing docs (not taken on Codex's word, and not
dismissed without checking either).

**F1 (Codex: Medium, VALID) — Backdrop polygon width (`farm_world.tscn`
lines 16/20/24) is a fixed 1200 units, which does not guarantee meadow
coverage to a tablet's physical screen edges (DESIGN.md Section 12 rule
4).**

Re-verified by calculation: at every phone reference device in
DESIGN.md's own table (360x640 through 430x932), the visible world
width at the camera's maximum zoom-out (0.8x fit_zoom) is a constant
487.5 world units — comfortably inside the 1200-unit backdrop on every
phone size. The only real gap is the tablet case, and there Codex is
factually correct that a fixed-width polygon cannot guarantee coverage
for an arbitrarily wide physical screen.

However: DESIGN.md Section 12 rule 4's tablet centering and
ARCHITECTURE.md itself (Section 2: "On tablets, `AppShell` centres a
game column..."; Section 3: `app_shell.tscn/.gd` owns "layer layout,
safe areas, **tablet column**") both assign tablet-column handling to
`AppShell`, which does not exist yet and is explicitly a later-phase
component. There is no way to "properly" fix tablet backdrop coverage
within Tasks 1-2 without either building `AppShell` early (out of
scope) or adding speculative tablet-viewport-tracking logic ahead of
the phase that is designed to own it.

**Classification: VALID finding, but premature for this phase.**
Recorded as a known future task (tracked below), not a blocking defect
in Tasks 1-2. Revisit when `AppShell` is built.

**F2 (Codex: Low, OPTIONAL) — `test_backdrop_extends_past_the_world_rect`
only checks horizontal coverage against the narrow 390-unit `world_rect()`,
not against the 0.8x-zoom or tablet-scale viewport the test's own
comment references.**

Re-verified directly: confirmed accurate. The test's comment (lines
54-57) describes the 0.8x zoom-out/tablet concern, but the assertion
only checks against `world_rect()`, which the current backdrop
trivially satisfies regardless of whether real tablet coverage holds.

**Classification: OPTIONAL**, as Codex itself classified — a reasonable
test-depth improvement, not required to close out Tasks 1-2, and
naturally resolved together with F1 whenever that's picked up.

### Codex Review Result (Tasks 1-2)

* Findings count: 2
* Valid findings: 1 (F1 — deferred, see below)
* Invalid findings: 0
* Already handled: 0
* Optional: 1 (F2)
* **Overall result: PASS for Tasks 1-2 as currently scoped.** F1 is a
  real, correctly-identified future requirement, not a defect
  introduced by Tasks 1-2 — it cannot be correctly resolved before
  `AppShell` exists, and Codex's own review found no gap affecting any
  currently-supported phone reference size. Logged as a tracked future
  task rather than a blocking finding; see `docs/PROGRESS.md`.

All 17 other review categories (Godot API correctness, scene/ownership
boundaries, FarmWorld hierarchy, BuildingSlots, y-sorting, input
propagation, camera/input placeholders, test quality elsewhere, null
references, lifecycle, maintainability, complexity, design/architecture
compliance, phase scope, and risk to upcoming Tasks 3-5): **no issues
found**, per Codex's own checklist, each independently spot-checked
above where a concrete claim was made.

---

## Phase 0 Review — [session date per environment: 2026-10-02]

**Reviewer:** Codex CLI (codex-cli 0.158.0), independent pass, read-only
sandbox, no implementation access.

**Scope reviewed:** `project.godot`, `scenes/main/`, `ui/theme/`,
`ui/components/`, `tests/`, `.gutconfig.json`, `assets/fonts/README.md`,
`icon.svg`, `docs/PROGRESS.md` (as a claims document).

**Source of truth given to Codex:** `CLAUDE.md`, `docs/GDD.md`,
`docs/DESIGN.md`, `docs/UI_SPEC.md`, `docs/ARCHITECTURE.md`.

Codex was explicitly instructed not to assume the implementation was
correct, not to propose fixes (findings only), and to be skeptical of
`docs/PROGRESS.md`'s self-reported bug fixes rather than trust them.

---

### Findings and classification

Each finding is reproduced from Codex's report, then classified
(VALID / INVALID / ALREADY_HANDLED / NOT_APPLICABLE / OPTIONAL) against
direct verification — re-reading the cited doc section and/or
reproducing the claimed behavior in the running engine, not taken on
Codex's word alone.

| # | Severity | Location | Finding (summary) | Classification | Verification |
|---|---|---|---|---|---|
| 1 | High | `screen_fit.gd` | Mobile branch uses Android DPI formula for iOS too; ARCHITECTURE §2 specifies `screen_get_scale()` for iOS, DPI/160 for Android | **VALID** | Confirmed: ARCHITECTURE.md §2 literally lists both paths; implementation only has one |
| 2 | Medium | `project.godot` | `application/config/quit_on_go_back` (required `false` by ARCHITECTURE §2) is missing | **VALID** | Confirmed: ARCHITECTURE.md §2 table requires it; confirmed the setting is real in Godot 4.7 (defaults `true`) and absent from the file |
| 3 | Medium | `farm_button.gd` | `commit_lock_ms` exported but never read/enforced anywhere | **VALID** | Confirmed by direct code read: no press-lock logic exists despite the property and its doc comment |
| 4 | Low | `farm_button.gd` | Press feedback is a vertical scale, not the specified 3 dp sink | **ALREADY_HANDLED** | The code's own comment explains this is a deliberate substitution (Containers can't safely animate `position`), documented as a known, intentional deviation — not an oversight. No further action beyond the existing comment. |
| 5 | Low | `icon_button.tscn` | Demo IconButton has no icon texture, renders empty | **OPTIONAL** | Correct observation; the demo scene is explicitly temporary (PROGRESS.md, main.gd comments) and no icon assets exist yet in Phase 0. Cosmetic only. |
| 6 | — | scenes/resources | `.tscn`/`.tres` syntax, `load_steps`, references | **NOT_APPLICABLE** (no issues found) | Codex found none; independently re-verified `load_steps` counts previously — still correct |
| 7 | — | theme type variations | Variation registration mechanism | **NOT_APPLICABLE** (no issues found) | Codex confirmed the fix already in place is correct |
| 8 | — | scene/node ownership | — | **NOT_APPLICABLE** (no issues found) | — |
| 9 | — | signal/event usage | — | **NOT_APPLICABLE** (no issues found) | — |
| 10 | Medium | `project.godot` | `config/features` declares `"4.2"` while the project actually targets/uses 4.7.2 | **VALID** (minor) | Confirmed the mismatch; harmless at runtime but should reflect the real baseline |
| 11 | Low | `screen_fit.gd` | Safe-area handling "required in Phase 0 by ARCHITECTURE §2" and missing | **INVALID** | Re-read ARCHITECTURE.md §2 directly: the safe-area paragraph assigns this to `AppShell` (a later-phase component per §3/§15.1), with no "build in Phase 0" instruction attached to it. Codex conflated the adjacent "Build this in Phase 0" sentence, which refers only to the preceding density-fit paragraph. |
| 12 | High | `screen_fit.gd` | Mobile branch still wrong for iOS even after the desktop fix | **VALID** (same root cause as #1) | Confirmed — this is finding #1 restated under a different category |
| 13 | Medium | `screen_fit.gd` | Width/height clamped independently; could distort aspect ratio on extreme devices | **OPTIONAL** | ARCHITECTURE.md §2 literally specifies "clamped to at least 360 x 640" with no aspect-preservation requirement — current code matches the spec as written. Codex's robustness concern is reasonable for a future hardening pass, not a deviation from the approved design. |
| 14 | High | `screen_fit.gd` / tests | Unit tests use idealized inputs, don't prove real-device behavior | **ALREADY_HANDLED** (acknowledged) | True and already acknowledged in ARCHITECTURE.md itself ("Verify it on real devices in Phase 10"). Not a Phase 0 gap. |
| 15 | Medium | `farm_button.gd` | Concurrent tweens on rapid press/release could race | **VALID** | Confirmed by code read: no tween is tracked/killed before starting a new one |
| 16 | Medium | `test_main_boots.gd` | Boot smoke test only checks node existence, not post-`_ready()` behavior or error absence | **VALID** | Fair test-quality gap |
| 17 | High | `test_screen_fit.gd` | No test coverage for the mobile `apply()` branch, only desktop | **VALID** | Confirmed: only one `OS.has_feature("pc")`-gated assertion exists; mobile path is untested |
| 18 | Low | `test_theme_tokens.gd` | Doesn't cover font sizes, pressed/disabled states, or all variations | **OPTIONAL** | Reasonable test-depth suggestion, not a defect; would expand Phase 0's test scope beyond what was approved |
| 19 | Low | `farm_button.gd` | `set_disabled_reason()` calls `add_sibling()` before the node may have a parent, which errors | **VALID** | Reproduced directly: confirmed engine error `"Parameter data.parent is null"` when called pre-tree-entry |
| 20 | Low | `farm_button.gd` | `size_variant` vs. ARCHITECTURE §15.4's documented `size` export name | **VALID** | Confirmed: ARCHITECTURE.md §15.4 does say `size`; the rename was a deliberate, undocumented-in-the-architecture fix for a real `Control.size` shadowing bug found during implementation |
| 21 | Medium | `farmora_theme.tres` | Toast corner radius (24 dp) claimed to violate "DESIGN §5's 16 dp toast radius" | **INVALID** | Re-read DESIGN.md §5 directly: no toast-specific radius row exists there at all (its radius scale is 10/14/20/28/999, no 16). The actual governing spec, UI_SPEC.md §15, explicitly specifies "radius 24" — exactly what is implemented. Codex's citation does not exist in the named section. |
| 22 | Low | `farmora_theme.tres` | Default font instead of Fredoka/Nunito | **ALREADY_HANDLED** | Explicitly documented, approved fallback per the Phase 0 approval constraints (constraint #5) and `assets/fonts/README.md`. Codex itself noted this is "a known design deviation rather than a hidden defect." |
| 23 | Medium | `main.gd` | Component demo's replacement boundary relies on comments, not structure | **OPTIONAL** | Reasonable forward-looking note; the demo is explicitly temporary and Phase 0 scope does not include building the real boot/AppShell integration seam yet |
| 24 | — | gameplay/phase scope | No out-of-phase systems found | **NOT_APPLICABLE** (confirms clean scope) | — |

### Summary

- **8 VALID findings requiring a fix**: #1/#12 (iOS screen-fit path), #2
  (`quit_on_go_back`), #3 (`commit_lock_ms` unused), #10 (`config/features`
  version string), #15 (concurrent tweens), #16 (shallow boot test), #17
  (missing mobile `ScreenFit` test coverage), #19 (`add_sibling` pre-tree
  error).
- **2 INVALID findings**: #11 (safe-area-in-Phase-0 claim; a
  misread of ARCHITECTURE §2), #21 (toast-radius claim; cites a
  nonexistent DESIGN §5 row and ignores the actual governing UI_SPEC §15
  value, which matches the implementation).
- **4 ALREADY_HANDLED**: #4, #14, #22, and #20's underlying cause (the
  `size`→`size_variant` rename itself was a deliberate, correct fix for a
  real bug — only its architecture-doc alignment needed follow-up).
- **4 OPTIONAL**: #5, #13, #18, #23 — reasonable suggestions beyond
  Phase 0's approved scope; not required for Phase 0 completion.

### Fixes applied

See `docs/PROGRESS.md` "Phase 0 — Codex review fixes" for the record of
what was changed, by which model, and the resulting verification run.

### Review Findings (established format)

* #1/#12 iOS ScreenFit path missing — FIXED
* #2 `quit_on_go_back` missing — FIXED
* #3 `commit_lock_ms` unused — FIXED
* #10 `config/features` version string stale — FIXED
* #15 Concurrent FarmButton tweens — FIXED
* #16 Shallow boot smoke test — FIXED
* #17 No mobile ScreenFit test coverage — FIXED
* #19 `add_sibling` pre-tree error — FIXED
* #11, #21 — INVALID, no action
* #4, #14, #20, #22 — ALREADY_HANDLED, no action
* #5, #13, #18, #23 — OPTIONAL, deferred (recorded as future tasks, not implemented)

---

### Fix implementation record

All 8 VALID findings were delegated to a cheaper model (Haiku) for
implementation, per the model-selection rule for routine, well-specified
fixes, with a verification gate applied independently afterward rather
than trusting the implementing model's self-report.

**Fixes applied (5 files touched, exactly as scoped — no other files
modified):**

1. `scenes/main/screen_fit.gd` — added the iOS `screen_get_scale()` path
   alongside the existing Android `screen_get_dpi() / 160.0` path,
   branching on `OS.get_name() == "iOS"`. Refactored the shared
   clamp/fallback logic into one private `_compute_fit_size_from_scale()`
   so neither path duplicates it.
2. `tests/unit/test_screen_fit.gd` — added 3 new tests for the iOS-style
   `compute_fit_size_from_scale()` pure function (normal case, zero-scale
   fallback, below-minimum clamp), closing the "mobile path has no test
   coverage" gap.
3. `project.godot` — added `config/quit_on_go_back=false`; updated
   `config/features` from `"4.2"` to `"4.3"`.
4. `ui/components/farm_button/farm_button.gd` — implemented the
   `commit_lock_ms` visual lock via a child one-shot `Timer` on the
   `pressed` signal; fixed concurrent-tween risk by tracking and killing
   the active scale tween before starting a new one; removed the broken
   `add_sibling()` call on a parentless node (replaced with a graceful
   `push_warning` early return).
5. `tests/integration/test_main_boots.gd` — added a test asserting
   `main.tscn`'s window reaches a valid post-`_ready()` state (non-negative
   `content_scale_size`), closing the "boot test only checks node
   existence" gap.

**Independent re-verification** (re-run directly, not taken from the
implementing agent's report):

- Headless import: zero errors, zero warnings.
- GUT suite: **20/20 tests passing, 33/33 asserts** (up from 16/16, 27/27
  before the fixes — 4 new tests added, all passing, none of the
  pre-existing tests broken).
- Visual re-check at 390x844: layout renders identically to the
  pre-fix screenshot, no regression from the `FarmButton` pressed-lock
  change or the `ScreenFit` refactor.

No further Codex re-review was requested for this fix batch: none of the
8 fixes materially changed reviewed *behavior* in a way that would alter
Codex's own findings (the iOS path addition and test additions are
pure-additive; the FarmButton fixes are internal robustness corrections
with no visible behavior change at Phase 0's demo scope). A re-review
would be warranted before Phase 1 if these components' public API changes
further.

---

## Phase 3 Full-Phase Review (Tasks 1-8) — [session date per environment: 2026-10-02]

**Reviewer:** Codex CLI (codex-cli 0.158.0), independent pass, read-only
sandbox, no implementation access, explicitly instructed not to trust
the implementing agent's progress summary.

**Scope reviewed:** `scripts/core/{action_result,game_clock,action_guard}.gd`,
`tests/helpers/fake_clock.gd`, `scripts/definitions/game_catalog.gd`
(FeedingParams/HappinessParams/StartParams), `tests/fixtures/balance_fixture.json`,
`scripts/state/player_state.gd`, `scripts/state/game_state.gd`,
`scripts/rules/feeding_rules.gd`, `autoload/game.gd` (`feed_animal()`),
`scenes/farm/animals/animal_view.gd`/`.tscn` (`Game.animal_changed`
wiring, `BubbleAnchor`), `scripts/rules/status_rules.gd`
(`Bubble`/`primary_bubble()`), `scenes/farm/world_ui/status_bubble.gd`/
`.tscn` (new), `scenes/farm/farm_world.gd` (bubble lifecycle,
`_on_bubble_tapped`), `scenes/farm/farm_input.gd` (`world_ui_container`,
`_bubble_targets()`), and all Phase 3 test files.

**Source of truth given to Codex:** `CLAUDE.md`, `docs/GDD.md`,
`docs/DESIGN.md`, `docs/UI_SPEC.md`, `docs/ARCHITECTURE.md`,
`docs/PROGRESS.md`.

**Out-of-scope checklist given to Codex** (to catch scope creep, not
just defects): hunger/happiness decay, `GameClock.now_ms()`, `SimTick`,
`_advance_to()`, `ProductionRules`, `last_seen_ms`,
`simulation_ticked`, `animal_status_changed`, a real PRODUCT/CLOUD
bubble trigger, any Animal Interaction sheet/Nav/AppShell/Overlay/
BottomSheet/HUD feed pill/ToastHost/ResultMessages/strings.csv UI
shell, `PlayerState.coins/xp/level`/feed cap/`buy_feed_pack`/
`feed_bought`/`coins_changed`, `SaveService`/`request_autosave`/
`to_dict`/`from_dict`/`extra`, breeding/genetics, audio/haptics.
Codex confirmed none of these were present.

### Findings and classification

Codex reported 2 findings on the first pass.

**F-01 (Codex: Medium, VALID) — `Game.feed_animal()` ignored
`catalog.feeding.debounce_ms`, hardcoding a `FEED_LOCK_MS = 300`
constant instead.**

Independently re-verified before accepting: read `autoload/game.gd`
directly and confirmed `FEED_LOCK_MS` was a hardcoded `const`, never
reading the `feeding.debounce_ms` field that Task 2 had deliberately
parsed and validated from `balance.json`. A real bug — tuning the
debounce window in balance data would have had zero effect on actual
command behavior, contradicting ARCHITECTURE.md's ADR-13 ("300 ms
commit lock ... mirrored ... shared value from balance").

**Classification: VALID. Fixed.** Removed the `FEED_LOCK_MS` constant
entirely; `feed_animal()` now passes `catalog.feeding.debounce_ms`
directly to `_guard.try_commit()`. Added a regression test
(`test_debounce_window_is_read_from_the_catalog_not_hardcoded` in
`tests/integration/test_game_commands.gd`) that configures a
non-default 1000ms window via a swapped catalog and confirms the lock
actually follows it (still locked at +300ms, free again at +1000ms) --
a test that would have failed against the old hardcoded implementation.

**F-02 (Codex: Low, OPTIONAL) — fractional JSON values (e.g.
`feedPerMeal: 1.5`) silently truncate via `int()` before validation can
detect the malformed value.**

**Classification: OPTIONAL, not fixed.** Independently verified this
is a pre-existing project-wide pattern, not something Phase 3
introduced: `scripts/definitions/animal_definition.gd` and
`product_definition.gd` (both Phase 2) use the identical
`int(data.get(...))` pattern with no integrality check. Fixing it now
would mean touching Phase 2 files outside this phase's declared scope
(CLAUDE.md Section 16). Recorded as a future cross-cutting task:
validate JSON field types/integrality before coercion, across all of
`scripts/definitions/`, not just this phase's additions.

### Re-review (F-01 fix only)

A second, narrower Codex pass reviewed only the F-01 fix (material
change to a command's runtime behavior, per the workflow's re-review
rules): confirmed `FEED_LOCK_MS` is fully removed with no remaining
references anywhere in the repo (only in comments describing the old
bug), confirmed the new regression test is genuine (not tautological --
would fail against the old code), and independently re-confirmed the
F-02 OPTIONAL reasoning by reading `animal_definition.gd`/
`product_definition.gd` itself. **No new findings.**

### Codex Review Result

**First pass:** Critical 0, High 0, Medium 1, Low 1 — **NEEDS_FIX**
**Re-review (F-01 fix):** 0 new findings — **PASS**

### Independent re-verification (re-run directly)

- Headless import: zero errors, zero warnings.
- GUT suite: **175/175 tests passing, 363/363 asserts** (up from
  119/267 at the start of Phase 3 — 56 new tests added across all 9
  tasks, including the F-01 regression test; zero pre-existing tests
  broken at any point).
- Visual check at both reference sizes (390x844, 360x640): a hungry
  chicken/cow shows the gold wheat bubble at its `BubbleAnchor`
  position; a fed pig shows none; calling `Game.feed_animal()` directly
  (the same path a real bubble tap uses) makes the chicken's bubble
  disappear and its face return to normal in the same run, confirmed by
  before/after screenshots, not assumed.

---

## Phase 4 Full-Phase Review (Tasks 1-8) — [session date per environment: 2026-10-03]

**Reviewer:** Codex CLI (codex-cli 0.158.0), independent pass, read-only
sandbox, no implementation access, explicitly instructed not to trust
the implementing agent's progress summary, and specifically asked to
independently verify two bugs the implementing agent claimed it had
already found and fixed during its own self-verification (see below).

**Scope reviewed:** `scripts/core/game_clock.gd` (`now_ms()`),
`tests/helpers/fake_clock.gd`, `scripts/state/inventory_state.gd`
(new), `scripts/state/game_state.gd` (`inventory`, `last_seen_ms`),
`scripts/definitions/game_catalog.gd` (`ProductionParams`),
`scripts/rules/production_rules.gd` (new: `advance_animal`,
`check_collect`, `apply_collect`), `autoload/game.gd` (`_advance_to`,
`SimTick`, `feed_animal` retrofit, `collect`),
`scenes/farm/world_ui/status_bubble.gd` (PRODUCT tinting + bob),
`scenes/farm/farm_world.gd` (`animal_status_changed` wiring,
recomputed-from-current-state bubble-tap routing),
`scenes/farm/animals/animal_view.gd` (`animal_status_changed`
reaction), and all Phase 4 test files.

**Source of truth given to Codex:** `CLAUDE.md`, `docs/GDD.md`,
`docs/DESIGN.md`, `docs/UI_SPEC.md`, `docs/ARCHITECTURE.md`,
`docs/PROGRESS.md`.

**Out-of-scope checklist given to Codex** (to catch scope creep):
`BuildingRules`/`BuildingInstance`/any building-multiplier division,
`TutorialRules`/any tutorial-boost substitution, `is_return`/
`OfflineReport` on `_advance_to`, `OfflineRules`,
`offline_progress_applied`, `on_app_backgrounded`/`on_app_resumed`,
`SaveService`/`request_autosave`, `InventoryState.remove()`/
`bag_changed`/selling, any new UI shell, breeding/genetics,
audio/haptics. Codex confirmed none of these were present (one caveat:
"existing UI assets such as ToastHost were present in the repository,
but no new UI shell was added in the reviewed changes" -- ToastHost
predates Phase 4, from Phase 0's design-system foundation, so this is
not scope creep).

**Two self-reported bugs, independently re-verified by Codex (not
taken on the implementing agent's word):**
- **Bug A** (`feed_animal()` missing its own `animal_status_changed`
  emission after the meal's own mutation): confirmed fixed --
  "`feed_animal()` snapshots flags immediately before the meal,
  applies it, then emits `animal_status_changed` only if the meal
  changes the flags. `_advance_to()` separately emits transitions
  caused by elapsed time."
- **Bug B** (`test_tapping_a_wheat_bubble_feeds_that_animal`'s stale
  `last_seen_ms` assumption breaking once `feed_animal` started calling
  `_advance_to`): confirmed fixed -- "the test seeds `last_seen_ms`
  from the real clock before tapping. The expected hunger is 5 + 50 =
  55, with elapsed decay tolerated up to 0.01 hunger units."

### Findings and classification

Codex reported 2 findings.

**F-01 (Codex: Medium) — `_advance_to()` re-bases `state.last_seen_ms
= now_ms` unconditionally, even when the clock moved backward
(`now_ms < last_seen_ms`, `dt_ms` clamped to 0). Codex's concern: if
the clock later corrects forward past the original time, the
intervening span gets simulated again.**

**Classification: INVALID.** Independently re-verified against
ARCHITECTURE.md Section 12.1 before accepting or rejecting -- that
section specifies this EXACT behavior as the intended design, in
nearly identical code: *"When the clock went backwards, `Game` also
**re-bases** `last_seen_ms = now_ms`. Otherwise a moved-back clock
would freeze production until real time caught up."* and the Section
12.2 pseudocode itself comments `state.last_seen_ms = now_ms  # also
re-bases a backwards clock`. Codex's suggested fix (keeping
`last_seen_ms` monotonic via `maxi(last_seen_ms, now_ms)`) would
directly contradict this documented design and reintroduce the
"frozen production" failure mode the docs explicitly call out as the
reason NOT to do that. The scenario Codex describes (re-simulating a
span after a backward-then-forward clock correction) is real in the
abstract, but it is the explicitly accepted tradeoff in exchange for
never freezing production -- not an implementation defect. No code
change made; this reasoning is recorded here per CLAUDE.md Section 14
("do not blindly apply every Codex suggestion").

**F-02 (Codex: Low) — test coverage gaps: the test named
`test_zero_or_negative_dt_does_nothing` only exercised `dt == 0.0` (no
negative-`dt` assertion), and no test directly proved `_advance_to()`
advances multiple animals independently in one call.**

**Classification: VALID. Fixed.**
- `tests/unit/test_production_rules.gd`: split the old test into
  `test_zero_dt_does_nothing` (unchanged assertion) and a new
  `test_negative_dt_does_nothing` (dt = -5.0, confirms progress,
  hunger, AND happiness are all left untouched -- not just progress).
- `tests/integration/test_game_commands.gd`: added
  `test_advance_to_advances_multiple_animals_independently_in_one_call`
  -- two animals of different species (different `cycle_seconds`)
  in one `GameState`, one command call, confirming the SECOND,
  untargeted animal is still advanced by the shared `_advance_to` loop
  using its OWN production parameters, not the targeted animal's.

### Codex Review Result

**First pass:** Critical 0, High 0, Medium 1, Low 1 — **NEEDS_FIX**
(1 INVALID, 1 VALID -- both resolved without further implementation
changes beyond the two new tests, which are purely additive and do not
change any reviewed behavior)

No re-review requested: F-01 required no code change (classified
INVALID with documented reasoning), and F-02's fix is purely additive
test coverage with zero production-code changes -- neither meets the
workflow's re-review triggers (a VALID finding's *fix* changing
architecture, public behavior, or a reviewed system).

### Independent re-verification (re-run directly)

- Headless import: zero errors, zero warnings.
- Full GUT suite: **229/229 passing, 449/449 asserts** (up from
  216/423 before the F-02 test additions; 13 new tests added across
  Tasks 7-8 plus the 2 F-02 regression tests, zero pre-existing tests
  broken).
- Visual check at both reference sizes (390x844, 360x640), using the
  REAL 1-second `SimTick` `Timer` (not a direct function call) to
  prove the online tick path end to end: a chicken at progress 0.99
  crosses to READY purely from the real timer firing over 2.2 real
  seconds, its egg-colored product bubble appears and bobs; calling
  `Game.collect()` then removes only that bubble, leaving an
  unaffected hungry animal's wheat bubble untouched. Confirmed by
  three sequential screenshots, not assumed.

---

## Phase 5 Full-Phase Review (Tasks 1-8) — [session date per environment: 2026-10-03]

**Reviewer:** Codex CLI (codex-cli 0.158.0), independent pass, read-only
sandbox, no implementation access, explicitly instructed not to trust
the implementing agent's progress summary, and specifically asked to
independently verify three bugs the implementing agent claimed it had
already found and fixed during its own self-verification (see below).

**Scope reviewed:** `scripts/state/player_state.gd` (`coins`, `level`),
`scripts/state/inventory_state.gd` (`remove()`),
`scripts/definitions/game_catalog.gd` (`EconomyParams`,
`NewAnimalParams`), `scripts/rules/economy_rules.gd` (new:
`missing_coins`, `check_buy_animal`, `check_buy_feed_pack`,
`sale_total`, `sell_all_total`), `autoload/game.gd` (`rng`,
`_generate_animal_id`, `buy_animal`, `buy_feed_pack`, `sell_product`,
`sell_all`), `scenes/farm/farm_world.gd` (`animal_added` reaction, the
building-tap seam, `_species_housed_in`), and all Phase 5 test files.

**Source of truth given to Codex:** `CLAUDE.md`, `docs/GDD.md`,
`docs/DESIGN.md`, `docs/UI_SPEC.md`, `docs/ARCHITECTURE.md`,
`docs/PROGRESS.md`.

**Out-of-scope checklist given to Codex** (to catch scope creep):
`BuildingRules`/`BuildingInstance`/`FarmState.buildings`/any
building-capacity or Market-bonus system (the `buildings` balance.json
group staying unparsed), `BUILDING_FULL`/`STORAGE_FULL` actually being
reachable, `SaveService`/`request_autosave`/`save_now`/any sync
save-and-rollback actually running, `xp`/`ProgressionRules`/
`xp_changed`/`level_changed`, any Shop/Market screen UI or other new UI
shell, animal sell-back, `play_drop_in`/Phase 9 polish. Codex confirmed
none of these were present.

**Three self-reported bugs, independently re-verified by Codex (not
taken on the implementing agent's word):**
- **Bug A** (two pre-existing test files leaving the real `SimTick`
  `Timer` running after `begin_session()`, leaking into later tests):
  confirmed fixed -- "The requested timer cleanup ... [is] present."
- **Bug B** (`_on_building_tapped` crashing a pre-existing
  Game.state-less test once it started unconditionally calling
  `Game.buy_animal()`): confirmed fixed -- "the null-state guard ...
  [is] present."
- **Bug C** (three new building-tap tests sharing the real
  `ActionGuard` singleton and debounce-locking each other's purchases):
  confirmed fixed -- "the per-test guard resets ... [are] present."

### Findings and classification

Codex reported 1 finding.

**F-01 (Codex: Low) — `test_sell_all_emits_the_full_signal_set_on_success`
only checked that `bag_changed` fired at all, never verifying either
sold product's own before/after quantity parameters or that both
expected emissions (egg, milk) actually occurred -- a stale or shared
quantity value in one emission could regress silently.**

**Classification: VALID. Fixed.** Independently re-verified against
the actual implementation (`Game.sell_all()` in `autoload/game.gd`)
before accepting: confirmed it does emit `bag_changed` once per sold
product inside a loop, each with that product's own
`get_qty()`-computed old/new values -- a genuine but previously
untested correctness property. Added
`test_sell_all_emits_bag_changed_once_per_sold_product_with_its_own_quantities`
to `tests/integration/test_game_commands_sell.gd`: asserts the
emission count is exactly 2 (not 1, not 3 -- pork is at 0 and must not
emit) and that each of the two emissions carries its own product's
correct id/new-qty/old-qty tuple, not a value leaked from the other
product's iteration.

### Codex Review Result

**Verdict:** Critical 0, High 0, Medium 0, Low 1 — **NEEDS_FIX** (the
one Low finding, fixed with a purely additive regression test; no
production code changed)

No re-review requested: F-01's fix is purely additive test coverage
with zero production-code changes, which does not meet the workflow's
re-review triggers (a VALID finding's *fix* changing architecture,
public behavior, or a reviewed system).

### Independent re-verification (re-run directly)

- Headless import: zero errors, zero warnings.
- Full GUT suite: **298/298 passing, 594/594 asserts** (up from
  297/591 before the F-01 test addition).
- Visual check at both reference sizes (390x844, 360x640), using a
  real building-tap-driven flow (not direct function calls) to prove
  the seam itself works end to end: tapping the Coop buys a chicken
  (200 → 100 coins), feeding it, fast-forwarding one full production
  cycle, collecting the egg, then tapping Market to sell it (100 → 105
  coins). Confirmed by four sequential screenshots, not assumed.

---

## Phase 6 Full-Phase Review (Tasks 1-8) — [session date per environment: 2026-10-03]

**Reviewer:** Codex CLI (codex-cli 0.158.0), independent pass, read-only
sandbox, no implementation access, explicitly instructed not to trust
the implementing agent's progress summary, and specifically asked to
independently verify four bugs the implementing agent claimed it had
already found and fixed during its own self-verification (see below).

**Scope reviewed:** `scripts/definitions/upgrade_definition.gd`/
`building_definition.gd` (new), `scripts/definitions/game_catalog.gd`
(buildings parsing + validation), `scripts/state/building_instance.gd`
(new), `scripts/state/farm_state.gd` (`buildings`, `get_building`),
`scripts/rules/building_rules.gd` (new, all 9 functions),
`scripts/rules/economy_rules.gd` (the `GameState`-param retrofit,
`BUILDING_FULL`/`STORAGE_FULL`), `autoload/game.gd`
(`_production_params_for`'s multiplier retrofit, `sell_product`/
`sell_all`'s bonus retrofit, `upgrade_building`),
`scenes/farm/farm_world.gd` (state-driven building spawning, the
long-press-to-upgrade seam), `scenes/farm/farm_input.gd`
(`building_long_pressed`), and all Phase 6 test files.

**Source of truth given to Codex:** `CLAUDE.md`, `docs/GDD.md`,
`docs/DESIGN.md`, `docs/UI_SPEC.md`, `docs/ARCHITECTURE.md`,
`docs/PROGRESS.md`.

**Out-of-scope checklist given to Codex** (to catch scope creep):
`SaveService`/sync save/rollback, `BuildingInstance.extra`,
`xp`/`ProgressionRules`/XP actually awarded by `upgrade_building`, any
building capacity/level UI (explicitly deferred with the user's
confirmation), any Shop/Market screen UI or upgrade confirm dialog,
building sell-back, `play_upgrade`'s animation, tutorial-boost
substitution, any construction/placement flow. Codex confirmed: "I
found no implemented save service, building serialization/`extra`, XP
awards, building-level UI, Shop UI, upgrade animation, tutorial boost,
or construction/placement flow in the inspected Phase 6 paths."

**Four self-reported bugs, independently re-verified by Codex (not
taken on the implementing agent's word):** all four (the
`test_economy_rules.gd` parse-error/silent-skip from the
`GameState`-param retrofit; `test_farm_world.gd`'s leaked-state
fragility exposed by the state-driven building-spawn retrofit;
`test_farm_input.gd`'s `test_farm_world_reemits_building_tapped` having
the same leaked-state issue; and `test_game_commands_upgrade.gd`'s
under-seeded-coins test design mistake) were confirmed present and
correctly fixed in the current files: "The supplied A–D fixes are
present in the current files. The integration test for repeated
upgrades seeds 3,000 coins, enough to reach the debounce check."

### Findings and classification

Codex reported 2 findings, both Medium.

**F-01 (Codex: Medium) — `buy_feed_pack()`'s `feed_bought` signal
always emits the nominal pack size (`catalog.economy.feed_pack_feed`),
even when the capacity clamp means fewer units were actually added
(the `refuse_overflowing_feed_pack = false` branch allows a
partially-overflowing purchase through, then clamps on apply).**

**Classification: VALID. Fixed.** Independently re-verified against
the actual implementation before accepting: confirmed
`feed_bought.emit(catalog.economy.feed_pack_feed)` was indeed
unconditional, while `feed_changed` right above it already carried the
accurate clamped before/after values -- a real, if narrow, inconsistency
reachable only when `refuse_overflowing_feed_pack` is false (not the
live default, but a documented, reachable switch). Fixed:
`feed_bought.emit(state.player.feed - old_feed)` -- the ACTUAL feed
added. Added
`test_buy_feed_pack_emits_the_actual_amount_added_not_the_nominal_pack_size_on_partial_overflow`
to `tests/integration/test_game_commands_buy.gd`, which temporarily
flips the live catalog's switch to `false`, seeds feed near the cap,
and confirms the signal reports the clamped delta (5), not the nominal
pack size (10).

**F-02 (Codex: Medium) — the long-press-to-upgrade seam
(`FarmWorld._on_building_long_pressed`) spends coins and changes a
building's level immediately with no confirmation, while GDD Section 6
requires a confirm dialog for every upgrade and UI_SPEC routes an
upgrade through Building Details.**

**Classification: INVALID.** This is the identical, already-accepted
tradeoff as the Phase 5 building-tap buy/sell seam: both were
explicitly proposed to the user as documented temporary stand-ins with
no design-doc counterpart, specifically BECAUSE skipping the
confirm-dialog/Shop-UI requirement is what lets the full economy loop
(buy, sell, and now upgrade) be exercised end-to-end in real play
before that UI exists -- without it, `BUILDING_FULL`/`STORAGE_FULL`
refusals (this same phase's own Task 4) would create a real dead end
with no way to progress. The user was asked this exact question before
implementation and approved it (see the Phase 6 plan's item 6 above).
Re-confirmed with the user before classifying this INVALID rather than
assuming the prior approval covered it automatically. No code change;
reasoning recorded here per CLAUDE.md Section 14 ("do not blindly
apply every Codex suggestion").

### Codex Review Result

**First pass:** Critical 0, High 0, Medium 2, Low 0 — **NEEDS_FIX**
(1 VALID fixed with a regression test, 1 INVALID with documented
reasoning; no re-review required since F-01's fix is additive/narrow
and F-02 required no code change)

### Independent re-verification (re-run directly)

- Headless import: zero errors, zero warnings.
- Full GUT suite: **368/368 passing, 727/727 asserts** (up from
  367/725 before the F-01 test addition).
- Visual check at both reference sizes (390x844, 360x640), using the
  real building-tap AND long-press seams (not direct function calls)
  to prove the full capacity/upgrade loop end to end: buying 4 chickens
  fills the Coop (1200 → 800 coins), a 5th buy attempt is refused with
  `BUILDING_FULL`, a real long-press upgrade brings the Coop to L2
  (800 → 300 coins), and the 5th chicken then succeeds (5 chickens
  visible at the upgraded Coop). Confirmed by three sequential
  screenshots at each size, not assumed.

---

## Phase 7 Full-Phase Review (Tasks 1-9) — [session date per environment: 2026-10-03]

**Reviewer:** Codex CLI (codex-cli 0.158.0), independent pass, read-only
sandbox, no implementation access, explicitly instructed not to trust
any implementation summary and to verify every claim directly against
source and tests.

**Process note (not a finding, recorded for future sessions):** the
first review attempt was given the full `CLAUDE.md` +
`docs/ARCHITECTURE.md` + `docs/PROGRESS.md` (6,447 combined lines) to
read as context. It spent its entire turn/token budget reading those
files in full and the complete source/test list, and exited without
ever producing a findings section (confirmed by inspecting its raw
transcript — it stopped mid-file-read, no analysis text at all). The
review was re-run with two small, purpose-built excerpt files (the
Phase 7 section of PROGRESS.md alone, ~370 lines, and the save-specific
slice of ARCHITECTURE.md Section 11, ~143 lines) and an explicit
instruction not to read the full docs — this run completed normally in
~13 minutes and produced real findings. CLAUDE.md Section 20.11 ("No
Unnecessary Re-Reading... avoid copying entire documents into prompts")
already recommends this; this is now a concrete, observed case of the
failure it is meant to prevent, worth remembering for every future
full-phase review as the docs keep growing.

**Scope reviewed:** all Phase 7 state-shape additions
(`SettingsState`, `PlayerState`/`BuildingInstance`/`InventoryState`/
`FarmState`/`GameState`'s `to_dict`/`from_dict`/`extra`/unrecognized
arrays), `scripts/save/save_file_io.gd`, `save_migrator.gd`,
`save_codec.gd`, `decode_result.gd`, `load_result.gd`,
`autoload/save_service.gd`, `autoload/game.gd`'s full Phase 7 retrofit
(`_save_snapshot`, `request_autosave()` call sites, the `sell_product`/
`sell_all` synchronous-save/rollback rewrite, `on_app_backgrounded`),
`scenes/main/main.gd`'s 3-branch boot tree and backgrounding
notification wiring, `project.godot`'s autoload registration, and the
corresponding test files (`test_save_file_io.gd`, `test_save_migrator.gd`,
`test_save_codec.gd`, `test_save_service.gd`, `test_main_boots.gd`, and
the Phase 7 additions to `test_game_commands*.gd`).

**Source of truth given to Codex:** the Phase 7 excerpt of
`docs/PROGRESS.md` and the Section 11 excerpt of `docs/ARCHITECTURE.md`
(see process note above), plus direct reads of every listed source/test
file.

**3 product decisions given to Codex as pre-approved, not to be
flagged as defects:** (1) Phase 7 is save/load ENGINE only, no Main
Menu/Splash/Settings UI; (2) a damaged/too-new save on boot starts a
fresh game in memory only, the bad file is left untouched on disk; (3)
persistence is enabled immediately from boot with no "tap Play" gate.

**Explicit focus areas given to Codex:** `SaveFileIO.write_atomic()`'s
4-step sequence; `SaveCodec.decode()`'s 6 ordered steps; `SaveService.
load_game()`'s Load-order table and the `TOO_NEW` short-circuit; the
`sell_product`/`sell_all` snapshot/apply/save/rollback sequence
specifically flagged as "the highest risk code in the phase"; autoload
singleton test-isolation (both `before_each` AND `after_each`,
per Phase 6's documented postmortem); static-typing compliance; the
boot tree against the 3 approved decisions; scope discipline against
Phase 8/UI leakage; test quality/tautology.

### Findings and classification

**Codex reported 0 findings.** Full PASS across all 10 requested
checks, each with a specific file:line citation:

1. No Critical or High severity defects anywhere in scope.
2. `SaveFileIO.write_atomic()` matches the documented sequence exactly
   (write+flush tmp → read back + parse → copy main to backup → rename
   tmp over main; remove-then-rename fallback confirmed for the
   desktop case).
3. `SaveCodec.decode()`'s six steps and their order match
   ARCHITECTURE.md Section 11.3 exactly.
4. `SaveService.load_game()`'s candidate order is correct: a `TOO_NEW`
   main returns immediately without ever trying `.tmp`/backup; a valid
   main wins, then `.tmp`, then backup.
5. **No sale-rollback defect.** On a `save_now()` failure, both
   `sell_product` and `sell_all` restore `coins` and the full inventory
   dictionary before returning `SAVE_FAILED`; every sale signal
   (`coins_changed`, `bag_changed`, `products_sold`, `state_changed`)
   is confirmed emitted only after a successful save, never on the
   rollback path.
6. No test-isolation issue in `test_save_service.gd`,
   `test_main_boots.gd`, or `test_game_commands_sell.gd` -- persistence,
   both timers, the retry index, and `io` are all reset in both
   `before_each` and `after_each`.
7. No untyped declarations found in the reviewed files.
8. The boot tree matches all 3 approved decisions exactly; the
   `DAMAGED`/`TOO_NEW` branch neither quarantines nor writes the save
   file.
9. No Phase 8 implementation (`on_app_resumed`/`is_return` confirmed
   still absent, only mentioned in deferral comments) and no
   out-of-scope UI found.
10. No tautological tests among those reviewed -- the sale-failure
    tests force a real I/O failure via `FailingSaveFileIO`, the boot
    tests exercise actual scene instantiation and real file-presence
    checks, and the codec tests assert genuinely decoded state.

### Codex Review Result

**PASS** — Critical 0, High 0, Medium 0, Low 0, 0 findings. No fixes
required, no re-review needed.

### Independent re-verification (re-run directly by the orchestrator,
not taken on any agent's or Codex's word)

- Headless import: zero errors, zero warnings, at every task boundary
  across the whole phase.
- Full GUT suite, final state: **436/436 passing, 922/922 asserts**
  (32 scripts), re-run independently after each of the 9 implementation
  tasks, not just once at the end.
- Every delegated subagent's production code was read in full by the
  orchestrator before being accepted (not just the agent's self-report):
  `save_file_io.gd`, `save_codec.gd`/`decode_result.gd`,
  `save_service.gd` and the full `autoload/game.gd` retrofit were each
  read end-to-end, with the sell-command rollback logic specifically
  traced line-by-line given its correctness-critical nature.
- **Real-engine round trip** (beyond GUT): launched the actual compiled
  `main.tscn` via `godot --headless --path . res://scenes/main/main.tscn`
  with a temporary throwaway probe autoload (removed afterward, along
  with the real `user://` save directory it created) -- first run
  booted `NO_SAVE`, mutated state via a real `Game.buy_feed_pack()`
  call, waited out the real 2-second autosave debounce, and confirmed
  `user://save/farmora_save.json` was written to the real OS
  filesystem with the correct values in the documented shape; a
  second, fully separate process launch of the same scene then loaded
  that real file back (`coins=125, feed=15, persistence=true`),
  confirming the complete launch → mutate → autosave → kill → relaunch
  → restore round trip works outside the test harness, not merely
  inside it.

**Phase 7 completion criteria met:**
```text
Claude Implementation     = COMPLETE
Verification               = PASS
Codex Review                = PASS
Unresolved VALID findings = 0
VALID_DEFERRED/OPTIONAL    = none this phase
```

---

## Phase 8 Full-Phase Review (Tasks 1-7) — [session date per environment: 2026-10-03]

**Reviewer:** Codex CLI (codex-cli 0.158.0), independent pass, read-only
sandbox, no implementation access, explicitly instructed not to trust
any implementation summary and to verify every claim directly against
source and tests. Given small, purpose-built excerpts (the Phase 8
section of PROGRESS.md and the offline-progression slice of
ARCHITECTURE.md Section 12) and an explicit instruction NOT to read the
full CLAUDE.md/ARCHITECTURE.md/PROGRESS.md, per the lesson recorded in
Phase 7's own review entry above (the first Phase 7 attempt exhausted
its budget reading full mega-docs and never produced findings). This
run completed normally and produced real findings on the first attempt.

**Scope reviewed:** `scripts/definitions/game_catalog.gd` (the new
`OfflineParams` class/parsing/validation), `scripts/rules/
offline_rules.gd` (new), `scripts/rules/offline_report.gd` (new),
`scripts/rules/economy_rules.gd` (the new `offline_coin_value`),
`autoload/game.gd` (`_advance_to`'s extended signature/body,
`begin_session`, `on_app_backgrounded`, `on_app_resumed`,
`_on_sim_tick_timeout`, `collect`/`_collect_one`/
`collect_offline_reward`), `scenes/main/main.gd` (the full boot/
notification wiring), and all Phase 8 test files (`test_offline_rules.gd`,
the offline additions to `test_game_catalog.gd`/`test_economy_rules.gd`,
`test_offline_progression.gd`, the offline additions to
`test_game_session.gd`, `test_game_commands_offline.gd`, the offline
additions to `test_main_boots.gd`).

**Product decision given to Codex as pre-approved, not to be flagged as
a defect:** Phase 8 is ENGINE ONLY -- no Nav/AppShell/modal UI exists.
A qualifying return is computed, reported via
`Game.offline_progress_applied`, and held by `Main` as
`pending_offline_report` (logged for dev visibility); nothing is shown
to the player. `collect_offline_reward()` is fully built and tested but
has no runtime caller this phase.

**Explicit focus areas given to Codex:** `OfflineRules.elapsed_ms()`'s
backwards-clock/cap handling and the strictly-greater-than modal
threshold; `_advance_to()`'s "one simulation path" guarantee (no
parallel advancement logic anywhere); the unconditional
`offline_progress_applied` emission on `is_return` (matching the
architecture doc's own pseudocode, not internally gated on
`should_show_modal()`); the SimTick gap-detection ordering (computed
BEFORE `_advance_to()` re-bases `last_seen_ms`, avoiding a
chicken-and-egg bug); `collect_offline_reward()`'s no-coins/stale-id-
tolerance/no-rollback-on-save-failure behavior; `Main`'s connect-before-
`begin_session()` ordering; test quality (specifically the split-
invariance test and the coin-value test); scope discipline against
Nav/AppShell/modal leakage; static typing; the Phase 7-documented GUT
signal-watcher gotcha's correct use throughout the new tests.

### Findings and classification

Codex reported 2 findings: 1 Medium, 1 Low. Both are test-coverage gaps,
not production-code defects.

**F-01 (Codex: Medium) — The split-invariance test
(`test_offline_progression.gd`, originally
`test_one_shot_two_hour_advance_matches_many_one_second_advances`) used
a 2-hour window with a cow (6-minute production cycle, hunger reaches 0
after 100 minutes at the fixture's decay rate). Both the one-shot and
the 7,200-tick runs saturate at `progress=1.0`/`hunger=0.0` well before
the window ends, so the assertion could pass even if the two paths
genuinely diverged somewhere in the middle of the window -- both would
still converge to the same clamped endpoint regardless.**

**Classification: VALID. Fixed.** Independently re-confirmed before
accepting: the cow's 6-minute cycle and the fixture's 1%/minute hunger
decay do mean both runs saturate well inside a 2-hour window, exactly
as Codex described -- this was a genuine masking bug in the test, not a
production defect (the production code itself was never suspect; only
the test's power to detect a regression was). Fixed by shrinking the
window to 2 minutes (well under the cow's 6-minute cycle and the
100-minute hunger-to-zero time) and adding two setup-sanity assertions
(`one_shot_hunger`/`one_shot_progress` must land strictly mid-range, not
saturated) so a future balance.json change that accidentally re-
saturates the window fails loudly at the setup assertion instead of
silently passing the comparison. Re-ran and confirmed the test still
passes with this stricter, genuinely discriminating window.

**F-02 (Codex: Low) — `test_build_computes_coin_value_including_the_market_bonus`
(`test_offline_rules.gd`) computed its own "expected" value by calling
`EconomyRules.offline_coin_value()` directly -- the very function
`OfflineReport.build()` internally calls -- so it only proved `build()`
passes its arguments through correctly, never independently verifying
the Market-bonus/rounding arithmetic from this call site (though that
arithmetic IS separately, genuinely tested in `test_economy_rules.gd`).**

**Classification: VALID. Fixed.** Replaced the self-referential
"expected" computation with a hand-computed value: 1 egg at the
fixture's 5-coin `sellPrice`, +5% Market-level-2 bonus = 5.25, rounds
HALF UP to 5 (`EconomyRules`' documented "round the total once" rule) --
confirmed by reading the fixture's own `market` level-2
`sellBonusPercent: 5` entry directly rather than trusting the prior
test's assumption.

### Codex Review Result

**First pass:** Critical 0, High 0, Medium 1, Low 1 — **NEEDS_FIX** (2
VALID, both fixed with no production-code change; re-review not
required since both fixes are test-only and narrow, per CLAUDE.md
Section 7/11's re-review criteria).

### Independent re-verification (re-run directly by the orchestrator,
not taken on Codex's word)

- Both fixed test files read and the fix logic independently confirmed
  against `data/balance.json`'s real animal cycle times/hunger decay
  rate and the fixture's own Market bonus table, not just Codex's
  stated numbers.
- Full GUT suite: **489/489 passing, 1008/1008 asserts** (35 scripts,
  +2 asserts over the pre-fix 1006 from the two new setup-sanity
  assertions added alongside F-01's fix). Zero regressions.
- Headless import: zero errors, zero warnings.

**Phase 8 completion criteria met:**
```text
Claude Implementation     = COMPLETE
Verification               = PASS
Codex Review                = PASS
Unresolved VALID findings = 0
VALID_DEFERRED/OPTIONAL    = none this phase
```

---

## Phase 9 Full-Phase Review (Tasks 1-9) — [session date per environment: 2026-10-03]

**Reviewer:** Codex CLI (codex-cli 0.158.0), independent pass, read-only
sandbox, no implementation access, explicitly instructed not to trust
any implementation summary and to verify every claim directly against
source and tests. Given a small, purpose-built excerpt (the Phase 9
section of PROGRESS.md alone) and an explicit instruction not to read
the full CLAUDE.md/ARCHITECTURE.md/PROGRESS.md, per the lesson first
recorded in Phase 7's review entry and reconfirmed in Phase 8's. This
run took noticeably longer than Phase 7/8's reviews (the explicit
instruction to directly diff-read 4 `.tscn` files against each other
for the species-scene structural risk added real work), but completed
normally and produced genuine findings.

**Scope reviewed:** `autoload/audio_service.gd` (new), `scenes/farm/
farm_camera.gd` (the new `zoom_changed`/`indicator_scale`/`_player_zoom`
additions), `scenes/farm/world_ui/status_bubble.gd` (full file),
`scenes/farm/world_ui/floater.gd` (new), `scenes/farm/ambient_budget.gd`
(new), `scenes/farm/ambient_backdrop.gd` (new), `scenes/farm/animals/
animal_view.gd` (full file, the highest-risk file this phase),
`scenes/farm/animals/{chicken,cow,pig}_view.gd` (new subclasses) and
their corresponding `.tscn` files, `scenes/farm/buildings/
building_view.gd` (the new `play_upgrade`), `scenes/farm/farm_world.gd`
(the Phase 9-relevant methods), and all new/modified Phase 9 test
files.

**The single highest-priority check given to Codex:** independently
verify the claim that ZERO new nodes were added to `animal_view.tscn`'s
root (the base scene every species scene hardcodes `index=` overrides
against) -- the exact structural risk that already caused a real bug
once in Phase 2. Codex confirmed directly by reading the raw `.tscn`
file contents: "The base scene has exactly seven direct root children
in the stated order. Each species scene's raw overrides place its
species parts at indices compatible with that order." Codex also
attempted a `git diff` to establish a tracked baseline for extra
certainty, but this repository has no commits yet (`git status` shows
every file as untracked) -- noted as a genuine tooling limitation, not
a finding, and resolved by reading the file contents directly instead
once the diff attempt came back empty.

**Explicit focus areas given to Codex:** the species-scene structural
risk (above); `FarmCamera.indicator_scale()`'s clamp formula and
player-zoom computation; `StatusBubble.despawn()`'s immediate
`_despawning` gate; the `_rebuilding`-gated live-only decision functions
(`_should_chime_on_ready`, `_should_play_drop_in`); `AmbientBudget`'s
2-slot cap and the `_exit_tree()` leak-prevention path; `Motion.reduced`
compliance across every new animation; confetti/sparkle particle
details (CPUParticles2D, GL Compatibility, caps, reduced-motion
skip-not-shorten); `AudioService`'s settings-gating and null-state
safety; scope discipline against Nav/AppShell/tr()/real-audio-asset
leakage; static typing; test quality/tautology.

### Findings and classification

Codex reported 1 finding: 1 Low. A test-quality gap, not a production
bug.

**F-01 (Codex: Low) — `test_building_view.gd`'s
`test_play_upgrade_plays_the_upgrade_sound_and_haptic` asserted only
`assert_true(true)`, a trivially-passing assertion that would pass even
if `BuildingView.play_upgrade()` stopped calling `AudioService`
entirely. The test name overstated what the test actually verified.**

**Classification: VALID. Fixed.** Independently confirmed before
accepting: the test body was indeed a bare `assert_true(true)`, and the
production code itself (`building_view.gd`'s `play_upgrade()`) was
separately confirmed correct by direct reading -- this was purely a
test-coverage gap, not a production defect. Attempted the natural first
fix (assert `AudioService.play()`/`haptic()` return `true` with sound/
vibration explicitly enabled) and discovered it itself failed: with no
audio asset files yet (Phase 9's own approved "ship silent" scope
decision), `AudioService.play()` correctly returns `false` even with
sound enabled, since `_load_stream()` finds no file at the resolved
path -- a useful reminder that the silent-by-design behavior applies
everywhere, including inside a test meant to verify it. Fixed instead
by asserting the GATING logic in the opposite direction: with sound/
vibration explicitly DISABLED, `AudioService.play()`/`haptic()` must
return `false`, confirming `play_upgrade()`'s own identical calls go
through the same real, correctly-gated API rather than some stub --
the strongest verification available without introducing a mocking
seam solely for this one test.

### Codex Review Result

**First pass:** Critical 0, High 0, Medium 0, Low 1 — **NEEDS_FIX** (1
VALID, fixed with no production-code change; re-review not required
since the fix is test-only and narrow, per CLAUDE.md Section 7/11's
re-review criteria).

### Independent re-verification (re-run directly by the orchestrator,
not taken on Codex's word)

- Read `chicken_view.tscn`/`animal_view.tscn`'s raw file contents
  directly (not just Codex's summary of them) to independently confirm
  the structural-risk claim: the `index=` overrides and base-scene
  child list are byte-for-byte what the implementing agent's report
  described, with only a `script =` line added to each species scene.
- Read `farm_camera.gd`'s `indicator_scale()`/`_player_zoom()`,
  `status_bubble.gd`'s `despawn()`/`tap_rect()`, and `farm_world.gd`'s
  `_should_chime_on_ready()`/`_should_play_drop_in()` end-to-end before
  accepting Codex's "no issues found" verdict on each.
- Full GUT suite: **559/559 passing, 1173/1173 asserts** (38 scripts,
  +1 assert over the pre-fix 1172 from F-01's fix). Zero regressions.
- Headless import: zero errors, zero warnings.

**Phase 9 completion criteria met:**
```text
Claude Implementation     = COMPLETE
Verification               = PASS
Codex Review                = PASS
Unresolved VALID findings = 0
VALID_DEFERRED/OPTIONAL    = none this phase
```
