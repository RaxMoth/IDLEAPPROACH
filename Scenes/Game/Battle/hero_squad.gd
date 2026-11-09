## The player's heroes in the battle lane. Spawns one Hero per recruited
## HeroData at a rally point next to the player's base (in recruit order),
## refreshes their stats after level ups and sends everyone back to the base
## when a new stage starts. Heroes spawn rarely, so no pooling.
##
## Dependencies: Profile autoload, Hero, HeroData, BattleLane, CampaignConfig
class_name HeroSquad
extends Node2D

@export var hero_scene: PackedScene
@export var lane: BattleLane
## Spawn / respawn spots next to the player's base, one per hero in recruit order.
@export var rally_points: Array[Marker2D] = []
## Each hero leaves the base this much later than the one before it.
@export var release_stagger_seconds: float = 0.45

var _heroes_by_id: Dictionary[StringName, Hero] = {}


## Spawns newly recruited heroes and removes heroes that were reset (rebirth).
func rebuild() -> void:
	var recruited: Array[HeroData] = Profile.heroes.get_recruited_heroes()
	for hero_id: StringName in _heroes_by_id.keys():
		var still_recruited: bool = recruited.any(func(data: HeroData) -> bool: return data.id == hero_id)
		if not still_recruited:
			_heroes_by_id[hero_id].queue_free()
			_heroes_by_id.erase(hero_id)
	var respawn_seconds: float = GameConfig.get_default().campaign.hero_respawn_seconds
	for recruit_index: int in recruited.size():
		var data: HeroData = recruited[recruit_index]
		if _heroes_by_id.has(data.id) or rally_points.is_empty():
			continue
		var rally_point: Marker2D = rally_points[recruit_index % rally_points.size()]
		var hero: Hero = hero_scene.instantiate() as Hero
		add_child(hero)
		hero.setup(data, lane, rally_point.global_position, respawn_seconds, recruit_index * release_stagger_seconds)
		_heroes_by_id[data.id] = hero


## Every hero back to its rally point at full health (new stage).
func reset_for_stage() -> void:
	for hero: Hero in _heroes_by_id.values():
		hero.reset_for_stage()


## Re-reads damage and health of every hero (relics bought).
func refresh_all_stats() -> void:
	for hero: Hero in _heroes_by_id.values():
		hero.refresh_stats()


func get_hero(hero_id: StringName) -> Hero:
	return _heroes_by_id.get(hero_id, null)


func get_hero_count() -> int:
	return _heroes_by_id.size()
