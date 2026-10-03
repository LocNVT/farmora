# Farmora

A cozy, portrait-mode animal farming simulation for Android and iOS, built in Godot 4.7 (GDScript).

Buy animals → feed them → collect what they make → sell it → upgrade the farm → buy more animals.

## Status

All 11 phases defined in [CLAUDE.md](CLAUDE.md) (Phase 0 – Phase 10) are implemented and verified. See [docs/PROGRESS.md](docs/PROGRESS.md) for the full phase-by-phase history, including each phase's Codex review findings.

Real device/store-build validation (Phase 10's Android/iOS build, on-device touch and performance testing) is the one remaining piece — it requires hardware and SDKs outside the dev environment this project was built in. `export_presets.cfg` is ready as the starting point; see the "Phase 10 — Mobile Validation" section of `docs/PROGRESS.md` for exactly what's done versus what's left.

## Documentation

Read in this order before making changes:

| Doc | Purpose |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Project rules, phase breakdown, workflow for AI-assisted development |
| [docs/GDD.md](docs/GDD.md) | Game design: vision, gameplay loop, animals, economy, progression |
| [docs/DESIGN.md](docs/DESIGN.md) | Visual design: palette, typography, spacing, motion principles |
| [docs/UI_SPEC.md](docs/UI_SPEC.md) | UI specification: screens, components, navigation, states |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Technical architecture: folder structure, services, data flow, save format |
| [docs/PROGRESS.md](docs/PROGRESS.md) | What's built, what's tested, current status, next action |
| [docs/CODEX_REVIEW.md](docs/CODEX_REVIEW.md) | Independent review findings per phase |

`docs/ARCHITECTURE.md` is the source of truth for *how* the code is organized; `docs/PROGRESS.md` is the source of truth for *what currently exists*.

## Requirements

- Godot 4.7.x (stable, non-Mono)
- No other runtime dependencies — local JSON save, no network, no third-party SDKs

## Running the game

Open the project in the Godot editor and run it, or from the command line:

```sh
godot --path . res://scenes/main/main.tscn
```

## Running tests

Tests use [GUT](https://github.com/bitwes/Gut) (vendored under `addons/gut/`):

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## Project layout

```
autoload/     Game, SaveService, AudioService — the global singletons
scripts/      Static definitions, runtime state, pure rules, save/load codec
scenes/       Farm world (Node2D, game content)
ui/           Screen-space UI components and theme (Control)
data/         balance.json — all tunable game values
tests/        GUT unit + integration tests
docs/         Design and architecture documentation
```

See `docs/ARCHITECTURE.md` Section 3 for the full annotated folder structure and the reasoning behind this split.
