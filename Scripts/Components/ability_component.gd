## Slots of AbilityData with independent cooldowns (active skills, dashes,
## bombs). Pair with CooldownButton for mobile skill buttons.
##
## Dependencies: AbilityData
class_name AbilityComponent
extends Node

signal ability_activated(slot_index: int, ability: AbilityData)
signal cooldown_started(slot_index: int, duration_seconds: float)

@export var abilities: Array[AbilityData] = []
## Node passed to AbilityData.activate() (defaults to owner).
@export var caster: Node2D
## Multiplies every cooldown (perks like "-20% cooldown" set 0.8).
@export var cooldown_multiplier: float = 1.0

var _cooldowns_remaining: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	if caster == null:
		caster = owner as Node2D
	_cooldowns_remaining.resize(abilities.size())


func _physics_process(delta: float) -> void:
	for slot_index: int in _cooldowns_remaining.size():
		_cooldowns_remaining[slot_index] = maxf(0.0, _cooldowns_remaining[slot_index] - delta)


## Replaces the slots at runtime (e.g. from data on setup); every slot starts ready.
func set_abilities(new_abilities: Array[AbilityData]) -> void:
	abilities = new_abilities
	_cooldowns_remaining.resize(abilities.size())
	_cooldowns_remaining.fill(0.0)


## Puts every slot on [param fraction] of its cooldown (0 = ready, 1 = full),
## e.g. so a whole team doesn't fire its skills in the same frame.
func reset_cooldowns(fraction: float) -> void:
	for slot_index: int in abilities.size():
		_cooldowns_remaining[slot_index] = abilities[slot_index].cooldown_seconds * cooldown_multiplier * clampf(fraction, 0.0, 1.0)


func get_ability(slot_index: int) -> AbilityData:
	return abilities[slot_index] if slot_index >= 0 and slot_index < abilities.size() else null


func is_ready(slot_index: int) -> bool:
	return get_ability(slot_index) != null and _cooldowns_remaining[slot_index] <= 0.0


func get_cooldown_remaining(slot_index: int) -> float:
	return _cooldowns_remaining[slot_index] if slot_index < _cooldowns_remaining.size() else 0.0


func try_activate(slot_index: int) -> bool:
	if not is_ready(slot_index):
		return false
	var ability: AbilityData = abilities[slot_index]
	if not ability.activate(caster):
		return false
	var cooldown_seconds: float = ability.cooldown_seconds * cooldown_multiplier
	_cooldowns_remaining[slot_index] = cooldown_seconds
	ability_activated.emit(slot_index, ability)
	cooldown_started.emit(slot_index, cooldown_seconds)
	return true
