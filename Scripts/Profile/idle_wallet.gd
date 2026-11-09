## Float balances for idle-scale currencies (gold) that grow past what an int
## can hold (1e18). Same API shape as Wallet; every change is broadcast via
## Events.idle_currency_changed. Definitions come from GameConfig.idle_currencies.
##
##   Profile.idle_wallet.add(Types.CURRENCY_GOLD, 1.5e12)
##   if Profile.idle_wallet.spend(Types.CURRENCY_GOLD, cost): ...
##
## Dependencies: Events, Profile, Types autoloads
class_name IdleWallet
extends ProfileModule

var _balances: Dictionary[StringName, float] = {}


func get_save_key() -> StringName:
	return &"idle_wallet"


func to_dict() -> Dictionary:
	return _balances


func from_dict(data: Dictionary) -> void:
	reset()
	var stored_balances: Dictionary[StringName, float] = to_float_dictionary(data)
	for currency_id: StringName in stored_balances:
		_balances[currency_id] = stored_balances[currency_id]


func reset() -> void:
	_balances = {}
	for currency: CurrencyData in config.idle_currencies:
		_balances[currency.id] = float(currency.starting_amount)


func get_amount(currency_id: StringName) -> float:
	return _balances.get(currency_id, 0.0)


func can_afford(currency_id: StringName, amount: float) -> bool:
	return get_amount(currency_id) >= amount


func add(currency_id: StringName, amount: float) -> void:
	if is_zero_approx(amount):
		return
	_balances[currency_id] = maxf(0.0, get_amount(currency_id) + amount)
	if currency_id == Types.CURRENCY_GOLD and amount > 0.0:
		Profile.stats.increment(Types.STAT_GOLD_EARNED, amount)
	Events.idle_currency_changed.emit(currency_id, _balances[currency_id], amount)
	mark_dirty()


## Returns false (and changes nothing) when the player can't afford it.
func spend(currency_id: StringName, amount: float) -> bool:
	if amount < 0.0 or not can_afford(currency_id, amount):
		return false
	add(currency_id, -amount)
	return true


## Sets a balance back to its starting amount (rebirth).
func reset_currency(currency_id: StringName) -> void:
	var currency: CurrencyData = config.find_idle_currency(currency_id)
	var starting_amount: float = float(currency.starting_amount) if currency != null else 0.0
	var amount_delta: float = starting_amount - get_amount(currency_id)
	_balances[currency_id] = starting_amount
	Events.idle_currency_changed.emit(currency_id, starting_amount, amount_delta)
	mark_dirty()
