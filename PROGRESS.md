# Project progress

## Current status

Phases 0–9 are implemented in the Godot project. The project was validated with Godot 4.7.2 and 191 automated assertions passed. No mouse, keyboard, or desktop-control automation was used. Human visual/usability review remains open because the game window was not opened.

## Phase 0 — contract and architecture

- Read the supplied project brief, set a top-down single-tile grid, data-driven recipes, shared storage, deterministic simulation, no transport belts/cables, and statically typed GDScript.
- Recorded the architecture, conventions, decisions, balance, and test plan.

## Phases 1–4 — core, interaction, economy, and power

- Added typed resource/recipe/building/state/command models, strict JSON validation, atomic build/demolish/upgrade/market/sale commands, deterministic fixed-step production, save recovery, and legacy migration.
- Built the 8×8 grid UI with build/inspect, zoom/pan, upgrades, demolition confirmation, market controls, shared storage, autosave, and speed selection.
- Implemented production, processing, market throughput/minimum stock, income, five-level upgrades, three generators, coal fuel, batteries, shared power dispatch, proportional slowdown, power reporting, and a manual shop that sells stored resources without a market.
- Added generated building sprites and subtle idle motion.

## Phase 5 — complete industrial chains

- Expanded the catalog to 18 resources, 18 recipes, and 27 building definitions, including corn, cotton, iron, copper, gas, sand, steel, cement, glass, cable, electronics, food, clothing, gas power, and park.
- Catalog validation checks every recipe input has a producer and every building recipe points to valid resources.
- Inspectors and build tooltips show recipe inputs and outputs.

## Phase 6 — cardinal adjacency

- Added parsed, data-driven neighbor effects; parks grant nearby farm/factory production bonuses.
- Only the four cardinal cells count. The bonus caps at 40%, never recurses, refreshes immediately after build/demolition, highlights affected buildings, and lists affected cells in the inspector.

## Phase 7 — tiers and expansion

- Added Tier 1–3 unlocks through cumulative revenue or production. Cumulative counters persist when money is spent, after load, and through prestige.
- Added paid land expansion from 8×8 to 24×24; current buildings/cells are retained. The progression panel shows requirements and costs.

## Phase 8 — offline and prestige

- Added an eight-hour offline cap, negative-time guard, one-second bounded catch-up using the simulation's input/power/storage/market rules, and a return report. The updated save is written before an offline claim is accepted.
- Added a prestige preview/confirmation and a reset that preserves lifetime progress, prestige points, and sound preference. Each point adds 5% production to a 50% cap.
- Bumped the save format to version 3. Version 1 and 2 saves add missing resource stocks/rules safely and receive a one-time minimum starting balance of `$500`; higher balances and boards remain intact.

## Phase 9 — presentation and release readiness

- Added project-native SVG art for new industrial buildings, a Persian starter guide, recipe-aware tooltips, clear no-stock/auto-sale feedback in the shop, neighbor indicators, a saved sound toggle, and a short generated interface sound.
- The 24×24 grid draws at most 576 cells/buildings in the simple CanvasItem renderer; no external art, audio, add-ons, or runtime packages are required.
- Updated project instructions, balance, testing, credits, and architecture documentation.
- Added a Windows Desktop export preset and attempted a release export. Godot reported that the matching Windows debug/release export templates are missing from this installation, so no executable was produced. No template was installed. The GUI was not opened for visual review per the user's request to keep system control with them.

## Validation

- Godot 4.7.2 headless test runner: **191 assertions passed, 0 failed**.
- Coverage includes legacy migration, manual sales, all tier/expansion paths, cardinal adjacency, power and battery, offline cap/negative time/steady-route parity, prestige reset/bonus, storage, save round-trip, and five-minute deterministic play.
- Interactive mouse/keyboard usability, Persian font rendering, and visual scaling still need a human check in the user's own Godot window.
