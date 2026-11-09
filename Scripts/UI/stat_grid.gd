## Stats as a grid of icon + value cells, without words: the icon says what
## each stat is (GameIcons, race emblems...). Used by the hero and monster
## popups; fill it with add_stat() after clear().
##
##   stat_grid.clear()
##   stat_grid.add_stat(GameIcons.DEFENSE, "20%")
##   stat_grid.add_stat(race.icon, "+15%", true, [GameIcons.ATTACK_SPEED])
##
## Dependencies: IconValue
class_name StatGrid
extends GridContainer

## Value color of a highlighted cell (an active bonus).
const HIGHLIGHT_COLOR: Color = Color(0.55, 1.0, 0.6)

@export var icon_size: float = 46.0
## Size of the extra icons after the value (what a bonus raises, who is strong against it).
@export var extra_icon_size: float = 38.0


func clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


## One cell: [param icon] and [param value]; [param extra_icons] follow the value.
func add_stat(icon: Texture2D, value: String, is_highlighted: bool = false, extra_icons: Array[Texture2D] = []) -> void:
	var cell: PanelContainer = PanelContainer.new()
	cell.theme_type_variation = &"StatCell"
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(row)
	var value_view: IconValue = IconValue.create(icon, value, icon_size)
	value_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_highlighted:
		value_view.value_color = HIGHLIGHT_COLOR
	row.add_child(value_view)
	for extra_icon: Texture2D in extra_icons:
		var extra_rect: TextureRect = TextureRect.new()
		extra_rect.texture = extra_icon
		extra_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		extra_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		extra_rect.custom_minimum_size = Vector2.ONE * extra_icon_size
		extra_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		extra_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(extra_rect)
	add_child(cell)
