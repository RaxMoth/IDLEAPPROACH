## Permanent hero progression: the hero collection (heroes found in chests,
## the starting hero from the start), shards collected per hero and the stars
## they were spent on. Unlike hero levels (Profile.heroes) this survives
## rebirth. Shards drop for any hero, owned or not, so a hero can arrive starred.
##
##   if Profile.hero_stars.unlock(hero): print("new hero!")
##   Profile.hero_stars.add_shards(&"archer", 1)
##   if Profile.hero_stars.can_star_up(hero): Profile.hero_stars.star_up(hero)
##
## Dependencies: Events, Profile, Types autoloads, CampaignConfig, HeroData
class_name HeroStars
extends ProfileModule

var _stars: Dictionary[StringName, int] = {}
var _shards: Dictionary[StringName, int] = {}
var _unlocked: Dictionary[StringName, bool] = {}


func get_save_key() -> StringName:
	return &"hero_stars"


func to_dict() -> Dictionary:
	return {"stars": _stars, "shards": _shards, "unlocked": _unlocked.keys()}


func from_dict(data: Dictionary) -> void:
	_stars = to_int_dictionary(data.get("stars", {}))
	_shards = to_int_dictionary(data.get("shards", {}))
	_unlocked = {}
	_unlock_starting_hero()
	var stored_unlocks: Variant = data.get("unlocked", [])
	if stored_unlocks is Array:
		for hero_id: Variant in stored_unlocks:
			_unlocked[StringName(str(hero_id))] = true


func reset() -> void:
	_stars = {}
	_shards = {}
	_unlocked = {}
	_unlock_starting_hero()


func is_unlocked(hero_id: StringName) -> bool:
	return _unlocked.has(hero_id)


func get_unlocked_count() -> int:
	return _unlocked.size()


## Adds [param hero] to the collection (it joins the squad at level 1).
## Returns false when it was already there.
func unlock(hero: HeroData) -> bool:
	if is_unlocked(hero.id):
		return false
	_unlocked[hero.id] = true
	Profile.stats.record_max(Types.STAT_HEROES_COLLECTED, get_unlocked_count())
	Events.hero_unlocked.emit(hero.id)
	mark_dirty()
	return true


func get_stars(hero_id: StringName) -> int:
	return _stars.get(hero_id, 0)


func get_shards(hero_id: StringName) -> int:
	return _shards.get(hero_id, 0)


func add_shards(hero_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	_shards[hero_id] = get_shards(hero_id) + amount
	Events.hero_shards_changed.emit(hero_id, _shards[hero_id])
	mark_dirty()


func _unlock_starting_hero() -> void:
	var starting_hero: HeroData = config.campaign.get_starting_hero() if config.campaign != null else null
	if starting_hero != null:
		_unlocked[starting_hero.id] = true


## Stars across every hero.
func get_total_stars() -> int:
	var total_stars: int = 0
	for hero_id: StringName in _stars:
		total_stars += _stars[hero_id]
	return total_stars


## Shards the next star costs (0 when the hero has every star).
func get_next_star_cost(hero: HeroData) -> int:
	return config.campaign.get_star_shard_cost(get_stars(hero.id))


func is_maxed(hero: HeroData) -> bool:
	return get_stars(hero.id) >= config.campaign.get_max_stars()


func can_star_up(hero: HeroData) -> bool:
	return not is_maxed(hero) and get_shards(hero.id) >= get_next_star_cost(hero)


## Spends shards on the next star. Returns false (and changes nothing) when not enough.
func star_up(hero: HeroData) -> bool:
	if not can_star_up(hero):
		return false
	_shards[hero.id] = get_shards(hero.id) - get_next_star_cost(hero)
	_stars[hero.id] = get_stars(hero.id) + 1
	Profile.stats.record_max(Types.STAT_TOTAL_STARS, get_total_stars())
	Events.hero_shards_changed.emit(hero.id, _shards[hero.id])
	Events.hero_star_changed.emit(hero.id, _stars[hero.id])
	mark_dirty()
	return true
