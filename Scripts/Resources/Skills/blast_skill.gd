## Skill: an explosion on the hero's current target that also hits every
## enemy around it.
##
## Dependencies: HeroSkill, Hero, SkillBurst
class_name BlastSkill
extends HeroSkill

@export var damage_multiplier: float = 3.0
## Blast radius around the target (px).
@export var radius: float = 110.0


func get_effect_text() -> String:
	return TranslationServer.translate("Blasts the target and everything near it for %sx damage.") % String.num(damage_multiplier, 1)


func _cast(hero: Hero) -> bool:
	var target: Node2D = hero.find_skill_target(0.0)
	if target == null:
		return false
	var center: Vector2 = hero.get_aim_position(target)
	SkillBurst.play(center, radius, effect_color)
	var damage: float = hero.get_hit_damage() * damage_multiplier
	for victim: Node2D in hero.get_lane().find_opponents_near(Types.Team.PLAYER, target.global_position.x, radius):
		hero.deal_skill_damage(victim, damage)
	return true
