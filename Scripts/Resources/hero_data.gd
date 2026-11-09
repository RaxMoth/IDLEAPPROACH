## Definition of one hero: look, how it fights in the lane, its stat sheet
## and its gold cost curve. Levels live in Profile.heroes, stars in
## Profile.hero_stars; stats are derived here so every number lives in one
## place (see Docs/GAME_DESIGN.md for the full stat model).
##
## Per level:  attack and health grow linearly (base * level)
## Milestones: every milestone_interval levels attack and health x milestone_multiplier
## Fixed per hero: attack speed, defense, crit chance / damage, range, move speed,
##   layer (ground / flying) and race (team synergy, race wheel)
## Stars: each star unlocks the next StarBonus (self, team or race)
## Cost of the next level = base_cost * cost_growth ^ level
##
## Instances live in Ressources/Heroes/ and are listed in CampaignConfig.
##
## Dependencies: Types autoload, PlaceholderShape (shape enum), GrowthCurve,
##               HeroSkill, HeroRace, StarBonus, SoundEffect
class_name HeroData
extends Resource

## How rare the hero's shards are (drop weights live in CampaignConfig).
enum Rarity { COMMON, RARE, EPIC, LEGENDARY, MYTHIC }

enum AttackStyle {
	## Walks up to monsters (short reach) and lunges at them.
	MELEE,
	## Stops at long reach and shoots.
	RANGED,
}

const RARITY_COLORS: Array[Color] = [
	Color(0.7, 0.72, 0.76),
	Color(0.35, 0.65, 1.0),
	Color(0.7, 0.45, 1.0),
	Color(1.0, 0.72, 0.2),
	Color(1.0, 0.35, 0.45),
]
const RARITY_NAMES: PackedStringArray = ["Common", "Rare", "Epic", "Legendary", "Mythic"]

@export var id: StringName = &""
@export var display_name: String = ""
## Short role line shown in the hero list ("Frontline", "Ranged"...).
@export var role: String = ""
## Character art, facing right: the battle sprite and the portrait (drawn by
## Assets/Art/Source/generate_art.py; null = placeholder shape).
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
## Team synergy race.
@export var race: HeroRace
## What each star unlocks, in star order (index 0 = 1 star). See StarBonus.
@export var star_bonuses: Array[StarBonus] = []

@export_group("Look")
@export var color: Color = Color(0.4, 0.7, 1.0)
@export var shape_kind: PlaceholderShape.ShapeKind = PlaceholderShape.ShapeKind.CIRCLE
@export var visual_size: Vector2 = Vector2(64, 64)
## Played (at the hero) with every normal attack: a swing, a shot, a spell.
@export var attack_sound: SoundEffect

@export_group("Combat")
@export var attack_style: AttackStyle = AttackStyle.MELEE
## Flyers can only be hit by ranged and flying enemies.
@export var layer: Types.UnitLayer = Types.UnitLayer.GROUND
## Auto-cast skill (fires on its own cooldown; null = none).
@export var skill: HeroSkill
## Damage of one hit at level 1 (grows per level).
@export var base_damage: float = 1.0
@export var attack_interval_seconds: float = 1.0
## Health at level 1 (grows per level).
@export var base_health: float = 30.0
## Share of incoming damage blocked (0.2 = 20%; capped by CampaignConfig.max_defense).
@export_range(0.0, 0.9) var defense: float = 0.0
@export_range(0.0, 1.0) var crit_chance: float = 0.05
## Damage multiplier of a critical hit.
@export var crit_multiplier: float = 2.0
## Walking speed along the lane (px/s).
@export var move_speed: float = 110.0
## Gap to a target (px) at which the hero stops and attacks.
@export var attack_range: float = 50.0
## Every N levels attack and health are multiplied by milestone_multiplier.
@export var milestone_interval: int = 25
@export var milestone_multiplier: float = 2.0

@export_group("Cost")
## Gold cost of level 1 (the recruit price).
@export var base_cost: float = 10.0
@export var cost_growth: float = 1.075


func is_ranged() -> bool:
	return attack_style == AttackStyle.RANGED


func is_flying() -> bool:
	return layer == Types.UnitLayer.AIR


## Ground melee heroes can't reach flyers; ranged and flying heroes can.
func can_hit_air() -> bool:
	return is_ranged() or is_flying()


func get_rarity_color() -> Color:
	return RARITY_COLORS[rarity]


## Translated rarity name ("Epic").
func get_rarity_name() -> String:
	return TranslationServer.translate(RARITY_NAMES[rarity])


## Damage of one hit at [param level], before stars and relics.
func get_damage(level: int) -> float:
	return base_damage * GrowthCurve.level_scale(level, milestone_interval, milestone_multiplier)


func get_attacks_per_second() -> float:
	return 1.0 / maxf(attack_interval_seconds, 0.01)


## Average damage per hit including crits.
func get_crit_factor() -> float:
	return 1.0 + crit_chance * (crit_multiplier - 1.0)


## Expected damage per second at [param level] (crits included), before stars and relics.
func get_damage_per_second(level: int) -> float:
	return get_damage(level) * get_attacks_per_second() * get_crit_factor()


## Maximum health at [param level], before stars and relics.
func get_health(level: int) -> float:
	return base_health * GrowthCurve.level_scale(level, milestone_interval, milestone_multiplier)


func get_next_milestone_level(level: int) -> int:
	return GrowthCurve.get_next_milestone_level(level, milestone_interval)


func get_level_cost(current_level: int) -> float:
	return GrowthCurve.level_cost(base_cost, cost_growth, current_level)


## Total cost of buying [param level_count] levels starting at [param current_level].
func get_bulk_cost(current_level: int, level_count: int) -> float:
	return GrowthCurve.bulk_cost(base_cost, cost_growth, current_level, level_count)


## How many levels [param available_gold] buys from [param current_level], capped at [param max_count].
func get_affordable_levels(current_level: int, available_gold: float, max_count: int) -> int:
	return GrowthCurve.affordable_levels(base_cost, cost_growth, current_level, available_gold, max_count)
