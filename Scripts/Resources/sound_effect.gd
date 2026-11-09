## One playable sound: a few interchangeable takes plus how loud and how
## varied it plays. Audio.play_effect() / play_effect_at() pick a random take
## and skip the sound when the same effect played less than
## min_interval_seconds ago, so twelve heroes hitting in the same frame don't
## stack twelve copies.
##
##   @export var hit_sound: SoundEffect
##   Audio.play_effect_at(hit_sound, global_position)
##
## Dependencies: none
class_name SoundEffect
extends Resource

## Interchangeable takes; one is picked at random each time.
@export var streams: Array[AudioStream] = []
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db: float = 0.0
## Base pitch (1 = as recorded), so one recording can serve several sounds.
@export_range(0.25, 4.0, 0.01) var pitch_scale: float = 1.0
## Random pitch spread per play (0.1 = ±10%).
@export_range(0.0, 0.5, 0.01) var pitch_variation: float = 0.0
## Plays closer together than this are skipped (0 = never throttled).
@export_range(0.0, 2.0, 0.01, "suffix:s") var min_interval_seconds: float = 0.0


func has_streams() -> bool:
	return not streams.is_empty()


func pick_stream() -> AudioStream:
	return streams.pick_random() as AudioStream if has_streams() else null


func pick_pitch() -> float:
	return pitch_scale * (1.0 + randf_range(-pitch_variation, pitch_variation))
