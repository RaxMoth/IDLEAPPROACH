## A hero's five star bonuses side by side, without words: per star its
## number, the stat icon with the bonus ("+10%") and who gets it (the hero's
## own portrait, the team helmets or the race emblem). Unlocked stars are lit
## and their bonus shows in the highlight color; the rest are dimmed.
##
##   star_ladder.show_hero(hero_data, Profile.hero_stars.get_stars(hero_data.id))
##
## Dependencies: StarBonus, HeroData, IconValue, GameIcons
class_name StarLadder
extends HBoxContainer

## Value color of an unlocked bonus.
const UNLOCKED_COLOR: Color = Color(0.55, 1.0, 0.6)
## Opacity of a star bonus that is still locked.
const LOCKED_ALPHA: float = 0.38

@export var icon_size: float = 28.0
@export var who_icon_size: float = 36.0
@export var value_font_size: int = 20


func show_hero(hero: HeroData, stars: int) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for star_index: int in hero.star_bonuses.size():
		var bonus: StarBonus = hero.star_bonuses[star_index]
		if bonus != null:
			add_child(_create_cell(hero, bonus, star_index + 1, star_index < stars))


func _create_cell(hero: HeroData, bonus: StarBonus, star_number: int, is_unlocked: bool) -> Control:
	var cell: PanelContainer = PanelContainer.new()
	cell.theme_type_variation = &"FeatureCard" if is_unlocked else &"StatCell"
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_unlocked:
		cell.modulate.a = LOCKED_ALPHA
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(column)
	var star_view: IconValue = IconValue.create(GameIcons.STAR, str(star_number), icon_size * 0.85)
	star_view.font_size = value_font_size
	star_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(star_view)
	var who_rect: TextureRect = TextureRect.new()
	who_rect.texture = _get_who_icon(hero, bonus)
	who_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	who_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	who_rect.custom_minimum_size = Vector2.ONE * who_icon_size
	who_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	who_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(who_rect)
	var value_view: IconValue = IconValue.create(GameIcons.for_star_stat(bonus.stat), bonus.format_amount(), icon_size)
	value_view.font_size = value_font_size
	value_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if is_unlocked:
		value_view.value_color = UNLOCKED_COLOR
	column.add_child(value_view)
	return cell


## Who the bonus reaches: the hero itself, the whole team or one race.
func _get_who_icon(hero: HeroData, bonus: StarBonus) -> Texture2D:
	match bonus.scope:
		StarBonus.Scope.TEAM:
			return GameIcons.TEAM
		StarBonus.Scope.RACE:
			return bonus.race.icon if bonus.race != null else GameIcons.TEAM
	return hero.icon
