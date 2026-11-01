# Industrial Frontier architecture

## Runtime and boundaries

- Engine: Godot 4.7.2; statically typed GDScript; 2D CanvasItem drawing and built-in UI controls.
- `GameCatalog` loads and validates resource, recipe, building, and balance JSON.
- `Simulation` and `GameState` contain deterministic economy rules. They do not read the UI, files, input, or wall clock.
- The presentation layer submits typed `GameCommand` objects and reads snapshots. It owns the fixed-step accumulator, animation, and autosave scheduling.
- `SaveService` owns persistence, backup rotation, legacy migration, and bounded offline advancement.
- No third-party add-ons, runtime dependencies, or physical transport networks are used.

```text
JSON definitions → GameCatalog → Simulation ← GameCommand
                                  ↓
                               GameState → SaveService
                                  ↓
                              UI snapshot
```

## Simulation order

1. Apply queued commands in order, even while simulation time is paused.
2. Estimate production and powered producer demand using current cardinal neighbors and permanent prestige bonus.
3. Dispatch renewable power, fuel generators, then battery discharge; charge batteries only from surplus after current demand is covered.
4. Process producers by stable building ID. Inputs are taken from available stock; new outputs are deferred until the producer pass ends.
5. Enforce shared inventory capacity during production; then apply market throughput and minimum-stock rules.
7. Publish a snapshot containing inventory, power, recipe inputs/outputs, progression, adjacency sources, and building statuses.

The live game uses a fixed 0.1-second simulation step. Catch-up work per rendered frame is bounded. Offline catch-up runs at one-second steps for no more than eight hours and writes the resulting state before displaying the reward report.

## Current game data

- Starting land is 8×8 and expands through 12, 16, 20, and 24. Every building occupies one cell.
- The catalog contains 18 resources, 18 recipes, and 27 buildings. Recipe inputs are validated against producer outputs, and recipe cycles are rejected.
- The market sells enabled goods through shared throughput; the shop provides manual all-stock sales at the configured resource price.
- The power grid is global. There are no cables, belts, or local power regions.
- Tier and expansion thresholds read cumulative revenue/production, so spending cannot undo an unlock. Prestige preserves cumulative counters and prestige points while resetting the current city.

## Persistence

Save format version 3 stores money, land, inventory, market rules, buildings/cells/levels, battery energy, simulation time, cumulative revenue/production, prestige, sound preference, and a wall-clock save timestamp. Version 1 and 2 saves are migrated by adding missing resource stock and market rules with safe defaults. A legacy balance below the new `$500` start is raised once; higher balances and existing layouts are preserved. Saves use a temporary file, rotate a backup, and recover from a damaged primary file when possible.
