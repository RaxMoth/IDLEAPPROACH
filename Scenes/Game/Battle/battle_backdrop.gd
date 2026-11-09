## Side-view battlefield backdrop in the game's inked doodle style: a sky
## gradient, outlined hills, two rows of the zone's props (a darker, smaller
## far row and a near row on the horizon), and the ground with an inked edge
## and scattered stones, all in the current MonsterZone's colors. Drawn once
## per zone (static, so it costs nothing per frame). Zones without props fall
## back to simple drawn trees. `scroll_offset` shifts the layers at different
## speeds (parallax) if a scene wants to pan it.
##
## Dependencies: MonsterZone
class_name BattleBackdrop
extends Node2D

const INK: Color = Color(0.11, 0.09, 0.12)

## World area to cover (wide and tall enough for tablets and 20:9 phones).
@export var area: Rect2 = Rect2(-400, -600, 1600, 2400)
@export var horizon_y: float = 500.0
@export var hill_spacing: float = 320.0
@export var prop_spacing: float = 150.0
@export var stone_spacing: float = 120.0
## Height of a near prop's art box (world px).
@export var prop_height: float = 190.0
@export var outline_width: float = 4.0
@export_range(0.0, 1.0) var hill_parallax: float = 0.2
@export_range(0.0, 1.0) var far_prop_parallax: float = 0.35
@export_range(0.0, 1.0) var prop_parallax: float = 0.5

## Ground offset in px; hills and props shift by their parallax factor.
var scroll_offset: float = 0.0:
	set(value):
		scroll_offset = value
		queue_redraw()

var _sky_color: Color = Color(0.37, 0.48, 0.55)
var _ground_color: Color = Color(0.29, 0.42, 0.23)
var _prop_color: Color = Color(0.23, 0.35, 0.19)
var _props: Array[Texture2D] = []


func apply_zone(zone: MonsterZone) -> void:
	if zone == null:
		return
	_sky_color = zone.sky_color
	_ground_color = zone.ground_color
	_prop_color = zone.prop_color
	_props = zone.props
	queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_hills()
	# Far props fade toward the sky (a plain darkening would turn them black).
	_draw_prop_row(far_prop_parallax, prop_height * 0.7, -26.0, Color.WHITE.lerp(_sky_color.lightened(0.2), 0.65), 17)
	_draw_ground()
	_draw_prop_row(prop_parallax, prop_height, 8.0, Color.WHITE, 0)
	_draw_stones()


func _draw_sky() -> void:
	var top: float = area.position.y
	var left: float = area.position.x
	var right: float = area.end.x
	var top_color: Color = _sky_color.darkened(0.55)
	draw_polygon(
		PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, horizon_y), Vector2(left, horizon_y)]),
		PackedColorArray([top_color, top_color, _sky_color, _sky_color]))


func _draw_hills() -> void:
	var hill_color: Color = _sky_color.darkened(0.25)
	var layer_offset: float = scroll_offset * hill_parallax
	var element_x: float = area.position.x - fposmod(layer_offset, hill_spacing)
	while element_x < area.end.x + hill_spacing:
		var element_index: int = floori((element_x + layer_offset) / hill_spacing)
		var radius: float = hill_spacing * (0.45 + 0.15 * _variation(element_index))
		var center: Vector2 = Vector2(element_x, horizon_y + radius * 0.45)
		draw_circle(center, radius + outline_width, INK)
		draw_circle(center, radius, hill_color)
		element_x += hill_spacing


## One row of zone props along the horizon; [param tint] darkens far rows.
func _draw_prop_row(parallax: float, height: float, foot_offset: float, tint: Color, seed_offset: int) -> void:
	var layer_offset: float = scroll_offset * parallax
	var spacing: float = prop_spacing * (height / prop_height)
	var element_x: float = area.position.x - fposmod(layer_offset, spacing)
	while element_x < area.end.x + spacing:
		var element_index: int = floori((element_x + layer_offset) / spacing) + seed_offset
		# Leave gaps so the row doesn't read as a wall.
		if _variation(element_index + 5) > 0.3:
			var size: float = height * (0.75 + 0.4 * _variation(element_index))
			var foot: Vector2 = Vector2(element_x + spacing * 0.4 * _variation(element_index + 7), horizon_y + foot_offset)
			if _props.is_empty():
				_draw_fallback_tree(foot, size * 0.6, tint)
			else:
				var texture: Texture2D = _props[element_index % _props.size()]
				draw_texture_rect(texture, Rect2(foot - Vector2(size * 0.5, size * 0.96), Vector2(size, size)), false, tint)
		element_x += spacing


func _draw_fallback_tree(foot: Vector2, tree_height: float, tint: Color) -> void:
	var crown: PackedVector2Array = PackedVector2Array([
		foot + Vector2(-tree_height * 0.32, -tree_height * 0.3),
		foot + Vector2(0.0, -tree_height),
		foot + Vector2(tree_height * 0.32, -tree_height * 0.3),
	])
	draw_rect(Rect2(foot.x - 6.0, foot.y - tree_height * 0.35, 12.0, tree_height * 0.35), _prop_color.darkened(0.45) * tint)
	draw_colored_polygon(crown, _prop_color * tint)
	crown.append(crown[0])
	draw_polyline(crown, INK, outline_width)


func _draw_ground() -> void:
	draw_rect(Rect2(area.position.x, horizon_y, area.size.x, area.end.y - horizon_y), _ground_color)
	# A darker band where the fighters stand reads as a path.
	draw_rect(Rect2(area.position.x, horizon_y + 110.0, area.size.x, 150.0), _ground_color.darkened(0.12))
	draw_rect(Rect2(area.position.x, horizon_y + 252.0, area.size.x, 4.0), _ground_color.darkened(0.3))
	draw_rect(Rect2(area.position.x, horizon_y - outline_width * 0.5, area.size.x, outline_width), INK)


## Flat pebbles (squashed circles) lighter than the ground, so they read as
## stones lying on it rather than holes.
func _draw_stones() -> void:
	var stone_color: Color = _ground_color.lightened(0.12)
	var element_x: float = area.position.x - fposmod(scroll_offset, stone_spacing)
	while element_x < area.end.x + stone_spacing:
		var element_index: int = floori((element_x + scroll_offset) / stone_spacing)
		var lane_y: float = horizon_y + 30.0 + 260.0 * _variation(element_index + 3)
		var stone_radius: float = 4.0 + 7.0 * _variation(element_index + 11)
		draw_set_transform(Vector2(element_x, lane_y), 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, stone_radius + 2.5, INK)
		draw_circle(Vector2.ZERO, stone_radius, stone_color)
		draw_circle(Vector2(-stone_radius * 0.3, -stone_radius * 0.35), stone_radius * 0.4, stone_color.lightened(0.15))
		element_x += stone_spacing
	draw_set_transform(Vector2.ZERO)


## Stable pseudo-random 0..1 per element so props keep their look while scrolling.
func _variation(element_index: int) -> float:
	return float(absi(element_index * 7919 + 104729) % 997) / 996.0
