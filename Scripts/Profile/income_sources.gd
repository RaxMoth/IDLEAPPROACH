## Levels and cycle progress of the timed gold sources (Lumber Camp, Mine...).
## The first source of CampaignConfig.income_sources starts at level 1.
## Progress is saved so a long cycle isn't lost when the app closes.
## Levels are bought with gold and reset on rebirth.
##
##   Profile.income.get_level(source.id)
##   Profile.income.purchase_levels(source, 10)   # spends gold, false if too poor
##
## Dependencies: Events, Profile, Types autoloads, CampaignConfig
class_name IncomeSources
extends ProfileModule

var _levels: Dictionary[StringName, int] = {}
var _progress: Dictionary[StringName, float] = {}


func get_save_key() -> StringName:
	return &"income"


func to_dict() -> Dictionary:
	return {"levels": _levels, "progress": _progress}


func from_dict(data: Dictionary) -> void:
	reset()
	var stored_levels: Dictionary[StringName, int] = to_int_dictionary(data.get("levels", {}))
	for source_id: StringName in stored_levels:
		_levels[source_id] = stored_levels[source_id]
	_progress = to_float_dictionary(data.get("progress", {}))


func reset() -> void:
	_levels = {}
	_progress = {}
	if config.campaign != null and not config.campaign.income_sources.is_empty():
		_levels[config.campaign.income_sources[0].id] = 1


func get_level(source_id: StringName) -> int:
	return _levels.get(source_id, 0)


func is_owned(source_id: StringName) -> bool:
	return get_level(source_id) > 0


## Share of the current cycle done (0..1).
func get_progress(source_id: StringName) -> float:
	return _progress.get(source_id, 0.0)


func set_progress(source_id: StringName, progress: float) -> void:
	_progress[source_id] = progress
	mark_dirty()


func can_purchase_levels(source: IncomeSourceData, level_count: int) -> bool:
	return level_count > 0 and Profile.idle_wallet.can_afford(Types.CURRENCY_GOLD, source.get_bulk_cost(get_level(source.id), level_count))


func purchase_levels(source: IncomeSourceData, level_count: int) -> bool:
	if not can_purchase_levels(source, level_count):
		return false
	var current_level: int = get_level(source.id)
	Profile.idle_wallet.spend(Types.CURRENCY_GOLD, source.get_bulk_cost(current_level, level_count))
	_levels[source.id] = current_level + level_count
	if current_level == 0:
		Profile.stats.record_max(Types.STAT_INCOME_SOURCES_OWNED, get_owned_count())
	Events.income_source_leveled.emit(source.id, current_level + level_count)
	mark_dirty()
	return true


func get_owned_count() -> int:
	var owned_count: int = 0
	for source_id: StringName in _levels:
		if _levels[source_id] > 0:
			owned_count += 1
	return owned_count


## Back to only the first source for a new run (rebirth).
func reset_for_new_run() -> void:
	reset()
	for source: IncomeSourceData in config.campaign.income_sources:
		Events.income_source_leveled.emit(source.id, get_level(source.id))
	mark_dirty()
