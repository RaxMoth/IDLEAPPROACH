## What one star of a hero unlocks: a bonus to one stat for the hero itself,
## the whole squad or every hero of one race (e.g. 1 star: +10% attack,
## 2 stars: team +100% move speed, 3 stars: Humans +50% attack).
## HeroData.star_bonuses lists them in star order; a hero with N stars has the
## first N. Team and race bonuses work while their hero is in the squad.
##
## Instances are sub-resources of the hero files in Ressources/Heroes/.
##
## Dependencies: HeroData, HeroRace
class_name StarBonus
extends Resource

enum Stat { ATTACK, HEALTH, ATTACK_SPEED, DEFENSE, MOVE_SPEED, CRIT_CHANCE }
enum Scope { SELF, TEAM, RACE }

@export var stat: Stat = Stat.ATTACK
## 0.1 = +10%. Defense and crit chance add it as a share (0.05 = +5 points).
@export var amount: float = 0.1
@export var scope: Scope = Scope.SELF
## Scope RACE: heroes of this race get the bonus.
@export var race: HeroRace


## Whether the bonus of [param owner_hero] reaches [param target_hero].
func applies_to(owner_hero: HeroData, target_hero: HeroData) -> bool:
	match scope:
		Scope.TEAM:
			return true
		Scope.RACE:
			return race != null and target_hero.race == race
	return target_hero == owner_hero


## "+10%" (or "+5%" points for defense / crit chance).
func format_amount() -> String:
	return "+%d%%" % roundi(amount * 100.0)
