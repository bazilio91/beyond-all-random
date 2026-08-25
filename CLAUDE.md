# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Beyond All Random (BaR)** — a Lua mod suite for Beyond All Reason, a Spring RTS Engine game. Based on AMBO & MGGW's Random Rarities mod. Adds a random rarity system to units with faction-balanced guarantees, a viewer widget, and a balance patch. Files are pure Lua loaded directly by the Spring engine.

## Build & Serialize

**Build via Docker.** The sanctioned pipeline is `make docker`, which uses `Dockerfile.build` (a `node:20-alpine` image with `luamin` baked in) to produce every `.b64`. Do **not** install `luamin` locally on dev machines — if Docker Desktop isn't running, surface that as a blocker rather than falling back to local tooling.

```bash
make docker   # Docker build: minifies mod.lua + mod_part2.lua + mod_tiers.lua → .b64 files
make test     # offline smoke test: runs every slot against a synthetic UnitDefs table
make segments # regenerates docs/js/*-template.js from the .lua sources (auto-runs on pre-commit)
make setup    # installs pre-commit hook (run once after cloning)
make clean    # removes .b64 files
```

(A plain `make` target also exists for CI runners that already have `luamin` installed, but local development should always use `make docker`.)

Each encoded output must stay under **16,384 chars** (BAR lobby slot limit). Apply in-game with:
```
!bset tweakdefs  <contents of mod.b64>
!bset tweakdefs1 <contents of mod_part2.b64>
!bset tweakdefs2 <contents of faction_buff.b64>
!bset tweakdefs3 <contents of mod_tiers.b64>
```

Slots execute in index order inside one Lua state, so a later file can read what
an earlier one wrote (`customparams.rarity`, `_G.BAR_RENAME_BLOCKS`).

`serialize.sh` handles the pipeline: extracts leading `--` comment headers, minifies via `luamin`, prepends headers, base64-encodes, and validates the output is under 16,384 chars.

## Architecture

The mod is split into three tweakdefs files, each loaded into a separate BAR lobby slot:

### mod.lua — Combat units & armed buildings (tweakdefs)

Handles units with `speed` or `weapondefs` or `builder == true`. Passive buildings are skipped (handled by mod_part2.lua).

**Pass 1a — Guaranteed spicy units:** `factory_units` is derived at load from the
live build tree — every static builder's `buildoptions`, keeping the entries that
are mobile, armed and not builders. For each such factory it picks a random unit
and rolls rarity with floor 7 (Mythical), tracking picks in `guaranteed` to avoid
duplicates. It replaced a hand-kept table of 33 groups; the derivation finds
**66** factories in a full game, because the curated list never covered the
underwater, hover, amphib and T3 labs. Echoed as `[BaRandom] factories: N`.
Twice as many guaranteed Mythical+ picks — turn `MIN_FACTORY_RARITY` down if that
is too much.

**Pass 1b — Remaining combat units:** All non-guaranteed units get a `get_rarity()` roll (75% chance to escalate per tier, 28 tiers). 20% curse chance for combat units.

**Pass 2a — Archetypes:** Armed units at rarity 5+ get one of 4 mobile archetypes (Glass Cannon, Tank, Sniper, Brawler) or 3 turret archetypes (Fortress, Watchtower, Suppressor).

**Pass 2b — Traits:** Archetype-specific traits at rarity 5+ with 50% chance. Each archetype has its own trait pool (3 traits each).

**Pass 3 — Stat scaling:** Applies exponential scaling via `set_v()` formula. Split into helper functions: `apply_curse_scaling`, `apply_unit_scaling`, `apply_weapon_scaling`, `apply_traits`, `build_rename`. Commander rarity capped at 6.

**Dead tags removed:** `windgenerator`, `tidalgenerator`, `energyconv_*` and
`energymultiplier` never appear on a unit in this file's scope (mobile / armed /
builder), so those scalings were dropped. `idleautoheal` is unset on *every* def
at tweakdef time — `alldefs_post.lua` fills in 5 hp/s afterwards, but only when
nil — which also meant the Tank pool's **Regenerator** trait silently did
nothing; it now writes `(idleautoheal or 5) * mult` instead of multiplying nil.
The same audit removed `workertime`, `builddistance` and `shield_*` scaling from
mod_part2.lua, where no passive building carries them. Every weapondef tag
the weapon pass touches is live (rarest: `sweepfire` on 5 weapons).

**Beam weapon handling:** Continuous beams detected when `beamtime/reloadtime >= BEAM_CONT_THRESHOLD` (0.90) — reloadtime is reset to beamtime after scaling. Sweepfire weapons let normal scaling handle both damage and reload.

### mod_part2.lua — Part 2: passive buildings + veterancy schools (tweakdefs1)

Not "the buildings mod" any more — it is simply the second half of the suite, and
anything that does not fit in mod.lua's 16 KB slot goes here. It was
`mod_buildings.lua`, and `mod_xp.lua` (tweakdefs4) was folded into it.

Handles buildings with no `speed`, no `weapondefs`, and `builder ~= true`. Has its own copy of shared helpers and independent rarity rolls.

**Category detection:** Buildings are classified by UnitDef fields into mex,
converter, windtidal, jammer, radar, sonar, energy, storage or generic — in that
order. Each category owns a trait pool, so the order matters:

- `energy` is tested **before** `storage`: fusions, AFUS and geos carry
  2.5k–90k `energystorage` and would otherwise be filed as storage buildings.
- Energy output lives in `energymake` **or** in a negative `energyupkeep` —
  solars have no `energymake` at all and generate through `energyupkeep = -20`
  (legmex does the same on top of its extraction). `energy_out(ud)` returns
  whichever field applies; the archetype's upkeep multiplier is skipped for the
  negative-upkeep ones so it cannot flip into an output multiplier.
- The factory test is `next(ud.buildoptions) ~= nil`, not plain truthiness: BAR
  normalises `buildoptions` to an **empty table** before tweakdefs run
  (`normalizeUnitDef` in `gamedata/unitdefs_post.lua`), so a bare `if
  ud.buildoptions` filed every passive building as a factory.
- There are no `factory` / `nano` trait pools: every lab and nano turret sets
  `builder = true`, so `is_passive()` hands them to mod.lua and those pools could
  never fire here.

The file echoes its histogram once per load
(`[BaRandom Part 2] categories: converter=15 energy=35 generic=29 …`) — a
misclassification shows up there instead of as traits that quietly stop firing.

**Building archetypes (3):** Efficient (cheap, moderate output), Fortified (tanky), Overclocked (fragile, high output, high upkeep). Assigned at rarity 5+.

**Evolution pairs (Metamorphic):** `unit_evolution.lua` re-creates the unit at
the same position, so a target with a different footprint overlaps its
neighbours — and when the parity changes (5x5 → 4x4) the rebuilt structure lands
off the build grid. `EVO_MEX` / `EVO_ENERGY` are therefore pruned once at load by
`same_footprint()`, which also drops pairs whose target is not in this game
(Legion disabled, trimmed unit list). The surviving list is echoed as
`[BaRandom Part 2] evo: armmex>armmoho …`. `armsolar`/`corsolar` → advsol is
exactly the mismatching case and gets dropped; the geo → advanced geo pairs are
in the table because they keep 5x5 and the vent is already under the building.
The Ascendant school in the second half of this file applies the same rule to
static units.

**Building traits (25 across 10 categories):** Category-specific traits including stat multipliers, death AoE explosions (`area_ondeath_*` customparams), unit evolution (`evolution_target/condition/timer`), jamming capability, and EMP resistance (`paralyzemultiplier`).

### mod_tiers.lua — Random tech tier cap (tweakdefs3)

Rolls `TIER = math.random(1, 3)` at load and filters the buildable roster so only rolled-tier combat/labs/defense units appear. Eco + utility (mex, solar, wind/tidal, fusion, afus, geo, converter, storage, radar, sonar, jammer, nano turret, commander) stay all-tier.

**Sparse `buildoptions`.** 20 defs ship a build list with holes in it — all
three commanders and every evocom level are missing `[19]`, `armhacs` is missing
five indices, `cormandot4` is missing `[1]`. BAR does not repack them before
tweakdefs run (`normalizeUnitDef` only `ensureTable`s), so `ipairs` stops at the
first hole and everything behind it is dropped. On a commander that is the
entire naval half of the list — shipyard, torpedo launcher, floating
constructors, hover and seaplane platforms — gone on *every* roll, T1 included.
`bo_list()` walks the integer keys instead and every loop in the file goes
through it.

**Classification:** every `UnitDef` is tagged on two axes — `tier` (1/2/3/"all")
and `gate` (combat/lab/defense/eco/utility). Tier comes from
`customparams.techlevel`, floored and clamped into 1..3: the hover / amphib /
seaplane platforms are `1.5` and the scav bosses are `4`, and a bare `== TIER`
test locks anything else out of all three rolls. Gate is derived from UnitDef
fields, and **the order of the tests is the whole game**:

- **mobile before eco** — every construction unit trickles energy (`armck`
  `energymake = 7`, `armack` 14), so an eco-first test files all of them as eco
  and the tier lock never touches a con.
- **buildoptions before builder** — every lab sets `builder = true`, so a plain
  `builder and not speed` test (meant for nano turrets) swallows all 66
  factories and the `lab` gate never fires at all. That took the commander
  override, the T3 escape hatch and the cost flattening down with it: all three
  read `unit_gate == "lab"`.
- **armed before eco and radar** — `armanni` carries `energystorage = 1000` and
  `radardistance = 1500`, `corbhmth`/`cordoom`/the shields the same, so an
  eco-first test exempts the heavy defences from the filter.

The `lab=` entry in the gate histogram is the canary: if it is missing, the
factory half of the file is inert.

**Commander overrides:** when T2/T3 rolls, commanders get the rolled-tier labs appended to `buildoptions` (they can't normally build T2/T3 labs directly) and T1 construction units stripped. Commanders are found by `customparams.iscommander`, which covers all 38 variants (starters, con-coms, Legion loadouts, the nine evocom levels) rather than the three starter names. Only labs that appear in *someone's* build list are appended, which keeps scav-only factories (`armapt3`) out of the player's hands.

**T3 meme-mode escape hatches:** T3 gantries get T2 construction units appended; T2 cons keep eco+utility options but lose combat/labs (so the economy is still reachable). Note there are **no player T3 defences** — the only four static armed defs at techlevel 3 are scav content — so a T3 roll is a game with no turrets at all.

**Per-category cost flattening:** surviving T2/T3 labs have their `metalcost`, `energycost`, and `buildtime` overwritten by the T1 equivalent in the same faction and category (`armalab` ← `armlab`, `armavp` ← `armvp`, etc.). T3 gantries flatten to the faction's T1 bot lab. Mapping lives in the `COST_MAP` table.

**Diagnostics:** echoes the gate histogram (`combat=375 defense=130 eco=90
lab=66 utility=295`) plus one line listing the statics that matched no gate
(walls, targeting facilities, cosmetics) and were therefore kept all-tier.
Mobile units that are neither armed nor builders — transports, drones,
lootboxes — are deliberately all-tier and are not reported.

**Integration:** orthogonal to the rarity system — never touches stats, weapondefs, or customparams the rarity system owns. Emits `Spring.Echo("[BaRandom Tiers] T" .. TIER)` for the viewer widget to surface.

#### Veterancy schools (second half of the file)

Turns BAR's XP curve into a rollable trait. The curve itself is global
(`gamedata/modrules.lua`: `experienceMult 0.3`, `healthScale 2.5`,
`reloadScale 1.25`), and the only per-unit knob a tweakdef owns is the `power`
tag — `xp gain = 0.1 * experienceMult * target_power / attacker_power` — so
`power` is the XP dial. BAR uses the same trick for evocom
(`alldefs_post.lua`: `uDef.power = uDef.power / evocomxpmultiplier`).

Merged in from `mod_xp.lua`, which used to occupy tweakdefs4.
It runs at the end of that file, so `customparams.rarity` is already set — by
mod.lua for combat units and by the first half of this file for buildings. With
no rarity slot loaded (`_G.BAR_RENAME_BLOCKS == 0`) it falls back to
`FALLBACK_RARITY` and still works.

**Independent parameters.** The building knobs (`rarity_chance`, `TRAIT_CHANCE`,
`TRAIT_MIN_RARITY`, per-faction floors/ceilings) and the XP knobs (`XP_CHANCE`,
`XP_MIN_RARITY`, `MENTOR_CHANCE`) are separate consecutive locals at the top of
the file — minified to `local b..f` and `local g..i` — so
`scripts/generate_part2_segments.js` slices both groups into
`docs/js/part2-template.js` and either side can be set without touching the
other. Anything added to the file must go **after** those locals or the segment
anchors shift.

**Runs before mod_tiers.lua now** (slot 1 vs slot 3), which has two consequences
the standalone version never hit:

- Raw `buildoptions` are **sparse** — 14 defs (all three commanders, `leghack`,
  …) have holes, and mod_tiers.lua is what repacks them. Indexing `bo[i]`
  blindly throws "table index is nil" and BAR's `pcall` swallows the whole
  tweakdef, so the slot silently does nothing. Both loops guard for it.
- Sibling lists are unfiltered, so an ascension could hand the player a unit the
  rolled tier is meant to lock away. `pick_target` therefore requires the target
  to share the source's `customparams.techlevel`.

**`power` is owned by this file.** mod.lua and mod_part2.lua deliberately do
*not* scale it: `power` is the divisor of the XP formula, so scaling it by rarity
turned every rare unit into a slower learner for no stated reason (and inflated
the team power sums that evocom thresholds and territorial domination read).
Both files leave it at its base value and the schools below are the only thing
that moves it.

**Schools (armed non-builders, rarity 4+, `XP_CHANCE`):**

| School | `power` | Effect |
| --- | --- | --- |
| Prodigy | ×0.08 | learns ~12× faster, HP ×0.92 |
| Bloodthirsty | ×0.20 | HP ×0.85, damage ×1.06 — snowballs on kills |
| Ascendant | ×0.15 | evolves into a costlier sibling at an XP threshold |
| Trophy | ×8 | never vets, feeds the killer XP; HP ×1.35, damage ×1.10 |
| Conscript | ×3 | cheap fodder, cost ×0.85 |

**Ascendant** sets `evolution_condition = "xp"` + `evolution_xp_threshold` for
BAR's `unit_evolution` gadget. The target is picked from the unit's *siblings* —
the other entries of the build list it came off, held by reference in `from_lab`
and read live, so it respects mod_tiers.lua's roster filter: same mobility class,
armed, non-builder, same footprint when static, costing at least
`ASCEND_MIN_COST`× more. The threshold scales with metal cost
(`ASCEND_XP_BASE + metalcost * ASCEND_XP_PER_METAL`) so cheap units promote fast
and a carried-over XP pool cannot chain-evolve a unit twice in one second. When
no target qualifies the roll falls back to Prodigy.

**Mentor (builders/labs, `MENTOR_CHANCE`):** sets `inheritxpratemultiplier`,
`inheritcreationxpmultiplier`, `childreninheritxp`, `parentsinheritxp` for BAR's
`unit_inherit_creation_xp` gadget — the lab banks the XP of everything it built
and stamps half of it onto the next unit off the line. Units that already ship an
XP-sharing setup (drone carriers, botcannons, evocom levels) are left alone, as
are units that already have an `evolution_target`.

Renames stack as a second bracket (`[Mythical Sniper] [+Prodigy] Sharpshooter`).
The viewer widget merges any `[+...]` prefix onto the rarity one instead of
overwriting it.

### PvE exclusion (`SKIP_PVE`)

mod.lua, mod_part2.lua and mod_tiers.lua all share an `is_pve()`
guard that skips units whose name contains `raptor`, `scav` or `critter`. Flip
`SKIP_PVE = false` at the top of a file to randomise them again.

Covered: every raptor def (`raptor_*`, loaded only in Raptor games), the
scav-named statics (`scavbeacon_*`, `corscav*`, `scavengerboss*`) and critters.
**Not** covered: the `<unit>_scav` mirrors — BAR generates those in
`createScavengerUnitDefs()` *after* tweakdefs run
(`gamedata/unitdefs_post.lua`), so they always inherit whatever their base unit
rolled. Neither are the ~70 scav-only units that carry ordinary names
(`armpwt4`, `cordoomt3`, `armwint2`, …); nothing in their UnitDef marks them as
scavenger content.

**Why it lives in its own slot.** Measured (minified → base64):

| variant | b64 | |
| --- | --- | --- |
| mod.lua as shipped | 13 419 | 2 965 free |
| mod.lua + XP hand-integrated into Pass 3 | 16 804 | over by 420 |
| mod_part2.lua = buildings + XP (shipped) | 14 351 | 2 033 free |

XP does not fit in mod.lua: deriving `factory_units` and removing the dead
scalings brought the gap down from 3 436 to 420 chars, but closing it means
dropping the `desc_prefix` tooltips that explain what each school does, and it
would leave that slot with no headroom at all. It lives in mod_part2.lua
instead, which keeps the lobby down to three `!bset` lines.

### Testing

`make test` (or `lua5.1 scripts/smoke_test.lua [defs_dir] [seed]`) runs all three
slots in load order against a synthetic `UnitDefs` table covering lab / con / bot
/ turret / mex / solar / radar / commander / raptor / scav / critter, with engine
stubs for `Spring.Echo` and `VFS`. It fails on any Lua error and checks the
invariants: PvE units untouched and unrenamed, two rename blocks with the
counter ending at 2, every ascension target resolvable, no pre-existing evolution
or XP-inheritance config overwritten, mod_part2.lua's category histogram
matching an independent classifier in the test, every building trait belonging to
its category's pool, energy output never shrinking, no eco building landing in
mod_tiers.lua's unclassified list, and every evolution target resolving without
changing the footprint of a static unit or its tech level.

The tier lock gets its own accounting pass: every original build option is
walked by index and has to be accounted for — a tier-gated one survives only at
the rolled tier (or as the T3 con hatch), everything else survives
unconditionally. That is what catches a truncated list, an ungated gate and a
misfiled unit in one check. The synthetic defs are shaped to trip all three:
`armcom` has a hole at `[3]` with eco and radar entries behind it, `armck`
carries `energymake`, and `armanni` carries the battery and radar that used to
buy a T2 turret its way out of the filter. On a T2/T3 roll the commander must
also have traded its T1 lab for the rolled tier's.

Pass a directory of real BAR `return { name = {...} }` unit files as the first
argument to run at full scale (`git -C Beyond-All-Reason archive HEAD units/ |
tar -x -C /tmp/u`; the loader reads one flat directory, so flatten the tree
first).

### docs/ — the web builder (GitHub Pages)

Single page, no build step, no framework. `index.html` loads five plain scripts
in order: `pipeline.js` (base64), the three payload templates, `docs-content.js`
(reference copy + trait data) and `app.js` (the whole UI).

The layout is a port of the design system's redesigned builder
(claude.ai design project → `ui_kits/web_builder/redesign.html`, a React
prototype). The prototype is the source of truth for *visuals*; the port is
vanilla DOM. Design tokens live in `css/tokens.css`, copied verbatim from that
project's `tokens/*.css` — edit them there first so the two stay in sync.
`css/app.css` holds the component styles, every value referencing a token.

Structure: tool first (mode tabs → step cards → output blocks), reference
collapsed underneath, sticky rail on the right carrying the expected roll
spread, the generate button, the per-slot character budget and the paste order.

**Expected roll spread.** The rail's bar is not a decoration: it models what
mod.lua actually does to a *combat unit*, and every knob that moves the outcome
moves the bar.

- `get_rarity()` escalates one tier with probability `rc`, so a raw roll is
  geometric — `P(T >= n) = rc^n`, capped at tier 28.
- Pass 1a rolls one unit per factory through `get_rarity_min(m)`, which starts
  the escalation at `m = max(MIN_FACTORY_RARITY, that faction's floor)`. Those
  units are written to `unit_rarities` before pass 1b runs, so they are **never
  cursed** — which is why raising the min factory rarity visibly drags the whole
  distribution up.
- Pass 1b rolls everything else, checking the curse first.
- Both passes clamp into the faction's `[floor, ceiling]`, so the clamp card
  reshapes the bar too. The three factions are averaged at 1/3 each.
- The guaranteed slice is `66 / 287` — factories with a combat option against
  mobile armed non-builders, measured on the live BAR unit list.

`scripts/spread_check.js` Monte-Carlos the same thing straight from the Lua
logic; the rendered legend matches it within a percentage point across presets,
min-factory sweeps and asymmetric clamps.

**No generate step.** A payload is a string concat plus a `btoa` of ~10 KB, so
every control rebuilds it directly (debounced 120 ms) and the output blocks and
the character budget are always in sync with the knobs. The output cards keep
their identity across rebuilds — only values and counters are rewritten — so a
slider drag never flickers or moves the scroll position.

**how-it-works.html** is the FAQ page: `<details>` blocks styled from the same
tokens, no JavaScript at all. It carries the long-form explanations (rolling,
guaranteed picks, archetypes, curses, schools, tier lock, slot split, widget,
sync, PvE rosters) so the builder itself stays a tool.

**Welcome message.** Generated from the current settings rather than a fixed
blurb: it quotes the escalation chance, the guaranteed factory tier, the curse
and trait chances with their tier names, the veterancy chance, and — behind two
checkboxes — the faction buff and the tier lock. Sections whose chance is 0 drop
out of the sentence entirely.

**Parameters.** The "Rarity mod" tab drives both payload slots from one set of
knobs, as the prototype does. Part 2's own knobs — its rarity/trait chances, its
faction clamps and the three XP-school knobs — live in an "Advanced — Part 2"
collapsible. Its *Mirror* checkbox (on by default) feeds the shared roll settings
and clamps into Part 2; unticking it reveals Part 2's own controls, which default
to that template's own defaults (floor 5, not 0).

### Tweakdefs Bridge protocol (external widget)

In-game renaming is done by **Tweakdefs Bridge**, Ambo's widget (not ours). We ship a copy in `docs/widgets/Tweakdefs_bridge.lua` + `widget_tweakdefs_bridge.lua`; the upstream source is Ambo's thread on the BAR Discord (`#📝｜widgets` → Tweakdefs Renamer, https://discord.com/channels/549281623154229250/1468742915315470591). **v6 (`date = '2026-05-17'`) is the minimum.**

Each mod file prints one rename block to infolog:

```
tweakdefs_rename_get_ready
/(<unitDefName>/-<command>/-<text>/)      -- command: rename | prefix | desc_change | desc_prefix
tweakdefs_rename_end
tweakdefs_rename_block_count:<N>
```

v6 takes the **last** `block_count` line as an anchor and reads the last N complete blocks; if the anchor falls outside that group's scope (`GROUP_WINDOW_BYTES = 500000`) it falls back to a single block. Since the mod is split across two tweakdefs slots, omitting the count made the widget drop half the prefixes.

`mod.lua` and `mod_part2.lua` therefore keep a running counter in `_G.BAR_RENAME_BLOCKS` and re-print the total after their own block. All `tweakdefs*` slots execute via one `loadstring` in a shared Lua state (`Beyond-All-Reason/gamedata/unitdefs_post.lua`), sorted by slot index, so the last block to run prints the correct total — and a solo load still reports `1`. Any new file that emits renames must join the same counter.

### Other files

- **widget_random_stats_viewer.lua** — In-game UI widget. Parses `infolog.txt` to read rarity assignments, displays units organized by faction with color-coded rarity, stats, and factory build trees. Toggle with `/unitstats`. Does its own infolog parsing and does not depend on the bridge. **Not published on the site** — it is no longer copied into `docs/widgets/` and `make widgets` only syncs the bridge; the file lives in the repo root (gitignored with the other `widget_*.lua`).

- **disable_t3_air.lua** — Makes T3 air units prohibitively expensive.

- **factory_tree.lua** — Auto-generated from BAR game data. Maps faction → factory → combat unit names. Regenerate with `python3 build_factory_tree.py`.

- **Beyond-All-Reason/** — Shallow clone of the BAR game repo, used by `build_factory_tree.py` to extract unit definitions.

- **Dockerfile.build** — Docker-based build with Node.js + luamin. Used by `make docker`.

**Data flow:** `mod.lua` + `mod_part2.lua` + `mod_tiers.lua` modify UnitDefs and log to infolog → `random_stats_viewer.lua` parses infolog and renders UI.

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
- The workflow updates version strings in `mod.lua` line 1, `mod_part2.lua` line 1, and `docs/js/rarity-template.js` header, commits with `[skip ci]`, tags, and creates a GitHub Release
- Release notes are generated by `git-cliff` from commit history between tags
- The GH Pages site fetches the latest version from the GitHub API at page load

## Spring Engine API Surface

- `UnitDefs` / `WeaponDefs` — global tables for unit and weapon definitions
- `Spring.Echo()` — logging to infolog.txt
- `VFS.LoadFile()` — reading files (e.g., infolog.txt)
- `gl.*` functions — OpenGL rendering (Color, Rect, Text, etc.)
- Widget callbacks: `widget:Initialize()`, `widget:DrawScreen()`, `widget:MousePress()`, `widget:MouseWheel()`, etc.
