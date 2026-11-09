## Runs one stage of the base battle: resets both bases, has the enemy base
## send groups of monsters on an interval (plus a boss on every zone's last
## stage) — each group stronger than the last the longer the stage lasts —
## and ends the stage when a base falls — the enemy's moves the player
## one stage up, the player's one stage down. Then the next stage starts.
##
## Flow (BattleChart, see Battle.tscn):
##   Standby -> Fighting -> Victory -> Fighting ...
##                       -> Defeat  -> Fighting ...
##   Any state -> Fighting on Types.EVENT_STAGE_RESTART.
##
## Owns monster spawning and both bases' health; the battle pays gold and
## resets the squad through the signals below. Writes Profile.campaign.
##
## Dependencies: Types, Pools, Profile autoloads, CampaignConfig, CombatStats,
##               Monster, BattleBase, BattleLane
class_name StageDirector
extends Node

signal stage_started(stage: int)
## [param is_first_clear]: the stage was never cleared before in this run (chest keys).
signal stage_won(cleared_stage: int, is_first_clear: bool)
signal stage_lost(lost_stage: int)
signal monster_defeated(monster: Monster)

## Pooled monster scene.
@export var monster_scene: PackedScene
## Parent node for spawned monsters (inside the World).
@export var monster_parent: Node2D
@export var lane: BattleLane
@export var player_base: BattleBase
@export var enemy_base: BattleBase
## Monsters leave the enemy base here (x), on their lane's y.
@export var spawn_marker: Marker2D
## Vertical offsets of the lanes monsters alternate between (depth).
@export var lane_offsets: PackedFloat32Array = PackedFloat32Array([-40.0, 40.0])
## Seconds before the first group leaves the enemy base.
@export var first_spawn_delay_seconds: float = 1.0

var campaign: CampaignConfig

var _monsters: Array[Monster] = []
var _spawn_cooldown: float = 0.0
var _spawn_lane_index: int = 0
## Both bases can fall in the same frame; only the first one ends the stage.
var _is_fighting: bool = false
var _stage_seconds: float = 0.0

@onready var state_chart: StateChart = %BattleChart


func _ready() -> void:
	campaign = GameConfig.get_default().campaign
	player_base.join_lane(lane)
	enemy_base.join_lane(lane)


## Starts the loop (call once gameplay begins).
func start() -> void:
	state_chart.set_expression_property(Types.EXPRESSION_STAGE_END_SECONDS, campaign.stage_end_seconds)
	# The chart enters its initial state one deferred call after _ready, and
	# LevelBase can start gameplay before that — an event sent now would be lost.
	restart_stage.call_deferred()


## Resets both bases, clears the field and fights the current stage again.
func restart_stage() -> void:
	state_chart.send_event(Types.EVENT_STAGE_RESTART)


## How much stronger monsters leaving the enemy base are right now (escalation).
## Races with a higher escalation_multiplier (demons) grow faster.
func get_enemy_power_multiplier(race: MonsterRace = null) -> float:
	var race_multiplier: float = race.escalation_multiplier if race != null else 1.0
	return campaign.get_enemy_power_multiplier(_stage_seconds * race_multiplier)


func get_alive_monster_count() -> int:
	var alive_count: int = 0
	for monster: Monster in _monsters:
		if monster.is_alive():
			alive_count += 1
	return alive_count


## Despawns every monster without paying out.
func clear_field() -> void:
	for monster: Monster in _monsters:
		Pools.despawn(monster)
	_monsters.clear()

# ============================================
# STATE CHART CALLBACKS (connected in Battle.tscn)
# ============================================

func _on_fighting_state_entered() -> void:
	var stage: int = Profile.campaign.current_stage
	clear_field()
	player_base.reset(CombatStats.get_player_base_health(stage))
	enemy_base.reset(campaign.get_enemy_base_health(stage))
	_spawn_cooldown = first_spawn_delay_seconds
	_stage_seconds = 0.0
	_is_fighting = true
	if campaign.is_boss_stage(stage):
		var zone: MonsterZone = campaign.get_zone(stage)
		_spawn_monster(zone.boss if zone != null else null, stage, true)
	stage_started.emit(stage)


func _on_fighting_state_processing(delta: float) -> void:
	_stage_seconds += delta
	_spawn_cooldown -= delta
	if _spawn_cooldown > 0.0:
		return
	_spawn_cooldown = campaign.spawn_interval_seconds
	var stage: int = Profile.campaign.current_stage
	var zone: MonsterZone = campaign.get_zone(stage)
	var group_size: int = randi_range(campaign.min_monsters_per_spawn, campaign.max_monsters_per_spawn)
	for group_index: int in group_size:
		var data: MonsterData = zone.pick_monster() if zone != null else null
		# Some races (goblinoids) bring friends.
		var copies: int = 1 + (data.race.extra_spawns if data != null and data.race != null else 0)
		for copy_index: int in copies:
			if get_alive_monster_count() >= campaign.max_alive_monsters:
				return
			_spawn_monster(data, stage, false)


func _on_fighting_state_exited() -> void:
	_is_fighting = false


func _on_stage_end_state_entered() -> void:
	clear_field()

# ============================================
# BASE CALLBACKS (connected in Battle.tscn)
# ============================================

func _on_enemy_base_destroyed(_base: BattleBase) -> void:
	if not _is_fighting:
		return
	_is_fighting = false
	var cleared_stage: int = Profile.campaign.current_stage
	# highest_stage is this run's best: clearing it is a first clear.
	var is_first_clear: bool = cleared_stage >= Profile.campaign.highest_stage
	Profile.stats.increment(Types.STAT_BASES_DESTROYED)
	Profile.campaign.advance_stage()
	stage_won.emit(cleared_stage, is_first_clear)
	state_chart.send_event(Types.EVENT_ENEMY_BASE_DESTROYED)


func _on_player_base_destroyed(_base: BattleBase) -> void:
	if not _is_fighting:
		return
	_is_fighting = false
	var lost_stage: int = Profile.campaign.current_stage
	Profile.campaign.retreat_stage()
	stage_lost.emit(lost_stage)
	state_chart.send_event(Types.EVENT_PLAYER_BASE_DESTROYED)

# ============================================
# INTERNALS
# ============================================

func _spawn_monster(data: MonsterData, stage: int, is_boss: bool) -> void:
	var lane_offset: float = 0.0
	if not lane_offsets.is_empty() and not is_boss:
		lane_offset = lane_offsets[_spawn_lane_index % lane_offsets.size()]
		_spawn_lane_index += 1
	var spawn_position: Vector2 = spawn_marker.global_position + Vector2(randf_range(0.0, 24.0), lane_offset)
	var monster: Monster = Pools.spawn(monster_scene, monster_parent, spawn_position) as Monster
	var power: float = get_enemy_power_multiplier(data.race if data != null else null)
	monster.setup(data, lane, CombatStats.get_monster_health(stage, is_boss, data) * power, CombatStats.get_monster_damage(stage, is_boss, data) * power, CombatStats.get_monster_gold(stage, is_boss, data), is_boss, power)
	if not monster.defeated.is_connected(_on_monster_defeated):
		monster.defeated.connect(_on_monster_defeated)
	_monsters.append(monster)


func _on_monster_defeated(monster: Monster) -> void:
	_monsters.erase(monster)
	monster_defeated.emit(monster)
