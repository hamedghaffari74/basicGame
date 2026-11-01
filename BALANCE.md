# Economy and progression balance

All prices and rates are data-driven in `data/*.json`.

## Starting economy and sales

- New games start with `$500`, an 8×8 plot, 40 shared storage units, and no buildings.
- A first powered wheat-to-flour chain costs `$178` (farm `$42`, mill `$58`, market `$34`, solar plant `$44`). A manual shop costs `$48`.
- The market sells enabled resources through a shared throughput of 0.55 units/second per level-one market and honors each resource's minimum stock. The shop sells one selected resource's full inventory at its configured unit price, with no market or throughput requirement.
- Default wheat sales are enabled. Fuel and industrial inputs that are costly to replace default to off where needed.
- Most buildings use an 8.5× level-one upgrade multiplier; the starter farm uses 13.5× to keep the first upgrade near the two-minute target with the increased starting cash. Rate increases by 30% per level above level one. Demolition refunds 50% of original construction cost.

## Production chains

The catalog contains 18 resources and 18 recipes. Every recipe input has a producer validated at load time. It includes wheat→flour, iron+coal→steel, stone+coal→cement, sand+coal→glass, copper→cable, cable+glass+steel→electronics, wheat+corn→food, and cotton→clothing. Gas extraction feeds the gas power plant. The industrial recipes and their producers are Tier 2 or 3 where specified in `data/buildings.json`.

## Power, adjacency, and land

- Solar produces 1.8 power/second, wind 3.5, coal 5.5 using 0.12 coal per delivered energy, and gas 4.5 using 0.09 gas per energy.
- The mill uses 1.6 power/second; the stone quarry uses 2.2. Battery capacity is 18 energy with 1.2 energy/second charge and discharge at level one.
- Park effects apply only to cardinal neighbors, add 12% per matching park, cap at 40%, and do not propagate through another building. The grid highlights buildings receiving a bonus, and the inspector shows both source and affected neighbor cells.
- Tier 2 opens at `$450` cumulative revenue or 150 cumulative produced units; Tier 3 opens at `$2,500` or 900 produced units. Revenue and production counters persist through spending and prestige.
- Land expansions are 8→12 (`$180`, no revenue requirement), 12→16 (`$450`, `$450` cumulative revenue), 16→20 (`$1,000`, `$1,200` cumulative revenue), and 20→24 (`$2,200`, `$3,000` cumulative revenue). Existing buildings retain their cells.

## Offline and prestige

- Offline time is clamped to 0–8 hours. It advances through the same simulation and storage/power/input/market checks in one-second steps to keep catch-up bounded. The save is committed before the offline result is applied, preventing repeat claims after reload. Negative clock differences give no reward.
- The farm-and-market 30-second offline route matches the 0.1-second reference ticks for money and stock in the regression suite. Long offline runs use coarser one-second steps and can differ slightly around short production-chain delays.
- Prestige begins at `$10,000` cumulative revenue; the next milestone rises by `$10,000` after each prestige. Prestige resets current cash, inventory, buildings, land, and run time while preserving lifetime revenue, lifetime production, sound preference, and prestige points/count.
- Each prestige point adds 5% production, up to a 50% cap. It does not change unlock requirements or construction costs.

## Deterministic measurements

Godot 4.7.2 fixed-step regression scenario with farm, mill, market, and solar:

- First market sale: 0.1 simulated seconds.
- First farm upgrade: 94.2 simulated seconds.
- After five simulated minutes: `$781.8` cumulative revenue, 39.9/40 storage, and farm at level 2.
- Over 60 seconds, raw wheat earned `$79.2`; processing it to flour earned `$148.3`.
- A single level-one market sold at most 0.55 units/second; two sold at most 1.1 without selling the same unit twice.

These are automated simulation results, not measurements from a human play session.
