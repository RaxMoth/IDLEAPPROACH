## Skill: the hero attacks much faster for a few seconds. Only fires while
## something is in reach.
##
## Dependencies: HeroSkill, Hero, LaneCombatComponent
class_name FrenzySkill
extends HeroSkill

@export var attack_speed_multiplier: float = 2.5
@export var duration_seconds: float = 4.0


func get_effect_text() -> String:
	return TranslationServer.translate("Attacks %sx faster for %ss.") % [String.num(attack_speed_multiplier, 1), String.num(duration_seconds, 1)]


func _cast(hero: Hero) -> bool:
	if hero.lane_combat.is_attack_speed_boosted() or hero.find_skill_target(0.0) == null:
		return false
	hero.lane_combat.boost_attack_speed(attack_speed_multiplier, duration_seconds)
	hero.play_frenzy(duration_seconds, effect_color)
	return true
