## Thin overview of the whole battle lane: both bases at the ends, a dot per
## hero (blue) and monster (red), and a frame for the part on screen. Tap or
## drag on it to jump the camera there. Display only — the battle feeds the
## positions and moves the camera.
##
## Dependencies: none
class_name LaneMinimap
extends Control

## Tapped / dragged at [param lane_fraction] (0 = player's base, 1 = enemy base).
signal jump_requested(lane_fraction: float)

const BACKGROUND_COLOR: Color = Color(0, 0, 0, 0.35)
const PLAYER_COLOR: Color = Color(0.35, 0.65, 1.0)
const ENEMY_COLOR: Color = Color(0.95, 0.35, 0.35)
const VIEW_COLOR: Color = Color(1, 1, 1, 0.8)
const DOT_RADIUS: float = 4.0
const BASE_WIDTH: float = 8.0

var _lane_start_x: float = 0.0
var _lane_end_x: float = 1.0
var _hero_positions: PackedFloat32Array = PackedFloat32Array()
var _monster_positions: PackedFloat32Array = PackedFloat32Array()
var _view_start_x: float = 0.0
var _view_end_x: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## World x range the minimap shows.
func set_lane(start_x: float, end_x: float) -> void:
	_lane_start_x = start_x
	_lane_end_x = maxf(end_x, start_x + 1.0)
	queue_redraw()


func update_view(hero_positions: PackedFloat32Array, monster_positions: PackedFloat32Array, view_start_x: float, view_end_x: float) -> void:
	_hero_positions = hero_positions
	_monster_positions = monster_positions
	_view_start_x = view_start_x
	_view_end_x = view_end_x
	queue_redraw()


func _draw() -> void:
	var bar_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(bar_rect, BACKGROUND_COLOR)
	draw_rect(Rect2(0.0, 0.0, BASE_WIDTH, size.y), PLAYER_COLOR)
	draw_rect(Rect2(size.x - BASE_WIDTH, 0.0, BASE_WIDTH, size.y), ENEMY_COLOR)
	var middle_y: float = size.y * 0.5
	for monster_x: float in _monster_positions:
		draw_circle(Vector2(_to_local_x(monster_x), middle_y), DOT_RADIUS, ENEMY_COLOR)
	for hero_x: float in _hero_positions:
		draw_circle(Vector2(_to_local_x(hero_x), middle_y), DOT_RADIUS, PLAYER_COLOR)
	var view_left: float = _to_local_x(_view_start_x)
	var view_right: float = _to_local_x(_view_end_x)
	draw_rect(Rect2(view_left, 1.0, maxf(view_right - view_left, 2.0), size.y - 2.0), VIEW_COLOR, false, 2.0)


func _gui_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	var is_press: bool = mouse_button != null and mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT
	var is_drag: bool = mouse_motion != null and (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if not is_press and not is_drag:
		return
	var local_x: float = mouse_button.position.x if is_press else mouse_motion.position.x
	jump_requested.emit(clampf(local_x / maxf(size.x, 1.0), 0.0, 1.0))
	accept_event()


func _to_local_x(world_x: float) -> float:
	return clampf((world_x - _lane_start_x) / (_lane_end_x - _lane_start_x), 0.0, 1.0) * size.x
