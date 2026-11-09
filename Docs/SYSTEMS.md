# Systems Reference

Quick API reference. Every script also has a header comment with usage.

## Autoloads (`Globals/`)

Load order matters and is set in Project Settings → Autoload:
`Types → Global → Events → Platform → Settings → SaveManager → Profile → Audio → Pools → Analytics → Ads → Store → UI → SceneManager → Debug`.

### Types
Constants only: `Types.LAYER_*` (physics bits), `GROUP_*`, `ACTION_*`,
`CURRENCY_*`, `STAT_*`, `ENTITY_STAT_*`, `EVENT_*` (StateChart events),
`METHOD_*` (optional duck-typed hooks) and enums (`DamageType`,
`TargetPriority`, `HapticStrength`, `ProductType`, `SwipeDirection`, `LevelOutcome`).

### Global
```gdscript
Global.find_nearest_in_group(Types.GROUP_ENEMY, global_position, 400.0)
Global.get_group_nodes_in_radius(Types.GROUP_ENEMY, center, radius)
Global.find_component(enemy, HealthComponent) as HealthComponent
Global.get_world_root()                 # where runtime spawns go
Global.screen_to_world(self, touch_position)
await Global.wait(0.5)                  # pausable delay
```

### Events
Global signals; emit or connect from anywhere:
`app_paused`, `app_resumed`, `back_requested`, `safe_area_changed`,
`scene_changed`, `level_started`, `level_finished(result)`, `score_changed`,
`currency_changed`, `item_changed`, `upgrade_purchased`, `stat_changed`,
`achievement_unlocked`, `daily_reward_claimed`, `energy_changed`,
`camera_shake_requested(trauma)`, `pickup_collected`, `enemy_defeated`,
`idle_currency_changed`, `stage_changed`, `hero_leveled`, `hero_shards_changed`,
`hero_star_changed`, `income_source_leveled`, `rebirth_completed`,
`setting_changed`, `rewarded_ad_finished`, `purchase_completed`, `purchase_failed`.

### Platform
```gdscript
Platform.is_mobile() / is_android() / is_ios() / is_web()
Platform.vibrate(Types.HapticStrength.MEDIUM)   # respects the setting
Platform.safe_margins                           # notch insets in viewport px
Platform.open_store_page()
```

### Settings
```gdscript
Settings.get_bool(Settings.KEY_HAPTICS_ENABLED)
Settings.set_value(Settings.KEY_MUSIC_VOLUME, 0.5)   # applies + saves + emits
```
Add a setting: a `KEY_` constant + an entry in `DEFAULTS` (+ a case in `_apply` if it changes the engine).

### SaveManager
```gdscript
SaveManager.register_section(&"key", to_dict_callable, from_dict_callable)
SaveManager.request_save()   # saves ≤ 1 s after the first unsaved change
SaveManager.save_now()       # also runs automatically on app pause / quit
```

Test scenes use their own files, so a test never touches the player's
progress or preferences.
- **Which scenes:** anything under `res://Tests/` (smoke test, screenshot tool,
  probes), detected by `Global.is_test_run()`.
- **Which files:** `user://test_savegame.json` and `user://test_settings.cfg`,
  resolved by `Global.resolve_user_path()`.
- **Where to check:** `SaveManager.save_path` is the file in use.

### Profile
```gdscript
Profile.wallet.add(Types.CURRENCY_COINS, 50) / spend() / can_afford() / get_amount()
Profile.inventory.add_item(&"revive") / consume_item() / has_item()
Profile.levels.get_stars(id) / get_best_score(id) / is_unlocked(level) / get_total_stars()
Profile.upgrades.get_level(id) / get_value(upgrade) / purchase(upgrade)
Profile.stats.increment(Types.STAT_X) / record_max(id, value)
Profile.achievements.is_unlocked(id) / get_progress_ratio(achievement)
Profile.daily_rewards.can_claim() / claim()
Profile.energy.get_current() / consume(1) / seconds_until_next()
Profile.meta.set_flag(&"tutorial_done") / has_flag() / offline_seconds
Profile.idle_wallet.add(Types.CURRENCY_GOLD, 1.5e12) / spend() / get_amount()   # float balances
Profile.campaign.current_stage / advance_stage() / retreat_stage() / rebirth_count
Profile.hero_stars.is_unlocked(id) / unlock(hero) / get_unlocked_count()     # hero collection, survives rebirth
Profile.hero_stars.get_stars(id) / get_shards(id) / add_shards(id, n) / star_up(hero)   # survives rebirth
Profile.income.get_level(id) / get_progress(id) / purchase_levels(source, n)             # timed gold sources
Profile.heroes.get_level(id) / purchase_levels(hero, count) / get_recruited_heroes()   # 0 = not collected; owned heroes start runs at 1
Profile.grant_rewards({&"coins": 100, &"revive": 1})   # currencies or items
Profile.reset_progress()
```

### Audio
```gdscript
Audio.play_music(stream, fade_seconds, volume_db)   # cross-fades; same track = no restart
Audio.get_current_music()
Audio.play_effect(sound_effect)                     # SoundEffect resource, full volume
Audio.play_effect_at(sound_effect, world_position)  # panned / quieter away from the camera
Audio.play_sfx(stream, pitch_variation, volume_db)  # raw stream
Audio.play_ui(Audio.UI_CLICK)    # click / confirm / error / reward
SfxSynth.get_preset(&"coin")     # placeholder sounds: coin hit shoot jump explosion pop
```

A `SoundEffect` (`Scripts/Resources/sound_effect.gd`) holds one or more takes
(picked at random), `volume_db`, `pitch_scale`, `pitch_variation` and
`min_interval_seconds`. Replays closer together than the interval are skipped,
so a busy fight doesn't stack copies of the same hit. Player pools prefer an
idle player, so short sounds don't cut off long ones.

**The battle's audio:**
- **Music:** `BattleSoundBank` (`Ressources/Audio/battle_sounds.tres`, set on
  `Battle.tscn`) holds the battle and boss themes and the stage / progress
  sounds.
- **Hero attacks:** `HeroData.attack_sound` (shared files in
  `Ressources/Audio/Attacks/`).
- **Skills:** `HeroSkill.cast_sound` (`Ressources/Audio/Skills/`).
- **Hit and death sounds:** sub-resources of `Hero.tscn`, `Monster.tscn` and
  `BattleBase.tscn`.

All of it is original audio synthesized by `Assets/Audio/Source/generate_audio.py`
(pure Python). Rerun it after changing a sound, or replace a WAV with a real
asset of the same name. Music WAVs are imported with a forward loop
(`edit/loop_mode=2` in their `.import` files), QOA compressed.

### Pools
```gdscript
var bullet: Projectile = Pools.spawn(BULLET_SCENE, Global.get_world_root(), position)
Pools.despawn(bullet)            # never queue_free pooled nodes
Pools.prewarm(BULLET_SCENE, 30)
```
Pooled scripts may implement `_on_pool_spawned()` / `_on_pool_despawned()` to reset.
Pools are cleared on every scene change.

### Ads / Store / Analytics
```gdscript
if await Ads.show_rewarded(&"revive"): ...
Ads.maybe_show_interstitial(&"level_end")      # capped, skipped with "no_ads"
if await Store.purchase(&"gems_small"): ...    # rewards granted automatically
Analytics.log_event(&"tutorial_step", {"step": 2})
Ads.set_provider(MyProvider.new())             # swap mock for a real SDK
```

### UI
```gdscript
var result: Variant = await UI.open_popup(MY_POPUP_SCENE, {"key": value}).closed
if await UI.confirm(tr("Quit?"), "", tr("Yes"), tr("No")): ...
UI.toast("Saved!")
UI.show_loading("Connecting…") / UI.hide_loading()
```
Every `BaseButton` automatically gets press scale, click sound and haptics;
set meta `no_juice` on a button to opt out.

New popup: a scene with root `Control` (script `extends BasePopup`), children
`%Backdrop` (ColorRect) and `CenterContainer/%Panel` (PanelContainer). Override
`_on_opened(data)` and call `close(result)`. Copy `ConfirmPopup` as a starter.

### SceneManager
```gdscript
SceneManager.change_scene(path, {Types.PARAM_LEVEL_DATA: level})
SceneManager.go_back() / go_to_main_menu() / reload_current_scene()
```
Target scenes receive params through `receive_scene_params(params)` before
`_ready`. Back button order: top popup → scene's `handle_back() -> bool` →
history → quit dialog.

### Debug (debug builds only)
F3 or five quick taps in the top-left corner: coins, gems, unlock levels,
refill energy, win/lose level, ×3 time scale, reset daily reward / progress.
Add cheats in `Globals/Debug/debug_overlay.gd → _build_cheats()`.

## LevelBase (`Scenes/Game/LevelBase/`)

StateChart: `Intro → Playing ⇄ Paused → Won | Lost`.

| Member | Use |
|---|---|
| `level_data`, `score`, `elapsed_seconds`, `phase`, `world`, `camera`, `hud` | state & nodes |
| `add_score()`, `set_score()`, `win()`, `lose()`, `end_run()` | flow |
| `pause_level()`, `restart_level()`, `quit_to_menu()`, `go_to_next_level()` | navigation |
| `LevelBase.start_level(level_data)` | start any level (consumes energy) |
| `_on_level_setup`, `_on_level_started`, `_level_process`, `_level_physics_process` | hooks |
| `_on_time_limit_reached`, `_calculate_stars`, `_calculate_rewards`, `_on_level_finished` | hooks |
| exports `show_intro_countdown`, `time_limit_seconds`, `show_elapsed_time`, `show_score` | config |

HUD (`hud`): `set_score`, `set_timer`, `set_progress(value, max, caption)`,
`show_message(text)`, `add_action_button(text)`, `add_action_control(control)`,
`set_currency_visible`.

## Idle base battle (`Scenes/Game/Battle/`)

The game's main screen: a side-view, endless `LevelBase` (`BattleLevel`). Your base
stands on the left, the enemy base on the right. Heroes leave your base and fight
on their own; the enemy base sends monsters. Destroy the enemy base → one stage
up; lose yours → one stage down. No tapping. All tuning is in
`Ressources/campaign.tres` (`GameConfig.get_default().campaign`, a `CampaignConfig`);
the stat model, formulas and scaling are in [GAME_DESIGN.md](GAME_DESIGN.md).
`GameConfig.boot_into_first_level` makes Boot open the battle directly (main menu
stays reachable from the pause menu).

| Piece | Role |
|---|---|
| `StageDirector` | Stage flow on its own StateChart (`Standby → Fighting → Victory / Defeat → Fighting`); resets bases, spawns monster groups and the zone boss |
| `BattleLane` | Registry of everything hittable; `find_target(team, x, reach, can_hit_air)` returns the nearest opponent ahead; `apply_hit(target, damage, crit, source, attacker_race)` resolves the race wheel, crit weakness and defense |
| `BattleBase` (`Scenes/Entities/`) | A base with health; `destroyed` ends the stage; `reset(max_health)` per stage |
| `Hero` / `Monster` (`Scenes/Entities/`) | Lane fighters: `Alive { Marching ⇄ Fighting } → Dead`; heroes respawn at their rally point, monsters are pooled |
| `LaneCombatComponent` (`Scripts/Components/`) | Walk / stop in reach / attack logic shared by heroes and monsters |
| `HeroSquad` | Spawns one `Hero` per collected `HeroData`, resets them every stage |
| `IncomeTicker` | Fills every owned `IncomeSourceData` cycle and pays its gold (`Ressources/Income/`) |
| `GestureDetector` (Battle) | A tap (not a drag) on the field opens `MonsterPopup` for the monster under it (`BattleLane.find_unit_near`) |
| `HeroPopup` / `MonsterPopup` (`Scenes/UI/Popups/`) | Stats as an icon + value grid (`StatGrid`), no captions; the hero popup also buys shard packs with gems |
| `StageBar` / `BattleMenu` (`Scenes/UI/`) | Top bar (stage, gold, income, both base bars, enemy power, `LaneMinimap`) and bottom tabs (heroes, income, relics); display only |
| `GameCamera` (Battle) | Always follows the front of the fight. A drag (pans inside `pan_limits`, the 2,220 px lane, and emits `user_panned`) or a minimap tap (`center_on_x()`) calls `BattleLevel.hold_manual_view()`. Once the finger is up (`GameCamera.is_touching()`), the camera waits `follow_resume_seconds` (3 s), then glides back; `is_following()` reports the state |
| `CombatStats` (`Scripts/Game/`) | Every derived number: hero damage / health, monster stats, base health, income, offline gold |
| `GrowthCurve` (`Scripts/Utils/`) | Shared level scaling (linear + milestones) and geometric / bulk cost math |

Data:
- `HeroData`: damage, health, reach, speed and cost curves, layer, race and
  five `StarBonus` sub-resources (`star_bonuses`, one per star). Lives in
  `Ressources/Heroes/`; the first hero starts recruited.
- `StarBonus`: a stat (attack, health, attack speed, defense, move speed or
  crit chance), an amount and a scope (`SELF`, `TEAM` or `RACE` plus a
  `HeroRace`). `CombatStats.get_star_bonus(hero, stat)` sums every unlocked
  bonus that reaches a hero.
- `HeroRace` / `MonsterRace`: both extend `UnitRace` (id, name, color, icon).
  They live in `Ressources/Races/` and carry team synergies / monster traits.
- The race wheel (`CampaignConfig.race_matchups`): a list of `RaceMatchup`s
  (strong race, weak race). `CampaignConfig.get_race_damage_multiplier()`
  gives ×1.5 / ×0.75, and every lane fighter passes its race into `BattleLane.apply_hit()`.

Also `MonsterZone` + `MonsterData` (sub-resources of
`campaign.tres`), `RelicData` (an `UpgradeData` bought with souls, `Ressources/Relics/`).
Gold is a float in `Profile.idle_wallet` (int64 is too small); souls live in the
normal `Profile.wallet`. Add a hero: new `HeroData` .tres → append to `campaign.heroes`.

Skills: each `HeroData.skill` is a `HeroSkill` (an `AbilityData`; `Ressources/Skills/`)
cast automatically through the hero's `AbilityComponent` — `StrikeSkill`, `VolleySkill`,
`BlastSkill`, `HealSkill`, `FrenzySkill`, `SnareSkill`, `RallySkill` (`Scripts/Resources/Skills/`). `_cast()` returns
false when it can't help (no cooldown spent). New effect: subclass `HeroSkill`.

Pressure: monsters sent later in a stage are stronger (`enemy_escalation_per_second`),
so a squad that can't break the base in time gets overrun and drops a stage.

Stars: every destroyed enemy base drops shards of one random hero (weighted by
`HeroData.rarity`, more on boss stages). Shards buy stars (`star_shard_costs`), and
each star unlocks the hero's next `StarBonus`. A star-up refreshes the whole squad,
because team and race bonuses reach the other heroes too. Stars and shards live in
`Profile.hero_stars` and survive rebirth. Tap a hero's portrait in the menu for
`HeroPopup`: details, the `StarLadder` (five cells, each with stat icon + bonus and
who gets it) and Star up.

**Hero chest.**
- **How heroes join:** heroes join the collection only from the hero chest at
  the top of the Heroes tab. `BattleLevel.open_hero_chest()` pays a chest key
  (`Types.CURRENCY_KEYS`), or `chest_gem_cost` gems when you're out of keys.
- **The roll:** `CampaignConfig.roll_chest_hero()` picks by `chest_rarity_weights`.
  It always gives a new hero until `chest_guaranteed_new_until` heroes are
  collected, and rerolls duplicates `chest_duplicate_rerolls` times.
- **Duplicates:** become `chest_duplicate_shards`.
- **Keys:** come from the first clear of every `chest_key_stage_interval`-th
  stage in a run (`StageDirector.stage_won(stage, is_first_clear)`), plus
  `chest_keys_per_boss`.
- **Screens:** the round button in the middle of the battle menu's navigation
  bar (with the key count) opens `ChestPopup`: the closed chest with the odds
  (`ChestOddsRow`), Open, and the reveal. The Collection tab shows every hero
  as a `HeroCard` slot (`Scenes/UI/HeroCard/`) with level and shard bar;
  locked heroes are silhouettes.

## Components (`Scripts/Components/`)

| Component | Node | Notes |
|---|---|---|
| `HealthComponent` | Node | `apply_damage`, `heal`, `revive`, i-frames; signals `damaged`, `died` |
| `HurtboxComponent` | Area2D | put on `*_hurtbox` layer; links a HealthComponent |
| `HitboxComponent` | Area2D | mask = hurtbox layer; one-shot or `hit_interval` contact damage, crits, knockback |
| `Projectile` | Area2D | pooled hitbox; speed, lifetime, pierce, homing |
| `ShooterComponent` | Marker2D | fire rate, spread, multi-shot, homing; multipliers for upgrades |
| `TargetingComponent` | Area2D | finds targets by group; priorities nearest/farthest/strongest/weakest/first/last on path |
| `VelocityComponent` | Node | accel/friction top-down movement + knockback |
| `PlatformerMovementComponent` | Node | jump by height/time, coyote, buffer, multi-jump, jump cut |
| `PathMoverComponent` | Node | follows a Path2D; `progress` for TD targeting |
| `WaveSpawner` | Node | `WaveData` waves; markers / ring around player / path start; endless scaling |
| `Pickup` / `CollectorComponent` | Area2D | magnet pickups; broadcast `Events.pickup_collected` |
| `LootDropComponent` | Node | rolls a `LootTable` |
| `StatsComponent` | Node | base stats + `StatModifier`s (flat / percent) |
| `AbilityComponent` | Node | `AbilityData` slots with cooldowns; pair with `CooldownButton` |
| `HitFlashComponent` | Node | flashes a CanvasItem on damage |
| `HealthBarComponent` | ProgressBar | world-space bar bound to health |
| `GameCamera` | Camera2D | follow, trauma shake, optional pan + pinch zoom |
| `TapArea` | Area2D | tappable world objects |
| `GestureDetector` (`Scripts/Input/`) | Node | tap, double tap, long press, swipe, drag, pinch |

Component wiring in scenes uses exported node references (e.g. a hurtbox's
`health_component`), not `get_parent()`.

## Reusable entities (`Scenes/Entities/`)

`TopDownPlayer` (joystick/keyboard, auto-aim, stats-driven), `ChaserEnemy`
(pooled melee AI with loot), `Projectile`, `Pickups/XpGem` & `Coin`,
`FloatingText` (`FloatingText.spawn("-12", position, color)`).

## UI controls (`Scripts/UI/`)

`SafeAreaContainer`, `CurrencyDisplay` (shows `CurrencyData.icon`), `EnergyDisplay`,
`StarsDisplay`, `TouchJoystick` (feeds the `move_*` actions), `CooldownButton`,
`BasePopup`, and the icon-first controls:

- `IconValue`: an icon followed by a value (`IconValue.create(GameIcons.HEALTH, "4.2K")`,
  or as a node with `icon` / `text` in the Inspector).
- `StatGrid`: a grid of `IconValue` cells (`add_stat(icon, value, highlighted, extra_icons)`).
- `GameIcons`: the shared stat, currency and tab icons, as `const` preloads.

## Art (`Assets/Art/`)

The original art is drawn by `Assets/Art/Source/generate_art.py`, a pure-Python
rasterizer that writes PNGs. It uses `doodle.py`, which builds SDF shapes and
paints them (`Canvas(paint=True, supersample=2)`):
- every part is a shaded volume, with cool shadows, warm lights and an
  optional shine for metal and slime;
- parts cast a small contact shadow on what is behind them;
- thin ink lines go inside the figure;
- `finish()` adds one brush-like outline around the whole silhouette and a
  faint grain;
- the image is drawn at 2× and averaged down.

Parts and details:
- **Shared parts:** `legs`, `arm`, `tunic`, `head`, `face`, `hood`,
  `hero_sword`, `feathered_wing`, `bat_wing`, `leaf_cluster`, `brick_wall`,
  `shingles` and others.
- **Detail:** plank, brick and bark lines, rivets, teeth and eye glints.

Organization and regenerating:
- **Folders:**
  - `Heroes/` (face right);
  - `Monsters/` (face left; bosses are larger);
  - `Bases/` and `Props/` (zone scenery);
  - `Chest/` and `Effects/`;
  - `Icons/`.
- **Regenerating:** `python3 Assets/Art/Source/generate_art.py [Folder|name...] [--sheet preview.png]`.
  It renders on every core (a `fork` process pool); everything takes about a
  minute.
- **Using real art:** replace a PNG with real art of the same name.

The art is used through data:
- **Characters:** `HeroData.icon` / `MonsterData.icon` is the character art.
  `CharacterArt.apply()` puts it on the entity's `%Art` sprite (feet on the
  shadow) and falls back to the `%Shape` placeholder when it's missing.
- **Icons:** `HeroRace.icon` / `MonsterRace.icon` (emblems), `AbilityData.icon`
  (skills), `IncomeSourceData.icon`, `UpgradeData.icon` (relics) and `CurrencyData.icon`.
- **Bases:** `BattleBase.art`.
- **Backdrop:** `MonsterZone.props`, drawn by `BattleBackdrop` in two depth rows.
- **UI skin:** `Assets/Art/Source/ui_skin.py` draws flat, muted 9-slice
  textures into `Assets/Art/UI/`:
  - dark warm charcoal panels and card slots with thin ink lines;
  - copper-lined slots for things you own (`card_owned`, `feature_card`);
  - stone buttons with a short lip (blue, grey, green, red, copper/gold,
    disabled);
  - flat bars and a portrait frame you tint by rarity;
  - nav tiles and the round chest medallion;
  - edge-to-edge docks (`dock_top`, `dock_bottom`) for the battle's top bar
    and bottom menu. They are square, with one ink edge toward the field.

  The battle's `StageBar` and `BattleMenu` use them through the theme
  variations `DockTopPanel` and `DockBottomPanel`.
  - The bars run to the screen edges, so the battle's root `SafeArea` only
    keeps clear of side cutouts.
  - Each bar has its own `SafeAreaContainer` inside it, which keeps its
    content clear of the notch (top bar) or the home indicator (menu).

  The theme (`main_theme.tres`) uses them as `StyleBoxTexture` (the variations
  include `GoldButton`, `FeatureCard`, `StatCell`, `NavTab`,
  `NavTabSelected`, `DockTopPanel` and `DockBottomPanel`). Text is bold with dark outlines.
- **Palette:** characters, props, bases, the chest and icons share one dusty
  palette (`doodle.muted`) and the painted look.
- **Battlefield:** `Battle.tscn` adds a vignette.

## Utilities (`Scripts/Utils/`)

`NumberFormat` (1.2K, 4.5aa, 1,234, 2:05), `TweenFX` (pop, bounce_in, shake, pulse,
count_label…), `RandomUtils` (weighted picks), `GridData` (board games: matches,
flood fill, cell↔world), `PlaceholderShape` & `GridBackground` (art stand-ins),
`CharacterArt` (sizes character art to a unit), `SfxSynth` (generated sounds).

## Data resources (`Scripts/Resources/`)

`GameConfig`, `LevelData`, `CurrencyData`, `UpgradeData`, `ProductData`, `SoundEffect`,
`AchievementData`, `RewardBundle`, `WaveData`/`WaveEntry`, `LootTable`/`LootEntry`,
`StatModifier`, `PerkData`, `AbilityData` (subclass and override `activate()`),
`CampaignConfig`, `HeroData`, `MonsterZone`, `MonsterData`, `RelicData`.

## Physics layers

| # | Name | Used by |
|---|---|---|
| 1 | world | walls, ground |
| 2 | player | player bodies |
| 3 | enemy | enemy bodies |
| 4 | player_hurtbox | hit by enemy hitboxes |
| 5 | enemy_hurtbox | hit by player projectiles; detected by targeting |
| 6 | pickup | collected by `CollectorComponent` |
| 7 | interactable | `TapArea` |
