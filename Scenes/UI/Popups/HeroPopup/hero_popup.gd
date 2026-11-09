## Everything about one hero at a glance: portrait, rarity, level, race,
## melee / ranged and ground / flying as icons, the star ladder (what each of
## the five stars gives and to whom), the auto-cast skill, and a grid of stats
## shown as icon + value (attack, attack speed, DPS, health, defense, crits,
## range, flyers, move speed, race synergy, which monster races it beats and
## loses to), plus shard progress, a gem shard purchase and Star up.
## Stays open after a star-up so the player sees the new numbers.
## Display only — the battle performs purchases when the signals fire.
##
## popup_data keys: hero (HeroData)
## Result: null.
##
## Dependencies: BasePopup, Events, Profile autoloads, CombatStats, StarLadder,
##               StatGrid, IconValue, GameIcons
class_name HeroPopup
extends BasePopup

signal star_up_requested(hero: HeroData)
signal shard_purchase_requested(hero: HeroData)

const TAG_ICON_SIZE: float = 40.0

var hero_data: HeroData

var _level_tag: IconValue

@onready var _rarity_frame: NinePatchRect = %RarityFrame
@onready var _portrait: ColorRect = %Portrait
@onready var _portrait_art: TextureRect = %PortraitArt
@onready var _initial_label: Label = %InitialLabel
@onready var _name_label: Label = %NameLabel
@onready var _rarity_label: Label = %RarityLabel
@onready var _tag_row: HBoxContainer = %TagRow
@onready var _star_ladder: StarLadder = %StarLadder
@onready var _stat_grid: StatGrid = %StatGrid
@onready var _skill_icon: TextureRect = %SkillIcon
@onready var _skill_title_label: Label = %SkillTitleLabel
@onready var _skill_cooldown: IconValue = %SkillCooldown
@onready var _skill_description_label: Label = %SkillDescriptionLabel
@onready var _shard_bar: ProgressBar = %ShardBar
@onready var _shard_label: Label = %ShardLabel
@onready var _star_up_button: Button = %StarUpButton
@onready var _buy_shards_button: Button = %BuyShardsButton
@onready var _buy_shards_amount: IconValue = %BuyShardsAmount
@onready var _buy_shards_price: IconValue = %BuyShardsPrice


func _on_opened(data: Dictionary) -> void:
	hero_data = data.get("hero") as HeroData
	if hero_data == null:
		return
	_rarity_frame.self_modulate = hero_data.get_rarity_color()
	_portrait_art.texture = hero_data.icon
	_initial_label.visible = hero_data.icon == null
	if hero_data.icon == null:
		_portrait.color = hero_data.color
		_initial_label.text = tr(hero_data.display_name).left(1)
	_name_label.text = tr(hero_data.display_name)
	_rarity_label.text = hero_data.get_rarity_name()
	_rarity_label.add_theme_color_override("font_color", hero_data.get_rarity_color())
	_build_tags()
	var skill: HeroSkill = hero_data.skill
	_skill_icon.texture = skill.icon if skill != null else null
	_skill_title_label.text = tr(skill.title) if skill != null else tr("No skill")
	_skill_cooldown.visible = skill != null
	_skill_description_label.text = skill.get_effect_text() if skill != null else ""
	if skill != null:
		_skill_cooldown.text = "%ss" % String.num(skill.cooldown_seconds, 0)
		_skill_title_label.add_theme_color_override("font_color", skill.effect_color)
	Events.hero_star_changed.connect(_on_hero_changed.unbind(1))
	Events.hero_shards_changed.connect(_on_hero_changed.unbind(1))
	Events.hero_leveled.connect(_on_hero_changed.unbind(1))
	Events.currency_changed.connect(func(currency_id: StringName, _amount: int, _delta: int) -> void:
		if currency_id == Types.CURRENCY_GEMS and not is_closing():
			_refresh())
	_refresh()


func _build_tags() -> void:
	_level_tag = IconValue.create(GameIcons.LEVEL, "", TAG_ICON_SIZE)
	_tag_row.add_child(_level_tag)
	var tag_icons: Array[Texture2D] = [
		hero_data.race.icon if hero_data.race != null else null,
		GameIcons.RANGED if hero_data.is_ranged() else GameIcons.MELEE,
		GameIcons.FLYING if hero_data.is_flying() else GameIcons.GROUND,
	]
	for tag_icon: Texture2D in tag_icons:
		if tag_icon != null:
			_tag_row.add_child(IconValue.create(tag_icon, "", TAG_ICON_SIZE))


func _refresh() -> void:
	var level: int = Profile.heroes.get_level(hero_data.id)
	_level_tag.text = str(level) if level > 0 else "–"
	_star_ladder.show_hero(hero_data, Profile.hero_stars.get_stars(hero_data.id))
	_fill_stat_grid(level)
	var shards: int = Profile.hero_stars.get_shards(hero_data.id)
	var campaign: CampaignConfig = GameConfig.get_default().campaign
	var gems: int = Profile.wallet.get_amount(Types.CURRENCY_GEMS)
	var pack_cost: int = campaign.get_shard_pack_cost(hero_data)
	_buy_shards_amount.text = "+%d" % campaign.shard_pack_size
	_buy_shards_price.text = str(pack_cost)
	_buy_shards_button.disabled = gems < pack_cost or Profile.hero_stars.is_maxed(hero_data)
	# The content is drawn by child nodes, which a disabled button doesn't dim.
	_buy_shards_button.modulate.a = 0.5 if _buy_shards_button.disabled else 1.0
	if Profile.hero_stars.is_maxed(hero_data):
		_shard_bar.max_value = 1.0
		_shard_bar.value = 1.0
		_shard_label.text = str(shards)
		_star_up_button.text = tr("Max stars")
		_star_up_button.disabled = true
		return
	var cost: int = Profile.hero_stars.get_next_star_cost(hero_data)
	_shard_bar.max_value = cost
	_shard_bar.value = mini(shards, cost)
	_shard_label.text = "%d / %d" % [shards, cost]
	_star_up_button.text = "+1"
	_star_up_button.disabled = not Profile.hero_stars.can_star_up(hero_data)


## Icon + value per stat (level 1 numbers until recruited); stats raised by a
## synergy or a star bonus show in the highlight color.
func _fill_stat_grid(level: int) -> void:
	_stat_grid.clear()
	var campaign: CampaignConfig = GameConfig.get_default().campaign
	var shown_level: int = maxi(level, 1)
	var attack: float = hero_data.get_damage(shown_level) * CombatStats.get_hero_attack_multiplier(hero_data)
	var health: float = hero_data.get_health(shown_level) * CombatStats.get_hero_health_multiplier_for(hero_data)
	var attacks_per_second: float = CombatStats.get_hero_attacks_per_second(hero_data)
	var speed_boosted: bool = CombatStats.get_synergy_bonus(HeroRace.SynergyStat.ATTACK_SPEED) > 0.0 or _has_star_bonus(StarBonus.Stat.ATTACK_SPEED)
	var defense_boosted: bool = CombatStats.get_synergy_bonus(HeroRace.SynergyStat.DEFENSE) > 0.0 or _has_star_bonus(StarBonus.Stat.DEFENSE)
	var crit_chance: float = CombatStats.get_hero_crit_chance(hero_data)
	var move_speed: float = CombatStats.get_hero_move_speed(hero_data)

	_stat_grid.add_stat(GameIcons.ATTACK, _format(attack), _has_star_bonus(StarBonus.Stat.ATTACK))
	_stat_grid.add_stat(GameIcons.ATTACK_SPEED, "%s/s" % String.num(attacks_per_second, 2), speed_boosted)
	_stat_grid.add_stat(GameIcons.DPS, _format(attack * attacks_per_second * CombatStats.get_hero_crit_factor(hero_data)))
	_stat_grid.add_stat(GameIcons.HEALTH, _format(health), _has_star_bonus(StarBonus.Stat.HEALTH))
	_stat_grid.add_stat(GameIcons.DEFENSE, "%d%%" % roundi(CombatStats.get_hero_defense(hero_data) * 100.0), defense_boosted)
	_stat_grid.add_stat(GameIcons.CRIT, "%d%% x%s" % [roundi(crit_chance * 100.0), String.num(hero_data.crit_multiplier, 1)], _has_star_bonus(StarBonus.Stat.CRIT_CHANCE))
	var style_icon: Array[Texture2D] = [GameIcons.RANGED if hero_data.is_ranged() else GameIcons.MELEE]
	_stat_grid.add_stat(GameIcons.RANGE, str(roundi(hero_data.attack_range)), false, style_icon)
	_stat_grid.add_stat(GameIcons.HITS_AIR if hero_data.can_hit_air() else GameIcons.MISSES_AIR, "")
	_stat_grid.add_stat(GameIcons.MOVE_SPEED, str(roundi(move_speed)), _has_star_bonus(StarBonus.Stat.MOVE_SPEED))
	if hero_data.race != null:
		var race: HeroRace = hero_data.race
		var race_count: int = CombatStats.get_race_count(race)
		var race_bonus: float = race.get_bonus(race_count)
		var first_tier: int = race.synergy_thresholds[0] if not race.synergy_thresholds.is_empty() else 0
		var boosted_stat: Array[Texture2D] = [GameIcons.for_synergy_stat(race.synergy_stat)]
		# Active: the bonus; not yet: heroes recruited / needed for the first tier.
		var race_value: String = "+%d%%" % roundi(race_bonus * 100.0) if race_bonus > 0.0 else "%d/%d" % [race_count, first_tier]
		_stat_grid.add_stat(race.icon, race_value, race_bonus > 0.0, boosted_stat)
	_add_race_wheel_stats(campaign)


## Which monster races this hero's race beats and loses to (race wheel).
func _add_race_wheel_stats(campaign: CampaignConfig) -> void:
	if hero_data.race == null:
		return
	var beaten: Array[Texture2D] = _get_race_icons(campaign.get_races_beaten_by(hero_data.race))
	if not beaten.is_empty():
		_stat_grid.add_stat(GameIcons.COUNTER_STRONG, "+%d%%" % roundi(campaign.race_counter_bonus * 100.0), true, beaten)
	var beating: Array[Texture2D] = _get_race_icons(campaign.get_races_beating(hero_data.race))
	if not beating.is_empty():
		_stat_grid.add_stat(GameIcons.COUNTER_WEAK, "-%d%%" % roundi(campaign.race_counter_penalty * 100.0), false, beating)


func _get_race_icons(races: Array[UnitRace]) -> Array[Texture2D]:
	var icons: Array[Texture2D] = []
	for race: UnitRace in races:
		if race.icon != null:
			icons.append(race.icon)
	return icons


## Some unlocked star bonus (own, team or race) raises [param stat] for this hero.
func _has_star_bonus(stat: StarBonus.Stat) -> bool:
	return CombatStats.get_star_bonus(hero_data, stat) > 0.0


func _format(value: float) -> String:
	return NumberFormat.compact(value if value < 10.0 else roundf(value))


func _on_hero_changed(hero_id: StringName) -> void:
	if hero_data != null and hero_id == hero_data.id and not is_closing():
		_refresh()


func _on_star_up_button_pressed() -> void:
	star_up_requested.emit(hero_data)


func _on_buy_shards_button_pressed() -> void:
	shard_purchase_requested.emit(hero_data)


func _on_close_button_pressed() -> void:
	close(null)
