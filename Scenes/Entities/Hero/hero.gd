## A hero fighting in the battle lane: leaves the player's base walking
## right, stops to fight the first monster (or the enemy base) in reach and
## respawns at its rally point a few seconds after falling. Melee heroes have
## a short reach and lunge; ranged heroes stop further back and shoot.
## Flying heroes hover above the lane: ground melee monsters can't hit them,
## and only ranged / flying heroes can hit flying monsters.
## State: Alive { Waiting -> Marching <-> Fighting } -> Dead -> Alive (after
## respawn_seconds, or at once on Types.EVENT_RESPAWN when a new stage starts).
## Waiting lasts release_seconds so the squad leaves the base one by one;
## Types.EVENT_STAGE_RESTART sends a living hero back to Waiting.
## While marching or fighting the hero also tries its HeroSkill (auto-cast
## through the AbilityComponent; the skill decides whether it can help).
##
## Sounds: HeroData.attack_sound per attack, HeroSkill.cast_sound per skill,
## plus this scene's defeated / respawned sounds (all positional).
##
## Dependencies: Types, Audio autoloads, HeroData, CombatStats, LaneCombatComponent,
##               AbilityComponent, HeroSkill, HealthComponent, BattleLane,
##               HeroBolt, FloatingText, TweenFX, SoundEffect, CharacterArt
class_name Hero
extends Node2D

const MARCH_BOB_HEIGHT: float = 8.0
const MARCH_BOB_SPEED: float = 10.0
const MAX_LUNGE_DISTANCE: float = 40.0
const LUNGE_SECONDS: float = 0.08
const FALLEN_ALPHA: float = 0.2
## Skills are retried on this interval while they can't fire (nothing to hit, nobody hurt).
const SKILL_RETRY_SECONDS: float = 0.2
const SKILL_SLOT: int = 0
const HOVER_BOB_HEIGHT: float = 6.0
const HOVER_BOB_SPEED: float = 3.0
## Size of the skill icon that pops up when a skill fires.
const SKILL_ICON_SIZE: float = 60.0

@export_group("Sounds")
@export var defeated_sound: SoundEffect
@export var respawned_sound: SoundEffect

var hero_data: HeroData
## Rally point next to the player's base (spawn and respawn spot).
var home_position: Vector2 = Vector2.ZERO

var _lane: BattleLane
var _is_fallen: bool = false
var _march_time: float = 0.0
var _lunge_tween: Tween
var _frenzy_tween: Tween
var _skill_retry_remaining: float = 0.0
var _flying_height: float = 0.0

@onready var health_component: HealthComponent = %HealthComponent
@onready var lane_combat: LaneCombatComponent = %LaneCombatComponent
@onready var ability_component: AbilityComponent = %AbilityComponent
@onready var state_chart: StateChart = %StateChart
@onready var _body: Node2D = %Body
@onready var _visual: Node2D = %Visual
# Skill tints go here so they don't fight the hit flash on _visual.
@onready var _tint: Node2D = %Tint
@onready var _art: Sprite2D = %Art
@onready var _shape: PlaceholderShape = %Shape
@onready var _health_bar: Control = %HealthBarComponent


func _ready() -> void:
	health_component.died.connect(func() -> void: state_chart.send_event(Types.EVENT_DIED))


## Call right after adding the hero to the tree. [param release_seconds] is how
## long the hero waits at the base before marching out (staggered per hero).
func setup(data: HeroData, lane: BattleLane, rally_position: Vector2, respawn_seconds: float, release_seconds: float) -> void:
	hero_data = data
	_lane = lane
	home_position = rally_position
	CharacterArt.place_health_bar(_health_bar, CharacterArt.apply(_art, _shape, data.icon, data.visual_size, data.color, data.shape_kind))
	lane_combat.lane = lane
	lane_combat.attack_range = data.attack_range
	lane_combat.attack_interval_seconds = data.attack_interval_seconds
	lane_combat.crit_multiplier = data.crit_multiplier
	lane_combat.can_hit_air = data.can_hit_air()
	lane_combat.race = data.race
	_flying_height = GameConfig.get_default().campaign.flying_height if data.is_flying() else 0.0
	_body.position.y = -_flying_height
	state_chart.set_expression_property(Types.EXPRESSION_RESPAWN_SECONDS, respawn_seconds)
	state_chart.set_expression_property(Types.EXPRESSION_RELEASE_SECONDS, release_seconds)
	global_position = rally_position
	_march_time = randf() * TAU
	health_component.revive(CombatStats.get_hero_max_health(data))
	refresh_stats()
	lane_combat.reset()
	var skills: Array[AbilityData] = []
	if data.skill != null:
		skills.append(data.skill)
	ability_component.set_abilities(skills)
	ability_component.reset_cooldowns(randf_range(0.3, 0.7))
	_join_lane()
	TweenFX.bounce_in(_body)


## Re-reads every derived stat after a level up, star (own, team or race
## bonus), relic or new recruit (race synergies) and heals the gained health.
func refresh_stats() -> void:
	lane_combat.attack_damage = CombatStats.get_hero_hit_damage(hero_data)
	lane_combat.move_speed = CombatStats.get_hero_move_speed(hero_data)
	lane_combat.crit_chance = CombatStats.get_hero_crit_chance(hero_data)
	lane_combat.attack_interval_seconds = 1.0 / CombatStats.get_hero_attacks_per_second(hero_data)
	health_component.set_max_health(CombatStats.get_hero_max_health(hero_data), true)
	if not _is_fallen and _lane != null:
		_join_lane()


## Back to the rally point at full health for a new stage.
func reset_for_stage() -> void:
	global_position = home_position
	health_component.revive(CombatStats.get_hero_max_health(hero_data))
	lane_combat.reset()
	ability_component.reset_cooldowns(randf_range(0.3, 0.7))
	_end_frenzy_visual()
	_body.modulate.a = 1.0
	_is_fallen = false
	_join_lane()
	state_chart.send_event(Types.EVENT_RESPAWN)
	state_chart.send_event(Types.EVENT_STAGE_RESTART)


func is_fallen() -> bool:
	return _is_fallen


func play_level_up() -> void:
	TweenFX.pop(_body, 1.25, 0.3)
	SkillBurst.play(get_aim_point(), hero_data.visual_size.x * 0.8, hero_data.color)

# ============================================
# SKILL API (used by HeroSkill subclasses)
# ============================================

func get_lane() -> BattleLane:
	return _lane


func get_hit_damage() -> float:
	return lane_combat.attack_damage


## Nearest enemy the hero can hit within its reach plus [param extra_reach], or null.
func find_skill_target(extra_reach: float) -> Node2D:
	return _lane.find_target(Types.Team.PLAYER, global_position.x, hero_data.attack_range + extra_reach, hero_data.can_hit_air())


## Skill damage goes through the target's defense and shows as a big number.
func deal_skill_damage(target: Node2D, amount: float) -> void:
	_lane.apply_hit(target, amount, true, self, hero_data.race)


## The hero's body (raised for flyers) — where enemies aim.
func get_aim_point() -> Vector2:
	return _body.global_position


## Front of the hero's body, where shots start.
func get_attack_origin() -> Vector2:
	return _body.global_position + Vector2(hero_data.visual_size.x * 0.5, -6.0)


## Where to aim at [param target] (flyers' bodies, the middle of a base).
func get_aim_position(target: Node2D) -> Vector2:
	return _lane.get_aim_point(target)


## Melee lunge or ranged shot toward [param target] (normal attacks and strikes).
func play_attack_visual(target: Node2D) -> void:
	if hero_data.is_ranged():
		HeroBolt.launch(get_attack_origin(), get_aim_position(target), hero_data.color)
	else:
		if _lunge_tween != null:
			_lunge_tween.kill()
		_lunge_tween = create_tween()
		_lunge_tween.tween_property(_visual, "position:x", MAX_LUNGE_DISTANCE, LUNGE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_lunge_tween.tween_property(_visual, "position:x", 0.0, LUNGE_SECONDS * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	TweenFX.punch_scale(_visual, 1.12, 0.14)


## Pulsing tint while an attack-speed skill lasts.
func play_frenzy(duration_seconds: float, color: Color) -> void:
	_end_frenzy_visual()
	var pulse_count: int = maxi(1, roundi(duration_seconds / 0.4))
	_frenzy_tween = create_tween().set_loops(pulse_count)
	_frenzy_tween.tween_property(_tint, "modulate", color.lightened(0.3), 0.2)
	_frenzy_tween.tween_property(_tint, "modulate", Color.WHITE, 0.2)


func _process(delta: float) -> void:
	if _flying_height <= 0.0:
		return
	_march_time += delta * HOVER_BOB_SPEED
	_body.position.y = -_flying_height + sin(_march_time) * HOVER_BOB_HEIGHT


func _exit_tree() -> void:
	if _lane != null:
		_lane.unregister(self)

# ============================================
# STATE CHART CALLBACKS (connected in Hero.tscn)
# ============================================

func _on_alive_state_entered() -> void:
	if not _is_fallen:
		return
	_is_fallen = false
	global_position = home_position
	health_component.revive(CombatStats.get_hero_max_health(hero_data))
	lane_combat.reset()
	_join_lane()
	create_tween().tween_property(_body, "modulate:a", 1.0, 0.25)
	SkillBurst.play(get_aim_point(), hero_data.visual_size.x * 0.7, Color.WHITE)
	Audio.play_effect_at(respawned_sound, get_aim_point())


func _on_marching_state_physics_processing(delta: float) -> void:
	lane_combat.process_marching(delta)
	_try_cast_skill(delta)
	_march_time += delta * MARCH_BOB_SPEED
	# Flyers glide; walkers bob with each step.
	_visual.position.y = 0.0 if hero_data.is_flying() else -absf(sin(_march_time)) * MARCH_BOB_HEIGHT


func _on_marching_state_exited() -> void:
	_visual.position.y = 0.0


func _on_fighting_state_physics_processing(delta: float) -> void:
	lane_combat.process_fighting(delta)
	_try_cast_skill(delta)


func _on_dead_state_entered() -> void:
	_is_fallen = true
	_lane.unregister(self)
	_end_frenzy_visual()
	create_tween().tween_property(_body, "modulate:a", FALLEN_ALPHA, 0.3)
	Audio.play_effect_at(defeated_sound, get_aim_point())


func _on_lane_combat_component_target_in_reach(_target: Node2D) -> void:
	state_chart.send_event(Types.EVENT_TARGET_IN_RANGE)


func _on_lane_combat_component_target_lost() -> void:
	state_chart.send_event(Types.EVENT_TARGET_OUT_OF_RANGE)


func _on_lane_combat_component_attacked(target: Node2D, _damage: float) -> void:
	play_attack_visual(target)
	Audio.play_effect_at(hero_data.attack_sound, get_attack_origin())


func _on_ability_component_ability_activated(_slot_index: int, ability: AbilityData) -> void:
	var skill: HeroSkill = ability as HeroSkill
	var callout_position: Vector2 = get_aim_point() + Vector2(0.0, -70.0)
	if ability.icon != null:
		FloatingText.spawn_icon(ability.icon, callout_position, SKILL_ICON_SIZE)
	else:
		FloatingText.spawn(tr(ability.title), callout_position, skill.effect_color if skill != null else Color.WHITE, 26)
	if skill != null:
		Audio.play_effect_at(skill.cast_sound, get_aim_point())

# ============================================
# INTERNALS
# ============================================

func _join_lane() -> void:
	var entry: BattleLane.LaneEntry = _lane.register(self, Types.Team.PLAYER, health_component, hero_data.visual_size.x * 0.5)
	entry.defense = CombatStats.get_hero_defense(hero_data)
	entry.layer = hero_data.layer
	entry.race = hero_data.race


func _try_cast_skill(delta: float) -> void:
	_skill_retry_remaining -= delta
	if _skill_retry_remaining > 0.0:
		return
	_skill_retry_remaining = SKILL_RETRY_SECONDS
	ability_component.try_activate(SKILL_SLOT)


func _end_frenzy_visual() -> void:
	if _frenzy_tween != null:
		_frenzy_tween.kill()
		_frenzy_tween = null
	_tint.modulate = Color.WHITE
