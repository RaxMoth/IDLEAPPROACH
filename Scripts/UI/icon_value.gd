## An icon followed by a value ("[heart] 4.2K"): the game shows numbers next
## to a picture instead of a word. Add it in a scene (set icon / text in the
## Inspector) or build it in code.
##
##   var health_view: IconValue = IconValue.create(GameIcons.HEALTH, "4.2K")
##   health_view.text = NumberFormat.compact(health)
##
## Dependencies: none
class_name IconValue
extends HBoxContainer

@export var icon: Texture2D:
	set(value):
		icon = value
		_icon_rect.texture = value
@export var text: String = "":
	set(value):
		text = value
		_label.text = value
@export var icon_size: float = 40.0:
	set(value):
		icon_size = value
		_icon_rect.custom_minimum_size = Vector2.ONE * value
## Label theme variation (e.g. &"SmallLabel"); empty = plain Label.
@export var label_variation: StringName = &"":
	set(value):
		label_variation = value
		_label.theme_type_variation = value
## 0 = the theme's font size.
@export var font_size: int = 0:
	set(value):
		font_size = value
		if value > 0:
			_label.add_theme_font_size_override("font_size", value)
		else:
			_label.remove_theme_font_size_override("font_size")
## Transparent = the theme's font color.
@export var value_color: Color = Color(0, 0, 0, 0):
	set(value):
		value_color = value
		if value.a > 0.0:
			_label.add_theme_color_override("font_color", value)
		else:
			_label.remove_theme_color_override("font_color")

var _icon_rect: TextureRect = TextureRect.new()
var _label: Label = Label.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.custom_minimum_size = Vector2.ONE * icon_size
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Internal, so the parts never show up in get_children() or saved scenes.
	add_child(_icon_rect, false, Node.INTERNAL_MODE_FRONT)
	add_child(_label, false, Node.INTERNAL_MODE_FRONT)


static func create(icon_texture: Texture2D, value_text: String = "", size: float = 40.0) -> IconValue:
	var icon_value: IconValue = IconValue.new()
	icon_value.icon_size = size
	icon_value.icon = icon_texture
	icon_value.text = value_text
	return icon_value


## The value label (for pop / count-up tweens).
func get_label() -> Label:
	return _label
