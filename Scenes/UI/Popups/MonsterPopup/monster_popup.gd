## Inspect one monster on the field (tap it): portrait, race, ground / flying,
## melee / shooter and boss as icons, its race trait in one line, and a grid
## of stats as icon + value — health, attack and how often it hits, defense,
## range, whether it reaches flyers, speed, how much stronger escalation made
## it, the gold it pays and, from the race wheel, the hero races it beats
## and the hero races it loses to (their emblems).
## Pauses the battle while open.
##
## popup_data keys: monster (Monster)
## Result: null.
##
## Dependencies: BasePopup, CampaignConfig, Monster, StatGrid, IconValue, GameIcons
class_name MonsterPopup
extends BasePopup

const TAG_ICON_SIZE: float = 40.0

@onready var _portrait: ColorRect = %Portrait
@onready var _portrait_art: TextureRect = %PortraitArt
@onready var _initial_label: Label = %InitialLabel
@onready var _name_label: Label = %NameLabel
@onready var _tag_row: HBoxContainer = %TagRow
@onready var _trait_label: Label = %TraitLabel
@onready var _stat_grid: StatGrid = %StatGrid


func _on_opened(data: Dictionary) -> void:
	var monster: Monster = data.get("monster") as Monster
	if monster == null or monster.monster_data == null:
		return
	var monster_data: MonsterData = monster.monster_data
	var race: MonsterRace = monster_data.race
	var campaign: CampaignConfig = GameConfig.get_default().campaign
	_portrait_art.texture = monster_data.icon
	_initial_label.visible = monster_data.icon == null
	if monster_data.icon == null:
		_portrait.color = monster_data.color
		_initial_label.text = tr(monster_data.display_name).left(1)
	_name_label.text = tr(monster_data.display_name)
	var tag_icons: Array[Texture2D] = [
		GameIcons.BOSS if monster.is_boss else null,
		race.icon if race != null else null,
		GameIcons.FLYING if monster_data.is_flying() else GameIcons.GROUND,
		GameIcons.RANGED if monster_data.is_ranged else GameIcons.MELEE,
	]
	for tag_icon: Texture2D in tag_icons:
		if tag_icon != null:
			_tag_row.add_child(IconValue.create(tag_icon, "", TAG_ICON_SIZE))
	_trait_label.visible = race != null
	if race != null:
		_trait_label.text = tr(race.trait_description)
		_trait_label.add_theme_color_override("font_color", race.color)
	var lane_combat: LaneCombatComponent = monster.lane_combat
	var health: HealthComponent = monster.health_component
	_stat_grid.clear()
	_stat_grid.add_stat(GameIcons.HEALTH, "%s/%s" % [_format(health.current_health), _format(health.max_health)])
	_stat_grid.add_stat(GameIcons.ATTACK, _format(lane_combat.attack_damage))
	_stat_grid.add_stat(GameIcons.COOLDOWN, "%ss" % String.num(lane_combat.attack_interval_seconds, 1))
	_stat_grid.add_stat(GameIcons.DEFENSE, "%d%%" % roundi(monster.defense * 100.0))
	var style_icon: Array[Texture2D] = [GameIcons.RANGED if monster_data.is_ranged else GameIcons.MELEE]
	_stat_grid.add_stat(GameIcons.RANGE, str(roundi(lane_combat.attack_range)), false, style_icon)
	_stat_grid.add_stat(GameIcons.HITS_AIR if monster_data.can_hit_air() else GameIcons.MISSES_AIR, "")
	_stat_grid.add_stat(GameIcons.MOVE_SPEED, str(roundi(lane_combat.move_speed)))
	_stat_grid.add_stat(GameIcons.ENEMY_POWER, "x%s" % String.num(monster.spawn_power, 2), monster.spawn_power >= 1.05)
	_stat_grid.add_stat(GameIcons.GOLD, _format(monster.gold_reward))
	if race != null:
		# Race wheel: hero races this monster beats (red: bad for you) and loses to.
		var beaten: Array[Texture2D] = _get_race_icons(campaign.get_races_beaten_by(race))
		if not beaten.is_empty():
			_stat_grid.add_stat(GameIcons.COUNTER_STRONG, "", false, beaten)
		var beating: Array[Texture2D] = _get_race_icons(campaign.get_races_beating(race))
		if not beating.is_empty():
			_stat_grid.add_stat(GameIcons.COUNTER_WEAK, "", true, beating)
	if monster.is_boss:
		_stat_grid.add_stat(GameIcons.BOSS, "x%s" % String.num(campaign.boss_health_multiplier, 0))


func _get_race_icons(races: Array[UnitRace]) -> Array[Texture2D]:
	var icons: Array[Texture2D] = []
	for race: UnitRace in races:
		if race.icon != null:
			icons.append(race.icon)
	return icons


func _format(value: float) -> String:
	return NumberFormat.compact(value if value < 10.0 else roundf(value))


func _on_close_button_pressed() -> void:
	close(null)
