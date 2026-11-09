## Shared UI icons (stats, currencies, tabs), so screens show a picture
## instead of a word. The art is drawn by Assets/Art/Source/generate_art.py;
## replace a PNG in Assets/Art/Icons/ to restyle it everywhere.
## Per-item icons live on their data instead: HeroData / MonsterData.icon
## (character art), HeroRace / MonsterRace.icon, AbilityData.icon (skills),
## IncomeSourceData.icon, UpgradeData.icon (relics), CurrencyData.icon.
##
##   icon_rect.texture = GameIcons.HEALTH
##
## Dependencies: none
class_name GameIcons
extends RefCounted

const ATTACK: Texture2D = preload("res://Assets/Art/Icons/attack.png")
const ATTACK_SPEED: Texture2D = preload("res://Assets/Art/Icons/attack_speed.png")
const DPS: Texture2D = preload("res://Assets/Art/Icons/dps.png")
const HEALTH: Texture2D = preload("res://Assets/Art/Icons/health.png")
const DEFENSE: Texture2D = preload("res://Assets/Art/Icons/defense.png")
const CRIT: Texture2D = preload("res://Assets/Art/Icons/crit.png")
const RANGE: Texture2D = preload("res://Assets/Art/Icons/range.png")
const MELEE: Texture2D = preload("res://Assets/Art/Icons/melee.png")
const RANGED: Texture2D = preload("res://Assets/Art/Icons/ranged.png")
const FLYING: Texture2D = preload("res://Assets/Art/Icons/flying.png")
const GROUND: Texture2D = preload("res://Assets/Art/Icons/ground.png")
const MOVE_SPEED: Texture2D = preload("res://Assets/Art/Icons/move_speed.png")
const LEVEL: Texture2D = preload("res://Assets/Art/Icons/level.png")
const STAR: Texture2D = preload("res://Assets/Art/Icons/star.png")
const COOLDOWN: Texture2D = preload("res://Assets/Art/Icons/cooldown.png")
const ENEMY_POWER: Texture2D = preload("res://Assets/Art/Icons/enemy_power.png")
const BOSS: Texture2D = preload("res://Assets/Art/Icons/boss.png")
## Race wheel: beats / loses to the races shown next to it.
const COUNTER_STRONG: Texture2D = preload("res://Assets/Art/Icons/counter_strong.png")
const COUNTER_WEAK: Texture2D = preload("res://Assets/Art/Icons/counter_weak.png")
## The whole squad (team-wide star bonuses).
const TEAM: Texture2D = preload("res://Assets/Art/Icons/team.png")
const HITS_AIR: Texture2D = preload("res://Assets/Art/Icons/hits_air.png")
const MISSES_AIR: Texture2D = preload("res://Assets/Art/Icons/misses_air.png")
const SHARDS: Texture2D = preload("res://Assets/Art/Icons/shards.png")
const GOLD: Texture2D = preload("res://Assets/Art/Icons/gold.png")
const GEMS: Texture2D = preload("res://Assets/Art/Icons/gems.png")
const SOULS: Texture2D = preload("res://Assets/Art/Icons/souls.png")
const BASE_PLAYER: Texture2D = preload("res://Assets/Art/Icons/base_player.png")
const BASE_ENEMY: Texture2D = preload("res://Assets/Art/Icons/base_enemy.png")
const INCOME_RATE: Texture2D = preload("res://Assets/Art/Icons/income_rate.png")
const TAB_HEROES: Texture2D = preload("res://Assets/Art/Icons/tab_heroes.png")
const TAB_INCOME: Texture2D = preload("res://Assets/Art/Icons/tab_income.png")
const TAB_RELICS: Texture2D = preload("res://Assets/Art/Icons/tab_relics.png")
const KEY: Texture2D = preload("res://Assets/Art/Icons/key.png")
const LOCK: Texture2D = preload("res://Assets/Art/Icons/lock.png")
const CHEST: Texture2D = preload("res://Assets/Art/Icons/chest.png")
const HERO_INDEX: Texture2D = preload("res://Assets/Art/Icons/hero_index.png")


## Icon for the stat a race synergy boosts.
static func for_synergy_stat(synergy_stat: HeroRace.SynergyStat) -> Texture2D:
	match synergy_stat:
		HeroRace.SynergyStat.HEALTH:
			return HEALTH
		HeroRace.SynergyStat.ATTACK_SPEED:
			return ATTACK_SPEED
		HeroRace.SynergyStat.DEFENSE:
			return DEFENSE
	return ATTACK


## Icon for the stat a star bonus raises.
static func for_star_stat(stat: StarBonus.Stat) -> Texture2D:
	match stat:
		StarBonus.Stat.HEALTH:
			return HEALTH
		StarBonus.Stat.ATTACK_SPEED:
			return ATTACK_SPEED
		StarBonus.Stat.DEFENSE:
			return DEFENSE
		StarBonus.Stat.MOVE_SPEED:
			return MOVE_SPEED
		StarBonus.Stat.CRIT_CHANCE:
			return CRIT
	return ATTACK
