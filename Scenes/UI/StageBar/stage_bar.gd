## Top bar of the base battle: zone and stage number, gold with income per
## second and team DPS, both bases' health side by side (yours left, the
## enemy's right — like on the field), how strong the enemy has grown this
## stage and a minimap of the whole lane. Numbers sit next to icons instead
## of captions. Display only.
##
## Dependencies: Events, Profile, Types autoloads, NumberFormat, TweenFX, IconValue
class_name StageBar
extends PanelContainer

## The lane minimap was tapped at [param lane_fraction] (0 = your base, 1 = enemy base).
signal lane_jump_requested(lane_fraction: float)

@onready var _zone_label: Label = %ZoneLabel
@onready var _stage_label: Label = %StageLabel
@onready var _gold_value: IconValue = %GoldValue
@onready var _income_value: IconValue = %IncomeValue
@onready var _dps_value: IconValue = %DpsValue
@onready var _player_base_bar: ProgressBar = %PlayerBaseBar
@onready var _player_base_value: IconValue = %PlayerBaseValue
@onready var _enemy_base_bar: ProgressBar = %EnemyBaseBar
@onready var _enemy_base_value: IconValue = %EnemyBaseValue
@onready var _enemy_power_value: IconValue = %EnemyPowerValue
@onready var _lane_minimap: LaneMinimap = %LaneMinimap


func _ready() -> void:
	_enemy_power_value.hide()
	Events.idle_currency_changed.connect(_on_idle_currency_changed)
	_set_gold(Profile.idle_wallet.get_amount(Types.CURRENCY_GOLD))


func set_stage(stage: int, zone_name: String, is_boss_stage: bool) -> void:
	_stage_label.text = tr("Stage %d") % stage
	_zone_label.text = "%s  •  %s" % [zone_name, tr("Boss")] if is_boss_stage else zone_name
	TweenFX.pop(_stage_label, 1.15, 0.25)


## World x range of the lane (for the minimap).
func set_lane_extent(start_x: float, end_x: float) -> void:
	_lane_minimap.set_lane(start_x, end_x)


func update_lane_view(hero_positions: PackedFloat32Array, monster_positions: PackedFloat32Array, view_start_x: float, view_end_x: float) -> void:
	_lane_minimap.update_view(hero_positions, monster_positions, view_start_x, view_end_x)


## Shows how much stronger the enemy's monsters have grown this stage.
func set_enemy_power(power_multiplier: float) -> void:
	_enemy_power_value.visible = power_multiplier >= 1.05
	_enemy_power_value.text = "x%s" % String.num(power_multiplier, 1)


func set_base_health(team: Types.Team, current_health: float, max_health: float) -> void:
	var is_player: bool = team == Types.Team.PLAYER
	var bar: ProgressBar = _player_base_bar if is_player else _enemy_base_bar
	var health_value: IconValue = _player_base_value if is_player else _enemy_base_value
	bar.max_value = maxf(max_health, 0.001)
	bar.value = current_health
	health_value.text = NumberFormat.compact(ceilf(current_health))


func set_team_stats(team_damage_per_second: float, income_per_second: float) -> void:
	# Whole numbers from 10 up; one decimal below so the early +0.5/s still shows.
	var income_shown: float = income_per_second if income_per_second < 10.0 else roundf(income_per_second)
	var damage_shown: float = team_damage_per_second if team_damage_per_second < 10.0 else roundf(team_damage_per_second)
	_income_value.text = "+%s/s" % NumberFormat.compact(income_shown)
	_dps_value.text = NumberFormat.compact(damage_shown)


func _set_gold(amount: float) -> void:
	_gold_value.text = NumberFormat.compact(floorf(amount))


func _on_idle_currency_changed(currency_id: StringName, new_amount: float, _amount_delta: float) -> void:
	if currency_id == Types.CURRENCY_GOLD:
		_set_gold(new_amount)


func _on_lane_minimap_jump_requested(lane_fraction: float) -> void:
	lane_jump_requested.emit(lane_fraction)
