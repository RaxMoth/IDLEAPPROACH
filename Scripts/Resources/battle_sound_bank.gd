## Music and stage-flow sounds of the idle battle (BattleLevel.sounds).
## Combat sounds live with what makes them: attacks on HeroData, skills on
## HeroSkill, and hits / deaths on the Hero, Monster and BattleBase scenes.
## Instance: Ressources/Audio/battle_sounds.tres. The audio itself is
## synthesized by Assets/Audio/Source/generate_audio.py.
##
## Dependencies: SoundEffect
class_name BattleSoundBank
extends Resource

@export_group("Music")
@export var battle_music: AudioStream
## Plays on boss stages (battle_music when empty).
@export var boss_music: AudioStream
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var music_volume_db: float = -3.0
@export_range(0.0, 5.0, 0.1, "suffix:s") var music_fade_seconds: float = 1.5

@export_group("Stage")
@export var stage_won: SoundEffect
@export var stage_lost: SoundEffect
@export var boss_arrived: SoundEffect
@export var shard_dropped: SoundEffect

@export_group("Progress")
@export var hero_recruited: SoundEffect
@export var hero_level_up: SoundEffect
@export var star_up: SoundEffect
## A hero chest bursting open.
@export var chest_opened: SoundEffect
@export var rebirth: SoundEffect


## The track for a stage: boss music on boss stages when there is one.
func get_stage_music(is_boss_stage: bool) -> AudioStream:
	return boss_music if is_boss_stage and boss_music != null else battle_music
