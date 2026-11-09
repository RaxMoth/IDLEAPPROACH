# Starting a New Game From This Template

A checklist for turning the template into a real game. Do the first section
right away; the rest when you need it.

## 1. Make it yours (10 minutes)

- [ ] Copy the repository (or "Use this template" on GitHub) and open `project.godot` in Godot 4.7+.
- [ ] **Project Settings → Application → Config:** name, description, version, icon.
- [ ] **`Ressources/game_config.tres`:** `game_title`, store URLs, privacy policy URL.
- [ ] **Project → Export:** set `package/unique_name` (Android) and `bundle_identifier` (iOS),
      e.g. `com.yourstudio.yourgame`. Never change it after publishing.
- [ ] Portrait is the default. For landscape: swap `viewport_width/height`, set
      `display/window/handheld/orientation` to landscape, swap the window override size.
- [ ] Press **F5** and click through once to see everything works.

## 2. Build your first level

1. **Scene → New Inherited Scene** → `Scenes/Game/LevelBase/LevelBase.tscn`.
2. Save it as `Scenes/Levels/Level01/Level01.tscn` (or anywhere under `Scenes/`).
3. Attach a new script to the root that `extends LevelBase`.
4. Put gameplay nodes under **World** (runtime spawns go there automatically).
5. Override the hooks you need:

```gdscript
extends LevelBase

func _on_level_setup() -> void:      # build / connect things (before the intro)
	pass

func _on_level_started() -> void:    # after "Ready? Go!"
	pass

func _level_physics_process(delta: float) -> void:  # only runs while playing
	pass
```

6. Call `add_score(points)`, `win()`, `lose()` (or `end_run()` for endless modes).
7. Create a `LevelData` resource (right-click `Ressources/Levels` → New Resource →
   LevelData), set `id`, `title`, `scene_path`, star thresholds and rewards, and
   add it to `game_config.tres → levels`. It now appears in Level Select with
   stars, best score, unlocking, rewards, analytics and the results screen.

Pause menu, back button, app backgrounding, timer (`time_limit_seconds`),
results popup, rewarded "×2", interstitial pacing and progress saving are
handled by `LevelBase`.

## 3. Remove what you don't need

- Delete any folder in `Scenes/Examples/` and remove its `LevelData` from
  `game_config.tres` (plus its file in `Ressources/Levels/`).
- Remove example upgrades (`survivor_*`, `td_*`, `idle_*`) from the config.
- Stat ids used only by examples live in `Types` (`STAT_TAPS`, …) — keep or delete.
- Run the smoke test afterwards (see README).

## 4. Art, fonts, audio

- **Theme:** `Assets/Themes/main_theme.tres` — colors, corner radius and font sizes
  for every control. Type variations: `TitleLabel`, `HeaderLabel`, `SmallLabel`,
  `BigNumberLabel`, `SecondaryButton`, `SuccessButton`, `DangerButton`,
  `IconButton`, `CardPanel`, `PillPanel`, `TopBarPanel`, `ToastPanel`.
- **Font:** drop a `.ttf` into `Assets/Fonts/` and set it as the theme's default font.
- **Placeholder art:** `PlaceholderShape` / `GridBackground` nodes — replace with
  `Sprite2D` / `AnimatedSprite2D` / `TileMapLayer` when real art arrives. The
  battle's art comes from `Assets/Art/Source/generate_art.py` (see SYSTEMS.md, Art).
- **Icons over words:** show numbers as `IconValue` (icon + value) and stat
  sheets as a `StatGrid`; shared icons live in `GameIcons`.
- **Sounds:** export a `SoundEffect` (takes, volume, pitch spread, minimum
  interval) and play it with `Audio.play_effect_at(sound, global_position)`;
  `Audio.play_music(...)` for music. `Assets/Audio/Source/generate_audio.py`
  shows how the battle's audio was synthesized; the `SfxSynth` presets are just
  stand-ins.
- **Currency icons:** set `icon` on each `CurrencyData` (the glyph is a fallback).

## 5. Economy & meta-progression

All in `game_config.tres`:

| What | Where |
|---|---|
| Currencies + starting amounts | `currencies` |
| Shop upgrades (cost curve, max level, value per level) | `upgrades` (`show_in_shop = false` for in-level upgrades) |
| Level rewards (first clear + every clear) | each `LevelData` |
| Achievements (stat id + target + reward) | `achievements` |
| 7-day login streak | `daily_rewards` |
| Energy / lives | `max_energy` (> 0 enables), `energy_regen_seconds`, `LevelData.energy_cost` |

Read upgrades in gameplay: `Profile.upgrades.get_value(config.find_upgrade(&"my_upgrade"))`.
Track stats for achievements: `Profile.stats.increment(Types.STAT_X)`.

## 6. Monetization & analytics (when you ship)

The game already calls `Ads`, `Store` and `Analytics`. They use mock providers
that simulate ads/purchases (purchases only succeed in debug builds).

1. Install the plugin (e.g. AdMob, GodotGooglePlayBilling, an iOS StoreKit plugin,
   Firebase/GameAnalytics).
2. Subclass the provider in `Scripts/Services/` (`AdsProvider`, `StoreProvider`,
   `AnalyticsProvider`) and implement the virtual methods.
3. Register it at startup, e.g. in `Scenes/Boot/boot.gd`:
   `Ads.set_provider(AdMobProvider.new())`.
4. Product ids in `game_config.tres → products` must match the store consoles.
5. Enable required permissions in the export preset (internet is already on).

## 7. Localization

`Assets/Localization/translations.csv` — English text is the key, add a column per
language and list the locale in `Settings.SUPPORTED_LOCALES`. Godot re-imports the
CSV automatically; UI text set in scenes translates itself, in code use `tr("Text")`.

- Data text (`display_name`, `title`, `description`... in `.tres` files) is stored
  in English and translated where it is shown: `tr(hero.display_name)`, or
  `TranslationServer.translate()` inside Resource scripts (they have no `tr()`).
- Keep each translatable string a whole sentence. Write variants as separate
  keys ("Hits for %sx damage." / "Hits for %sx damage and knocks it back.")
  instead of joining fragments, and never start a key with a space.
- Placeholders are positional (`%s`, `%d`, `%%`): a translation must keep them
  in the same order, so phrase it around that.
- German runs about 30% longer than English: give labels room to wrap
  (`autowrap_mode`) or shorten (`text_overrun_behavior`), and check both
  languages on a 720-wide screen.

## 8. Saving custom data

```gdscript
# Any node or object can persist itself:
SaveManager.register_section(&"my_feature", _to_dict, _from_dict)
SaveManager.request_save()   # after changes (debounced)
```

For player-wide data prefer a new `ProfileModule` (see `Scripts/Profile/`) and add
it in `Globals/profile.gd`. Bump `SaveManager.SAVE_VERSION` and handle the old
layout in `_migrate()` when you change saved data after release.

## 9. Before release

- [ ] Remove or hide cheats you don't want testers to see (the Debug overlay is
      already stripped from release builds).
- [ ] Set `ads_enabled`, product ids and real providers.
- [ ] App icons in the export presets; splash color in Project Settings.
- [ ] Test on a low-end Android device with **Battery Saver** both on and off.
- [ ] Run the smoke test.
