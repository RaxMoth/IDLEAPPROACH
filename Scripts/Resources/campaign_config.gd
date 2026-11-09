## Tuning for the idle base battle: the enemy base, the monsters it sends,
## the player's base, timed gold sources, heroes, relics, rebirth and offline gold.
## The full stat model is described in Docs/GAME_DESIGN.md.
##
## Edit Ressources/campaign.tres in the inspector. Read it anywhere with
## GameConfig.get_default().campaign.
##
## Every stage value grows exponentially: value(S) = base * growth ^ (S - 1).
## Destroying the enemy base advances one stage; losing the player's base
## drops one stage. Every zone_length-th stage the enemy base also sends a boss.
##
## Dependencies: HeroData, MonsterZone, RelicData, IncomeSourceData
class_name CampaignConfig
extends Resource

@export_group("Stages")
## Stages per zone. A zone changes the monster set; its last stage sends a boss.
@export var zone_length: int = 10
## Pause after a base falls before the next stage starts (seconds).
@export var stage_end_seconds: float = 1.6
## From this stage on, enemies (monsters and the enemy base) grow an extra
## late_game_growth per stage, so a strong late-game squad still meets walls.
@export var late_game_start_stage: int = 60
@export var late_game_growth: float = 1.04
@export var zone_monsters: Array[MonsterZone] = []

@export_group("Enemy base")
@export var enemy_base_health: float = 150.0
@export var enemy_base_health_growth: float = 1.17
## Seconds between groups of monsters leaving the enemy base.
@export var spawn_interval_seconds: float = 3.2
@export var min_monsters_per_spawn: int = 1
@export var max_monsters_per_spawn: int = 2
## The enemy base stops sending while this many monsters are alive.
@export var max_alive_monsters: int = 8
## Monsters sent later in a stage are stronger: health and damage x growth ^ seconds.
## Compounding breaks stalemates: a squad that can't break the base in time
## gets overrun and drops a stage (1.0 = off).
@export var enemy_escalation_growth: float = 1.012

@export_group("Monsters")
@export var monster_base_health: float = 12.0
@export var monster_health_growth: float = 1.16
@export var monster_base_damage: float = 3.0
@export var monster_damage_growth: float = 1.15
@export var monster_attack_interval_seconds: float = 1.2
@export var monster_move_speed: float = 75.0
@export var monster_attack_range: float = 40.0
@export var monster_base_gold: float = 2.0
@export var monster_gold_growth: float = 1.15
## Bosses block this much damage unless their MonsterData says more.
@export_range(0.0, 0.9) var boss_defense: float = 0.2
@export var boss_health_multiplier: float = 12.0
@export var boss_damage_multiplier: float = 4.0
@export var boss_gold_multiplier: float = 15.0

@export_group("Player base")
## Grows with monster damage so later stages stay a fight.
@export var player_base_health: float = 200.0
@export var player_base_health_growth: float = 1.15

@export_group("Income")
## Timed gold sources in unlock order. The first one starts at level 1.
@export var income_sources: Array[IncomeSourceData] = []
## Income payouts grow by this factor per stage (keeps them in step with kill gold).
@export var income_stage_growth: float = 1.15

@export_group("Combat rules")
## No unit blocks more than this share of a hit, whatever its defense.
@export_range(0.0, 0.95) var max_defense: float = 0.75
## How high flyers hover above the lane (visual only).
@export var flying_height: float = 110.0

@export_group("Races")
## Every hero race (team synergies), listed for the UI.
@export var hero_races: Array[HeroRace] = []
## Every monster race (traits), listed for the UI.
@export var monster_races: Array[MonsterRace] = []
## The race wheel (rock, paper, scissors): who beats whom. Hero and monster
## races alternate, so each race beats one race and loses to another.
@export var race_matchups: Array[RaceMatchup] = []
## Extra damage when the attacker's race beats the target's (0.5 = +50%).
@export var race_counter_bonus: float = 0.5
## Less damage when the attacker's race loses to the target's (0.25 = -25%).
@export_range(0.0, 0.95) var race_counter_penalty: float = 0.25

@export_group("Heroes")
## Every hero (the hero index order). The first one is in the collection
## from the start; the others come from hero chests.
@export var heroes: Array[HeroData] = []
## Seconds a fallen hero needs to get back on its feet at the base.
@export var hero_respawn_seconds: float = 4.0

@export_group("Stars")
## Each star unlocks the hero's next StarBonus (HeroData.star_bonuses).
## Stars and shards are permanent (they survive rebirth).
## Shards needed for each next star; its size is the max star count.
@export var star_shard_costs: PackedInt32Array = PackedInt32Array([10, 25, 50, 100, 200])
## Shards of one random hero for every destroyed enemy base (boss stages give more).
@export var shards_per_enemy_base: int = 1
@export var shards_per_boss_base: int = 5
## Chance weight per HeroData.Rarity (Common, Rare, Epic, Legendary, Mythic).
@export var rarity_drop_weights: PackedFloat32Array = PackedFloat32Array([50.0, 30.0, 14.0, 5.0, 1.0])
## Shards per gem purchase in the hero popup (gems come from achievements and daily rewards).
@export var shard_pack_size: int = 5
## Gem price of one shard pack per HeroData.Rarity (Common, Rare, Epic, Legendary, Mythic).
@export var shard_pack_gem_costs: PackedInt32Array = PackedInt32Array([20, 30, 45, 70, 100])

@export_group("Hero chest")
## A chest gives one random hero (weighted by rarity). A hero already in the
## collection comes as shards instead.
## Gems for one chest when the player has no chest key.
@export var chest_gem_cost: int = 150
## Clearing every Nth stage for the first time in a run drops a chest key.
@export var chest_key_stage_interval: int = 5
## Extra keys for clearing a boss stage for the first time in a run.
@export var chest_keys_per_boss: int = 1
## Chance weight per hero of each HeroData.Rarity (Common, Rare, Epic, Legendary, Mythic).
@export var chest_rarity_weights: PackedFloat32Array = PackedFloat32Array([50.0, 30.0, 14.0, 5.0, 1.0])
## While the collection is smaller than this, chests always give a new hero.
@export var chest_guaranteed_new_until: int = 4
## A duplicate is rerolled this many times before it's accepted (luck protection).
@export var chest_duplicate_rerolls: int = 1
## Shards a duplicate gives, per HeroData.Rarity.
@export var chest_duplicate_shards: PackedInt32Array = PackedInt32Array([5, 6, 8, 10, 12])

@export_group("Rebirth")
## Highest stage needed before rebirth is allowed.
@export var rebirth_min_stage: int = 40
## Souls = floor(rebirth_soul_base * (highest_stage / rebirth_min_stage) ^ rebirth_soul_exponent)
@export var rebirth_soul_base: float = 5.0
@export var rebirth_soul_exponent: float = 3.0
@export var relics: Array[RelicData] = []

@export_group("Offline")
## Share of the online kill gold earned while away.
@export var offline_efficiency: float = 0.5
## Share of the income sources' gold earned while away (they keep running).
@export var offline_income_efficiency: float = 1.0
@export var max_offline_hours: float = 8.0
## Shorter absences pay their gold without the "Welcome back" popup.
@export var min_offline_popup_seconds: float = 60.0


func is_boss_stage(stage: int) -> bool:
	return zone_length > 0 and stage % zone_length == 0


func get_zone_index(stage: int) -> int:
	return floori(float(stage - 1) / maxi(1, zone_length))


func get_zone(stage: int) -> MonsterZone:
	if zone_monsters.is_empty():
		return null
	return zone_monsters[get_zone_index(stage) % zone_monsters.size()]


## Extra enemy multiplier past late_game_start_stage (1 before it).
func get_late_game_multiplier(stage: int) -> float:
	return pow(late_game_growth, maxi(0, stage - late_game_start_stage))


func get_enemy_base_health(stage: int) -> float:
	return enemy_base_health * pow(enemy_base_health_growth, stage - 1) * get_late_game_multiplier(stage)


func get_player_base_health(stage: int) -> float:
	return player_base_health * pow(player_base_health_growth, stage - 1)


func get_monster_health(stage: int, is_boss: bool) -> float:
	var health: float = monster_base_health * pow(monster_health_growth, stage - 1) * get_late_game_multiplier(stage)
	return health * boss_health_multiplier if is_boss else health


func get_monster_damage(stage: int, is_boss: bool) -> float:
	var damage: float = monster_base_damage * pow(monster_damage_growth, stage - 1) * get_late_game_multiplier(stage)
	return damage * boss_damage_multiplier if is_boss else damage


func get_monster_gold(stage: int, is_boss: bool) -> float:
	var gold: float = monster_base_gold * pow(monster_gold_growth, stage - 1)
	return gold * boss_gold_multiplier if is_boss else gold


## Payout multiplier of every income source on [param stage].
func get_income_stage_multiplier(stage: int) -> float:
	return pow(income_stage_growth, stage - 1)


## Health and damage multiplier for monsters sent [param stage_seconds] into a stage.
func get_enemy_power_multiplier(stage_seconds: float) -> float:
	return pow(enemy_escalation_growth, maxf(stage_seconds, 0.0))


## Most monsters per second the enemy base can send (caps offline kill rates).
func get_max_spawn_rate() -> float:
	return (min_monsters_per_spawn + max_monsters_per_spawn) * 0.5 / maxf(spawn_interval_seconds, 0.1)


func get_souls_for_rebirth(highest_stage: int) -> int:
	if highest_stage < rebirth_min_stage or rebirth_min_stage <= 0:
		return 0
	return floori(rebirth_soul_base * pow(float(highest_stage) / rebirth_min_stage, rebirth_soul_exponent))


func get_shard_pack_cost(hero: HeroData) -> int:
	return shard_pack_gem_costs[mini(hero.rarity, shard_pack_gem_costs.size() - 1)] if not shard_pack_gem_costs.is_empty() else 0


## 1 when [param attacker_race] beats [param defender_race] on the race
## wheel, -1 when it loses to it, 0 otherwise (or when either is null).
func get_race_matchup(attacker_race: UnitRace, defender_race: UnitRace) -> int:
	if attacker_race == null or defender_race == null:
		return 0
	for matchup: RaceMatchup in race_matchups:
		if matchup.strong_race == attacker_race and matchup.weak_race == defender_race:
			return 1
		if matchup.strong_race == defender_race and matchup.weak_race == attacker_race:
			return -1
	return 0


## Damage factor for a hit from [param attacker_race] on [param defender_race].
func get_race_damage_multiplier(attacker_race: UnitRace, defender_race: UnitRace) -> float:
	match get_race_matchup(attacker_race, defender_race):
		1:
			return 1.0 + race_counter_bonus
		-1:
			return 1.0 - race_counter_penalty
	return 1.0


## Races [param race] beats on the wheel.
func get_races_beaten_by(race: UnitRace) -> Array[UnitRace]:
	var beaten: Array[UnitRace] = []
	for matchup: RaceMatchup in race_matchups:
		if matchup.strong_race == race and matchup.weak_race != null:
			beaten.append(matchup.weak_race)
	return beaten


## Races that beat [param race] on the wheel.
func get_races_beating(race: UnitRace) -> Array[UnitRace]:
	var beating: Array[UnitRace] = []
	for matchup: RaceMatchup in race_matchups:
		if matchup.weak_race == race and matchup.strong_race != null:
			beating.append(matchup.strong_race)
	return beating


func get_max_stars() -> int:
	return star_shard_costs.size()


## Shards needed to go from [param current_stars] to the next star (0 = maxed).
func get_star_shard_cost(current_stars: int) -> int:
	return star_shard_costs[current_stars] if current_stars < star_shard_costs.size() else 0


## Random hero for a shard drop, weighted by rarity (common heroes drop more often).
func pick_shard_hero() -> HeroData:
	var weights: PackedFloat32Array = PackedFloat32Array()
	for hero: HeroData in heroes:
		weights.append(rarity_drop_weights[hero.rarity] if hero.rarity < rarity_drop_weights.size() else 0.0)
	var picked_index: int = RandomUtils.weighted_index(weights)
	return heroes[picked_index] if picked_index >= 0 else null


## Chest keys for clearing [param stage] for the first time in a run.
func get_chest_keys_for_clear(stage: int) -> int:
	var keys: int = 1 if chest_key_stage_interval > 0 and stage % chest_key_stage_interval == 0 else 0
	return keys + (chest_keys_per_boss if is_boss_stage(stage) else 0)


## The hero a chest gives. [param is_owned] says which heroes are already in
## the collection (for the new-hero guarantee and duplicate rerolls).
func roll_chest_hero(is_owned: Callable, owned_count: int) -> HeroData:
	var only_new: bool = owned_count < chest_guaranteed_new_until
	var weights: PackedFloat32Array = PackedFloat32Array()
	for hero: HeroData in heroes:
		var weight: float = get_chest_weight(hero)
		weights.append(0.0 if only_new and is_owned.call(hero) else weight)
	var picked: HeroData = null
	for attempt: int in chest_duplicate_rerolls + 1:
		var picked_index: int = RandomUtils.weighted_index(weights)
		if picked_index < 0:
			break
		picked = heroes[picked_index]
		if not is_owned.call(picked):
			break
	return picked


func get_chest_weight(hero: HeroData) -> float:
	return chest_rarity_weights[hero.rarity] if hero.rarity < chest_rarity_weights.size() else 0.0


## Chance (0..1) that a chest's roll lands on [param rarity] (before rerolls).
func get_chest_rarity_chance(rarity: HeroData.Rarity) -> float:
	var total_weight: float = 0.0
	var rarity_weight: float = 0.0
	for hero: HeroData in heroes:
		total_weight += get_chest_weight(hero)
		if hero.rarity == rarity:
			rarity_weight += get_chest_weight(hero)
	return rarity_weight / total_weight if total_weight > 0.0 else 0.0


func get_chest_duplicate_shards(hero: HeroData) -> int:
	return chest_duplicate_shards[mini(hero.rarity, chest_duplicate_shards.size() - 1)] if not chest_duplicate_shards.is_empty() else 0


func get_starting_hero() -> HeroData:
	return heroes[0] if not heroes.is_empty() else null


func find_hero(hero_id: StringName) -> HeroData:
	for hero: HeroData in heroes:
		if hero.id == hero_id:
			return hero
	return null
