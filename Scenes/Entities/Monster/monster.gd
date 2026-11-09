## Pooled monster sent by the enemy base: walks (or flies) left along the
## lane, fights the first hero (or the player's base) it can hit and reports
## its defeat so the stage can pay out gold. Its MonsterData decides the role
## (flyer, shooter, brute...) and its MonsterRace adds a trait (fast, gets up
## once, weak to crits...).
## State: Alive { Marching <-> Fighting } -> Dead, Dead -> Alive on respawn (pool reuse).
##
## Spawn:  var monster: Monster = Pools.spawn(MONSTER_SCENE, parent, spawn_position)
##         monster.setup(monster_data, lane, health, damage, gold, is_boss, power)
##
## Sounds (positional, set in Monster.tscn): melee / ranged attack, defeated
## (boss_defeated for bosses) and revived for undead getting back up.
##
## Dependencies: Types, Pools, Profile, Events, Audio autoloads, LaneCombatComponent,
##               HealthComponent, HitFlashComponent, BattleLane, FloatingText,
##               HeroBolt, SoundEffect, CharacterArt
class_name Monster
extends Node2D

## Emitted once when the monster's health reaches zero (for good — undead get up first).
signal defeated(monster: Monster)

const BOSS_SCALE: float = 1.6
const BOSS_SPEED_MULTIPLIER: float = 0.7
const DAMAGE_NUMBER_COLOR: Color = Color(1, 1, 1)
const CRIT_NUMBER_COLOR: Color = Color(1.0, 0.55, 0.2)
const REVIVE_TEXT_COLOR: Color = Color(0.75, 0.55, 1.0)
const LUNGE_DISTANCE: float = 30.0
const HOVER_BOB_HEIGHT: float = 7.0
const HOVER_BOB_SPEED: float = 3.5

@export_group("Sounds")
@export var melee_attack_sound: SoundEffect
@export var ranged_attack_sound: SoundEffect
@export var defeated_sound: SoundEffect
## Bosses fall with this one (defeated_sound when empty).
@export var boss_defeated_sound: SoundEffect
## Undead getting back up once.
@export var revived_sound: SoundEffect

var monster_data: MonsterData
var gold_reward: float = 0.0
var is_boss: bool = false
## Escalation multiplier it was sent with (shown when inspecting it).
var spawn_power: float = 1.0
## Final share of every hit it blocks (type, race and boss bonuses included).
var defense: float = 0.0

var _lane: BattleLane
var _has_been_used: bool = false
var _can_revive: bool = false
var _flying_height: float = 0.0
var _hover_time: float = 0.0
var _death_tween: Tween
var _lunge_tween: Tween

@onready var health_component: HealthComponent = %HealthComponent
@onready var hit_flash_component: HitFlashComponent = %HitFlashComponent
@onready var lane_combat: LaneCombatComponent = %LaneCombatComponent
@onready var state_chart: StateChart = %StateChart
@onready var _visual: Node2D = %Visual
# Snare tints go here so they don't fight the hit flash on _visual.
@onready var _tint: Node2D = %Tint
@onready var _art: Sprite2D = %Art
@onready var _shape: PlaceholderShape = %Shape
@onready var _health_bar: Control = %HealthBarComponent
@onready var _body: Node2D = %Body


func _ready() -> void:
	add_to_group(Types.GROUP_ENEMY)
	health_component.died.connect(_on_health_died)
	health_component.damaged.connect(_on_damaged)


func _on_pool_spawned() -> void:
	if _death_tween != null:
		_death_tween.kill()
	if _lunge_tween != null:
		_lunge_tween.kill()
	hit_flash_component.reset()
	_body.modulate.a = 1.0
	_visual.position = Vector2.ZERO
	_tint.modulate = Color.WHITE
	if _has_been_used:
		state_chart.send_event(Types.EVENT_RESPAWN)
	_has_been_used = true


func _on_pool_despawned() -> void:
	if _lane != null:
		_lane.unregister(self)


## Configures a freshly spawned monster. Call right after Pools.spawn().
## [param power] is the escalation multiplier already applied to health and damage.
func setup(data: MonsterData, lane: BattleLane, max_health: float, damage: float, gold: float, boss: bool, power: float = 1.0) -> void:
	monster_data = data
	_lane = lane
	gold_reward = gold
	is_boss = boss
	spawn_power = power
	var campaign: CampaignConfig = GameConfig.get_default().campaign
	var race: MonsterRace = data.race if data != null else null
	if data != null:
		CharacterArt.place_health_bar(_health_bar, CharacterArt.apply(_art, _shape, data.icon, data.visual_size, data.color, data.shape_kind))
	# Placeholder shapes point right; monsters face the squad on the left
	# (their art is drawn that way). Flip the shape, not _visual: punches reset its scale.
	_shape.scale = Vector2(-1.0, 1.0)
	_body.scale = Vector2.ONE * (BOSS_SCALE if boss else 1.0)
	_flying_height = campaign.flying_height if data != null and data.is_flying() else 0.0
	_body.position.y = -_flying_height
	_can_revive = race != null and race.revive_health_fraction > 0.0
	var speed_multiplier: float = (data.speed_multiplier if data != null else 1.0) * (race.speed_multiplier if race != null else 1.0)
	lane_combat.lane = lane
	lane_combat.attack_damage = damage
	lane_combat.move_speed = campaign.monster_move_speed * speed_multiplier * (BOSS_SPEED_MULTIPLIER if boss else 1.0)
	lane_combat.attack_range = data.attack_range if data != null and data.attack_range > 0.0 else campaign.monster_attack_range
	lane_combat.attack_interval_seconds = campaign.monster_attack_interval_seconds
	lane_combat.can_hit_air = data.can_hit_air() if data != null else false
	lane_combat.race = race
	lane_combat.reset()
	health_component.revive(max_health)
	_join_lane(campaign, race)
	state_chart.send_event(Types.EVENT_TARGET_OUT_OF_RANGE)


func is_alive() -> bool:
	return not health_component.is_dead and not Pools.is_in_pool(self)


## The monster's body (raised for flyers) — where heroes aim.
func get_aim_point() -> Vector2:
	return _body.global_position


## Roots the monster: no moving or attacking for [param duration_seconds].
func snare(duration_seconds: float, tint: Color) -> void:
	lane_combat.stun(duration_seconds)
	var snare_tween: Tween = create_tween()
	snare_tween.tween_property(_tint, "modulate", tint.lightened(0.2), 0.1)
	snare_tween.tween_interval(maxf(duration_seconds - 0.2, 0.0))
	snare_tween.tween_property(_tint, "modulate", Color.WHITE, 0.1)


## Pushes the monster back toward its base; it walks in again.
func knock_back(distance: float) -> void:
	global_position.x += distance
	lane_combat.reset()
	state_chart.send_event(Types.EVENT_TARGET_OUT_OF_RANGE)


func _process(delta: float) -> void:
	if _flying_height <= 0.0:
		return
	_hover_time += delta * HOVER_BOB_SPEED
	_body.position.y = -_flying_height + sin(_hover_time) * HOVER_BOB_HEIGHT


func _exit_tree() -> void:
	if _lane != null:
		_lane.unregister(self)

# ============================================
# STATE CHART CALLBACKS (connected in Monster.tscn)
# ============================================

func _on_marching_state_physics_processing(delta: float) -> void:
	lane_combat.process_marching(delta)


func _on_fighting_state_physics_processing(delta: float) -> void:
	lane_combat.process_fighting(delta)


func _on_dead_state_entered() -> void:
	_lane.unregister(self)
	Profile.stats.increment(Types.STAT_ENEMIES_DEFEATED)
	if monster_data != null and monster_data.is_flying():
		Profile.stats.increment(Types.STAT_FLYERS_DEFEATED)
	if is_boss:
		Profile.stats.increment(Types.STAT_BOSSES_DEFEATED)
	Events.enemy_defeated.emit(self)
	defeated.emit(self)
	Audio.play_effect_at(boss_defeated_sound if is_boss and boss_defeated_sound != null else defeated_sound, get_aim_point())
	_death_tween = create_tween().set_parallel(true)
	_death_tween.tween_property(_body, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(_body, "modulate:a", 0.0, 0.18)
	_death_tween.chain().tween_callback(Pools.despawn.bind(self))


func _on_lane_combat_component_target_in_reach(_target: Node2D) -> void:
	state_chart.send_event(Types.EVENT_TARGET_IN_RANGE)


func _on_lane_combat_component_target_lost() -> void:
	state_chart.send_event(Types.EVENT_TARGET_OUT_OF_RANGE)


func _on_lane_combat_component_attacked(target: Node2D, _damage: float) -> void:
	if monster_data != null and monster_data.is_ranged:
		HeroBolt.launch(get_aim_point() - Vector2(monster_data.visual_size.x * 0.5, 6.0), _lane.get_aim_point(target), monster_data.color)
		TweenFX.punch_scale(_visual, 1.12, 0.14)
		Audio.play_effect_at(ranged_attack_sound, get_aim_point())
		return
	Audio.play_effect_at(melee_attack_sound, get_aim_point())
	if _lunge_tween != null:
		_lunge_tween.kill()
	_lunge_tween = create_tween()
	_lunge_tween.tween_property(_visual, "position:x", -LUNGE_DISTANCE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lunge_tween.tween_property(_visual, "position:x", 0.0, 0.16)

# ============================================
# INTERNALS
# ============================================

func _join_lane(campaign: CampaignConfig, race: MonsterRace) -> void:
	var visual_width: float = monster_data.visual_size.x if monster_data != null else 64.0
	var entry: BattleLane.LaneEntry = _lane.register(self, Types.Team.ENEMY, health_component, visual_width * 0.5 * _body.scale.x)
	defense = monster_data.defense if monster_data != null else 0.0
	if is_boss:
		defense = maxf(defense, campaign.boss_defense)
	defense = minf(defense + (race.defense_bonus if race != null else 0.0), campaign.max_defense)
	entry.defense = defense
	entry.layer = monster_data.layer if monster_data != null else Types.UnitLayer.GROUND
	entry.race = race
	entry.crit_damage_taken_multiplier = race.crit_damage_taken_multiplier if race != null else 1.0


## Undead get up once at a share of their health instead of dying.
func _on_health_died() -> void:
	if _can_revive:
		_can_revive = false
		health_component.revive(-1.0, monster_data.race.revive_health_fraction)
		FloatingText.spawn(tr("Rises again!"), get_aim_point() + Vector2(0.0, -60.0), REVIVE_TEXT_COLOR, 26)
		Audio.play_effect_at(revived_sound, get_aim_point())
		return
	state_chart.send_event(Types.EVENT_DIED)


func _on_damaged(damage_info: DamageInfo) -> void:
	var number_color: Color = CRIT_NUMBER_COLOR if damage_info.is_critical else DAMAGE_NUMBER_COLOR
	FloatingText.spawn(NumberFormat.compact(damage_info.amount), get_aim_point() + Vector2(randf_range(-24.0, 24.0), -50.0 * _body.scale.y), number_color, 40 if damage_info.is_critical else 28)
