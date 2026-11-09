## Where the player is in the idle base battle: the current stage, the best
## stage of this run and the rebirth count. Destroying the enemy base moves
## one stage up, losing the player's base one stage down.
## Broadcasts Events.stage_changed on every stage change.
##
##   Profile.campaign.current_stage
##   Profile.campaign.advance_stage()   # enemy base destroyed
##   Profile.campaign.retreat_stage()   # player base destroyed
##
## Dependencies: Events, Profile, Types autoloads
class_name CampaignProgress
extends ProfileModule

var current_stage: int = 1
## Best stage reached since the last rebirth (drives the soul reward).
var highest_stage: int = 1
var rebirth_count: int = 0


func get_save_key() -> StringName:
	return &"campaign"


func to_dict() -> Dictionary:
	return {
		"current_stage": current_stage,
		"highest_stage": highest_stage,
		"rebirth_count": rebirth_count,
	}


func from_dict(data: Dictionary) -> void:
	current_stage = maxi(1, int(data.get("current_stage", 1)))
	highest_stage = maxi(current_stage, int(data.get("highest_stage", 1)))
	rebirth_count = int(data.get("rebirth_count", 0))


func reset() -> void:
	current_stage = 1
	highest_stage = 1
	rebirth_count = 0


func advance_stage() -> void:
	current_stage += 1
	highest_stage = maxi(highest_stage, current_stage)
	Profile.stats.record_max(Types.STAT_HIGHEST_STAGE, highest_stage)
	Events.stage_changed.emit(current_stage, highest_stage)
	mark_dirty()


## One stage down (never below 1). The best stage of the run is kept.
func retreat_stage() -> void:
	if current_stage <= 1:
		return
	current_stage -= 1
	Events.stage_changed.emit(current_stage, highest_stage)
	mark_dirty()


## Back to stage 1 for a new run (rebirth). Rebirth count goes up.
func start_new_run() -> void:
	current_stage = 1
	highest_stage = 1
	rebirth_count += 1
	Events.stage_changed.emit(current_stage, highest_stage)
	mark_dirty()
