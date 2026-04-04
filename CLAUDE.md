# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Beyond All Random (BaR)** — a Lua mod suite for Beyond All Reason, a Spring RTS Engine game. Based on AMBO & MGGW's Random Rarities mod. Adds a random rarity system to units with faction-balanced guarantees, a viewer widget, and a balance patch. Files are pure Lua loaded directly by the Spring engine.

## Build & Serialize

Requires `luamin` (`npm install -g luamin`) for minification, or Docker.

```bash
make          # minifies mod.lua + mod_buildings.lua → mod.b64 + mod_buildings.b64
make docker   # same, but uses Docker (no local luamin needed)
make segments # regenerates docs/js/rarity-template.js from mod.lua (auto-runs on pre-commit)
make setup    # installs pre-commit hook (run once after cloning)
make clean    # removes .b64 files
```

Each encoded output must stay under **16,384 chars** (BAR lobby slot limit). Apply in-game with:
```
!bset tweakdefs <contents of mod.b64>
!bset tweakdefs1 <contents of mod_buildings.b64>
```

`serialize.sh` handles the pipeline: extracts leading `--` comment headers, minifies via `luamin`, prepends headers, base64-encodes, and validates the output is under 16,384 chars.

## Architecture

The mod is split into two tweakdefs files, each loaded into a separate BAR lobby slot:

### mod.lua — Combat units & armed buildings (tweakdefs)

Handles units with `speed` or `weapondefs` or `builder == true`. Passive buildings are skipped (handled by mod_buildings.lua).

**Pass 1a — Guaranteed spicy units:** For each factory's combat unit list (`factory_units`), picks a random unit and rolls rarity with floor 7 (Mythical). Tracks picks in `guaranteed` table to avoid duplicates.

**Pass 1b — Remaining combat units:** All non-guaranteed units get a `get_rarity()` roll (75% chance to escalate per tier, 28 tiers). 20% curse chance for combat units.

**Pass 2a — Archetypes:** Armed units at rarity 5+ get one of 4 mobile archetypes (Glass Cannon, Tank, Sniper, Brawler) or 3 turret archetypes (Fortress, Watchtower, Suppressor).

**Pass 2b — Traits:** Archetype-specific traits at rarity 5+ with 50% chance. Each archetype has its own trait pool (3 traits each).

**Pass 3 — Stat scaling:** Applies exponential scaling via `set_v()` formula. Split into helper functions: `apply_curse_scaling`, `apply_unit_scaling`, `apply_weapon_scaling`, `apply_traits`, `build_rename`. Commander rarity capped at 6.

**Beam weapon handling:** Continuous beams detected when `beamtime/reloadtime >= BEAM_CONT_THRESHOLD` (0.90) — reloadtime is reset to beamtime after scaling. Sweepfire weapons let normal scaling handle both damage and reload.

### mod_buildings.lua — Passive buildings (tweakdefs1)

Handles buildings with no `speed`, no `weapondefs`, and `builder ~= true`. Has its own copy of shared helpers and independent rarity rolls.

**Category detection:** Buildings are classified by UnitDef fields: mex, energy, windtidal, converter, radar, sonar, jammer, factory, storage, nano, or generic.

**Building archetypes (3):** Efficient (cheap, moderate output), Fortified (tanky), Overclocked (fragile, high output, high upkeep). Assigned at rarity 5+.

**Building traits (25 across 10 categories):** Category-specific traits including stat multipliers, death AoE explosions (`area_ondeath_*` customparams), unit evolution (`evolution_target/condition/timer`), jamming capability, and EMP resistance (`paralyzemultiplier`).

### Other files

- **random_stats_viewer.lua** — In-game UI widget. Parses `infolog.txt` to read rarity assignments, displays units organized by faction with color-coded rarity, stats, and factory build trees. Toggle with `/unitstats`.

- **disable_t3_air.lua** — Makes T3 air units prohibitively expensive.

- **factory_tree.lua** — Auto-generated from BAR game data. Maps faction → factory → combat unit names. Regenerate with `python3 build_factory_tree.py`.

- **Beyond-All-Reason/** — Shallow clone of the BAR game repo, used by `build_factory_tree.py` to extract unit definitions.

- **Dockerfile.build** — Docker-based build with Node.js + luamin. Used by `make docker`.

**Data flow:** `mod.lua` + `mod_buildings.lua` modify UnitDefs and log to infolog → `random_stats_viewer.lua` parses infolog and renders UI.

## Commit Conventions

Commits use prefixes parsed by `git-cliff` (see `cliff.toml`) to generate changelogs. Use these prefixes:

- `feat:` — New features (traits, archetypes, new systems)
- `fix:` — Bug fixes (scaling bugs, beam handling, edge cases)
- `balance:` — Balance changes (stat multiplier tweaks, rarity tuning)
- `ui:` — UI changes (viewer widget, web builder, GH Pages)
- `chore:` — Build/CI/docs (skipped in changelog)

Examples: `feat: add Plague trait`, `fix: beam reload at extreme rarity`, `balance: nerf Glass Cannon HP to 0.88`.

Unprefixed commits starting with Add/Fix/Update/Improve/Remove are auto-categorized. The `chore:` prefix (including version bump commits) is excluded from release notes.

## Versioning & Releases

- Version is an integer tag (`v5`, `v6`, ...) auto-incremented on every push to master via `.github/workflows/autobump.yml`
- The workflow updates version strings in `mod.lua` line 1, `mod_buildings.lua` line 1, and `docs/js/rarity-template.js` header, commits with `[skip ci]`, tags, and creates a GitHub Release
- Release notes are generated by `git-cliff` from commit history between tags
- The GH Pages site fetches the latest version from the GitHub API at page load

## Spring Engine API Surface

- `UnitDefs` / `WeaponDefs` — global tables for unit and weapon definitions
- `Spring.Echo()` — logging to infolog.txt
- `VFS.LoadFile()` — reading files (e.g., infolog.txt)
- `gl.*` functions — OpenGL rendering (Color, Rect, Text, etc.)
- Widget callbacks: `widget:Initialize()`, `widget:DrawScreen()`, `widget:MousePress()`, `widget:MouseWheel()`, etc.
