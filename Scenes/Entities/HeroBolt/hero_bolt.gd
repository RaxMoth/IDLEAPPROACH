## Pooled, purely visual attack streak flying from a hero to its target.
## Damage is applied instantly by the battle; this only sells the hit.
##
##   HeroBolt.launch(hero.get_attack_origin(), monster.global_position, hero_data.color)
##
## Dependencies: Pools, Global autoloads, PlaceholderShape
class_name HeroBolt
extends Node2D

const SCENE_PATH: String = "res://Scenes/Entities/HeroBolt/HeroBolt.tscn"
const FLIGHT_SECONDS: float = 0.14

var _tween: Tween

@onready var _visual: PlaceholderShape = %Visual


static func launch(from_position: Vector2, to_position: Vector2, color: Color) -> HeroBolt:
	# load() hits the resource cache after the first call, so this stays cheap.
	var bolt: HeroBolt = Pools.spawn(load(SCENE_PATH) as PackedScene, Global.get_world_root(), from_position) as HeroBolt
	bolt.fly_to(to_position, color)
	return bolt


func fly_to(to_position: Vector2, color: Color) -> void:
	_visual.color = color
	rotation = (to_position - global_position).angle()
	scale = Vector2.ONE
	modulate.a = 1.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", to_position, FLIGHT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.06)
	_tween.tween_callback(Pools.despawn.bind(self))
