## One hero in the battle menu: portrait art (rarity frame, level, stars, a
## marker when a star-up is ready), name, attack and health as icon + value,
## what the next purchase adds, and a level-up button with the gold cost.
## Display only — emits level_up_pressed / details_pressed.
##
## Dependencies: HeroData, IconValue
class_name HeroRow
extends PanelContainer

signal level_up_pressed
## The portrait was tapped (open the hero's details).
signal details_pressed

## Behind the character art (the hero color is the fallback without art).
const PORTRAIT_BACKGROUND: Color = Color(0.17, 0.15, 0.17)

var hero_data: HeroData

@onready var _rarity_frame: NinePatchRect = %RarityFrame
@onready var _portrait: ColorRect = %Portrait
@onready var _portrait_art: TextureRect = %PortraitArt
@onready var _initial_label: Label = %InitialLabel
@onready var _star_badge: Label = %StarBadge
@onready var _ready_badge: Label = %ReadyBadge
@onready var _level_badge: Label = %LevelBadge
@onready var _name_label: Label = %NameLabel
@onready var _attack_value: IconValue = %AttackValue
@onready var _health_value: IconValue = %HealthValue
@onready var _gain_row: HBoxContainer = %GainRow
@onready var _attack_gain: IconValue = %AttackGain
@onready var _health_gain: IconValue = %HealthGain
@onready var _level_up_button: Button = %LevelUpButton


func setup(data: HeroData) -> void:
	hero_data = data
	_rarity_frame.self_modulate = data.get_rarity_color()
	_portrait_art.texture = data.icon
	_initial_label.visible = data.icon == null
	_initial_label.text = tr(data.display_name).left(1)
	_portrait.color = PORTRAIT_BACKGROUND if data.icon != null else data.color


## Attack / health now (or what recruiting gives), the gains of the next
## purchase (empty = hidden) and the button's text (the coin icon is on it).
func update_display(level: int, attack_text: String, health_text: String, attack_gain_text: String, health_gain_text: String, button_text: String, can_afford: bool) -> void:
	var is_recruited: bool = level > 0
	_name_label.text = tr(hero_data.display_name)
	_level_badge.text = tr("Lv %d") % level if is_recruited else ""
	_attack_value.text = attack_text
	_health_value.text = health_text
	_attack_gain.text = attack_gain_text
	_health_gain.text = health_gain_text
	_gain_row.visible = not attack_gain_text.is_empty()
	_level_up_button.text = button_text
	_level_up_button.disabled = not can_afford
	var portrait_tint: Color = Color.WHITE if is_recruited else Color(1, 1, 1, 0.45)
	_portrait.modulate = portrait_tint
	_portrait_art.modulate = portrait_tint


func update_stars(star_count: int, can_star_up: bool) -> void:
	_star_badge.text = "★%d" % star_count if star_count > 0 else ""
	_ready_badge.visible = can_star_up


func get_level_up_button() -> Button:
	return _level_up_button


func _on_level_up_button_pressed() -> void:
	level_up_pressed.emit()


func _on_portrait_button_pressed() -> void:
	details_pressed.emit()
