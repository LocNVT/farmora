# Fonts — TEMPORARY fallback in place (Phase 0)

docs/DESIGN.md Section 3 specifies two licensed font families:

- **Fredoka** (600, 700) — display, headings, buttons, every number
- **Nunito** (600, 700) — body copy, captions

Neither font's files were available in the repo at Phase 0 time. Per
CLAUDE.md Section 10 ("do not block gameplay implementation waiting for
final artwork") and the Phase 0 approval constraints, Phase 0 does **not**
block on sourcing these files.

## What Phase 0 actually does

`ui/theme/farmora_theme.tres` uses Godot's built-in default theme font
(no custom `FontFile` assigned) for every type variation. This is a
placeholder, not a design decision — DESIGN.md's type scale (sizes,
weights, line heights) is still honored via the Theme's font sizes; only
the font *family* is a temporary substitute.

## How to swap in the real fonts later

1. Obtain the official Fredoka and Nunito OFL files (weights 600 and 700
   of each) and place them here as:
   - `assets/fonts/Fredoka-SemiBold.ttf` (600)
   - `assets/fonts/Fredoka-Bold.ttf` (700)
   - `assets/fonts/Nunito-SemiBold.ttf` (600)
   - `assets/fonts/Nunito-Bold.ttf` (700)
   - Their `LICENSE.txt` (SIL OFL) files alongside them.
2. Import them into Godot (they'll appear as `.ttf` resources).
3. Open `ui/theme/farmora_theme.tres` and assign the imported `FontFile`
   resources to the default font and to each type variation listed in
   `docs/ARCHITECTURE.md` Section 15.5.
4. No GDScript changes are required — `UiTokens` only holds sizes, radii,
   colors and durations, never font references, so this swap is confined
   entirely to the one `.tres` file.
5. Update this README and `docs/PROGRESS.md` once done.

Do not treat the built-in font as final. Do not replace it with any other
non-approved font family.
