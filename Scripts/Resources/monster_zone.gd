## One zone of the campaign (e.g. "Meadow", stages 1-10): its name, the
## regular monsters that spawn in waves, the boss and the backdrop colors and props.
##
## Dependencies: MonsterData
class_name MonsterZone
extends Resource

@export var display_name: String = ""
@export_group("Backdrop")
@export var sky_color: Color = Color(0.47, 0.71, 0.89)
@export var ground_color: Color = Color(0.33, 0.55, 0.27)
## Hills, and the fallback trees when there are no props.
@export var prop_color: Color = Color(0.25, 0.45, 0.2)
## Scenery drawn along the horizon (trees, rocks...), standing on the bottom edge.
@export var props: Array[Texture2D] = []
@export_group("")
@export var monsters: Array[MonsterData] = []
@export var boss: MonsterData


func pick_monster() -> MonsterData:
	return monsters.pick_random() if not monsters.is_empty() else null
