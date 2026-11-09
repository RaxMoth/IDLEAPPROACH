## The hero chest screen. It opens on the closed chest with the chest odds
## per rarity; Open (a key first, then gems) asks the battle to open one, and
## play() runs the opening: the chest shakes, bursts open in light rays tinted
## by the hero's rarity, and the hero's card rises out of it — "New hero!" for
## a new member of the collection, or the shards a duplicate turned into.
## Open stays available for the next chest. Display only.
##
## popup_data keys: none (the battle calls play() with each result).
## Result: null.
##
## Dependencies: BasePopup, Events, Profile, Types autoloads, HeroCard, IconValue,
##               ChestOddsRow, GameIcons, TweenFX
class_name ChestPopup
extends BasePopup

## Open was pressed (the battle pays and calls play(), or refuses).
signal open_requested
## The result is on screen (the battle plays the matching sound).
signal revealed(is_new: bool)

const CHEST_CLOSED: Texture2D = preload("res://Assets/Art/Chest/hero_chest_closed.png")
const CHEST_OPEN: Texture2D = preload("res://Assets/Art/Chest/hero_chest_open.png")
const RAY_SPIN_DEGREES_PER_SECOND: float = 24.0
const IDLE_RAY_ALPHA: float = 0.25
const IDLE_RAY_COLOR: Color = Color(0.82, 0.46, 0.24)
const SHAKE_COUNT: int = 6
const SHAKE_ANGLE: float = 0.09
## How far below its spot the card starts when it rises out of the chest.
const CARD_RISE_DISTANCE: float = 150.0
## The closed chest is shown bigger while waiting to be opened.
const IDLE_CHEST_SCALE: float = 1.6

var _sequence: Tween
var _card_rest_y: float = 0.0
var _is_playing: bool = false

@onready var _title_label: Label = %TitleLabel
@onready var _rays: TextureRect = %Rays
@onready var _chest: TextureRect = %Chest
@onready var _hero_card: HeroCard = %HeroCard
@onready var _new_label: Label = %NewLabel
@onready var _shard_value: IconValue = %ShardValue
@onready var _odds_row: HBoxContainer = %OddsRow
@onready var _open_button: Button = %OpenButton


func _on_opened(_data: Dictionary) -> void:
	_card_rest_y = _hero_card.position.y
	Events.currency_changed.connect(func(_currency_id: StringName, _amount: int, _delta: int) -> void:
		if not is_closing():
			_refresh_open_button())
	_title_label.text = tr("Hero chest")
	_rays.self_modulate = IDLE_RAY_COLOR
	_rays.modulate.a = IDLE_RAY_ALPHA
	_hero_card.visible = false
	_new_label.visible = false
	_shard_value.visible = false
	_chest.scale = Vector2.ONE * IDLE_CHEST_SCALE
	_refresh_open_button()


func _process(delta: float) -> void:
	_rays.rotation += deg_to_rad(RAY_SPIN_DEGREES_PER_SECOND) * delta


## Runs the opening for one chest result ({hero, is_new, shards}).
func play(result: Dictionary) -> void:
	var hero: HeroData = result.get("hero") as HeroData
	if hero == null:
		return
	var is_new: bool = bool(result.get("is_new", false))
	if _sequence != null:
		_sequence.kill()
	_is_playing = true
	_title_label.text = tr("Hero chest")
	_title_label.remove_theme_color_override("font_color")
	_chest.texture = CHEST_CLOSED
	_chest.rotation = 0.0
	if _chest.scale != Vector2.ONE:
		create_tween().tween_property(_chest, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_rays.self_modulate = hero.get_rarity_color()
	_rays.modulate.a = 0.0
	_hero_card.show_hero(hero, true, Profile.heroes.get_level(hero.id), Profile.hero_stars.get_stars(hero.id),
		Profile.hero_stars.get_shards(hero.id), Profile.hero_stars.get_next_star_cost(hero))
	_hero_card.visible = false
	_new_label.visible = false
	_shard_value.visible = false
	_odds_row.visible = false
	_open_button.disabled = true
	_sequence = create_tween()
	for shake_index: int in SHAKE_COUNT:
		var direction: float = 1.0 if shake_index % 2 == 0 else -1.0
		_sequence.tween_property(_chest, "rotation", SHAKE_ANGLE * direction * (1.0 + shake_index * 0.15), 0.06)
	_sequence.tween_property(_chest, "rotation", 0.0, 0.05)
	_sequence.tween_callback(_burst_open)
	_sequence.tween_interval(0.45)
	_sequence.tween_callback(_show_result.bind(hero, is_new, int(result.get("shards", 0))))


func _burst_open() -> void:
	_chest.texture = CHEST_OPEN
	TweenFX.pop(_chest, 1.18, 0.3)
	_hero_card.visible = true
	_hero_card.scale = Vector2.ONE * 0.3
	_hero_card.position.y = _card_rest_y + CARD_RISE_DISTANCE
	var reveal: Tween = create_tween().set_parallel(true)
	reveal.tween_property(_rays, "modulate:a", 0.85, 0.3)
	reveal.tween_property(_hero_card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_hero_card, "position:y", _card_rest_y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_result(hero: HeroData, is_new: bool, shards: int) -> void:
	_is_playing = false
	_title_label.text = tr(hero.display_name)
	_title_label.add_theme_color_override("font_color", hero.get_rarity_color().lightened(0.25))
	_new_label.visible = is_new
	_shard_value.visible = not is_new
	_shard_value.text = "+%d" % shards
	TweenFX.pop(_new_label if is_new else _shard_value, 1.25, 0.3)
	_refresh_open_button()
	revealed.emit(is_new)


## A key first; without keys the gem price (disabled when it can't be paid).
func _refresh_open_button() -> void:
	if _is_playing:
		return
	var keys: int = Profile.wallet.get_amount(Types.CURRENCY_KEYS)
	var gem_cost: int = GameConfig.get_default().campaign.chest_gem_cost
	if keys > 0:
		_open_button.icon = GameIcons.KEY
		_open_button.text = "%s  (%d)" % [tr("Open"), keys]
		_open_button.disabled = false
	else:
		_open_button.icon = GameIcons.GEMS
		_open_button.text = str(gem_cost)
		_open_button.disabled = Profile.wallet.get_amount(Types.CURRENCY_GEMS) < gem_cost


func _on_open_button_pressed() -> void:
	open_requested.emit()


func _on_close_button_pressed() -> void:
	close(null)
