@Docs/instructor.md

## Working in this repo

- API overview: `Docs/SYSTEMS.md`. Starting a new game: `Docs/GETTING_STARTED.md`.
- Validate changes with the smoke test (exit code 0 = pass):
  `godot --headless --fixed-fps 60 res://Tests/SmokeTest.tscn`
- When writing `.tscn` files by hand, exported Node references (e.g.
  `health_component = NodePath("../HealthComponent")`) must be listed in the
  node header as `node_paths=PackedStringArray("health_component")`, otherwise
  Godot silently leaves them null.
