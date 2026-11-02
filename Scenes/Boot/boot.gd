## First scene: shows the splash while autoloads finish booting (settings,
## savegame, profile), then routes to the main menu.
## Add first-launch work here (consent dialogs, tutorial routing, SDK init).
##
## Dependencies: SceneManager, Profile autoloads
extends Control

@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	var config: GameConfig = GameConfig.get_default()
	_title_label.text = config.game_title
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.1.0")
	TweenFX.bounce_in(_title_label, 0.5)
	await get_tree().create_timer(config.boot_splash_seconds).timeout
	SceneManager.change_scene(config.main_menu_scene, {}, false)
