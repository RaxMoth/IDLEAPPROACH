## Pooled, purely visual ring that expands and fades — skill impacts, heals.
##
##   SkillBurst.play(target_position, 110.0, Color.ORANGE)
##
## Dependencies: Pools, Global autoloads, PlaceholderShape
class_name SkillBurst
extends Node2D

const SCENE_PATH: String = "res://Scenes/Entities/SkillBurst/SkillBurst.tscn"
const DURATION_SECONDS: float = 0.35

var _tween: Tween

@onready var _visual: PlaceholderShape = %Visual


static func play(world_position: Vector2, radius: float, color: Color) -> SkillBurst:
	# load() hits the resource cache after the first call, so this stays cheap.
	var burst: SkillBurst = Pools.spawn(load(SCENE_PATH) as PackedScene, Global.get_world_root(), world_position) as SkillBurst
	burst.expand(radius, color)
	return burst


func expand(radius: float, color: Color) -> void:
	_visual.size = Vector2.ONE * radius * 2.0
	_visual.color = Color(color, 0.35)
	_visual.outline_color = color
	scale = Vector2.ONE * 0.3
	modulate.a = 1.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, DURATION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, DURATION_SECONDS).set_delay(DURATION_SECONDS * 0.4)
	_tween.chain().tween_callback(Pools.despawn.bind(self))
