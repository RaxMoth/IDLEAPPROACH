## Captures a screenshot of any scene after a delay — handy for checking
## layouts and for store screenshots. Must run with a window (not headless);
## it runs muted and on the test savegame (Global.is_test_run), not yours:
##   godot --path . --audio-driver Dummy --resolution 720x1280 res://Tests/ScreenshotTool.tscn -- scene=res://Scenes/Menus/MainMenu/MainMenu.tscn frames=90 out=/tmp/menu.png [popup=res://...tscn] [level=survivor]
##
## Dependencies: SceneManager, UI autoloads
extends Node


func _ready() -> void:
	# Tests never make sound. Muting the bus (not Settings) leaves the saved volumes alone.
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	_run.call_deferred()


func _run() -> void:
	get_tree().current_scene = null
	var arguments: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.split("=", true, 1)
		if parts.size() == 2:
			arguments[parts[0]] = parts[1]
	var scene_params: Dictionary = {}
	if arguments.has("level"):
		var level: LevelData = GameConfig.get_default().find_level(StringName(arguments["level"]))
		scene_params[Types.PARAM_LEVEL_DATA] = level
		arguments["scene"] = level.scene_path
	SceneManager.change_scene(str(arguments.get("scene", GameConfig.get_default().main_menu_scene)), scene_params)
	for frame_index: int in 20:
		await get_tree().process_frame
	if arguments.has("popup"):
		UI.open_popup(load(str(arguments["popup"])) as PackedScene)
	for frame_index: int in int(arguments.get("frames", "90")):
		await get_tree().process_frame
	var output_path: String = str(arguments.get("out", "user://screenshot.png"))
	get_viewport().get_texture().get_image().save_png(output_path)
	print("Saved screenshot: " + output_path)
	get_tree().quit()
