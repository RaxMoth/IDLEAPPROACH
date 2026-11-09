## One timed gold source in the battle menu: its art, level, payout per
## cycle and cycle length as icon + value, a filling timer bar with the
## seconds left, and a level-up / unlock button with the gold cost.
## Display only — emits level_up_pressed.
##
## Dependencies: IncomeSourceData, NumberFormat, TweenFX, IconValue
class_name IncomeRow
extends PanelContainer

signal level_up_pressed

var source_data: IncomeSourceData

@onready var _icon: ColorRect = %Icon
@onready var _icon_art: TextureRect = %IconArt
@onready var _initial_label: Label = %InitialLabel
@onready var _level_badge: Label = %LevelBadge
@onready var _title_label: Label = %TitleLabel
@onready var _payout_value: IconValue = %PayoutValue
@onready var _cycle_value: IconValue = %CycleValue
@onready var _gain_label: Label = %GainLabel
@onready var _cycle_bar: ProgressBar = %CycleBar
@onready var _cycle_label: Label = %CycleLabel
@onready var _level_up_button: Button = %LevelUpButton


func setup(source: IncomeSourceData) -> void:
	source_data = source
	_icon_art.texture = source.icon
	_initial_label.visible = source.icon == null
	_initial_label.text = tr(source.title).left(1)
	if source.icon == null:
		_icon.color = source.color


## Gold per cycle, the cycle length, what the next purchase adds (empty =
## hidden) and the button's text (the coin icon is on it).
func update_display(level: int, payout_text: String, cycle_text: String, gain_text: String, button_text: String, can_afford: bool) -> void:
	var is_owned: bool = level > 0
	_title_label.text = tr(source_data.title)
	_level_badge.text = tr("Lv %d") % level if is_owned else ""
	_payout_value.text = payout_text
	_cycle_value.text = cycle_text
	_gain_label.text = gain_text
	_gain_label.visible = not gain_text.is_empty()
	_level_up_button.text = button_text
	_level_up_button.disabled = not can_afford
	_icon.modulate = Color.WHITE if is_owned else Color(1, 1, 1, 0.45)
	_cycle_bar.visible = is_owned


## [param progress] is the share of the current cycle done (0..1).
func set_cycle_progress(progress: float) -> void:
	_cycle_bar.value = progress
	_cycle_label.text = "%ss" % String.num(maxf(0.0, (1.0 - progress) * source_data.cycle_seconds), 1)


func play_payout() -> void:
	TweenFX.pop(_icon, 1.15, 0.2)


func get_level_up_button() -> Button:
	return _level_up_button


func _on_level_up_button_pressed() -> void:
	level_up_pressed.emit()
