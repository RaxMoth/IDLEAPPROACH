## Registry of everything that can be hit in the battle lane: heroes and
## the player's base (team PLAYER, fighting toward +x) against monsters and
## the enemy base (team ENEMY, fighting toward -x). Fighters ask it for the
## nearest opponent ahead of them within reach, and every hit is resolved
## here so defense, crit weakness and the race wheel (CampaignConfig.race_matchups)
## work the same for attacks and skills. AIR entries are skipped for attackers that can't hit air
## (ground melee), so flyers pass over the melee line.
##
##   var entry: BattleLane.LaneEntry = lane.register(hero, Types.Team.PLAYER, hero.health_component, 30.0)
##   entry.defense = 0.2; entry.layer = Types.UnitLayer.AIR
##   var target: Node2D = lane.find_target(Types.Team.PLAYER, global_position.x, 60.0, can_hit_air)
##   lane.apply_hit(target, 120.0, false, self, attacker_race)
##
## Dependencies: Types autoload, HealthComponent, UnitRace, CampaignConfig
class_name BattleLane
extends Node2D

## One registered combatant.
class LaneEntry:
	var unit: Node2D
	var team: Types.Team
	var health: HealthComponent
	## Half width along the lane: reach is measured to the unit's edge.
	var radius: float
	## Share of incoming damage blocked.
	var defense: float = 0.0
	var layer: Types.UnitLayer = Types.UnitLayer.GROUND
	## Hero or monster race (null for bases), for the race wheel.
	var race: UnitRace = null
	## Critical hits on this unit are multiplied by this (elementals are weak to crits).
	var crit_damage_taken_multiplier: float = 1.0


## Allies may overlap a little: a target this far behind still counts as ahead.
const BEHIND_TOLERANCE: float = 12.0

## Defense never blocks more than this (CampaignConfig.max_defense).
var max_defense: float = 0.75
## Supplies the race wheel (who beats whom).
var campaign: CampaignConfig

var _entries: Dictionary[Node2D, LaneEntry] = {}


func _ready() -> void:
	campaign = GameConfig.get_default().campaign
	if campaign != null:
		max_defense = campaign.max_defense


## Adds (or replaces) [param unit]; set defense / layer / race on the returned entry.
func register(unit: Node2D, team: Types.Team, health: HealthComponent, radius: float) -> LaneEntry:
	var entry: LaneEntry = LaneEntry.new()
	entry.unit = unit
	entry.team = team
	entry.health = health
	entry.radius = radius
	_entries[unit] = entry
	return entry


func unregister(unit: Node2D) -> void:
	_entries.erase(unit)


## Nearest living opponent of [param team] ahead of [param from_x] whose edge is
## within [param reach] (units and bases alike), or null. Flyers only count
## when [param can_hit_air].
func find_target(team: Types.Team, from_x: float, reach: float, can_hit_air: bool = true) -> Node2D:
	var best_target: Node2D = null
	var best_gap: float = INF
	for entry: LaneEntry in _entries.values():
		if not _is_hittable(entry, team, can_hit_air):
			continue
		var gap: float = _get_gap(team, from_x, entry)
		if gap <= reach and gap < best_gap:
			best_gap = gap
			best_target = entry.unit
	return best_target


## Every living opponent of [param team] ahead of [param from_x] within [param reach].
func find_targets_in_reach(team: Types.Team, from_x: float, reach: float, can_hit_air: bool = true) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for entry: LaneEntry in _entries.values():
		if _is_hittable(entry, team, can_hit_air) and _get_gap(team, from_x, entry) <= reach:
			targets.append(entry.unit)
	return targets


## Every living opponent of [param team] whose edge is within [param radius] of
## [param center_x] (area effects hit flyers too).
func find_opponents_near(team: Types.Team, center_x: float, radius: float) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for entry: LaneEntry in _entries.values():
		if _is_hittable(entry, team, true) and absf(entry.unit.global_position.x - center_x) - entry.radius <= radius:
			targets.append(entry.unit)
	return targets


## Living fighters (bases excluded) of [param team].
func get_living_units(team: Types.Team) -> Array[Node2D]:
	var units: Array[Node2D] = []
	for entry: LaneEntry in _entries.values():
		if entry.team == team and not entry.health.is_dead and not (entry.unit is BattleBase):
			units.append(entry.unit)
	return units


## The base of [param team], or null.
func get_base(team: Types.Team) -> BattleBase:
	for entry: LaneEntry in _entries.values():
		if entry.team == team and entry.unit is BattleBase:
			return entry.unit as BattleBase
	return null


## Still alive, still registered, still hittable and still within [param reach] of [param from_x].
func is_target_valid(target: Node2D, team: Types.Team, from_x: float, reach: float, can_hit_air: bool = true) -> bool:
	var entry: LaneEntry = _entries.get(target, null)
	if entry == null or not _is_hittable(entry, team, can_hit_air):
		return false
	return _get_gap(team, from_x, entry) <= reach


## True when a living fighter of [param team] moves on [param layer] (e.g. a flyer is out).
func has_living(team: Types.Team, layer: Types.UnitLayer) -> bool:
	for entry: LaneEntry in _entries.values():
		if entry.team == team and entry.layer == layer and not entry.health.is_dead and not (entry.unit is BattleBase):
			return true
	return false


## X positions of living fighters (bases excluded) of [param team] (lane minimap).
func get_unit_positions(team: Types.Team) -> PackedFloat32Array:
	var positions: PackedFloat32Array = PackedFloat32Array()
	for entry: LaneEntry in _entries.values():
		if entry.team == team and not entry.health.is_dead and not (entry.unit is BattleBase):
			positions.append(entry.unit.global_position.x)
	return positions


## Living fighter (bases excluded) of [param team] whose body is closest to
## [param world_position] within [param radius], or null (tap to inspect).
func find_unit_near(team: Types.Team, world_position: Vector2, radius: float) -> Node2D:
	var nearest_unit: Node2D = null
	var nearest_distance: float = radius
	for entry: LaneEntry in _entries.values():
		if entry.team != team or entry.health.is_dead or entry.unit is BattleBase:
			continue
		var distance: float = get_aim_point(entry.unit).distance_to(world_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_unit = entry.unit
	return nearest_unit


## Where shots and effects should aim at [param unit] (its body; flyers are raised).
func get_aim_point(unit: Node2D) -> Vector2:
	if unit.has_method(Types.METHOD_GET_AIM_POINT):
		return unit.call(Types.METHOD_GET_AIM_POINT)
	return unit.global_position


## Deals [param raw_damage] to [param target] and returns the damage that landed
## (0 when the target is gone or already dead). Order: race wheel
## ([param attacker_race] against the target's race), crit weakness, then defense.
func apply_hit(target: Node2D, raw_damage: float, is_critical: bool, source: Node, attacker_race: UnitRace = null) -> float:
	var entry: LaneEntry = _entries.get(target, null)
	if entry == null or entry.health.is_dead:
		return 0.0
	var damage: float = raw_damage
	if campaign != null:
		damage *= campaign.get_race_damage_multiplier(attacker_race, entry.race)
	if is_critical:
		damage *= entry.crit_damage_taken_multiplier
	var damage_info: DamageInfo = DamageInfo.create(damage * (1.0 - clampf(entry.defense, 0.0, max_defense)), source)
	damage_info.is_critical = is_critical
	entry.health.apply_damage(damage_info)
	return damage_info.amount


func get_health(target: Node2D) -> HealthComponent:
	var entry: LaneEntry = _entries.get(target, null)
	return entry.health if entry != null else null


func _is_hittable(entry: LaneEntry, attacker_team: Types.Team, can_hit_air: bool) -> bool:
	if entry.team == attacker_team or entry.health.is_dead:
		return false
	return can_hit_air or entry.layer != Types.UnitLayer.AIR


## Distance from [param from_x] to the near edge of [param entry] in the
## attacker's walking direction (negative = overlapping, INF = behind).
func _get_gap(team: Types.Team, from_x: float, entry: LaneEntry) -> float:
	var direction: float = 1.0 if team == Types.Team.PLAYER else -1.0
	var distance_ahead: float = (entry.unit.global_position.x - from_x) * direction
	if distance_ahead < -entry.radius - BEHIND_TOLERANCE:
		return INF
	return distance_ahead - entry.radius
