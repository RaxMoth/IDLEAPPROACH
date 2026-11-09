## A collectible hero card (a tall slot like the rest of the collection):
## the hero's art, its level and a shard bar toward the next star, which
## turns red when a star-up is ready. Owned heroes get the copper-lined card;
## heroes still in the chest are a dark silhouette with a lock. A thin strip
## shows the rarity, small stars show once earned. Used by the hero
## collection and the chest reveal; tapping it emits Button.pressed.
##
##   card.show_hero(hero, is_owned, level, stars, shards, shards_for_next_star)
##
## Dependencies: HeroData
class_name HeroCard
extends Button

const CARD_TEXTURE: Texture2D = preload("res://Assets/Art/UI/card.png")
const OWNED_CARD_TEXTURE: Texture2D = preload("res://Assets/Art/UI/card_owned.png")
const LOCKED_TINT: Color = Color(0.06, 0.055, 0.05, 0.95)
const STAR_OFF_COLOR: Color = Color(1, 1, 1, 0)

## Shard bar fill while collecting / once a star-up is ready.
@export var shard_fill: StyleBox
@export var ready_fill: StyleBox

var hero_data: HeroData

@onready var _background: NinePatchRect = %Background
@onready var _rarity_strip: ColorRect = %RarityStrip
@onready var _art: TextureRect = %Art
@onready var _level_label: Label = %LevelLabel
@onready var _lock: TextureRect = %Lock
@onready var _shard_bar: ProgressBar = %ShardBar
@onready var _shard_label: Label = %ShardLabel
@onready var _star_row: HBoxContainer = %StarRow


func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = size * 0.5)


## [param shards_for_next_star] 0 = every star earned (the bar shows MAX).
func show_hero(hero: HeroData, is_owned: bool, level: int, stars: int, shards: int, shards_for_next_star: int) -> void:
	hero_data = hero
	_background.texture = OWNED_CARD_TEXTURE if is_owned else CARD_TEXTURE
	_rarity_strip.color = hero.get_rarity_color()
	_art.texture = hero.icon
	_art.self_modulate = Color.WHITE if is_owned else LOCKED_TINT
	_level_label.visible = is_owned
	_level_label.text = tr("Lv %d") % maxi(level, 1)
	_lock.visible = not is_owned
	if shards_for_next_star > 0:
		_shard_bar.max_value = shards_for_next_star
		_shard_bar.value = mini(shards, shards_for_next_star)
		_shard_label.text = "%d/%d" % [shards, shards_for_next_star]
		var is_ready: bool = is_owned and shards >= shards_for_next_star
		_shard_bar.add_theme_stylebox_override("fill", ready_fill if is_ready else shard_fill)
	else:
		_shard_bar.max_value = 1.0
		_shard_bar.value = 1.0
		_shard_label.text = tr("Max")
		_shard_bar.add_theme_stylebox_override("fill", shard_fill)
	for star_index: int in _star_row.get_child_count():
		(_star_row.get_child(star_index) as CanvasItem).modulate = Color.WHITE if star_index < stars else STAR_OFF_COLOR
