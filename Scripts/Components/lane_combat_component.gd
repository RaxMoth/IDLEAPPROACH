## Lane fighting for side-view battles: walks the actor toward the enemy
## side while nothing is in reach, then attacks the nearest opponent (unit or
## base) until it dies or leaves reach. Hits can crit and are resolved by
## BattleLane.apply_hit (target defense); the owner plays the visuals from
## `attacked`.
##
## Drive it from the owner's StateChart:
##   Marching.state_physics_processing -> process_marching(delta)
##   Fighting.state_physics_processing -> process_fighting(delta)
## and send Types.EVENT_TARGET_IN_RANGE / EVENT_TARGET_OUT_OF_RANGE from
## target_in_reach / target_lost.
##
## Dependencies: BattleLane
class_name LaneCombatComponent
extends Node

## Something came within reach while marching.
signal target_in_reach(target: Node2D)
## The target died or left reach and nothing else is in reach.
signal target_lost
## Emitted on every swing, before the damage lands.
signal attacked(target: Node2D, damage: float)

## The node that walks along the lane (usually the entity root).
@export var actor: Node2D
## PLAYER walks toward +x, ENEMY toward -x.
@export var team: Types.Team = Types.Team.PLAYER
@export var move_speed: float = 100.0
@export var attack_range: float = 50.0
@export var attack_interval_seconds: float = 1.0
## Targets are searched on an interval instead of every frame.
@export var retarget_interval_seconds: float = 0.12
@export_range(0.0, 1.0) var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0
## Ground melee fighters can't reach flyers; ranged and flying fighters can.
@export var can_hit_air: bool = true

## Damage per swing; owners update it when stats change (level up, stage).
var attack_damage: float = 1.0
## The fighter's own race: its hits follow the race wheel (BattleLane.apply_hit).
var race: UnitRace = null
## Injected by the owner on setup.
var lane: BattleLane
var current_target: Node2D = null

var _attack_cooldown: float = 0.0
var _retarget_remaining: float = 0.0
var _attack_speed_multiplier: float = 1.0
var _attack_speed_boost_remaining: float = 0.0
var _stun_remaining: float = 0.0


## Forget the current target and restart the timers (spawn, respawn, stage start).
func reset() -> void:
	current_target = null
	_retarget_remaining = 0.0
	_attack_speed_multiplier = 1.0
	_attack_speed_boost_remaining = 0.0
	_stun_remaining = 0.0
	# Half a swing of random delay keeps a group from attacking in lockstep.
	_attack_cooldown = randf_range(0.0, attack_interval_seconds * 0.5)


## Attacks [param multiplier] times faster for [param duration_seconds] (skills, buffs).
## A weaker boost never replaces a stronger one that is still running.
func boost_attack_speed(multiplier: float, duration_seconds: float) -> void:
	if is_attack_speed_boosted() and multiplier < _attack_speed_multiplier:
		return
	_attack_speed_multiplier = maxf(multiplier, 0.01)
	_attack_speed_boost_remaining = duration_seconds
	_attack_cooldown = minf(_attack_cooldown, attack_interval_seconds / _attack_speed_multiplier)


func is_attack_speed_boosted() -> bool:
	return _attack_speed_boost_remaining > 0.0


func get_attack_speed_multiplier() -> float:
	return _attack_speed_multiplier if is_attack_speed_boosted() else 1.0


## Can't move or attack for [param duration_seconds] (snares). Longer stuns win.
func stun(duration_seconds: float) -> void:
	_stun_remaining = maxf(_stun_remaining, duration_seconds)


func is_stunned() -> bool:
	return _stun_remaining > 0.0


func get_walk_direction() -> float:
	return 1.0 if team == Types.Team.PLAYER else -1.0


func process_marching(delta: float) -> void:
	if lane == null:
		return
	_tick_attack_speed_boost(delta)
	if _tick_stun(delta):
		return
	_retarget_remaining -= delta
	if _retarget_remaining <= 0.0:
		_retarget_remaining = retarget_interval_seconds
		var target: Node2D = lane.find_target(team, actor.global_position.x, attack_range, can_hit_air)
		if target != null:
			current_target = target
			target_in_reach.emit(target)
			return
	actor.global_position.x += get_walk_direction() * move_speed * delta


func process_fighting(delta: float) -> void:
	if lane == null:
		return
	_tick_attack_speed_boost(delta)
	if _tick_stun(delta):
		return
	if not lane.is_target_valid(current_target, team, actor.global_position.x, attack_range, can_hit_air):
		# Switch straight to the next opponent in reach, else walk on.
		current_target = lane.find_target(team, actor.global_position.x, attack_range, can_hit_air)
		if current_target == null:
			_retarget_remaining = 0.0
			target_lost.emit()
			return
	_attack_cooldown -= delta
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = attack_interval_seconds / _attack_speed_multiplier
	var is_critical: bool = randf() < crit_chance
	var damage: float = attack_damage * (crit_multiplier if is_critical else 1.0)
	attacked.emit(current_target, damage)
	lane.apply_hit(current_target, damage, is_critical, actor, race)


## Counts the stun down; true while it still blocks moving and attacking.
func _tick_stun(delta: float) -> bool:
	if _stun_remaining <= 0.0:
		return false
	_stun_remaining -= delta
	return true


func _tick_attack_speed_boost(delta: float) -> void:
	if _attack_speed_boost_remaining <= 0.0:
		return
	_attack_speed_boost_remaining -= delta
	if _attack_speed_boost_remaining <= 0.0:
		_attack_speed_multiplier = 1.0
