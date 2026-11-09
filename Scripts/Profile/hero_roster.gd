## Hero levels for the current run. Only heroes in the collection
## (Profile.hero_stars) have a level: they start every run at level 1 and level
## up with gold; levels reset on rebirth, the collection stays.
##
##   Profile.heroes.get_level(hero.id)          # 0 = not in the collection
##   Profile.heroes.purchase_levels(hero, 10)   # spends gold, false if too poor
##
## Dependencies: Events, Profile, Types autoloads, CampaignConfig
class_name HeroRoster
extends ProfileModule

# Levels above 1 only (owned heroes default to level 1).
var _levels: Dictionary[StringName, int] = {}


func get_save_key() -> StringName:
	return &"heroes"


func to_dict() -> Dictionary:
	return _levels


func from_dict(data: Dictionary) -> void:
	reset()
	var stored_levels: Dictionary[StringName, int] = to_int_dictionary(data)
	for hero_id: StringName in stored_levels:
		_levels[hero_id] = stored_levels[hero_id]


func reset() -> void:
	_levels = {}


func get_level(hero_id: StringName) -> int:
	if not Profile.hero_stars.is_unlocked(hero_id):
		return 0
	return maxi(_levels.get(hero_id, 1), 1)


## In the collection, so on the field.
func is_recruited(hero_id: StringName) -> bool:
	return get_level(hero_id) > 0


## Heroes in the collection, in CampaignConfig.heroes order.
func get_recruited_heroes() -> Array[HeroData]:
	var recruited: Array[HeroData] = []
	for hero: HeroData in config.campaign.heroes:
		if is_recruited(hero.id):
			recruited.append(hero)
	return recruited


func can_purchase_levels(hero: HeroData, level_count: int) -> bool:
	return level_count > 0 and is_recruited(hero.id) and Profile.idle_wallet.can_afford(Types.CURRENCY_GOLD, hero.get_bulk_cost(get_level(hero.id), level_count))


func purchase_levels(hero: HeroData, level_count: int) -> bool:
	if not can_purchase_levels(hero, level_count):
		return false
	var current_level: int = get_level(hero.id)
	Profile.idle_wallet.spend(Types.CURRENCY_GOLD, hero.get_bulk_cost(current_level, level_count))
	_levels[hero.id] = current_level + level_count
	Events.hero_leveled.emit(hero.id, current_level + level_count)
	mark_dirty()
	return true


## Every hero back to level 1 for a new run (rebirth); the collection stays.
func reset_for_new_run() -> void:
	reset()
	for hero: HeroData in config.campaign.heroes:
		Events.hero_leveled.emit(hero.id, get_level(hero.id))
	mark_dirty()
