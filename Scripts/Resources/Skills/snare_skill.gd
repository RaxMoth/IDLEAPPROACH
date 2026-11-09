## Skill: roots every monster in reach (they can't move or attack for a
## moment) and deals a little damage. Bosses shake it off in half the time.
##
## Dependencies: HeroSkill, Hero, Monster, SkillBurst
class_name SnareSkill
extends HeroSkill

@export var damage_multiplier: float = 0.5
## Reach of the snare (px); never shorter than the hero's own attack range.
@export var reach: float = 300.0
@export var duration_seconds: float = 2.5
## Bosses are snared for this share of the duration.
@export_range(0.0, 1.0) var boss_duration_factor: float = 0.5


func get_effect_text() -> String:
	return TranslationServer.translate("Roots every enemy in reach for %ss (bosses half as long) and hits them for %sx damage.") % [String.num(duration_seconds, 1), String.num(damage_multiplier, 1)]


func _cast(hero: Hero) -> bool:
	var targets: Array[Node2D] = hero.get_lane().find_targets_in_reach(Types.Team.PLAYER, hero.global_position.x, maxf(reach, hero.hero_data.attack_range), hero.hero_data.can_hit_air())
	var snared_any: bool = false
	var damage: float = hero.get_hit_damage() * damage_multiplier
	for target: Node2D in targets:
		var monster: Monster = target as Monster
		if monster == null:
			continue
		monster.snare(duration_seconds * (boss_duration_factor if monster.is_boss else 1.0), effect_color)
		SkillBurst.play(hero.get_aim_position(monster), 40.0, effect_color)
		hero.deal_skill_damage(monster, damage)
		snared_any = true
	return snared_any
