## Skill: one heavy blow on the hero's current target, optionally knocking a
## monster back so it has to walk in again.
##
## Dependencies: HeroSkill, Hero, Monster
class_name StrikeSkill
extends HeroSkill

@export var damage_multiplier: float = 4.0
## Pixels a monster is pushed back toward its base (0 = none).
@export var knockback_distance: float = 60.0


func get_effect_text() -> String:
	var multiplier_text: String = String.num(damage_multiplier, 1)
	if knockback_distance > 0.0:
		return TranslationServer.translate("Hits the target for %sx damage and knocks it back.") % multiplier_text
	return TranslationServer.translate("Hits the target for %sx damage.") % multiplier_text


func _cast(hero: Hero) -> bool:
	var target: Node2D = hero.find_skill_target(0.0)
	if target == null:
		return false
	hero.play_attack_visual(target)
	hero.deal_skill_damage(target, hero.get_hit_damage() * damage_multiplier)
	var monster: Monster = target as Monster
	if knockback_distance > 0.0 and monster != null and monster.is_alive():
		monster.knock_back(knockback_distance)
	return true
