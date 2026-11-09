## Skill: a shot at every monster (and the enemy base) within reach.
##
## Dependencies: HeroSkill, Hero, HeroBolt
class_name VolleySkill
extends HeroSkill

@export var damage_multiplier: float = 1.5
## Reach of the volley (px); never shorter than the hero's own attack range.
@export var reach: float = 340.0


func get_effect_text() -> String:
	return TranslationServer.translate("Shoots every enemy in reach for %sx damage.") % String.num(damage_multiplier, 1)


func _cast(hero: Hero) -> bool:
	var targets: Array[Node2D] = hero.get_lane().find_targets_in_reach(Types.Team.PLAYER, hero.global_position.x, maxf(reach, hero.hero_data.attack_range), hero.hero_data.can_hit_air())
	if targets.is_empty():
		return false
	var damage: float = hero.get_hit_damage() * damage_multiplier
	for target: Node2D in targets:
		HeroBolt.launch(hero.get_attack_origin(), hero.get_aim_position(target), effect_color)
		hero.deal_skill_damage(target, damage)
	return true
