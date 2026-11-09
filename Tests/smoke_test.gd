## Automated smoke test. Boots every menu and level, plays a few seconds,
## exercises pause / win / lose / results, opens every popup and checks the
## savegame round-trip. Exit code 0 = all good.
##
## Run from the project folder:
##   godot --headless --fixed-fps 60 res://Tests/SmokeTest.tscn
##
## Runs on its own savegame and settings (user://test_savegame.json,
## user://test_settings.cfg), so it never touches the player's progress.
##
## Dependencies: every autoload
extends Node

const TIMEOUT_FRAMES: int = 900

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	# Tests never make sound. Muting the bus (not Settings) leaves the saved volumes alone.
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	if SaveManager.save_path == SaveManager.SAVE_PATH:
		push_error("Smoke test: refusing to run on the player's savegame.")
		get_tree().quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	# Detach from get_tree().current_scene so SceneManager can swap scenes without freeing the test.
	get_tree().current_scene = null
	await _frames(10)
	Profile.reset_progress()
	await _test_save_roundtrip()
	await _test_menus()
	await _test_popups()
	var config: GameConfig = GameConfig.get_default()
	for level_index: int in config.levels.size():
		await _test_level(config.levels[level_index], level_index % 2 == 0)
	_test_idle_math()
	await _test_lane_rules()
	_test_audio()
	_test_art()
	await _test_battle()
	print("\n==== SMOKE TEST: %d checks, %d failures ====" % [_checks, _failures.size()])
	for failure: String in _failures:
		print("  FAIL: " + failure)
	Profile.reset_progress()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _test_save_roundtrip() -> void:
	Profile.wallet.add(Types.CURRENCY_COINS, 123)
	var expected_coins: int = Profile.wallet.get_amount(Types.CURRENCY_COINS)
	_check(SaveManager.save_now(), "save_now succeeded")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path))
	var saved_coins: int = int(saved["sections"]["wallet"]["coins"]) if saved is Dictionary else -1
	_check(saved_coins == expected_coins, "wallet persisted (%d == %d)" % [saved_coins, expected_coins])
	_check(not Profile.wallet.spend(Types.CURRENCY_COINS, 999999999), "cannot overspend")


func _test_menus() -> void:
	var config: GameConfig = GameConfig.get_default()
	for scene_path: String in [config.main_menu_scene, config.level_select_scene, config.shop_scene]:
		SceneManager.change_scene(scene_path)
		_check(await _wait_for_scene(scene_path), "menu loads: " + scene_path)
	_check(SceneManager.go_back(), "back stack works")
	await _wait_for_transition()


func _test_popups() -> void:
	var popup_paths: PackedStringArray = [
		"res://Scenes/UI/Popups/SettingsPopup/SettingsPopup.tscn",
		"res://Scenes/UI/Popups/AchievementsPopup/AchievementsPopup.tscn",
		"res://Scenes/UI/Popups/PausePopup/PausePopup.tscn",
	]
	for popup_path: String in popup_paths:
		UI.open_popup(load(popup_path) as PackedScene)
		await _frames(20)
		_check(UI.has_open_popup(), "popup opens: " + popup_path.get_file())
		UI.close_top_popup()
		await _frames(30)
		_check(not UI.has_open_popup(), "popup closes: " + popup_path.get_file())
	var reward_popup: BasePopup = UI.open_popup(load("res://Scenes/UI/Popups/RewardPopup/RewardPopup.tscn") as PackedScene, {"title": "Test", "rewards": {Types.CURRENCY_COINS: 5}})
	await _frames(20)
	reward_popup.close(1)
	var perk: PerkData = PerkData.new()
	perk.title = "Test perk"
	var perk_popup: BasePopup = UI.open_popup(load("res://Scenes/UI/Popups/PerkChoicePopup/PerkChoicePopup.tscn") as PackedScene, {"perks": [perk]})
	await _frames(20)
	_check(get_tree().paused, "perk popup pauses the game")
	perk_popup.close(perk)
	await _frames(30)
	_check(not get_tree().paused, "perk popup unpauses the game")
	var confirm_task: Array[bool] = [false]
	var confirm_coroutine: Callable = func() -> void: confirm_task[0] = await UI.confirm("Test", "Message")
	confirm_coroutine.call()
	await _frames(20)
	UI.close_top_popup()
	await _frames(30)
	_check(not UI.has_open_popup(), "confirm dialog closes via back")


func _test_level(level: LevelData, force_win: bool) -> void:
	var attempts_before: int = Profile.levels.get_attempts(level.id)
	LevelBase.start_level(level)
	if not await _wait_for_scene(level.scene_path):
		_check(false, "level loads: " + level.id)
		return
	var active_level: LevelBase = get_tree().current_scene as LevelBase
	_check(active_level != null and active_level.level_data == level, "level receives its LevelData: " + level.id)
	_check(await _wait_until(func() -> bool: return active_level.phase == LevelBase.Phase.PLAYING), "intro finishes: " + level.id)
	await _frames(180)
	if active_level.phase == LevelBase.Phase.PLAYING:
		active_level.pause_level()
		await _frames(20)
		_check(get_tree().paused and UI.has_open_popup(), "pause opens menu: " + level.id)
		UI.close_top_popup()
		_check(await _wait_until(func() -> bool: return active_level.phase == LevelBase.Phase.PLAYING), "resume works: " + level.id)
		await _frames(60)
		if force_win and not level.is_endless:
			active_level.win()
		else:
			active_level.lose()
	_check(await _wait_until(func() -> bool: return UI.has_open_popup() and active_level.phase == LevelBase.Phase.FINISHED), "results popup shows: " + level.id)
	_check(Profile.levels.get_attempts(level.id) == attempts_before + 1, "attempt recorded: " + level.id)
	await _frames(30)
	UI.close_top_popup()
	_check(await _wait_until(func() -> bool: return not (get_tree().current_scene is LevelBase) and not SceneManager.is_transitioning), "left level to menu: " + level.id)
	await _frames(5)


func _test_idle_math() -> void:
	var campaign: CampaignConfig = GameConfig.get_default().campaign
	_check(campaign != null and campaign.get_starting_hero() != null, "campaign config loaded")
	if campaign == null or campaign.heroes.is_empty():
		return
	var hero: HeroData = campaign.heroes[0]
	var summed_cost: float = hero.get_level_cost(0) + hero.get_level_cost(1) + hero.get_level_cost(2)
	_check(is_equal_approx(hero.get_bulk_cost(0, 3), summed_cost), "bulk cost equals the sum of level costs")
	_check(hero.get_affordable_levels(0, hero.get_bulk_cost(0, 7), 1000) == 7, "affordable levels match the bulk cost")
	_check(NumberFormat.compact(4.5e36) == "4.5aa", "idle-scale suffix after Dc (%s)" % NumberFormat.compact(4.5e36))
	_check(NumberFormat.compact(999999.0) == "1M", "suffix carries at the boundary (%s)" % NumberFormat.compact(999999.0))
	var late_stage: int = campaign.late_game_start_stage + 10
	var normal_ratio: float = campaign.get_monster_health(late_stage, false) / campaign.get_monster_health(late_stage - 1, false)
	_check(is_equal_approx(normal_ratio, campaign.monster_health_growth * campaign.late_game_growth), "late-game stages grow enemies faster")


## Targeting and damage rules of the lane: flyers, the race wheel, crit weakness, undead.
func _test_lane_rules() -> void:
	var lane: BattleLane = BattleLane.new()
	add_child(lane)
	var flyer: Node2D = _make_lane_dummy(lane)
	flyer.global_position = Vector2(100.0, 0.0)
	var flyer_entry: BattleLane.LaneEntry = lane.register(flyer, Types.Team.ENEMY, flyer.get_child(0) as HealthComponent, 20.0)
	flyer_entry.layer = Types.UnitLayer.AIR
	_check(lane.find_target(Types.Team.PLAYER, 50.0, 100.0, false) == null, "ground melee can't target flyers")
	_check(lane.find_target(Types.Team.PLAYER, 50.0, 100.0, true) == flyer, "ranged and flying fighters can target flyers")
	var beast: MonsterRace = load("res://Ressources/Races/Monsters/beast.tres") as MonsterRace
	var walker: Node2D = _make_lane_dummy(lane)
	var walker_entry: BattleLane.LaneEntry = lane.register(walker, Types.Team.ENEMY, walker.get_child(0) as HealthComponent, 20.0)
	walker_entry.defense = 0.2
	var human: HeroRace = load("res://Ressources/Races/Heroes/human.tres") as HeroRace
	var goblinoid: MonsterRace = load("res://Ressources/Races/Monsters/goblinoid.tres") as MonsterRace
	walker_entry.race = goblinoid
	var counter_damage: float = lane.apply_hit(walker, 100.0, false, null, human)
	_check(is_equal_approx(counter_damage, 100.0 * (1.0 + lane.campaign.race_counter_bonus) * 0.8), "race wheel: Humans hit Goblinoids harder, then defense (%s)" % String.num(counter_damage, 1))
	walker_entry.race = human
	var countered_damage: float = lane.apply_hit(walker, 100.0, false, null, goblinoid)
	_check(is_equal_approx(countered_damage, 100.0 * (1.0 - lane.campaign.race_counter_penalty) * 0.8), "race wheel: Goblinoids hit Humans softer (%s)" % String.num(countered_damage, 1))
	walker_entry.race = beast
	_check(is_equal_approx(lane.apply_hit(walker, 100.0, false, null, human), 80.0), "race wheel: unrelated races deal normal damage")
	walker_entry.defense = 0.0
	walker_entry.crit_damage_taken_multiplier = 1.5
	_check(is_equal_approx(lane.apply_hit(walker, 10.0, true, null), 15.0), "crit weakness multiplies critical hits")
	var undead_data: MonsterData = MonsterData.new()
	undead_data.race = load("res://Ressources/Races/Monsters/undead.tres") as MonsterRace
	var monster: Monster = (load("res://Scenes/Entities/Monster/Monster.tscn") as PackedScene).instantiate() as Monster
	lane.add_child(monster)
	await _frames(3)
	monster.setup(undead_data, lane, 100.0, 1.0, 1.0, false)
	lane.apply_hit(monster, 1000.0, false, null)
	_check(not monster.health_component.is_dead and is_equal_approx(monster.health_component.current_health, 30.0), "undead get up once at 30% health")
	lane.apply_hit(monster, 1000.0, false, null)
	_check(monster.health_component.is_dead, "undead stay down the second time")
	var walker_monster: Monster = (load("res://Scenes/Entities/Monster/Monster.tscn") as PackedScene).instantiate() as Monster
	lane.add_child(walker_monster)
	await _frames(3)
	walker_monster.global_position = Vector2(2000.0, 0.0)
	walker_monster.setup(MonsterData.new(), lane, 100.0, 1.0, 1.0, false)
	walker_monster.snare(1.0, Color.GREEN)
	var snared_x: float = walker_monster.global_position.x
	for physics_frame: int in 30:
		await get_tree().physics_frame
	_check(walker_monster.lane_combat.is_stunned() and is_equal_approx(walker_monster.global_position.x, snared_x), "snared monsters can't move")
	var combat: LaneCombatComponent = LaneCombatComponent.new()
	add_child(combat)
	combat.boost_attack_speed(2.5, 4.0)
	combat.boost_attack_speed(1.6, 5.0)
	_check(is_equal_approx(combat.get_attack_speed_multiplier(), 2.5), "a weaker attack speed boost doesn't replace a stronger one")
	combat.queue_free()
	lane.queue_free()
	await _frames(2)


## Sound data is complete and SoundEffect throttling works (no battle needed).
func _test_audio() -> void:
	var throttled: SoundEffect = SoundEffect.new()
	throttled.streams = [SfxSynth.get_preset(&"click")]
	throttled.min_interval_seconds = 10.0
	_check(Audio.play_effect(throttled), "a sound effect plays")
	_check(not Audio.play_effect_at(throttled, Vector2.ZERO), "replays within the min interval are skipped")
	var unthrottled: SoundEffect = SoundEffect.new()
	unthrottled.streams = throttled.streams
	_check(Audio.play_effect(unthrottled) and Audio.play_effect(unthrottled), "effects without a min interval always play")
	_check(not Audio.play_effect(null) and not Audio.play_effect(SoundEffect.new()), "missing sounds are skipped quietly")
	var campaign: CampaignConfig = GameConfig.get_default().campaign
	var silent_heroes: PackedStringArray = []
	for hero: HeroData in campaign.heroes:
		if hero.attack_sound == null or not hero.attack_sound.has_streams():
			silent_heroes.append(hero.id)
		elif hero.skill != null and (hero.skill.cast_sound == null or not hero.skill.cast_sound.has_streams()):
			silent_heroes.append(String(hero.skill.id))
	_check(silent_heroes.is_empty(), "every hero attack and skill has a sound %s" % str(silent_heroes))
	var battle_scene: Node = load("res://Scenes/Game/Battle/Battle.tscn").instantiate()
	var sounds: BattleSoundBank = (battle_scene as BattleLevel).sounds
	battle_scene.free()
	_check(sounds != null, "the battle has a sound bank")
	if sounds == null:
		return
	var sound_owners: Array[Object] = [sounds]
	for scene_path: String in ["res://Scenes/Entities/Hero/Hero.tscn", "res://Scenes/Entities/Monster/Monster.tscn", "res://Scenes/Entities/BattleBase/BattleBase.tscn"]:
		sound_owners.append(load(scene_path).instantiate())
	var checked_count: int = 0
	var missing_sounds: PackedStringArray = []
	for sound_owner: Object in sound_owners:
		for property_name: String in _get_sound_properties(sound_owner):
			checked_count += 1
			var effect: SoundEffect = sound_owner.get(property_name) as SoundEffect
			if effect == null or not effect.has_streams():
				missing_sounds.append(property_name)
		if sound_owner is Node:
			(sound_owner as Node).free()
	# Bank (8) + Hero (2) + Monster (5) + BattleBase (2).
	_check(checked_count >= 17 and missing_sounds.is_empty(), "every battle and entity sound is set (%d checked) %s" % [checked_count, str(missing_sounds)])
	for music: AudioStream in [sounds.battle_music, sounds.boss_music]:
		var looping_music: AudioStreamWAV = music as AudioStreamWAV
		_check(looping_music != null and looping_music.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music loops: %s" % (music.resource_path if music != null else "missing"))


## Every hero, monster, skill, race, income source, relic and currency has
## its art / icon, and every zone has backdrop props.
func _test_art() -> void:
	var config: GameConfig = GameConfig.get_default()
	var campaign: CampaignConfig = config.campaign
	var missing_art: PackedStringArray = []
	for hero: HeroData in campaign.heroes:
		if hero.icon == null:
			missing_art.append(hero.id)
		if hero.skill != null and hero.skill.icon == null:
			missing_art.append(String(hero.skill.id))
		if hero.race != null and hero.race.icon == null:
			missing_art.append(String(hero.race.id))
		if hero.star_bonuses.size() != campaign.get_max_stars():
			missing_art.append("%s star bonuses" % hero.id)
	for hero_race: HeroRace in campaign.hero_races:
		_check(campaign.get_races_beaten_by(hero_race).size() >= 1 and campaign.get_races_beating(hero_race).size() == 1, "race wheel: %s beats a monster race and loses to one" % hero_race.id)
	for matchup: RaceMatchup in campaign.race_matchups:
		_check((matchup.strong_race is HeroRace) != (matchup.weak_race is HeroRace), "race wheel pairs a hero race with a monster race")
	var zones_without_props: int = 0
	for zone: MonsterZone in campaign.zone_monsters:
		if zone.props.is_empty():
			zones_without_props += 1
		var zone_monsters: Array[MonsterData] = zone.monsters.duplicate()
		if zone.boss != null:
			zone_monsters.append(zone.boss)
		for monster: MonsterData in zone_monsters:
			if monster.icon == null:
				missing_art.append(monster.display_name)
	for source: IncomeSourceData in campaign.income_sources:
		if source.icon == null:
			missing_art.append(source.id)
	for relic: RelicData in campaign.relics:
		if relic.icon == null:
			missing_art.append(relic.id)
	for currency: CurrencyData in config.currencies + config.idle_currencies:
		if currency.icon == null:
			missing_art.append(currency.id)
	_check(missing_art.is_empty(), "everything has its art or icon %s" % str(missing_art))
	_check(zones_without_props == 0 and not campaign.zone_monsters.is_empty(), "every zone has backdrop props")
	_check(GameIcons.HEALTH != null and GameIcons.for_synergy_stat(HeroRace.SynergyStat.DEFENSE) == GameIcons.DEFENSE, "stat icons load")


## Names of the saved SoundEffect properties of [param sound_owner].
func _get_sound_properties(sound_owner: Object) -> PackedStringArray:
	var property_names: PackedStringArray = []
	for property: Dictionary in sound_owner.get_property_list():
		if property["class_name"] == &"SoundEffect" and int(property["usage"]) & PROPERTY_USAGE_STORAGE:
			property_names.append(str(property["name"]))
	return property_names


func _make_lane_dummy(parent: Node) -> Node2D:
	var dummy: Node2D = Node2D.new()
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 1000.0
	dummy.add_child(health)
	parent.add_child(dummy)
	return dummy


## Plays the base battle: monsters marching, gold, recruiting, winning and
## losing a stage, rebirth, relics and saving.
func _test_battle() -> void:
	var config: GameConfig = GameConfig.get_default()
	var campaign: CampaignConfig = config.campaign
	Profile.reset_progress()
	var battle_level: LevelData = config.find_level(&"battle")
	if battle_level == null:
		_check(false, "battle level is configured")
		return
	LevelBase.start_level(battle_level)
	if not await _wait_for_scene(battle_level.scene_path):
		_check(false, "battle loads")
		return
	var battle: BattleLevel = get_tree().current_scene as BattleLevel
	_check(battle != null, "battle scene is a BattleLevel")
	if battle == null:
		return
	_check(battle.hero_squad.get_hero_count() == 1, "the run starts with one hero")
	var starter_node: Hero = battle.hero_squad.get_hero(campaign.get_starting_hero().id)
	var starter_art: Sprite2D = starter_node.get_node("%Art") as Sprite2D if starter_node != null else null
	_check(starter_art != null and starter_art.visible and starter_art.texture != null and not (starter_node.get_node("%Shape") as CanvasItem).visible, "heroes show their art instead of a placeholder")
	_check(await _wait_until(func() -> bool: return Audio.get_current_music() == battle.sounds.battle_music), "the battle music plays")
	var payouts: Array[int] = [0]
	battle.income_ticker.cycle_completed.connect(func(_source: IncomeSourceData, _gold: float) -> void: payouts[0] += 1)
	_check(await _wait_until(func() -> bool: return payouts[0] > 0), "the starting income source pays out on its own")
	_check(await _wait_until(func() -> bool: return battle.stage_director.get_alive_monster_count() > 0), "the enemy base sends monsters")
	var kills_before: float = Profile.stats.get_value(Types.STAT_ENEMIES_DEFEATED)
	# A lone level-1 hero can fall and respawn before its next kill, so allow two timeouts.
	_check(await _wait_until(func() -> bool: return Profile.stats.get_value(Types.STAT_ENEMIES_DEFEATED) > kills_before, TIMEOUT_FRAMES * 2), "the hero defeats monsters on its own")
	_check(Profile.idle_wallet.get_amount(Types.CURRENCY_GOLD) > 0.0, "kills and income pay gold")
	Profile.idle_wallet.add(Types.CURRENCY_GOLD, 1.0e6)
	_check(Profile.wallet.get_amount(Types.CURRENCY_KEYS) == 1, "the run starts with one chest key")
	var first_chest: Dictionary = battle.open_hero_chest()
	var second_hero: HeroData = first_chest.get("hero") as HeroData
	_check(second_hero != null and bool(first_chest.get("is_new", false)) and Profile.hero_stars.is_unlocked(second_hero.id), "the first chest gives a new hero")
	_check(battle.hero_squad.get_hero_count() == 2 and Profile.heroes.get_level(second_hero.id) == 1, "a hero from a chest joins the field at level 1")
	_check(Profile.wallet.get_amount(Types.CURRENCY_KEYS) == 0 and battle.open_hero_chest().is_empty(), "without keys or gems no chest opens")
	Profile.wallet.add(Types.CURRENCY_GEMS, campaign.chest_gem_cost)
	_check(not battle.open_hero_chest().is_empty() and Profile.wallet.get_amount(Types.CURRENCY_GEMS) < campaign.chest_gem_cost, "gems open a chest when out of keys")
	var collected_before: int = Profile.hero_stars.get_unlocked_count()
	var duplicate_hero: HeroData = campaign.get_starting_hero()
	var shards_before_duplicate: int = Profile.hero_stars.get_shards(duplicate_hero.id)
	Profile.hero_stars.add_shards(duplicate_hero.id, campaign.get_chest_duplicate_shards(duplicate_hero))
	_check(Profile.hero_stars.get_shards(duplicate_hero.id) > shards_before_duplicate and not Profile.hero_stars.unlock(duplicate_hero) and Profile.hero_stars.get_unlocked_count() == collected_before, "an owned hero can't be unlocked twice (duplicates are shards)")
	_check(campaign.get_chest_keys_for_clear(campaign.chest_key_stage_interval) >= 1 and campaign.get_chest_keys_for_clear(campaign.zone_length) > campaign.get_chest_keys_for_clear(1), "first clears of key stages and bosses drop chest keys")
	Profile.wallet.add(Types.CURRENCY_KEYS, 1)
	var revealed_results: Array[bool] = []
	var chest_screen: ChestPopup = battle.open_chest_screen()
	chest_screen.revealed.connect(func(is_new: bool) -> void: revealed_results.append(is_new))
	await _frames(20)
	chest_screen.open_requested.emit()
	_check(await _wait_until(func() -> bool: return not revealed_results.is_empty()), "the chest screen opens a chest and reveals the hero")
	UI.close_top_popup()
	await _frames(30)
	var battle_menu: BattleMenu = battle.get_node("%BattleMenu") as BattleMenu
	battle_menu._on_collection_tab_button_pressed()
	await _frames(5)
	_check(battle_menu.find_children("*", "HeroCard", true, false).size() == campaign.heroes.size(), "the collection tab shows every hero")
	battle_menu._on_heroes_tab_button_pressed()
	var second_source: IncomeSourceData = campaign.income_sources[1]
	_check(Profile.income.purchase_levels(second_source, 5) and CombatStats.get_income_per_second() > campaign.income_sources[0].get_gold_per_second(1), "income sources can be unlocked and leveled with gold")
	var speed_race: HeroRace = null
	for hero: HeroData in campaign.heroes:
		if hero.race != null and hero.race.synergy_stat == HeroRace.SynergyStat.ATTACK_SPEED:
			speed_race = hero.race
	var speed_heroes: Array[HeroData] = []
	for hero: HeroData in campaign.heroes:
		if hero.race == speed_race:
			speed_heroes.append(hero)
	for speed_hero: HeroData in speed_heroes:
		Profile.hero_stars.unlock(speed_hero)
	battle.hero_squad.rebuild()
	_check(speed_race != null and CombatStats.get_synergy_bonus(HeroRace.SynergyStat.ATTACK_SPEED) > 0.0, "a full race switches on its team bonus")
	_check(speed_heroes.size() < 3 or is_equal_approx(CombatStats.get_synergy_bonus(HeroRace.SynergyStat.ATTACK_SPEED), speed_race.get_bonus(3)), "three of a race reach the second bonus tier")
	battle.camera.pan_by(Vector2(-99999.0, 0.0))
	var half_view_width: float = battle.get_viewport_rect().size.x * 0.5
	_check(is_equal_approx(battle.camera.global_position.x, battle.camera.pan_limits.position.x + half_view_width), "camera pan stops at your base")
	battle.camera.pan_by(Vector2(99999.0, 0.0))
	_check(is_equal_approx(battle.camera.global_position.x, battle.camera.pan_limits.end.x - half_view_width), "camera pan stops at the enemy base")
	battle.camera.pan_by(Vector2(-99999.0, 0.0))
	battle.follow_resume_seconds = 0.5
	battle.camera.user_panned.emit()
	_check(not battle.is_following(), "dragging the view pauses the auto-follow")
	await _frames(150)
	_check(battle.is_following(), "the camera returns to following on its own")
	var front_x: float = battle.player_base.global_position.x
	for hero_x: float in battle.lane.get_unit_positions(Types.Team.PLAYER):
		front_x = maxf(front_x, hero_x)
	var follow_x: float = clampf(front_x + BattleLevel.FOLLOW_LEAD_DISTANCE, battle.camera.pan_limits.position.x + half_view_width, battle.camera.pan_limits.end.x - half_view_width)
	_check(absf(battle.camera.global_position.x - follow_x) < 120.0, "the camera glides back to the front of the fight (%d vs %d)" % [roundi(battle.camera.global_position.x), roundi(follow_x)])
	var skill_casts: Array[int] = [0]
	for hero: HeroData in Profile.heroes.get_recruited_heroes():
		battle.hero_squad.get_hero(hero.id).ability_component.ability_activated.connect(func(_slot_index: int, _ability: AbilityData) -> void: skill_casts[0] += 1)
	_check(await _wait_until(func() -> bool: return skill_casts[0] > 0), "heroes cast their skills on their own")
	Profile.idle_wallet.add(Types.CURRENCY_GOLD, 1.0e40)
	for hero: HeroData in Profile.heroes.get_recruited_heroes():
		Profile.heroes.purchase_levels(hero, 400)
	battle.hero_squad.refresh_all_stats()
	var stage_before: int = Profile.campaign.current_stage
	_check(await _wait_until(func() -> bool: return Profile.campaign.current_stage > stage_before), "destroying the enemy base moves one stage up")
	_check(await _wait_until(func() -> bool: return not battle.enemy_base.is_destroyed()), "the next stage rebuilds the enemy base")
	var total_shards: int = 0
	for hero: HeroData in campaign.heroes:
		total_shards += Profile.hero_stars.get_shards(hero.id)
	_check(total_shards > 0, "destroyed enemy bases drop hero shards (%d)" % total_shards)
	var starter: HeroData = campaign.get_starting_hero()
	Profile.hero_stars.add_shards(starter.id, 1000)
	var damage_before_star: float = CombatStats.get_hero_hit_damage(starter)
	var hero_popup: HeroPopup = battle.open_hero_details(starter)
	await _frames(20)
	_check(UI.has_open_popup(), "hero details popup opens")
	var gems_before: int = Profile.wallet.get_amount(Types.CURRENCY_GEMS)
	Profile.wallet.add(Types.CURRENCY_GEMS, campaign.get_shard_pack_cost(starter))
	var shards_before: int = Profile.hero_stars.get_shards(starter.id)
	hero_popup._on_buy_shards_button_pressed()
	_check(Profile.hero_stars.get_shards(starter.id) == shards_before + campaign.shard_pack_size and Profile.wallet.get_amount(Types.CURRENCY_GEMS) == gems_before, "gems buy a shard pack")
	hero_popup._on_star_up_button_pressed()
	_check(Profile.hero_stars.get_stars(starter.id) == 1 and CombatStats.get_hero_hit_damage(starter) > damage_before_star, "shards buy a star that boosts the hero")
	var other_hero: HeroData = campaign.heroes[1]
	var other_speed_before: float = CombatStats.get_hero_move_speed(other_hero)
	hero_popup._on_star_up_button_pressed()
	var team_bonus: StarBonus = starter.star_bonuses[1]
	_check(Profile.hero_stars.get_stars(starter.id) == 2 and team_bonus.scope == StarBonus.Scope.TEAM and CombatStats.get_star_bonus(other_hero, team_bonus.stat) >= team_bonus.amount, "a team star bonus reaches the other heroes")
	_check(team_bonus.stat != StarBonus.Stat.MOVE_SPEED or CombatStats.get_hero_move_speed(other_hero) > other_speed_before, "the team move speed star makes everyone faster")
	var starred_hero_node: Hero = battle.hero_squad.get_hero(starter.id)
	_check(starred_hero_node != null and is_equal_approx(starred_hero_node.lane_combat.move_speed, CombatStats.get_hero_move_speed(starter)), "heroes on the field pick up new star bonuses")
	UI.close_top_popup()
	await _frames(30)
	_check(not UI.has_open_popup(), "hero details popup closes")
	var any_monster: Monster = null
	for monster_node: Node in battle.get_node("%MonsterLane").get_children():
		if monster_node is Monster and (monster_node as Monster).is_alive():
			any_monster = monster_node as Monster
	if any_monster == null:
		await _wait_until(func() -> bool: return battle.stage_director.get_alive_monster_count() > 0)
		for monster_node: Node in battle.get_node("%MonsterLane").get_children():
			if monster_node is Monster and (monster_node as Monster).is_alive():
				any_monster = monster_node as Monster
	if any_monster != null:
		battle.open_monster_details(any_monster)
		await _frames(20)
		_check(UI.has_open_popup() and get_tree().paused, "inspecting a monster opens its popup and pauses")
		UI.close_top_popup()
		await _frames(30)
		_check(not get_tree().paused, "closing the monster popup resumes the battle")
	else:
		_check(false, "a monster was available to inspect")
	var stage_after_win: int = Profile.campaign.current_stage
	battle.player_base.health_component.damage(1.0e300)
	_check(await _wait_until(func() -> bool: return Profile.campaign.current_stage == stage_after_win - 1), "losing your base drops one stage")
	_check(await _wait_until(func() -> bool: return not battle.player_base.is_destroyed()), "your base is rebuilt for the next try")
	Profile.campaign.current_stage = campaign.zone_length
	battle.stage_director.restart_stage()
	_check(await _wait_until(func() -> bool: return Audio.get_current_music() == battle.sounds.boss_music), "boss stages switch to the boss music")
	Profile.campaign.highest_stage = campaign.rebirth_min_stage
	var souls_before: int = Profile.wallet.get_amount(Types.CURRENCY_SOULS)
	var souls_gained: int = battle.perform_rebirth()
	_check(souls_gained > 0 and Profile.wallet.get_amount(Types.CURRENCY_SOULS) == souls_before + souls_gained, "rebirth grants souls (+%d)" % souls_gained)
	_check(Profile.campaign.current_stage == 1 and Profile.heroes.get_level(second_hero.id) == 1, "rebirth resets the stage and hero levels")
	_check(is_zero_approx(Profile.idle_wallet.get_amount(Types.CURRENCY_GOLD)), "rebirth resets gold")
	_check(Profile.income.get_level(second_source.id) == 0 and Profile.income.get_level(campaign.income_sources[0].id) == 1, "rebirth resets income sources")
	await _frames(2)
	_check(battle.hero_squad.get_hero_count() == Profile.hero_stars.get_unlocked_count() and Profile.hero_stars.is_unlocked(second_hero.id), "the hero collection survives rebirth")
	_check(await _wait_until(func() -> bool: return Audio.get_current_music() == battle.sounds.battle_music), "the battle music returns after the boss stage")
	_check(Profile.hero_stars.get_stars(starter.id) == 2, "stars survive rebirth")
	var relic: RelicData = campaign.relics[0]
	var multiplier_before: float = CombatStats.get_hero_damage_multiplier()
	_check(Profile.upgrades.purchase(relic) and CombatStats.get_hero_damage_multiplier() > multiplier_before, "relics boost damage")
	Profile.idle_wallet.add(Types.CURRENCY_GOLD, 1.5e40)
	_check(SaveManager.save_now(), "save after rebirth")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path))
	var saved_gold: float = float(saved["sections"]["idle_wallet"]["gold"]) if saved is Dictionary else -1.0
	var saved_rebirths: int = int(saved["sections"]["campaign"]["rebirth_count"]) if saved is Dictionary else -1
	_check(is_equal_approx(saved_gold, Profile.idle_wallet.get_amount(Types.CURRENCY_GOLD)), "idle-scale gold persisted (%s)" % NumberFormat.compact(saved_gold))
	_check(saved_rebirths == 1, "rebirth count persisted")
	battle.quit_to_menu()
	_check(await _wait_until(func() -> bool: return not (get_tree().current_scene is LevelBase) and not SceneManager.is_transitioning), "left battle to menu")
	await _frames(5)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ok   " + description)
	else:
		print("  FAIL " + description)
		_failures.append(description)


func _frames(count: int) -> void:
	for frame_index: int in count:
		await get_tree().process_frame


func _wait_until(condition: Callable, timeout_frames: int = TIMEOUT_FRAMES) -> bool:
	for frame_index: int in timeout_frames:
		if condition.call():
			return true
		await get_tree().process_frame
	return false


func _wait_for_scene(scene_path: String) -> bool:
	var loaded: bool = await _wait_until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == scene_path and not SceneManager.is_transitioning)
	await _frames(5)
	return loaded


func _wait_for_transition() -> void:
	await _frames(5)
	await _wait_until(func() -> bool: return not SceneManager.is_transitioning)
	await _frames(5)
