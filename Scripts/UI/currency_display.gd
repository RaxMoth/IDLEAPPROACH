## Pill showing a currency balance that updates (with a count-up) whenever the
## wallet changes. Drop it anywhere: Add Node > CurrencyDisplay, set currency_id.
##
## Dependencies: Events, Profile autoloads
class_name CurrencyDisplay
extends PanelContainer

## Emitted when tapped (e.g. open the shop).
signal tapped(currency_id: StringName)

@export var currency_id: StringName = &"coins":
	set(value):
		currency_id = value
		if is_node_ready():
			_refresh_definition()

var _symbol_label: Label
var _amount_label: Label
var _displayed_amount: int = 0


func _ready() -> void:
	theme_type_variation = &"PillPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var content_row: HBoxContainer = HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 10)
	content_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_row)
	_symbol_label = Label.new()
	_symbol_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(_symbol_label)
	_amount_label = Label.new()
	_amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(_amount_label)
	Events.currency_changed.connect(_on_currency_changed)
	_refresh_definition()


func _gui_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(currency_id)


func _refresh_definition() -> void:
	var currency: CurrencyData = GameConfig.get_default().find_currency(currency_id)
	_symbol_label.text = currency.fallback_symbol if currency != null else "?"
	_symbol_label.add_theme_color_override("font_color", currency.color if currency != null else Color.WHITE)
	_displayed_amount = Profile.wallet.get_amount(currency_id)
	_amount_label.text = NumberFormat.compact(_displayed_amount)


func _on_currency_changed(changed_currency_id: StringName, new_amount: int, _amount_delta: int) -> void:
	if changed_currency_id != currency_id:
		return
	TweenFX.count_label(_amount_label, _displayed_amount, new_amount, 0.35)
	_displayed_amount = new_amount
	TweenFX.pop(self, 1.08, 0.2)
