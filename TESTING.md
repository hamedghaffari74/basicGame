# Testing and verification

## Environment and exact command

- Godot: `4.7.2.stable.official.ed1daf0bf`.
- Project: the current project directory.
- Headless test scene is run with an absolute scene path in PowerShell, because `res://tests/test_runner.tscn` was ignored by the installed Windows command invocation.

```powershell
$godot = "godot"
& $godot --headless --path (Get-Location).Path --editor --import --quit
$testScene = (Resolve-Path "tests\test_runner.tscn").Path
& $godot --headless --path (Get-Location).Path --scene $testScene --quit-after 900
```

If Godot is not in `PATH`, replace the `$godot` value with the path to the Godot 4.7.2 executable.

## Latest run

- Result: **191 assertions passed; 0 failed**.
- The test scene exited normally. The log included `PASS: 191 assertions` and no script parse/runtime errors.
- A separate editor import/parse pass completed with exit code 0.
- Five-minute economy scenario: sale at 0.1 simulated seconds, first farm upgrade at 94.2 seconds, `$781.8` revenue and 39.9/40 storage at five minutes.
- Manual shop sale works without a market. Empty stock returns a clear failure reason; the UI displays why the shop button is disabled.
- Offline regression covers negative time, eight-hour cap, storage/sales constraints, and exact money/stock parity for a steady farm-and-market route against 0.1-second reference ticks.

## Coverage

The runner exercises data validation, missing input suppliers, duplicate IDs, recipe references, loading all 15 new SVG sprites and generated UI audio, atomic construction failures, demolition refunds, grid coordinate mapping through the 24×24 limit, deterministic steps, shared storage, no same-pass recipe chaining, market minimum stock/throughput, power shortage and fuel depletion, battery charging/discharging/save, v1/v2 migration without repeat grants, manual shop sales, tier unlocks, all 8→12→16→20→24 land expansions with retained buildings, cardinal-only adjacency and refresh after demolition, offline calculation and repeat-claim prevention, prestige reset/bonus, upgrade limits, five-minute progression, and save/continue/backup recovery.

## Unverified by automation

- Persian font rendering, RTL spacing, button overflow, and mouse interaction were not visually inspected. The user asked that system control remain with them, so no GUI automation was used.
- A Windows Desktop export preset was added and the release export was attempted. Godot reported the matching 4.7.2.stable Windows export templates are missing; no executable was produced and no external template was installed.
