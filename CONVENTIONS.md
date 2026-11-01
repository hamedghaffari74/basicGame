# Conventions

- Use typed GDScript declarations for fields, parameters, and return values.
- Keep simulation code deterministic and independent of rendering, input, SceneTree, files, and system time.
- Use stable snake_case IDs in data; user-facing Persian labels stay separate from IDs.
- Validate external JSON at the loading boundary and report file, ID, and field where possible.
- Keep each building on one integer grid cell. Neighboring cells use the four cardinal directions only.
- Route state changes through `GameCommand`; failed commands must not change money, inventory, buildings, or rules.
- Keep production values in units per simulation second, use the fixed 0.1-second step, and compare floating-point amounts with the documented tolerance.
- Keep power output, demand, fuel use, and battery energy in the same simulation units. Estimate active demand deterministically before dispatch; use one shared ratio for powered producers and persist battery energy.
- Prefer short, direct scripts and built-in Godot APIs. Do not add plug-ins or runtime dependencies.
- Update `PROGRESS.md`, `TESTING.md`, and `BALANCE.md` with implementation and actual validation results.
