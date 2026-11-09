## One timed gold source (the idle income loop): a progress bar fills every
## cycle_seconds and pays gold on its own. Levels raise the payout; better
## sources cost more, take longer and pay far more. Levels live in
## Profile.income and reset on rebirth.
##
## Gold per cycle = base_gold * level * milestone_multiplier ^ (level / milestone_interval)
##                  * CampaignConfig.get_income_stage_multiplier(stage)
## (workers earn more the further you push, so income keeps pace with kill gold)
## Cost of the next level = base_cost * cost_growth ^ level
##
## Instances live in Ressources/Income/ and are listed in CampaignConfig.
##
## Dependencies: GrowthCurve
class_name IncomeSourceData
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var color: Color = Color(0.6, 0.45, 0.3)

@export_group("Payout")
## Seconds per payout.
@export var cycle_seconds: float = 3.0
## Gold per payout at level 1.
@export var base_gold: float = 3.0
## Every N levels the payout is multiplied by milestone_multiplier.
@export var milestone_interval: int = 25
@export var milestone_multiplier: float = 2.0

@export_group("Cost")
## Gold cost of level 1 (the unlock price).
@export var base_cost: float = 10.0
@export var cost_growth: float = 1.07


## Payout at [param level] before the stage multiplier and relics.
func get_gold_per_cycle(level: int) -> float:
	return base_gold * GrowthCurve.level_scale(level, milestone_interval, milestone_multiplier)


func get_gold_per_second(level: int) -> float:
	return get_gold_per_cycle(level) / maxf(cycle_seconds, 0.01)


func get_next_milestone_level(level: int) -> int:
	return GrowthCurve.get_next_milestone_level(level, milestone_interval)


func get_level_cost(current_level: int) -> float:
	return GrowthCurve.level_cost(base_cost, cost_growth, current_level)


func get_bulk_cost(current_level: int, level_count: int) -> float:
	return GrowthCurve.bulk_cost(base_cost, cost_growth, current_level, level_count)


func get_affordable_levels(current_level: int, available_gold: float, max_count: int) -> int:
	return GrowthCurve.affordable_levels(base_cost, cost_growth, current_level, available_gold, max_count)
