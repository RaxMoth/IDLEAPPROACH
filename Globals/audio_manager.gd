## Music with cross-fades plus pooled one-shot sound effects.
##
##   Audio.play_music(preload("res://Assets/Audio/theme.ogg"))
##   Audio.play_sfx(hit_sound, 0.1)            # 10% random pitch variation
##   Audio.play_sfx_at(explosion, global_position)
##   Audio.play_ui(Audio.UI_CLICK)            # built-in synthesized UI sounds
##   Audio.play_effect_at(hit_sound, global_position)   # SoundEffect resource
##
## SoundEffect resources carry their own volume, pitch spread and a minimum
## interval: replays closer together are skipped so busy fights don't stack
## dozens of copies of the same hit.
## Volumes are controlled by Settings through the Music / SFX / UI buses.
##
## Dependencies: Settings autoload, SfxSynth, SoundEffect
extends Node

const SFX_POOL_SIZE: int = 12
const POSITIONAL_POOL_SIZE: int = 12
const UI_CLICK: StringName = &"click"
const UI_CONFIRM: StringName = &"confirm"
const UI_ERROR: StringName = &"error"
const UI_REWARD: StringName = &"reward"

var _music_players: Array[AudioStreamPlayer] = []
var _active_music_index: int = 0
var _music_tween: Tween
var _sfx_players: Array[AudioStreamPlayer] = []
var _positional_players: Array[AudioStreamPlayer2D] = []
var _next_sfx_index: int = 0
var _next_positional_index: int = 0
var _effect_last_played_msec: Dictionary[SoundEffect, int] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for music_index: int in 2:
		var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
		music_player.bus = Settings.BUS_MUSIC
		add_child(music_player)
		_music_players.append(music_player)
	for sfx_index: int in SFX_POOL_SIZE:
		var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
		sfx_player.bus = Settings.BUS_SFX
		add_child(sfx_player)
		_sfx_players.append(sfx_player)
	for positional_index: int in POSITIONAL_POOL_SIZE:
		var positional_player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		positional_player.bus = Settings.BUS_SFX
		add_child(positional_player)
		_positional_players.append(positional_player)

func _exit_tree() -> void:
	SfxSynth.clear_cache()

# ============================================
# MUSIC
# ============================================

func play_music(stream: AudioStream, fade_seconds: float = 1.0, volume_db: float = 0.0) -> void:
	var current_player: AudioStreamPlayer = _music_players[_active_music_index]
	if current_player.stream == stream and current_player.playing:
		return
	_active_music_index = 1 - _active_music_index
	var next_player: AudioStreamPlayer = _music_players[_active_music_index]
	next_player.stream = stream
	next_player.volume_db = -60.0 if fade_seconds > 0.0 else volume_db
	next_player.play()
	_crossfade(current_player, next_player, volume_db, fade_seconds)


func stop_music(fade_seconds: float = 1.0) -> void:
	var current_player: AudioStreamPlayer = _music_players[_active_music_index]
	_crossfade(current_player, null, 0.0, fade_seconds)


func is_music_playing() -> bool:
	return _music_players[_active_music_index].playing


## The track playing now (null when nothing plays).
func get_current_music() -> AudioStream:
	var current_player: AudioStreamPlayer = _music_players[_active_music_index]
	return current_player.stream if current_player.playing else null


func _crossfade(outgoing: AudioStreamPlayer, incoming: AudioStreamPlayer, target_volume_db: float, fade_seconds: float) -> void:
	if _music_tween != null:
		_music_tween.kill()
	if fade_seconds <= 0.0:
		outgoing.stop()
		return
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(outgoing, "volume_db", -60.0, fade_seconds)
	if incoming != null:
		_music_tween.tween_property(incoming, "volume_db", target_volume_db, fade_seconds)
	_music_tween.chain().tween_callback(outgoing.stop)

# ============================================
# SOUND EFFECTS
# ============================================

## Plays a non-positional sound. [param pitch_variation] 0.1 = ±10%.
func play_sfx(stream: AudioStream, pitch_variation: float = 0.0, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	_play_on(_take_sfx_player(), stream, 1.0 + randf_range(-pitch_variation, pitch_variation), volume_db)


## Plays a sound at a world position (panning/attenuation relative to the camera).
func play_sfx_at(stream: AudioStream, world_position: Vector2, pitch_variation: float = 0.0, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	_play_on_positional(_take_positional_player(), stream, world_position, 1.0 + randf_range(-pitch_variation, pitch_variation), volume_db)


## Plays [param effect] at full volume wherever the camera is (stage results,
## purchases). Returns false when skipped: no effect or stream, or the same
## effect played less than its min_interval_seconds ago.
func play_effect(effect: SoundEffect) -> bool:
	if not _claim_effect(effect):
		return false
	_play_on(_take_sfx_player(), effect.pick_stream(), effect.pick_pitch(), effect.volume_db)
	return true


## Like play_effect(), but panned and fading with distance from the camera.
func play_effect_at(effect: SoundEffect, world_position: Vector2) -> bool:
	if not _claim_effect(effect):
		return false
	_play_on_positional(_take_positional_player(), effect.pick_stream(), world_position, effect.pick_pitch(), effect.volume_db)
	return true


## Plays one of the built-in synthesized sounds (see SfxSynth presets) on the UI bus.
## Replace with real assets by calling play_sfx with your own streams.
func play_ui(preset_name: StringName) -> void:
	var stream: AudioStream = SfxSynth.get_preset(preset_name)
	if stream == null:
		return
	_play_on(_take_sfx_player(), stream, 1.0, -6.0)


func _claim_effect(effect: SoundEffect) -> bool:
	if effect == null or not effect.has_streams():
		return false
	var now_msec: int = Time.get_ticks_msec()
	var min_interval_msec: int = roundi(effect.min_interval_seconds * 1000.0)
	if _effect_last_played_msec.has(effect) and now_msec - _effect_last_played_msec[effect] < min_interval_msec:
		return false
	_effect_last_played_msec[effect] = now_msec
	return true


# Prefers an idle player so a long sound isn't cut off by a short one;
# when all are busy, the next in turn (the oldest sound, usually) is reused.
func _take_sfx_player() -> AudioStreamPlayer:
	for offset: int in _sfx_players.size():
		var candidate_index: int = (_next_sfx_index + offset) % _sfx_players.size()
		if not _sfx_players[candidate_index].playing:
			_next_sfx_index = candidate_index
			break
	var sfx_player: AudioStreamPlayer = _sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
	return sfx_player


func _take_positional_player() -> AudioStreamPlayer2D:
	for offset: int in _positional_players.size():
		var candidate_index: int = (_next_positional_index + offset) % _positional_players.size()
		if not _positional_players[candidate_index].playing:
			_next_positional_index = candidate_index
			break
	var positional_player: AudioStreamPlayer2D = _positional_players[_next_positional_index]
	_next_positional_index = (_next_positional_index + 1) % _positional_players.size()
	return positional_player


func _play_on(sfx_player: AudioStreamPlayer, stream: AudioStream, pitch: float, volume_db: float) -> void:
	sfx_player.stream = stream
	sfx_player.volume_db = volume_db
	sfx_player.pitch_scale = pitch
	sfx_player.play()


func _play_on_positional(positional_player: AudioStreamPlayer2D, stream: AudioStream, world_position: Vector2, pitch: float, volume_db: float) -> void:
	positional_player.stream = stream
	positional_player.global_position = world_position
	positional_player.volume_db = volume_db
	positional_player.pitch_scale = pitch
	positional_player.play()
