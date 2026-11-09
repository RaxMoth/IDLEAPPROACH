## Generic shop row: optional icon, title, description, detail line and a
## buy button (optionally with an icon, e.g. the currency it costs).
## The Shop scene binds it to upgrades, products or rewarded ads.
##
## Dependencies: none
class_name ShopItemRow
extends PanelContainer

signal buy_pressed

@onready var _title_label: Label = %TitleLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _buy_button: Button = %BuyButton
@onready var _item_icon: TextureRect = %ItemIcon


func setup(title: String, description: String, detail: String, button_text: String, is_enabled: bool) -> void:
	_title_label.text = title
	_description_label.text = description
	_description_label.visible = not description.is_empty()
	_detail_label.text = detail
	_detail_label.visible = not detail.is_empty()
	_buy_button.text = button_text
	_buy_button.disabled = not is_enabled


## [param item_icon] left of the title, [param button_icon] on the buy button (null = none).
func set_icons(item_icon: Texture2D, button_icon: Texture2D) -> void:
	_item_icon.texture = item_icon
	_item_icon.visible = item_icon != null
	_buy_button.icon = button_icon


func get_buy_button() -> Button:
	return _buy_button


func _on_buy_button_pressed() -> void:
	buy_pressed.emit()
