@Docs/instructor.md

## Working in this repo

- API overview: `Docs/SYSTEMS.md`. Starting a new game: `Docs/GETTING_STARTED.md`.
- Validate changes with the smoke test (exit code 0 = pass):
  `godot --headless --fixed-fps 60 res://Tests/SmokeTest.tscn`
- Tests never touch the player's save: scenes under `res://Tests/` use
  `user://test_savegame.json` / `test_settings.cfg`. Put probe scenes in
  `Tests/` so they get this too.
- Every test run is muted. `--headless` already uses the silent audio driver.
  Windowed runs (screenshots, probe scenes) must pass `--audio-driver Dummy`,
  and test scenes mute the Master bus in `_ready()`.
- When writing `.tscn` files by hand, exported Node references (e.g.
  `health_component = NodePath("../HealthComponent")`) must be listed in the
  node header as `node_paths=PackedStringArray("health_component")`, otherwise
  Godot silently leaves them null.
