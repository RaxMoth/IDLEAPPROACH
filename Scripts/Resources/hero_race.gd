## A hero race and its team synergy: with enough recruited heroes of the race,
## the whole squad gets a bonus to one stat (e.g. 2 Elves: +10% attack speed).
## Thresholds and bonuses are paired by index; the highest reached applies.
##
## Where it sits on the race wheel: CampaignConfig.race_matchups.
##
## Dependencies: UnitRace
class_name HeroRace
extends UnitRace

enum SynergyStat { ATTACK, HEALTH, ATTACK_SPEED, DEFENSE }

const STAT_NAMES: PackedStringArray = ["attack", "health", "attack speed", "defense"]

@export var synergy_stat: SynergyStat = SynergyStat.ATTACK
## Recruited heroes of this race needed for each tier.
@export var synergy_thresholds: PackedInt32Array = PackedInt32Array([2, 3])
## Bonus per tier (0.15 = +15%; defense is added as a share).
@export var synergy_bonuses: PackedFloat32Array = PackedFloat32Array([0.15, 0.3])


## Bonus for [param hero_count] recruited heroes of this race (0 below the first tier).
func get_bonus(hero_count: int) -> float:
	var bonus: float = 0.0
	for tier_index: int in mini(synergy_thresholds.size(), synergy_bonuses.size()):
		if hero_count >= synergy_thresholds[tier_index]:
			bonus = synergy_bonuses[tier_index]
	return bonus


func get_stat_name() -> String:
	return TranslationServer.translate(STAT_NAMES[synergy_stat])


## "2 Elves: +10% attack speed  •  3: +20%"
func describe_synergy() -> String:
	var parts: PackedStringArray = []
	for tier_index: int in mini(synergy_thresholds.size(), synergy_bonuses.size()):
		parts.append(TranslationServer.translate("%d: +%d%%") % [synergy_thresholds[tier_index], roundi(synergy_bonuses[tier_index] * 100.0)])
	return TranslationServer.translate("Team %s with %s heroes — %s") % [get_stat_name(), TranslationServer.translate(display_name), "  •  ".join(parts)]
