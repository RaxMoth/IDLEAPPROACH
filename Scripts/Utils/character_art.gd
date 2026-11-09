## Shows a unit's character art on a Sprite2D sized to its visual_size, or
## its placeholder shape while it has no art. The art is drawn in a square
## design box with the feet at FEET_LINE of its height
## (Assets/Art/Source/generate_art.py), and lands with the feet on the
## placeholder's bottom edge so shadows and health bars stay where they were.
##
##   CharacterArt.apply(%Art, %Shape, hero_data.icon, hero_data.visual_size, hero_data.color, hero_data.shape_kind)
##
## Dependencies: PlaceholderShape
class_name CharacterArt
extends RefCounted

## Where the feet sit in the art, as a share of its height.
const FEET_LINE: float = 0.92
## Art height relative to the unit's visual size (the drawing has padding).
const HEIGHT_FACTOR: float = 1.75
## Empty space above the tallest drawings, as a share of the art's height.
const TOP_PADDING: float = 0.06
## Gap between the top of the art and a health bar above it.
const HEALTH_BAR_GAP: float = 4.0


## Returns the y of the drawing's top edge (for placing a health bar above it).
static func apply(art: Sprite2D, shape: PlaceholderShape, texture: Texture2D, visual_size: Vector2, color: Color, shape_kind: PlaceholderShape.ShapeKind) -> float:
	art.visible = texture != null
	shape.visible = texture == null
	if texture == null:
		shape.shape_kind = shape_kind
		shape.size = visual_size
		shape.color = color
		return -visual_size.y * 0.5
	art.texture = texture
	var display_height: float = visual_size.y * HEIGHT_FACTOR
	var feet_y: float = visual_size.y * 0.5
	art.scale = Vector2.ONE * display_height / float(texture.get_height())
	art.position = Vector2(0.0, feet_y - (FEET_LINE - 0.5) * display_height)
	return feet_y - (FEET_LINE - TOP_PADDING) * display_height


## Puts [param health_bar] (centered on x) just above [param art_top_y].
static func place_health_bar(health_bar: Control, art_top_y: float) -> void:
	health_bar.position.y = art_top_y - health_bar.size.y - HEALTH_BAR_GAP
