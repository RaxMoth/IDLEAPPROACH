## Game-wide enums, constants and StateChart event names.
##
## Holds no mutable state. Every magic string used across the project
## (groups, input actions, state chart events, currency ids) lives here so a
## typo becomes a compile error instead of a silent bug.
##
## Dependencies: none
extends Node

# ============================================
# ENUMS
# ============================================

enum DamageType { PHYSICAL, FIRE, ICE, POISON, TRUE_DAMAGE }
enum Team { NEUTRAL, PLAYER, ENEMY }
enum TargetPriority { NEAREST, FARTHEST, STRONGEST, WEAKEST, FIRST_ON_PATH, LAST_ON_PATH }
enum HapticStrength { LIGHT, MEDIUM, HEAVY }
enum ProductType { CONSUMABLE, NON_CONSUMABLE, SUBSCRIPTION }
enum SwipeDirection { NONE, UP, DOWN, LEFT, RIGHT }
enum LevelOutcome { NONE, WON, LOST, QUIT }
enum StatModifierKind { FLAT, PERCENT }
## Where a lane fighter moves: ground melee can't hit AIR; ranged and AIR units hit both.
enum UnitLayer { GROUND, AIR }

# ============================================
# PHYSICS LAYERS (bit values, keep in sync with [layer_names] in project.godot)
# ============================================

const LAYER_WORLD: int = 1 << 0
const LAYER_PLAYER: int = 1 << 1
const LAYER_ENEMY: int = 1 << 2
const LAYER_PLAYER_HURTBOX: int = 1 << 3
const LAYER_ENEMY_HURTBOX: int = 1 << 4
const LAYER_PICKUP: int = 1 << 5
const LAYER_INTERACTABLE: int = 1 << 6

# ============================================
# GROUPS
# ============================================

const GROUP_PLAYER: StringName = &"player"
const GROUP_ENEMY: StringName = &"enemy"
const GROUP_PICKUP: StringName = &"pickup"
## Node that pooled projectiles, pickups and effects are spawned under.
const GROUP_WORLD_ROOT: StringName = &"world_root"

# ============================================
# INPUT ACTIONS (defined in Project Settings > Input Map)
# ============================================

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_MOVE_UP: StringName = &"move_up"
const ACTION_MOVE_DOWN: StringName = &"move_down"
const ACTION_JUMP: StringName = &"jump"
const ACTION_PAUSE: StringName = &"pause"
const ACTION_DEBUG_TOGGLE: StringName = &"debug_toggle"

# ============================================
# ECONOMY IDS (must match ids in Ressources/game_config.tres)
# ============================================

const CURRENCY_COINS: StringName = &"coins"
const CURRENCY_GEMS: StringName = &"gems"
## Prestige currency earned by rebirthing, spent on relics (Profile.wallet).
const CURRENCY_SOULS: StringName = &"souls"
## Opens one hero chest (dropped by first clears of every few stages).
const CURRENCY_KEYS: StringName = &"keys"
## Idle-scale battle currency stored as float (Profile.idle_wallet).
const CURRENCY_GOLD: StringName = &"gold"
const ITEM_NO_ADS: StringName = &"no_ads"

# ============================================
# STATISTIC IDS (tracked by Profile.stats, referenced by achievements)
# ============================================

const STAT_LEVELS_PLAYED: StringName = &"levels_played"
const STAT_LEVELS_WON: StringName = &"levels_won"
const STAT_ENEMIES_DEFEATED: StringName = &"enemies_defeated"
const STAT_COINS_EARNED: StringName = &"coins_earned"
const STAT_TAPS: StringName = &"taps"
const STAT_BEST_RUNNER_SCORE: StringName = &"best_runner_score"
const STAT_MATCHES_MADE: StringName = &"matches_made"
const STAT_HIGHEST_STAGE: StringName = &"highest_stage"
const STAT_BOSSES_DEFEATED: StringName = &"bosses_defeated"
const STAT_BASES_DESTROYED: StringName = &"bases_destroyed"
const STAT_FLYERS_DEFEATED: StringName = &"flyers_defeated"
const STAT_HEROES_COLLECTED: StringName = &"heroes_collected"
const STAT_INCOME_SOURCES_OWNED: StringName = &"income_sources_owned"
const STAT_TOTAL_STARS: StringName = &"total_stars"
const STAT_REBIRTHS: StringName = &"rebirths"
const STAT_GOLD_EARNED: StringName = &"gold_earned"

# ============================================
# ENTITY STAT IDS (used by StatsComponent / StatModifier / PerkData)
# ============================================

const ENTITY_STAT_MAX_HEALTH: StringName = &"max_health"
const ENTITY_STAT_MOVE_SPEED: StringName = &"move_speed"
const ENTITY_STAT_DAMAGE: StringName = &"damage"
const ENTITY_STAT_FIRE_RATE: StringName = &"fire_rate"
const ENTITY_STAT_PROJECTILE_COUNT: StringName = &"projectile_count"
const ENTITY_STAT_PICKUP_RADIUS: StringName = &"pickup_radius"

# ============================================
# STATE CHART EVENTS — level flow (Scenes/Game/LevelBase.tscn)
# ============================================

const EVENT_LEVEL_START: StringName = &"level_start"
const EVENT_PAUSE: StringName = &"pause"
const EVENT_RESUME: StringName = &"resume"
const EVENT_WIN: StringName = &"win"
const EVENT_LOSE: StringName = &"lose"

# ============================================
# STATE CHART EVENTS — battle stage flow (Scenes/Game/Battle/Battle.tscn)
# ============================================

## Resets both bases, clears the field and starts the current stage (start, rebirth).
const EVENT_STAGE_RESTART: StringName = &"stage_restart"
## The player's squad destroyed the enemy base: one stage up.
const EVENT_ENEMY_BASE_DESTROYED: StringName = &"enemy_base_destroyed"
## The monsters destroyed the player's base: one stage down.
const EVENT_PLAYER_BASE_DESTROYED: StringName = &"player_base_destroyed"
## Expression properties read by StateChart delays.
const EXPRESSION_STAGE_END_SECONDS: StringName = &"stage_end_seconds"
const EXPRESSION_RESPAWN_SECONDS: StringName = &"respawn_seconds"
## Per-hero wait at the base before marching out, so the squad leaves in a line.
const EXPRESSION_RELEASE_SECONDS: StringName = &"release_seconds"

# ============================================
# STATE CHART EVENTS — entities (Scenes/Entities/*)
# ============================================

const EVENT_MOVE_STARTED: StringName = &"move_started"
const EVENT_MOVE_STOPPED: StringName = &"move_stopped"
const EVENT_TARGET_ACQUIRED: StringName = &"target_acquired"
const EVENT_TARGET_LOST: StringName = &"target_lost"
const EVENT_TARGET_IN_RANGE: StringName = &"target_in_range"
const EVENT_TARGET_OUT_OF_RANGE: StringName = &"target_out_of_range"
const EVENT_DIED: StringName = &"died"
const EVENT_RESPAWN: StringName = &"respawn"

# ============================================
# DUCK-TYPED HOOKS (optional methods nodes may implement)
# ============================================

## Called on a pooled node every time Pools hands it out.
const METHOD_POOL_SPAWNED: StringName = &"_on_pool_spawned"
## Called on a pooled node right before Pools takes it back.
const METHOD_POOL_DESPAWNED: StringName = &"_on_pool_despawned"
## Called on a new scene by SceneManager before it enters the tree.
const METHOD_RECEIVE_SCENE_PARAMS: StringName = &"receive_scene_params"
## Called on the current scene when the Android back button / Esc is pressed.
## Return true when the scene consumed the request.
const METHOD_HANDLE_BACK: StringName = &"handle_back"
## Called by WaveSpawner after spawning an enemy so it can scale itself.
const METHOD_APPLY_WAVE_MODIFIERS: StringName = &"apply_wave_modifiers"
## Lane fighters / bases return where shots and effects should aim (their body).
const METHOD_GET_AIM_POINT: StringName = &"get_aim_point"

# ============================================
# SCENE PARAM KEYS (SceneManager.change_scene params dictionary)
# ============================================

const PARAM_LEVEL_DATA: StringName = &"level_data"
