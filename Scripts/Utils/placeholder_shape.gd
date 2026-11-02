## Draws a simple colored shape so prototypes work without art.
## Replace with a Sprite2D / AnimatedSprite2D when real assets arrive.
##
## Dependencies: none
@tool
class_name PlaceholderShape
extends Node2D

enum ShapeKind { CIRCLE, RECTANGLE, TRIANGLE, DIAMOND, CAPSULE, HEXAGON }

@export var shape_kind: ShapeKind = ShapeKind.CIRCLE:
	set(value):
		shape_kind = value
		queue_redraw()
@export var size: Vector2 = Vector2(48, 48):
	set(value):
		size = value
		queue_redraw()
@export var color: Color = Color(0.24, 0.48, 1.0):
	set(value):
		color = value
		queue_redraw()
@export var outline_color: Color = Color(0, 0, 0, 0.35):
	set(value):
		outline_color = value
		queue_redraw()
@export var outline_width: float = 4.0:
	set(value):
		outline_width = value
		queue_redraw()


func _draw() -> void:
	var half_size: Vector2 = size * 0.5
	match shape_kind:
		ShapeKind.CIRCLE:
			draw_circle(Vector2.ZERO, half_size.x, color)
			if outline_width > 0.0:
				draw_arc(Vector2.ZERO, half_size.x - outline_width * 0.5, 0.0, TAU, 32, outline_color, outline_width, true)
		ShapeKind.RECTANGLE:
			var rectangle: Rect2 = Rect2(-half_size, size)
			draw_rect(rectangle, color)
			if outline_width > 0.0:
				draw_rect(rectangle.grow(-outline_width * 0.5), outline_color, false, outline_width)
		ShapeKind.TRIANGLE:
			_draw_polygon_with_outline(PackedVector2Array([Vector2(half_size.x, 0), Vector2(-half_size.x, -half_size.y), Vector2(-half_size.x, half_size.y)]))
		ShapeKind.DIAMOND:
			_draw_polygon_with_outline(PackedVector2Array([Vector2(0, -half_size.y), Vector2(half_size.x, 0), Vector2(0, half_size.y), Vector2(-half_size.x, 0)]))
		ShapeKind.HEXAGON:
			var hexagon_points: PackedVector2Array = PackedVector2Array()
			for corner_index: int in 6:
				hexagon_points.append(Vector2.from_angle(TAU * corner_index / 6.0) * half_size)
			_draw_polygon_with_outline(hexagon_points)
		ShapeKind.CAPSULE:
			var radius: float = minf(half_size.x, half_size.y)
			draw_rect(Rect2(-half_size.x + radius, -half_size.y, size.x - radius * 2.0, size.y), color)
			draw_circle(Vector2(-half_size.x + radius, 0), radius, color)
			draw_circle(Vector2(half_size.x - radius, 0), radius, color)


func _draw_polygon_with_outline(points: PackedVector2Array) -> void:
	draw_colored_polygon(points, color)
	if outline_width > 0.0:
		var closed_points: PackedVector2Array = points.duplicate()
		closed_points.append(points[0])
		draw_polyline(closed_points, outline_color, outline_width, true)
