## Touch joystick. By default it also presses the move_* input actions, so
## movement code can simply use Input.get_vector() and works with keyboard on
## desktop and the joystick on phones without any branching.
##
## Place it as a Control covering the area that should accept the thumb
## (e.g. the bottom half of the screen) on a CanvasLayer below the HUD, so HUD
## buttons on top still receive their touches. Modes:
##   FIXED    — stays at its rest position
##   FLOATING — appears where the thumb touches down
##
## Dependencies: Types autoload
class_name TouchJoystick
extends Control

signal direction_changed(direction: Vector2)

enum JoystickMode { FIXED, FLOATING }

@export var mode: JoystickMode = JoystickMode.FLOATING
@export var base_radius: float = 110.0
@export var knob_radius: float = 46.0
@export_range(0.0, 0.9) var dead_zone: float = 0.15
## Rest position relative to this control's size (0..1).
@export var rest_anchor: Vector2 = Vector2(0.5, 0.7)
@export var show_when_idle: bool = true
@export var feed_input_actions: bool = true
@export var base_color: Color = Color(1, 1, 1, 0.12)
@export var knob_color: Color = Color(1, 1, 1, 0.45)

var _touch_index: int = -1
var _base_center: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_to_rest()
	resized.connect(_reset_to_rest)


func get_direction() -> Vector2:
	return _direction


func is_active() -> bool:
	return _touch_index >= 0


## Touch positions arrive in this control's local space (the GUI keeps routing
## a finger's drags here even after it leaves the rectangle).
func _gui_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index < 0:
			_touch_index = touch.index
			if mode == JoystickMode.FLOATING:
				_base_center = touch.position
			_update_knob(touch.position)
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			_release()
			accept_event()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		_update_knob(drag.position)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release()


func _update_knob(local_position: Vector2) -> void:
	_knob_offset = (local_position - _base_center).limit_length(base_radius)
	var raw_direction: Vector2 = _knob_offset / base_radius
	_set_direction(raw_direction if raw_direction.length() > dead_zone else Vector2.ZERO)
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_knob_offset = Vector2.ZERO
	_reset_to_rest()
	_set_direction(Vector2.ZERO)


func _reset_to_rest() -> void:
	if _touch_index < 0:
		_base_center = size * rest_anchor
	queue_redraw()


func _set_direction(new_direction: Vector2) -> void:
	if new_direction == _direction:
		return
	_direction = new_direction
	if feed_input_actions:
		_feed_action(Types.ACTION_MOVE_LEFT, maxf(0.0, -_direction.x))
		_feed_action(Types.ACTION_MOVE_RIGHT, maxf(0.0, _direction.x))
		_feed_action(Types.ACTION_MOVE_UP, maxf(0.0, -_direction.y))
		_feed_action(Types.ACTION_MOVE_DOWN, maxf(0.0, _direction.y))
	direction_changed.emit(_direction)


func _feed_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _draw() -> void:
	if not show_when_idle and _touch_index < 0:
		return
	draw_circle(_base_center, base_radius, base_color)
	draw_arc(_base_center, base_radius, 0.0, TAU, 48, Color(knob_color, 0.35), 3.0, true)
	draw_circle(_base_center + _knob_offset, knob_radius, knob_color)
