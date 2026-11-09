## Derived numbers for the idle base battle: hero damage and health,
## monster stats per stage, base health, income per second and offline earnings.
## Combines hero levels (Profile.heroes), star bonuses (Profile.hero_stars),
## race synergies and relic levels (Profile.upgrades) so the battle, the hero
## list and offline earnings all agree.
##
##   var damage: float = CombatStats.get_hero_hit_damage(hero)
##   var base_health: float = CombatStats.get_player_base_health(stage)
##
## Dependencies: Profile autoload, GameConfig, CampaignConfig, RelicData, StarBonus
class_name CombatStats
extends RefCounted


static func get_campaign() -> CampaignConfig:
	return GameConfig.get_default().campaign


## Sum of get_value() over every relic with [param effect] (0 when none owned).
static func get_relic_bonus(effect: RelicData.Effect) -> float:
	var total_bonus: float = 0.0
	for relic: RelicData in get_campaign().relics:
		if relic.effect == effect:
			total_bonus += Profile.upgrades.get_value(relic)
	return total_bonus


## Relic and race synergy bonuses on every hero's attack.
static func get_hero_damage_multiplier() -> float:
	return (1.0 + get_relic_bonus(RelicData.Effect.HERO_DAMAGE)) * (1.0 + get_synergy_bonus(HeroRace.SynergyStat.ATTACK))


## Relic and race synergy bonuses on every hero's health.
static func get_hero_health_multiplier() -> float:
	return (1.0 + get_relic_bonus(RelicData.Effect.HERO_HEALTH)) * (1.0 + get_synergy_bonus(HeroRace.SynergyStat.HEALTH))


static func get_gold_multiplier() -> float:
	return 1.0 + get_relic_bonus(RelicData.Effect.GOLD_GAIN)


## Recruited heroes of [param race].
static func get_race_count(race: HeroRace) -> int:
	var race_count: int = 0
	for hero: HeroData in Profile.heroes.get_recruited_heroes():
		if hero.race == race:
			race_count += 1
	return race_count


## Team-wide bonus to [param stat] from every active race synergy.
static func get_synergy_bonus(stat: HeroRace.SynergyStat) -> float:
	var total_bonus: float = 0.0
	for race: HeroRace in get_campaign().hero_races:
		if race.synergy_stat == stat:
			total_bonus += race.get_bonus(get_race_count(race))
	return total_bonus


## Sum of every unlocked star bonus to [param stat] that reaches [param hero]:
## its own, the team-wide ones and those for its race, from every hero in the squad.
static func get_star_bonus(hero: HeroData, stat: StarBonus.Stat) -> float:
	var total_bonus: float = 0.0
	for owner_hero: HeroData in Profile.heroes.get_recruited_heroes():
		var unlocked_count: int = mini(Profile.hero_stars.get_stars(owner_hero.id), owner_hero.star_bonuses.size())
		for star_index: int in unlocked_count:
			var bonus: StarBonus = owner_hero.star_bonuses[star_index]
			if bonus != null and bonus.stat == stat and bonus.applies_to(owner_hero, hero):
				total_bonus += bonus.amount
	return total_bonus


## Relics, synergies and star bonuses on [param hero]'s attack.
static func get_hero_attack_multiplier(hero: HeroData) -> float:
	return get_hero_damage_multiplier() * (1.0 + get_star_bonus(hero, StarBonus.Stat.ATTACK))


## Relics, synergies and star bonuses on [param hero]'s health.
static func get_hero_health_multiplier_for(hero: HeroData) -> float:
	return get_hero_health_multiplier() * (1.0 + get_star_bonus(hero, StarBonus.Stat.HEALTH))


## Hits per second including the attack speed synergy and star bonuses.
static func get_hero_attacks_per_second(hero: HeroData) -> float:
	return hero.get_attacks_per_second() * (1.0 + get_synergy_bonus(HeroRace.SynergyStat.ATTACK_SPEED) + get_star_bonus(hero, StarBonus.Stat.ATTACK_SPEED))


## Defense including the defense synergy and star bonuses (capped).
static func get_hero_defense(hero: HeroData) -> float:
	return minf(hero.defense + get_synergy_bonus(HeroRace.SynergyStat.DEFENSE) + get_star_bonus(hero, StarBonus.Stat.DEFENSE), get_campaign().max_defense)


static func get_hero_move_speed(hero: HeroData) -> float:
	return hero.move_speed * (1.0 + get_star_bonus(hero, StarBonus.Stat.MOVE_SPEED))


static func get_hero_crit_chance(hero: HeroData) -> float:
	return minf(hero.crit_chance + get_star_bonus(hero, StarBonus.Stat.CRIT_CHANCE), 1.0)


## Average damage factor from crits (1 = no crits).
static func get_hero_crit_factor(hero: HeroData) -> float:
	return 1.0 + get_hero_crit_chance(hero) * (hero.crit_multiplier - 1.0)


static func get_hero_hit_damage(hero: HeroData) -> float:
	return hero.get_damage(Profile.heroes.get_level(hero.id)) * get_hero_attack_multiplier(hero)


## Expected damage per second (crits and every bonus included).
static func get_hero_damage_per_second(hero: HeroData) -> float:
	return get_hero_hit_damage(hero) * get_hero_attacks_per_second(hero) * get_hero_crit_factor(hero)


static func get_hero_max_health(hero: HeroData) -> float:
	return hero.get_health(Profile.heroes.get_level(hero.id)) * get_hero_health_multiplier_for(hero)


## Damage per second of every recruited hero.
static func get_team_damage_per_second() -> float:
	var team_dps: float = 0.0
	for hero: HeroData in get_campaign().heroes:
		team_dps += get_hero_damage_per_second(hero)
	return team_dps


static func get_player_base_health(stage: int) -> float:
	return get_campaign().get_player_base_health(stage) * (1.0 + get_relic_bonus(RelicData.Effect.BASE_HEALTH))


static func get_monster_health(stage: int, is_boss: bool, monster: MonsterData) -> float:
	var monster_multiplier: float = monster.health_multiplier if monster != null else 1.0
	return get_campaign().get_monster_health(stage, is_boss) * monster_multiplier


static func get_monster_damage(stage: int, is_boss: bool, monster: MonsterData) -> float:
	var monster_multiplier: float = monster.damage_multiplier if monster != null else 1.0
	return get_campaign().get_monster_damage(stage, is_boss) * monster_multiplier


## Whole gold per kill (rounded up) so balances and costs read as integers early on.
static func get_monster_gold(stage: int, is_boss: bool, monster: MonsterData) -> float:
	var monster_multiplier: float = monster.gold_multiplier if monster != null else 1.0
	return ceilf(get_campaign().get_monster_gold(stage, is_boss) * monster_multiplier * get_gold_multiplier())


## What every income payout is multiplied by right now (stage and gold relic).
static func get_income_multiplier() -> float:
	return get_campaign().get_income_stage_multiplier(Profile.campaign.current_stage) * get_gold_multiplier()


## Gold per second of every owned income source (stage and gold relic included).
static func get_income_per_second() -> float:
	var gold_per_second: float = 0.0
	for source: IncomeSourceData in get_campaign().income_sources:
		gold_per_second += source.get_gold_per_second(Profile.income.get_level(source.id))
	return gold_per_second * get_income_multiplier()


## Kill gold per second the squad's DPS could make on [param stage], capped by
## how fast the enemy base sends monsters (offline estimate).
static func estimate_kill_gold_per_second(stage: int) -> float:
	var campaign: CampaignConfig = get_campaign()
	var monster_health: float = campaign.get_monster_health(stage, false)
	var kills_per_second: float = minf(get_team_damage_per_second() / maxf(monster_health, 0.001), campaign.get_max_spawn_rate())
	return kills_per_second * campaign.get_monster_gold(stage, false) * get_gold_multiplier()


## Gold per second while away: income sources keep running, kills count partly.
static func estimate_offline_gold_per_second(stage: int) -> float:
	var campaign: CampaignConfig = get_campaign()
	return get_income_per_second() * campaign.offline_income_efficiency + estimate_kill_gold_per_second(stage) * campaign.offline_efficiency
