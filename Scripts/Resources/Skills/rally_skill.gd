## Skill: a war cry that makes every living hero attack faster for a few
## seconds. Only fires while the caster has an enemy close by; never weakens
## a stronger boost that is already running (e.g. Rapid Fire).
##
## Dependencies: HeroSkill, Hero, BattleLane, LaneCombatComponent
class_name RallySkill
extends HeroSkill

@export var attack_speed_multiplier: float = 1.6
@export var duration_seconds: float = 5.0
## The caster needs an enemy within its reach plus this (px) to rally.
@export var trigger_extra_reach: float = 200.0


func get_effect_text() -> String:
	return TranslationServer.translate("Every hero attacks %sx faster for %ss.") % [String.num(attack_speed_multiplier, 1), String.num(duration_seconds, 1)]


func _cast(hero: Hero) -> bool:
	if hero.find_skill_target(trigger_extra_reach) == null:
		return false
	for unit: Node2D in hero.get_lane().get_living_units(Types.Team.PLAYER):
		var ally: Hero = unit as Hero
		if ally == null:
			continue
		ally.lane_combat.boost_attack_speed(attack_speed_multiplier, duration_seconds)
		ally.play_frenzy(duration_seconds, effect_color)
	return true
