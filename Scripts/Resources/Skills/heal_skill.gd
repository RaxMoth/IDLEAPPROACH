## Skill: heals every living hero (and optionally the player's base) by a
## share of their maximum health. Only fires when someone is hurt.
##
## Dependencies: HeroSkill, Hero, BattleLane, BattleBase, SkillBurst, FloatingText
class_name HealSkill
extends HeroSkill

const HEAL_TEXT_COLOR: Color = Color(0.45, 1.0, 0.5)
## Below this share of max health a target counts as hurt.
const HURT_THRESHOLD: float = 0.95

## Share of each hero's max health restored (0.3 = 30%).
@export_range(0.0, 1.0) var hero_heal_fraction: float = 0.3
## Share of the player's base max health restored (0 = heroes only).
@export_range(0.0, 1.0) var base_heal_fraction: float = 0.0


func get_effect_text() -> String:
	var hero_percent: int = roundi(hero_heal_fraction * 100.0)
	if base_heal_fraction > 0.0:
		return TranslationServer.translate("Heals every hero by %d%% of their health and your base by %d%%.") % [hero_percent, roundi(base_heal_fraction * 100.0)]
	return TranslationServer.translate("Heals every hero by %d%% of their health.") % hero_percent


func _cast(hero: Hero) -> bool:
	var lane: BattleLane = hero.get_lane()
	var patients: Array[Node2D] = []
	if hero_heal_fraction > 0.0:
		patients.append_array(lane.get_living_units(Types.Team.PLAYER))
	var player_base: BattleBase = lane.get_base(Types.Team.PLAYER) if base_heal_fraction > 0.0 else null
	if player_base != null and not player_base.is_destroyed():
		patients.append(player_base)
	var hurt_patients: Array[Node2D] = []
	for patient: Node2D in patients:
		if _is_hurt(lane.get_health(patient)):
			hurt_patients.append(patient)
	if hurt_patients.is_empty():
		return false
	for patient: Node2D in hurt_patients:
		var health: HealthComponent = lane.get_health(patient)
		var fraction: float = base_heal_fraction if patient is BattleBase else hero_heal_fraction
		var heal_amount: float = health.max_health * fraction
		health.heal(heal_amount)
		var aim_position: Vector2 = hero.get_aim_position(patient)
		SkillBurst.play(aim_position, 50.0, effect_color)
		FloatingText.spawn("+%s" % NumberFormat.compact(roundf(heal_amount)), aim_position + Vector2(0.0, -40.0), HEAL_TEXT_COLOR, 28)
	return true


func _is_hurt(health: HealthComponent) -> bool:
	return health != null and not health.is_dead and health.current_health < health.max_health * HURT_THRESHOLD
