## Automated smoke test. Boots every menu and level, plays a few seconds,
## exercises pause / win / lose / results, opens every popup and checks the
## savegame round-trip. Exit code 0 = all good.
##
## Run from the project folder:
##   godot --headless --fixed-fps 60 res://Tests/SmokeTest.tscn
##
## Note: uses (and resets) the real user:// savegame of the project.
##
## Dependencies: every autoload
extends Node

const TIMEOUT_FRAMES: int = 900

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
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
	print("\n==== SMOKE TEST: %d checks, %d failures ====" % [_checks, _failures.size()])
	for failure: String in _failures:
		print("  FAIL: " + failure)
	Profile.reset_progress()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _test_save_roundtrip() -> void:
	Profile.wallet.add(Types.CURRENCY_COINS, 123)
	var expected_coins: int = Profile.wallet.get_amount(Types.CURRENCY_COINS)
	_check(SaveManager.save_now(), "save_now succeeded")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
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


func _wait_until(condition: Callable) -> bool:
	for frame_index: int in TIMEOUT_FRAMES:
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
