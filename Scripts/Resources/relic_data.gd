## Permanent upgrade bought with souls (the rebirth currency). Relic levels
## survive rebirths because they are stored in Profile.upgrades like any
## UpgradeData; the effect tells CombatStats which number to boost.
##
## The bonus is get_value(level): e.g. value_per_level 0.5 on HERO_DAMAGE
## means +50% hero damage per level.
##
## Dependencies: UpgradeData
class_name RelicData
extends UpgradeData

enum Effect {
	## Multiplies the damage of every hero.
	HERO_DAMAGE,
	## Multiplies the health of every hero.
	HERO_HEALTH,
	## Multiplies gold from monsters, base income and offline earnings.
	GOLD_GAIN,
	## Multiplies the health of the player's base.
	BASE_HEALTH,
}

@export var effect: Effect = Effect.HERO_DAMAGE


## Player-facing bonus at [param level], e.g. "+150% hero damage".
func describe_bonus(level: int) -> String:
	var percent: int = roundi(get_value(level) * 100.0)
	match effect:
		Effect.HERO_DAMAGE:
			return TranslationServer.translate("+%d%% hero damage") % percent
		Effect.HERO_HEALTH:
			return TranslationServer.translate("+%d%% hero health") % percent
		Effect.GOLD_GAIN:
			return TranslationServer.translate("+%d%% gold") % percent
		Effect.BASE_HEALTH:
			return TranslationServer.translate("+%d%% base health") % percent
	return ""
