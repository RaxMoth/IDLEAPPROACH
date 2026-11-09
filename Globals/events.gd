## Global event bus. Systems that don't know each other talk through these
## typed signals instead of holding references (e.g. a coin pickup emits
## currency_changed via Profile, and every CurrencyDisplay updates itself).
##
## Emit:    Events.score_changed.emit(new_score, delta)
## Listen:  Events.score_changed.connect(_on_score_changed)
##
## Dependencies: none
extends Node
@warning_ignore_start("unused_signal")

# --- Application lifecycle (emitted by Platform) ---
signal app_paused
signal app_resumed
signal back_requested
signal safe_area_changed(safe_margins: Rect2)

# --- Navigation (emitted by SceneManager) ---
signal scene_change_started(scene_path: String)
signal scene_changed(scene_path: String)

# --- Level flow (emitted by LevelBase) ---
signal level_started(level_id: StringName)
signal level_finished(result: LevelResult)
signal level_paused(is_paused: bool)
signal score_changed(new_score: int, score_delta: int)

# --- Economy & progression (emitted by Profile modules) ---
signal currency_changed(currency_id: StringName, new_amount: int, amount_delta: int)
## Float balances from Profile.idle_wallet (gold) that outgrow int64.
signal idle_currency_changed(currency_id: StringName, new_amount: float, amount_delta: float)
signal item_changed(item_id: StringName, new_count: int)
signal upgrade_purchased(upgrade_id: StringName, new_level: int)
signal stat_changed(stat_id: StringName, new_value: float)
signal achievement_unlocked(achievement: AchievementData)
signal daily_reward_claimed(streak_day: int, rewards: Dictionary)
signal energy_changed(current_energy: int, max_energy: int)
signal progress_reset

# --- Idle battle progression (emitted by Profile.campaign / heroes / hero_stars) ---
signal stage_changed(current_stage: int, highest_stage: int)
signal hero_leveled(hero_id: StringName, new_level: int)
signal hero_shards_changed(hero_id: StringName, shard_count: int)
signal hero_star_changed(hero_id: StringName, star_count: int)
## A hero joined the collection (from a hero chest).
signal hero_unlocked(hero_id: StringName)
signal income_source_leveled(source_id: StringName, new_level: int)
signal rebirth_completed(souls_gained: int, rebirth_count: int)

# --- Gameplay feedback ---
signal camera_shake_requested(trauma_amount: float)
signal pickup_collected(pickup_id: StringName, amount: int, world_position: Vector2)
signal enemy_defeated(enemy: Node2D)

# --- Settings ---
signal setting_changed(setting_key: StringName, value: Variant)

# --- Monetization (emitted by Ads / Store) ---
signal rewarded_ad_finished(placement: StringName, was_rewarded: bool)
signal purchase_completed(product_id: StringName)
signal purchase_failed(product_id: StringName, reason: String)
