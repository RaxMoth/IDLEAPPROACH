## The idle base battle — the game's main screen. A side-view, endless
## LevelBase with the player's base on the left and the enemy base on the
## right. Heroes leave their base and fight on their own; the enemy base
## sends monsters. Destroy the enemy base to move one stage up; lose yours
## and you drop one stage. Gold comes from kills and from timed income
## sources (Lumber Camp, Mine...) that pay on their own; it levels up
## heroes and income sources. Heroes come from hero chests (opened with chest
## keys from first stage clears, or gems) and stay in the collection for good;
## duplicates and destroyed enemy bases give hero shards that buy permanent
## stars. Rebirth trades the run for souls that buy permanent relics.
## Offline gold is paid on return. No tapping needed.
##
## Composition (Battle.tscn):
##   Backdrop (BattleBackdrop) — sky / ground in zone colors
##   Lane (BattleLane) — who can hit whom; PlayerBase / EnemyBase (BattleBase)
##   StageDirector — stage flow (own StateChart), monster spawning, base resets
##   Squad (HeroSquad) — hero spawning, respawns, stage resets
##   IncomeTicker — fills the income sources' cycles and pays their gold
##   BattleUI — StageBar (top) and BattleMenu (bottom); display only
## This script pays gold, shards and keys and performs purchases, chest
## openings, star-ups and rebirth.
## It also plays the music (boss music on boss stages) and the stage-flow
## sounds from [member sounds]; combat sounds come from the entities.
##
## Dependencies: LevelBase, Profile, UI, Audio, Platform, Events, SaveManager
##               autoloads, CombatStats, CampaignConfig, BattleSoundBank
class_name BattleLevel
extends LevelBase

const GOLD_TEXT_COLOR: Color = Color(1, 0.84, 0.3)
const GOLD_POP_RADIUS: float = 34.0
const BASE_DESTROYED_SHAKE_TRAUMA: float = 0.5
const MONSTER_SCENE: PackedScene = preload("res://Scenes/Entities/Monster/Monster.tscn")
const HERO_POPUP: PackedScene = preload("res://Scenes/UI/Popups/HeroPopup/HeroPopup.tscn")
const MONSTER_POPUP: PackedScene = preload("res://Scenes/UI/Popups/MonsterPopup/MonsterPopup.tscn")
const CHEST_POPUP: PackedScene = preload("res://Scenes/UI/Popups/ChestPopup/ChestPopup.tscn")
## Where the chest key drop appears, relative to the enemy base's feet.
const KEY_DROP_OFFSET: Vector2 = Vector2(-60.0, -330.0)
## How close (world px) a tap must land to a monster's body to inspect it.
const INSPECT_TAP_RADIUS: float = 80.0
## Where the shard drop text appears, relative to the enemy base's feet.
const SHARD_TEXT_OFFSET: Vector2 = Vector2(-140.0, -290.0)
const MONSTER_PREWARM_COUNT: int = 8
## The enemy power readout doesn't need to change every frame.
const ENEMY_POWER_REFRESH_SECONDS: float = 0.5
## Minimap refresh rate (seconds between updates).
const MINIMAP_REFRESH_SECONDS: float = 0.1
## The camera follows the fight centered this far ahead of the frontmost hero.
const FOLLOW_LEAD_DISTANCE: float = 150.0
## Higher = the camera catches up faster while following.
const FOLLOW_SMOOTHING: float = 3.0
## Offline earnings are paid only once per app session.
static var offline_earnings_claimed: bool = false

## World y kept at the bottom edge of the visible battlefield (just above the
## menu), so the battle line sits in the same place on every screen shape.
@export var field_bottom_world_y: float = 735.0
## Music and stage / progress sounds (Ressources/Audio/battle_sounds.tres).
@export var sounds: BattleSoundBank
## After the player drags the view or taps the lane map, the camera stays
## there this long (once the finger is up), then glides back to the front.
@export_range(0.5, 10.0, 0.5, "suffix:s") var follow_resume_seconds: float = 3.0

var campaign: CampaignConfig

var _enemy_power_refresh_remaining: float = 0.0
var _minimap_refresh_remaining: float = 0.0
var _manual_view_remaining: float = 0.0

@onready var stage_director: StageDirector = %StageDirector
@onready var hero_squad: HeroSquad = %Squad
@onready var income_ticker: IncomeTicker = %IncomeTicker
@onready var player_base: BattleBase = %PlayerBase
@onready var enemy_base: BattleBase = %EnemyBase
@onready var backdrop: BattleBackdrop = %Backdrop
@onready var lane: BattleLane = %Lane
@onready var _stage_bar: StageBar = %StageBar
@onready var _battle_menu: BattleMenu = %BattleMenu
@onready var _field_space: Control = %FieldSpace


func _on_level_setup() -> void:
	campaign = GameConfig.get_default().campaign
	if sounds == null:
		sounds = BattleSoundBank.new()
	hud.set_currency_visible(false)
	Pools.prewarm(MONSTER_SCENE, MONSTER_PREWARM_COUNT)
	Events.stage_changed.connect(func(_stage: int, _highest_stage: int) -> void: _refresh_stage_display())
	Events.hero_leveled.connect(func(_hero_id: StringName, _level: int) -> void: _refresh_damage_display())
	Events.upgrade_purchased.connect(func(_upgrade_id: StringName, _level: int) -> void: _on_relics_changed())
	Events.income_source_leveled.connect(func(_source_id: StringName, _level: int) -> void: _refresh_damage_display())
	_battle_menu.build(campaign)
	hero_squad.rebuild()
	_stage_bar.set_lane_extent(camera.pan_limits.position.x, camera.pan_limits.end.x)
	camera.user_panned.connect(hold_manual_view)
	_refresh_stage_display()


func _on_level_started() -> void:
	stage_director.start()
	_offer_offline_earnings()


func _level_process(delta: float) -> void:
	if is_following():
		_follow_front(delta)
	elif not camera.is_touching():
		_manual_view_remaining -= delta
	_minimap_refresh_remaining -= delta
	if _minimap_refresh_remaining <= 0.0:
		_minimap_refresh_remaining = MINIMAP_REFRESH_SECONDS
		var half_view_width: float = get_viewport_rect().size.x * 0.5 / camera.zoom.x
		_stage_bar.update_lane_view(lane.get_unit_positions(Types.Team.PLAYER), lane.get_unit_positions(Types.Team.ENEMY), camera.global_position.x - half_view_width, camera.global_position.x + half_view_width)
	_enemy_power_refresh_remaining -= delta
	if _enemy_power_refresh_remaining > 0.0:
		return
	_enemy_power_refresh_remaining = ENEMY_POWER_REFRESH_SECONDS
	_stage_bar.set_enemy_power(stage_director.get_enemy_power_multiplier())

# ============================================
# PUBLIC API
# ============================================

## Trades the run for souls: stage, gold and hero levels reset, relics stay.
## Returns the souls gained (0 = not allowed yet). Ask the player first.
func perform_rebirth() -> int:
	var souls_gained: int = campaign.get_souls_for_rebirth(Profile.campaign.highest_stage)
	if souls_gained <= 0:
		return 0
	Profile.wallet.add(Types.CURRENCY_SOULS, souls_gained)
	Profile.idle_wallet.reset_currency(Types.CURRENCY_GOLD)
	Profile.heroes.reset_for_new_run()
	Profile.income.reset_for_new_run()
	Profile.campaign.start_new_run()
	Profile.stats.increment(Types.STAT_REBIRTHS)
	Events.rebirth_completed.emit(souls_gained, Profile.campaign.rebirth_count)
	SaveManager.save_now()
	hero_squad.rebuild()
	# The collection stays; every hero is back to level 1.
	hero_squad.refresh_all_stats()
	stage_director.restart_stage()
	hud.show_message(tr("Reborn!"), 1.2)
	Audio.play_effect(sounds.rebirth)
	return souls_gained


## Opens one hero chest, paying a chest key (gems when out of keys). A new
## hero joins the collection and the field at level 1; a hero already owned
## comes as shards. Returns {hero: HeroData, is_new: bool, shards: int}, or
## an empty Dictionary when it can't be paid.
func open_hero_chest() -> Dictionary:
	if not Profile.wallet.spend(Types.CURRENCY_KEYS, 1) and not Profile.wallet.spend(Types.CURRENCY_GEMS, campaign.chest_gem_cost):
		return {}
	var is_owned: Callable = func(hero: HeroData) -> bool: return Profile.hero_stars.is_unlocked(hero.id)
	var hero: HeroData = campaign.roll_chest_hero(is_owned, Profile.hero_stars.get_unlocked_count())
	if hero == null:
		return {}
	var is_new: bool = Profile.hero_stars.unlock(hero)
	var shards: int = 0
	if is_new:
		hero_squad.rebuild()
		# A new hero can switch on a race synergy for the whole squad.
		hero_squad.refresh_all_stats()
		_refresh_damage_display()
	else:
		shards = campaign.get_chest_duplicate_shards(hero)
		Profile.hero_stars.add_shards(hero.id, shards)
	Audio.play_effect(sounds.chest_opened)
	SaveManager.request_save()
	return {"hero": hero, "is_new": is_new, "shards": shards}


## Opens the hero chest screen (closed chest, keys, odds); its Open button
## pays and opens a chest through open_hero_chest().
func open_chest_screen() -> ChestPopup:
	var popup: ChestPopup = UI.open_popup(CHEST_POPUP, {}) as ChestPopup
	popup.open_requested.connect(_on_chest_popup_open_requested.bind(popup))
	popup.revealed.connect(_on_chest_popup_revealed)
	return popup


## Opens the inspect popup for [param monster] (pauses the battle) and returns it.
func open_monster_details(monster: Monster) -> MonsterPopup:
	return UI.open_popup(MONSTER_POPUP, {"monster": monster}) as MonsterPopup


## Opens the details / star-up popup for [param hero] and returns it.
func open_hero_details(hero: HeroData) -> HeroPopup:
	var popup: HeroPopup = UI.open_popup(HERO_POPUP, {"hero": hero}) as HeroPopup
	popup.star_up_requested.connect(_on_hero_popup_star_up_requested)
	popup.shard_purchase_requested.connect(_on_hero_popup_shard_purchase_requested)
	return popup

## True while the camera tracks the front of the fight; false for a moment
## after the player looked around themselves.
func is_following() -> bool:
	return _manual_view_remaining <= 0.0


## The player moved the view: keep it there for follow_resume_seconds.
func hold_manual_view() -> void:
	_manual_view_remaining = follow_resume_seconds

# ============================================
# STAGE DIRECTOR CALLBACKS (connected in Battle.tscn)
# ============================================

func _on_stage_director_stage_started(stage: int) -> void:
	hero_squad.reset_for_stage()
	var is_boss_stage: bool = campaign.is_boss_stage(stage)
	Audio.play_music(sounds.get_stage_music(is_boss_stage), sounds.music_fade_seconds, sounds.music_volume_db)
	if not is_boss_stage:
		return
	Audio.play_effect(sounds.boss_arrived)
	var zone: MonsterZone = campaign.get_zone(stage)
	var boss: MonsterData = zone.boss if zone != null else null
	if boss == null:
		hud.show_message(tr("Boss stage!"), 1.0)
	elif boss.is_flying():
		hud.show_message(tr("Boss: %s — it flies!") % tr(boss.display_name), 1.6)
	else:
		hud.show_message(tr("Boss: %s") % tr(boss.display_name), 1.4)


func _on_stage_director_stage_won(cleared_stage: int, is_first_clear: bool) -> void:
	_grant_base_shards(cleared_stage)
	if is_first_clear:
		_grant_chest_keys(campaign.get_chest_keys_for_clear(cleared_stage))
	hud.show_message(tr("Base destroyed!"), 1.2)
	Events.camera_shake_requested.emit(BASE_DESTROYED_SHAKE_TRAUMA)
	Audio.play_effect(sounds.stage_won)
	Platform.vibrate(Types.HapticStrength.MEDIUM)


func _on_stage_director_stage_lost(lost_stage: int) -> void:
	hud.show_message(tr("Base lost!") if lost_stage > 1 else tr("Hold the line!"), 1.2)
	Events.camera_shake_requested.emit(BASE_DESTROYED_SHAKE_TRAUMA)
	Audio.play_effect(sounds.stage_lost)


func _on_stage_director_monster_defeated(monster: Monster) -> void:
	Profile.idle_wallet.add(Types.CURRENCY_GOLD, monster.gold_reward)
	SkillBurst.play(monster.get_aim_point(), GOLD_POP_RADIUS, GOLD_TEXT_COLOR)
	FloatingText.spawn("+%s" % NumberFormat.compact(monster.gold_reward), monster.get_aim_point() + Vector2(0.0, -20.0), GOLD_TEXT_COLOR, 32)

# ============================================
# BASE / UI CALLBACKS (connected in Battle.tscn)
# ============================================

func _on_player_base_health_changed(current_health: float, max_health: float) -> void:
	_stage_bar.set_base_health(Types.Team.PLAYER, current_health, max_health)


func _on_enemy_base_health_changed(current_health: float, max_health: float) -> void:
	_stage_bar.set_base_health(Types.Team.ENEMY, current_health, max_health)


## Tall phones give the field more height: move the camera so the ground line
## stays right above the menu and the extra space becomes sky.
func _on_field_space_resized() -> void:
	var viewport_center_y: float = get_viewport_rect().size.y * 0.5
	var field_bottom_screen_y: float = _field_space.get_global_rect().end.y
	camera.position.y = field_bottom_world_y - (field_bottom_screen_y - viewport_center_y)


## A tap (not a drag) on the field: inspect the monster under it, if any.
func _on_gesture_detector_tapped(screen_position: Vector2) -> void:
	if not is_playing():
		return
	var monster: Monster = lane.find_unit_near(Types.Team.ENEMY, Global.screen_to_world(self, screen_position), INSPECT_TAP_RADIUS) as Monster
	if monster != null and monster.is_alive():
		open_monster_details(monster)


func _on_stage_bar_lane_jump_requested(lane_fraction: float) -> void:
	hold_manual_view()
	camera.center_on_x(camera.pan_limits.position.x + lane_fraction * camera.pan_limits.size.x)


func _on_battle_menu_hero_level_up_requested(hero: HeroData, level_count: int) -> void:
	var succeeded: bool = Profile.heroes.purchase_levels(hero, level_count)
	_battle_menu.play_purchase_feedback(hero, succeeded)
	if not succeeded:
		Audio.play_ui(Audio.UI_ERROR)
		return
	Audio.play_effect(sounds.hero_level_up)
	var hero_node: Hero = hero_squad.get_hero(hero.id)
	if hero_node != null:
		hero_node.refresh_stats()
		hero_node.play_level_up()


func _on_battle_menu_hero_details_requested(hero: HeroData) -> void:
	open_hero_details(hero)


func _on_battle_menu_chest_requested() -> void:
	open_chest_screen()


func _on_chest_popup_open_requested(popup: ChestPopup) -> void:
	var result: Dictionary = open_hero_chest()
	if result.is_empty():
		_refuse_chest()
		return
	popup.play(result)


func _on_chest_popup_revealed(is_new: bool) -> void:
	Audio.play_effect(sounds.hero_recruited if is_new else sounds.shard_dropped)


func _on_hero_popup_star_up_requested(hero: HeroData) -> void:
	if not Profile.hero_stars.star_up(hero):
		Audio.play_ui(Audio.UI_ERROR)
		return
	Audio.play_effect(sounds.star_up)
	# Team and race star bonuses reach the other heroes too.
	hero_squad.refresh_all_stats()
	var hero_node: Hero = hero_squad.get_hero(hero.id)
	if hero_node != null:
		hero_node.play_level_up()
	_refresh_damage_display()


func _on_battle_menu_income_level_up_requested(source: IncomeSourceData, level_count: int) -> void:
	var succeeded: bool = Profile.income.purchase_levels(source, level_count)
	_battle_menu.play_income_purchase_feedback(source, succeeded)
	Audio.play_ui(Audio.UI_CONFIRM if succeeded else Audio.UI_ERROR)


func _on_income_ticker_cycle_completed(source: IncomeSourceData, gold: float) -> void:
	_battle_menu.play_income_payout(source, gold)


## Gems buy a pack of shards for the chosen hero.
func _on_hero_popup_shard_purchase_requested(hero: HeroData) -> void:
	if not Profile.wallet.spend(Types.CURRENCY_GEMS, campaign.get_shard_pack_cost(hero)):
		Audio.play_ui(Audio.UI_ERROR)
		UI.toast(tr("Not enough gems"))
		return
	Profile.hero_stars.add_shards(hero.id, campaign.shard_pack_size)
	Audio.play_ui(Audio.UI_REWARD)


func _on_battle_menu_relic_purchase_requested(relic: RelicData) -> void:
	if Profile.upgrades.purchase(relic):
		Audio.play_ui(Audio.UI_CONFIRM)
	else:
		Audio.play_ui(Audio.UI_ERROR)


func _on_battle_menu_rebirth_requested() -> void:
	var souls_on_rebirth: int = campaign.get_souls_for_rebirth(Profile.campaign.highest_stage)
	if souls_on_rebirth <= 0:
		return
	var message: String = tr("Start again from stage 1 with no gold, and earn %d souls for permanent relics. Your heroes stay.") % souls_on_rebirth
	if await UI.confirm(tr("Rebirth?"), message, tr("Rebirth"), tr("Not yet")):
		perform_rebirth()

# ============================================
# INTERNALS
# ============================================

func _refresh_stage_display() -> void:
	var stage: int = Profile.campaign.current_stage
	var zone: MonsterZone = campaign.get_zone(stage)
	_stage_bar.set_stage(stage, tr(zone.display_name) if zone != null else "", campaign.is_boss_stage(stage))
	backdrop.apply_zone(zone)
	_refresh_damage_display()
	set_score(Profile.campaign.highest_stage)


func _refresh_damage_display() -> void:
	_stage_bar.set_team_stats(CombatStats.get_team_damage_per_second(), CombatStats.get_income_per_second())


func _refuse_chest() -> void:
	Audio.play_ui(Audio.UI_ERROR)
	UI.toast(tr("Not enough gems"))


func _grant_chest_keys(key_count: int) -> void:
	if key_count <= 0:
		return
	Profile.wallet.add(Types.CURRENCY_KEYS, key_count)
	var drop_position: Vector2 = enemy_base.global_position + KEY_DROP_OFFSET
	FloatingText.spawn_icon(GameIcons.KEY, drop_position, 64.0)
	FloatingText.spawn("+%d" % key_count, drop_position + Vector2(56.0, 0.0), GOLD_TEXT_COLOR, 34)


## Every destroyed enemy base drops shards of one random hero (rarity weighted).
func _grant_base_shards(cleared_stage: int) -> void:
	var shard_hero: HeroData = campaign.pick_shard_hero()
	if shard_hero == null:
		return
	var shard_count: int = campaign.shards_per_boss_base if campaign.is_boss_stage(cleared_stage) else campaign.shards_per_enemy_base
	Profile.hero_stars.add_shards(shard_hero.id, shard_count)
	Audio.play_effect(sounds.shard_dropped)
	FloatingText.spawn(tr("+%d %s shard") % [shard_count, tr(shard_hero.display_name)], enemy_base.global_position + SHARD_TEXT_OFFSET, shard_hero.get_rarity_color(), 30)


## Glides the camera toward the frontmost living hero (or your base when all are down).
func _follow_front(delta: float) -> void:
	var front_x: float = player_base.global_position.x
	for hero_x: float in lane.get_unit_positions(Types.Team.PLAYER):
		front_x = maxf(front_x, hero_x)
	var target_x: float = front_x + FOLLOW_LEAD_DISTANCE
	camera.center_on_x(lerpf(camera.global_position.x, target_x, 1.0 - exp(-FOLLOW_SMOOTHING * delta)))


func _on_relics_changed() -> void:
	hero_squad.refresh_all_stats()
	_refresh_damage_display()


func _offer_offline_earnings() -> void:
	if offline_earnings_claimed:
		return
	offline_earnings_claimed = true
	var offline_seconds: float = minf(Profile.meta.offline_seconds, campaign.max_offline_hours * 3600.0)
	var earned_gold: float = floorf(CombatStats.estimate_offline_gold_per_second(Profile.campaign.current_stage) * offline_seconds)
	if earned_gold < 1.0:
		return
	# Granted before the popup so closing the app on it never loses the gold.
	Profile.idle_wallet.add(Types.CURRENCY_GOLD, earned_gold)
	if offline_seconds < campaign.min_offline_popup_seconds:
		return
	var message: String = tr("Your heroes and workers earned %s gold in %s.") % [NumberFormat.compact(earned_gold), NumberFormat.duration_short(offline_seconds)]
	await UI.confirm(tr("Welcome back!"), message, tr("Collect"), "")
