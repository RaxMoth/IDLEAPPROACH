## A base at one end of the battle lane — the player's on the left, the
## enemy's on the right. It only takes hits; when its health runs out it
## collapses and reports `destroyed`. Reset it to full health for every stage.
## State: Standing -> Destroyed on Types.EVENT_DIED, back on Types.EVENT_RESPAWN.
##
## Sounds: hit_sound (positional, throttled by its SoundEffect) and
## destroyed_sound, which plays at full volume wherever the camera is.
##
## Dependencies: Types, Audio autoloads, HealthComponent, HitFlashComponent,
##               HealthBarComponent, FloatingText, BattleLane, SkillBurst, SoundEffect
class_name BattleBase
extends Node2D

signal destroyed(base: BattleBase)
## Forwarded from the HealthComponent for the top bar.
signal health_changed(current_health: float, max_health: float)

const DAMAGE_NUMBER_COLOR: Color = Color(1.0, 0.75, 0.6)
const COLLAPSE_BURST_RADIUS: float = 170.0
const COLLAPSE_SECOND_BURST_DELAY: float = 0.15
const CRIT_NUMBER_COLOR: Color = Color(1.0, 0.55, 0.2)
## Base art is drawn in a 160 x 256 box with the feet at this height
## (Assets/Art/Source/generate_art.py); one design unit = one world pixel.
const ART_DESIGN_SIZE: Vector2 = Vector2(160.0, 256.0)
const ART_FEET_Y: float = 252.0

@export var team: Types.Team = Types.Team.PLAYER
## Half width along the lane: units stop this far from the base's center.
@export var lane_radius: float = 55.0
## Roof and flag color: tells the two sides apart.
@export var banner_color: Color = Color(0.35, 0.6, 1.0)
## Tower art (null = the placeholder shapes in banner_color).
@export var art: Texture2D

@export_group("Sounds")
@export var hit_sound: SoundEffect
@export var destroyed_sound: SoundEffect

@onready var health_component: HealthComponent = %HealthComponent
@onready var hit_flash_component: HitFlashComponent = %HitFlashComponent
@onready var state_chart: StateChart = %StateChart
@onready var _body: Node2D = %Body
@onready var _roof: PlaceholderShape = %Roof
@onready var _flag: PlaceholderShape = %Flag
@onready var _placeholder: Node2D = %Placeholder
@onready var _art: Sprite2D = %Art

var _collapse_tween: Tween


func _ready() -> void:
	_roof.color = banner_color
	_flag.color = banner_color
	_show_art()
	health_component.died.connect(func() -> void: state_chart.send_event(Types.EVENT_DIED))
	health_component.health_changed.connect(func(current_health: float, max_health: float) -> void: health_changed.emit(current_health, max_health))
	health_component.damaged.connect(_on_damaged)


func _show_art() -> void:
	_art.visible = art != null
	_placeholder.visible = art == null
	if art == null:
		return
	_art.texture = art
	_art.scale = Vector2.ONE * ART_DESIGN_SIZE.x / float(art.get_width())
	_art.position = Vector2(-ART_DESIGN_SIZE.x * 0.5, -ART_FEET_Y)


## Registers the base so fighters of the other team can target it.
func join_lane(lane: BattleLane) -> void:
	lane.register(self, team, health_component, lane_radius)


## Shots aim at the middle of the tower (the base is drawn upward from its feet).
func get_aim_point() -> Vector2:
	return global_position + Vector2(0.0, -80.0)


## Full health for a new stage; stands back up if it was destroyed.
func reset(max_health: float) -> void:
	health_component.revive(max_health)
	state_chart.send_event(Types.EVENT_RESPAWN)


func is_destroyed() -> bool:
	return health_component.is_dead

# ============================================
# STATE CHART CALLBACKS
# ============================================

func _on_standing_state_entered() -> void:
	if _collapse_tween != null:
		_collapse_tween.kill()
	hit_flash_component.reset()
	_body.scale = Vector2.ONE
	_body.modulate.a = 1.0


func _on_destroyed_state_entered() -> void:
	destroyed.emit(self)
	Audio.play_effect(destroyed_sound)
	SkillBurst.play(get_aim_point(), COLLAPSE_BURST_RADIUS, banner_color)
	get_tree().create_timer(COLLAPSE_SECOND_BURST_DELAY).timeout.connect(func() -> void: SkillBurst.play(get_aim_point() + Vector2(0.0, 40.0), COLLAPSE_BURST_RADIUS * 0.7, Color.WHITE))
	_collapse_tween = create_tween().set_parallel(true)
	_collapse_tween.tween_property(_body, "scale", Vector2(1.15, 0.25), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_collapse_tween.tween_property(_body, "modulate:a", 0.35, 0.35)


func _on_damaged(damage_info: DamageInfo) -> void:
	var number_color: Color = CRIT_NUMBER_COLOR if damage_info.is_critical else DAMAGE_NUMBER_COLOR
	FloatingText.spawn(NumberFormat.compact(damage_info.amount), global_position + Vector2(randf_range(-30.0, 30.0), -150.0), number_color, 36 if damage_info.is_critical else 26)
	Audio.play_effect_at(hit_sound, get_aim_point())
