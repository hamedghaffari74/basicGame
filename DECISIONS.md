# Decisions

## 2026-11-01 — phase 0

- The starter project is an otherwise empty Godot project. Its project feature marker says `4.7`; the installed executable reports `4.7.2.stable.official.ed1daf0bf`.
- No `AGENTS.md`, existing architecture documentation, test suite, or image reference was found in the project/attachment folder.
- Use a self-contained first playable slice with six building definitions and four resources. No external packages, fonts, or graphics are needed for this slice.
- Keep the initial land at 8×8. Buildings occupy one cell and cannot be moved; demolition refund is shown before confirmation.
- Use continuous fractional inventory values. A recipe's inputs are reserved from stock available at the start of the producer pass; outputs enter storage after all producers are processed. Markets sell after production.
- The shared storage capacity starts at 40 units. Each warehouse adds 30 units. Each unit of every resource uses one storage unit.
- Initial money is 180. Building and upgrade values are data-driven and will be measured against short deterministic scenarios before phase 3 is reported complete.
- Phase 3 intentionally has no electricity. This is shown in the UI and documentation until phase 4.
- Use procedural colored tile/building placeholders, not extracted art. `CREDITS.md` will state that the visuals are original project code and no third-party assets are included.

## 2026-11-01 — phase 4

- Solar output is 1.8 energy units/second and costs $44, allowing a starting $180 town to build a farm, mill, market, and solar plant for $178. Wind produces 3.5 units/second; coal produces up to 5.5 and consumes 0.12 coal per energy unit.
- Quarry and mill demand 2.2 and 1.6 energy units/second. Farms, tree lots, markets, storage, and coal mines do not need electricity, preserving a low-power start and avoiding a fuel-production loop.
- Coal mining was included one phase early because a coal plant needs a player-accessible fuel source to test depletion and sustain production. Coal is not sold automatically by default.
- Electricity dispatch order is fixed: count only producers able to run, take renewable output, burn coal only for remaining demand, discharge batteries only for remaining deficit, and charge from renewable surplus only when demand is fully met. Batteries cannot charge and discharge in one step.
- Save version 2 stores per-battery energy. Version 1 saves remain loadable; new resources default to zero stock and their configured market defaults.
- Building art is generated per building and resized to 128×128 with nearest-neighbor sampling; it is not extracted from the missing reference image.

## 2026-11-01 — phases 5–9

- Raise new-game cash to `$500`. Migrate old version-1/2 saves once to a minimum `$500` only when their current balance is lower, preserving larger balances and all saved buildings.
- Keep supply chains, tier requirements, adjacency effects, expansion steps, and prestige/offline limits data-driven. Production unlocks and cumulative revenue remain permanent through spending and prestige.
- Count only direct cardinal neighbors for parks; cap total adjacency at 40% and do not propagate effects.
- Simulate offline progress through the same production/power/storage/market code in one-second batches, capped at eight hours; save it before showing the return report.
- Use in-project SVG art for new buildings and generated short UI audio with a persistent mute toggle. No third-party dependencies or external asset packs are added.
