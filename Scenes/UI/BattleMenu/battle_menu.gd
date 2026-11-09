## Bottom panel of the idle battle: a page on top and a navigation bar at
## the bottom (Heroes, Income, the hero chest in the middle, Relics,
## Collection).
##   Heroes     — every hero in the collection to level up (attack, health, next gains).
##   Income     — every timed gold source: unlock, level, watch their cycles fill.
##   Chest      — the round center button (with the key count) asks to open the hero chest.
##   Relics     — rebirth card and the relics bought with souls.
##   Collection — every hero as a card slot (locked ones as silhouettes), with
##                collection progress and the chest odds per rarity.
## The x1 / x10 / x100 / Max selector applies to heroes and income sources.
## Display only: purchases are requested through signals and the battle
## performs them. Refreshes are throttled because gold changes constantly.
##
## Dependencies: Events, Profile, Types autoloads, CombatStats, CampaignConfig,
##               HeroRow, IncomeRow, ShopItemRow, HeroCard, CurrencyDisplay,
##               IconValue, NumberFormat
class_name BattleMenu
extends PanelContainer

signal hero_level_up_requested(hero: HeroData, level_count: int)
## A hero's portrait was tapped.
signal hero_details_requested(hero: HeroData)
## The hero chest button in the middle of the navigation bar was pressed.
signal chest_requested
signal income_level_up_requested(source: IncomeSourceData, level_count: int)
signal relic_purchase_requested(relic: RelicData)
signal rebirth_requested

enum Tab { HEROES, INCOME, RELICS, COLLECTION }

const HERO_ROW_SCENE: PackedScene = preload("res://Scenes/UI/BattleMenu/HeroRow.tscn")
const INCOME_ROW_SCENE: PackedScene = preload("res://Scenes/UI/BattleMenu/IncomeRow.tscn")
const RELIC_ROW_SCENE: PackedScene = preload("res://Scenes/Menus/Shop/ShopItemRow.tscn")
## Buy amount presets; 0 = as many as gold allows.
const BUY_AMOUNTS: Array[int] = [1, 10, 100, 0]
const MAX_BUY_LEVELS: int = 100000
const REFRESH_INTERVAL_SECONDS: float = 0.15
const ACTIVE_TAB_VARIATION: StringName = &"NavTabSelected"
const INACTIVE_TAB_VARIATION: StringName = &"NavTab"
const HERO_CARD_SCENE: PackedScene = preload("res://Scenes/UI/HeroCard/HeroCard.tscn")
const PAGE_TITLES: Dictionary[Tab, String] = {Tab.HEROES: "Heroes", Tab.INCOME: "Income", Tab.RELICS: "Relics", Tab.COLLECTION: "Collection"}
## The collection grid needs more room: the menu takes this share of the
## space it splits with the battlefield (1 = as much as the field).
const COLLECTION_STRETCH_RATIO: float = 2.6

var campaign: CampaignConfig

var _current_tab: Tab = Tab.HEROES
var _buy_amount_index: int = 0
var _hero_rows: Array[HeroRow] = []
var _income_rows: Array[IncomeRow] = []
var _relic_rows: Dictionary[RelicData, ShopItemRow] = {}
var _hero_cards: Array[HeroCard] = []
var _is_dirty: bool = true
var _refresh_cooldown: float = 0.0

@onready var _heroes_tab_button: Button = %HeroesTabButton
@onready var _income_tab_button: Button = %IncomeTabButton
@onready var _relics_tab_button: Button = %RelicsTabButton
@onready var _buy_amount_button: Button = %BuyAmountButton
@onready var _heroes_page: ScrollContainer = %HeroesPage
@onready var _income_page: ScrollContainer = %IncomePage
@onready var _relics_page: ScrollContainer = %RelicsPage
@onready var _hero_list: VBoxContainer = %HeroList
@onready var _income_list: VBoxContainer = %IncomeList
@onready var _relic_list: VBoxContainer = %RelicList
@onready var _rebirth_info_label: Label = %RebirthInfoLabel
@onready var _rebirth_button: Button = %RebirthButton
@onready var _collection_tab_button: Button = %CollectionTabButton
@onready var _collection_page: ScrollContainer = %CollectionPage
@onready var _collection_grid: GridContainer = %CollectionGrid
@onready var _collection_value: IconValue = %CollectionValue
@onready var _chest_button: TextureButton = %ChestButton
@onready var _key_badge: Control = %KeyBadge
@onready var _key_count: IconValue = %KeyCount
@onready var _page_title: Label = %PageTitle


func _ready() -> void:
	Events.idle_currency_changed.connect(func(_currency_id: StringName, _amount: float, _delta: float) -> void: mark_dirty())
	Events.currency_changed.connect(func(_currency_id: StringName, _amount: int, _delta: int) -> void: mark_dirty())
	Events.hero_unlocked.connect(func(_hero_id: StringName) -> void: mark_dirty())
	Events.currency_changed.connect(func(_currency_id: StringName, _amount: int, _delta: int) -> void: mark_dirty())
	Events.hero_leveled.connect(func(_hero_id: StringName, _level: int) -> void: mark_dirty())
	Events.income_source_leveled.connect(func(_source_id: StringName, _level: int) -> void: mark_dirty())
	Events.upgrade_purchased.connect(func(_upgrade_id: StringName, _level: int) -> void: mark_dirty())
	Events.stage_changed.connect(func(_stage: int, _highest_stage: int) -> void: mark_dirty())
	Events.hero_shards_changed.connect(func(_hero_id: StringName, _shards: int) -> void: mark_dirty())
	Events.hero_star_changed.connect(func(_hero_id: StringName, _stars: int) -> void: mark_dirty())
	_show_tab(Tab.HEROES)
	_update_buy_amount_button()


## Creates one row per hero, income source and relic. Call once from the battle's setup.
func build(campaign_config: CampaignConfig) -> void:
	campaign = campaign_config
	for hero: HeroData in campaign.heroes:
		var hero_row: HeroRow = HERO_ROW_SCENE.instantiate() as HeroRow
		_hero_list.add_child(hero_row)
		hero_row.setup(hero)
		hero_row.level_up_pressed.connect(func() -> void: hero_level_up_requested.emit(hero, get_hero_purchase_count(hero)))
		hero_row.details_pressed.connect(func() -> void: hero_details_requested.emit(hero))
		_hero_rows.append(hero_row)
	for source: IncomeSourceData in campaign.income_sources:
		var income_row: IncomeRow = INCOME_ROW_SCENE.instantiate() as IncomeRow
		_income_list.add_child(income_row)
		income_row.setup(source)
		income_row.level_up_pressed.connect(func() -> void: income_level_up_requested.emit(source, get_income_purchase_count(source)))
		_income_rows.append(income_row)
	for relic: RelicData in campaign.relics:
		var relic_row: ShopItemRow = RELIC_ROW_SCENE.instantiate() as ShopItemRow
		_relic_list.add_child(relic_row)
		relic_row.buy_pressed.connect(func() -> void: relic_purchase_requested.emit(relic))
		_relic_rows[relic] = relic_row
	for hero: HeroData in campaign.heroes:
		var hero_card: HeroCard = HERO_CARD_SCENE.instantiate() as HeroCard
		_collection_grid.add_child(hero_card)
		hero_card.pressed.connect(func() -> void: hero_details_requested.emit(hero))
		_hero_cards.append(hero_card)
	refresh()


func mark_dirty() -> void:
	_is_dirty = true


## Levels the current buy amount buys for [param hero].
func get_hero_purchase_count(hero: HeroData) -> int:
	var current_level: int = Profile.heroes.get_level(hero.id)
	var gold: float = Profile.idle_wallet.get_amount(Types.CURRENCY_GOLD)
	return _resolve_purchase_count(current_level, hero.get_affordable_levels(current_level, gold, MAX_BUY_LEVELS))


## Levels the current buy amount buys for [param source] (always 1 to unlock).
func get_income_purchase_count(source: IncomeSourceData) -> int:
	var current_level: int = Profile.income.get_level(source.id)
	var gold: float = Profile.idle_wallet.get_amount(Types.CURRENCY_GOLD)
	return _resolve_purchase_count(current_level, source.get_affordable_levels(current_level, gold, MAX_BUY_LEVELS))


## Pop on success, shake when the purchase was refused.
func play_purchase_feedback(hero: HeroData, succeeded: bool) -> void:
	for hero_row: HeroRow in _hero_rows:
		if hero_row.hero_data == hero:
			_play_button_feedback(hero_row.get_level_up_button(), succeeded)
			return


func play_income_purchase_feedback(source: IncomeSourceData, succeeded: bool) -> void:
	for income_row: IncomeRow in _income_rows:
		if income_row.source_data == source:
			_play_button_feedback(income_row.get_level_up_button(), succeeded)
			return


## A source just paid out (only animates while the Income tab is open).
func play_income_payout(source: IncomeSourceData, _gold: float) -> void:
	if _current_tab != Tab.INCOME:
		return
	for income_row: IncomeRow in _income_rows:
		if income_row.source_data == source:
			income_row.play_payout()
			return


func refresh() -> void:
	_is_dirty = false
	if campaign == null:
		return
	_refresh_chest_button()
	_refresh_hero_rows()
	_refresh_income_rows()
	_refresh_relic_rows()
	_refresh_rebirth_card()
	_refresh_collection()


func _process(delta: float) -> void:
	if _current_tab == Tab.INCOME:
		for income_row: IncomeRow in _income_rows:
			income_row.set_cycle_progress(Profile.income.get_progress(income_row.source_data.id))
	_refresh_cooldown -= delta
	if _is_dirty and _refresh_cooldown <= 0.0:
		_refresh_cooldown = REFRESH_INTERVAL_SECONDS
		refresh()


func _resolve_purchase_count(current_level: int, affordable_levels: int) -> int:
	if current_level == 0:
		return 1
	var buy_amount: int = BUY_AMOUNTS[_buy_amount_index]
	return buy_amount if buy_amount > 0 else maxi(1, affordable_levels)


func _refresh_hero_rows() -> void:
	var gold: float = Profile.idle_wallet.get_amount(Types.CURRENCY_GOLD)
	for hero_row: HeroRow in _hero_rows:
		var hero: HeroData = hero_row.hero_data
		var level: int = Profile.heroes.get_level(hero.id)
		# Only heroes in the collection; the others are in the hero index.
		hero_row.visible = level > 0
		if level == 0:
			continue
		var level_count: int = get_hero_purchase_count(hero)
		var cost: float = hero.get_bulk_cost(level, level_count)
		var attack_gain: float = (hero.get_damage(level + level_count) - hero.get_damage(level)) * CombatStats.get_hero_attack_multiplier(hero)
		var health_gain: float = (hero.get_health(level + level_count) - hero.get_health(level)) * CombatStats.get_hero_health_multiplier_for(hero)
		var button_text: String = "%s\n%s" % [tr("Lv +%d") % level_count, NumberFormat.compact(ceilf(cost))]
		hero_row.update_display(level, _format_stat(CombatStats.get_hero_hit_damage(hero)), _format_stat(CombatStats.get_hero_max_health(hero)),
			"+" + _format_stat(attack_gain), "+" + _format_stat(health_gain), button_text, gold >= cost)
		hero_row.update_stars(Profile.hero_stars.get_stars(hero.id), Profile.hero_stars.can_star_up(hero))


## The key count on the chest button (hidden without keys).
func _refresh_chest_button() -> void:
	var keys: int = Profile.wallet.get_amount(Types.CURRENCY_KEYS)
	_key_badge.visible = keys > 0
	_key_count.text = str(keys)


## Every hero's card (owned or locked), collection progress.
func _refresh_collection() -> void:
	for card_index: int in _hero_cards.size():
		var hero: HeroData = campaign.heroes[card_index]
		_hero_cards[card_index].show_hero(hero, Profile.hero_stars.is_unlocked(hero.id), Profile.heroes.get_level(hero.id),
			Profile.hero_stars.get_stars(hero.id), Profile.hero_stars.get_shards(hero.id), Profile.hero_stars.get_next_star_cost(hero))
	_collection_value.text = "%d/%d" % [Profile.hero_stars.get_unlocked_count(), campaign.heroes.size()]


func _refresh_income_rows() -> void:
	var gold: float = Profile.idle_wallet.get_amount(Types.CURRENCY_GOLD)
	var gold_multiplier: float = CombatStats.get_income_multiplier()
	for income_row: IncomeRow in _income_rows:
		var source: IncomeSourceData = income_row.source_data
		var level: int = Profile.income.get_level(source.id)
		var level_count: int = get_income_purchase_count(source)
		var cost: float = source.get_bulk_cost(level, level_count)
		var shown_level: int = maxi(level, 1)
		var payout: float = source.get_gold_per_cycle(shown_level) * gold_multiplier
		var gain: float = (source.get_gold_per_cycle(level + level_count) - source.get_gold_per_cycle(level)) * gold_multiplier
		var gain_text: String = "+" + _format_stat(gain) if level > 0 else ""
		var action_text: String = tr("Unlock") if level == 0 else tr("Lv +%d") % level_count
		var button_text: String = "%s\n%s" % [action_text, NumberFormat.compact(ceilf(cost))]
		income_row.update_display(level, _format_stat(payout), "%ss" % String.num(source.cycle_seconds, 0), gain_text, button_text, gold >= cost)


func _refresh_relic_rows() -> void:
	var souls_icon: Texture2D = _get_souls_icon()
	for relic: RelicData in _relic_rows:
		var level: int = Profile.upgrades.get_level(relic.id)
		var detail: String = "%s  •  %s" % [tr("Lv %d") % level, relic.describe_bonus(level)]
		var is_maxed: bool = relic.is_maxed(level)
		var button_text: String = tr("Max") if is_maxed else NumberFormat.compact(relic.get_cost(level))
		_relic_rows[relic].set_icons(relic.icon, null if is_maxed else souls_icon)
		_relic_rows[relic].setup(tr(relic.title), "", detail, button_text, Profile.upgrades.can_purchase(relic))


func _refresh_rebirth_card() -> void:
	var highest_stage: int = Profile.campaign.highest_stage
	var souls_on_rebirth: int = campaign.get_souls_for_rebirth(highest_stage)
	if souls_on_rebirth > 0:
		_rebirth_info_label.text = tr("Rebirth now for %d souls. Stage, gold, hero levels and income reset; heroes, relics and stars stay.") % souls_on_rebirth
	else:
		_rebirth_info_label.text = tr("Reach stage %d to rebirth (best this run: %d).") % [campaign.rebirth_min_stage, highest_stage]
	_rebirth_button.disabled = souls_on_rebirth <= 0
	_rebirth_button.text = "%s  +%d" % [tr("Rebirth"), souls_on_rebirth] if souls_on_rebirth > 0 else tr("Rebirth")
	_rebirth_button.icon = _get_souls_icon() if souls_on_rebirth > 0 else null


## Whole numbers from 10 up ("475 ATK"); one decimal below so small gains still show.
func _format_stat(value: float) -> String:
	return NumberFormat.compact(value if value < 10.0 else roundf(value))


func _get_souls_icon() -> Texture2D:
	var souls_currency: CurrencyData = GameConfig.get_default().find_currency(Types.CURRENCY_SOULS)
	return souls_currency.icon if souls_currency != null else null


func _play_button_feedback(button: Button, succeeded: bool) -> void:
	if succeeded:
		TweenFX.pop(button, 1.08, 0.2)
	else:
		TweenFX.shake(button)


func _show_tab(tab: Tab) -> void:
	_current_tab = tab
	_heroes_page.visible = tab == Tab.HEROES
	_income_page.visible = tab == Tab.INCOME
	_relics_page.visible = tab == Tab.RELICS
	_collection_page.visible = tab == Tab.COLLECTION
	size_flags_stretch_ratio = COLLECTION_STRETCH_RATIO if tab == Tab.COLLECTION else 1.0
	_buy_amount_button.visible = tab == Tab.HEROES or tab == Tab.INCOME
	_page_title.text = tr(PAGE_TITLES[tab])
	_heroes_tab_button.theme_type_variation = ACTIVE_TAB_VARIATION if tab == Tab.HEROES else INACTIVE_TAB_VARIATION
	_income_tab_button.theme_type_variation = ACTIVE_TAB_VARIATION if tab == Tab.INCOME else INACTIVE_TAB_VARIATION
	_relics_tab_button.theme_type_variation = ACTIVE_TAB_VARIATION if tab == Tab.RELICS else INACTIVE_TAB_VARIATION
	_collection_tab_button.theme_type_variation = ACTIVE_TAB_VARIATION if tab == Tab.COLLECTION else INACTIVE_TAB_VARIATION


func _update_buy_amount_button() -> void:
	var buy_amount: int = BUY_AMOUNTS[_buy_amount_index]
	_buy_amount_button.text = tr("Max") if buy_amount == 0 else "x%d" % buy_amount


func _on_chest_button_pressed() -> void:
	chest_requested.emit()


func _on_collection_tab_button_pressed() -> void:
	_show_tab(Tab.COLLECTION)
	refresh()


func _on_heroes_tab_button_pressed() -> void:
	_show_tab(Tab.HEROES)
	refresh()


func _on_income_tab_button_pressed() -> void:
	_show_tab(Tab.INCOME)
	refresh()


func _on_relics_tab_button_pressed() -> void:
	_show_tab(Tab.RELICS)
	refresh()


func _on_buy_amount_button_pressed() -> void:
	_buy_amount_index = (_buy_amount_index + 1) % BUY_AMOUNTS.size()
	_update_buy_amount_button()
	refresh()


func _on_rebirth_button_pressed() -> void:
	rebirth_requested.emit()
