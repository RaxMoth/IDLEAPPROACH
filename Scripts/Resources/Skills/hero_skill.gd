## Base for a hero's auto-cast skill (an AbilityData). Heroes try their skill
## on their own while alive — no buttons. _cast() returns false when the skill
## can't help right now (nothing in reach, nobody hurt), so the cooldown only
## starts when it really fired. Damage scales with the caster's hit damage,
## so levels, stars and relics all make skills stronger.
## The resource is shared by every caster: keep per-cast state on the Hero.
##
## Dependencies: AbilityData, Hero, SoundEffect
class_name HeroSkill
extends AbilityData

## Color of the skill name popup and effect visuals.
@export var effect_color: Color = Color.WHITE
## Played at the caster when the skill fires.
@export var cast_sound: SoundEffect


## @virtual Player-facing line with this skill's numbers ("4x damage and knockback").
func get_effect_text() -> String:
	return ""


func activate(caster: Node2D) -> bool:
	var hero: Hero = caster as Hero
	if hero == null or hero.is_fallen():
		return false
	return _cast(hero)


## @virtual Performs the skill for [param hero]. Return false to skip (no cooldown).
func _cast(_hero: Hero) -> bool:
	return false
