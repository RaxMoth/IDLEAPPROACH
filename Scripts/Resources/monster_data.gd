## Look and relative strength of one monster type. Absolute health, damage
## and gold come from CampaignConfig (they scale with the stage); these
## multipliers make some monsters tankier, harder hitting, faster or richer,
## and defense blocks a share of every hit. Layer, attack style and race give
## each type its role (flyer, shooter...). See Docs/GAME_DESIGN.md.
##
## Dependencies: Types autoload, PlaceholderShape (shape enum), MonsterRace
class_name MonsterData
extends Resource

@export var display_name: String = ""
## Character art, facing left (null = placeholder shape in color / shape_kind).
@export var icon: Texture2D
@export var race: MonsterRace
## Flyers pass over ground melee heroes; only ranged and flying heroes hit them.
@export var layer: Types.UnitLayer = Types.UnitLayer.GROUND
## Shooters stop at attack_range and fire bolts (they can hit flyers).
@export var is_ranged: bool = false
## Gap at which it stops and attacks (0 = CampaignConfig.monster_attack_range).
@export var attack_range: float = 0.0
@export var color: Color = Color(0.85, 0.3, 0.3)
@export var shape_kind: PlaceholderShape.ShapeKind = PlaceholderShape.ShapeKind.CIRCLE
@export var visual_size: Vector2 = Vector2(64, 64)
@export var health_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var gold_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
## Share of incoming damage blocked (0.25 = 25%; capped by CampaignConfig.max_defense).
@export_range(0.0, 0.9) var defense: float = 0.0


func is_flying() -> bool:
	return layer == Types.UnitLayer.AIR


## Ground melee monsters can't reach flying heroes; shooters and flyers can.
func can_hit_air() -> bool:
	return is_ranged or is_flying()
