## Shared idle-game growth math: linear-per-level values with a multiplier
## every N levels (milestones), and geometric costs with bulk buying.
## Used by heroes and income sources so both grow the same way.
##
##   value = base * GrowthCurve.level_scale(level, 25, 2.0)
##   cost  = GrowthCurve.level_cost(base_cost, 1.075, level)
##
## Dependencies: none
class_name GrowthCurve
extends RefCounted


## level * multiplier ^ (level / interval) — 0 below level 1.
static func level_scale(level: int, milestone_interval: int, milestone_multiplier: float) -> float:
	if level <= 0:
		return 0.0
	return level * pow(milestone_multiplier, get_milestones_reached(level, milestone_interval))


static func get_milestones_reached(level: int, milestone_interval: int) -> int:
	return floori(float(level) / milestone_interval) if milestone_interval > 0 else 0


## First level that reaches the next milestone after [param level].
static func get_next_milestone_level(level: int, milestone_interval: int) -> int:
	if milestone_interval <= 0:
		return 0
	return (get_milestones_reached(level, milestone_interval) + 1) * milestone_interval


## Cost of the level after [param current_level].
static func level_cost(base_cost: float, cost_growth: float, current_level: int) -> float:
	return base_cost * pow(cost_growth, current_level)


## Total cost of [param level_count] levels from [param current_level] (geometric sum).
static func bulk_cost(base_cost: float, cost_growth: float, current_level: int, level_count: int) -> float:
	if level_count <= 0:
		return 0.0
	if is_equal_approx(cost_growth, 1.0):
		return base_cost * level_count
	return level_cost(base_cost, cost_growth, current_level) * (pow(cost_growth, level_count) - 1.0) / (cost_growth - 1.0)


## Levels [param available_gold] buys from [param current_level], capped at [param max_count].
static func affordable_levels(base_cost: float, cost_growth: float, current_level: int, available_gold: float, max_count: int) -> int:
	var next_cost: float = level_cost(base_cost, cost_growth, current_level)
	if available_gold < next_cost or max_count <= 0:
		return 0
	if is_equal_approx(cost_growth, 1.0):
		return mini(max_count, floori(available_gold / base_cost))
	var affordable: int = floori(log(available_gold * (cost_growth - 1.0) / next_cost + 1.0) / log(cost_growth))
	# Float rounding can overshoot by one level at the boundary.
	while affordable > 0 and bulk_cost(base_cost, cost_growth, current_level, affordable) > available_gold:
		affordable -= 1
	return clampi(affordable, 0, max_count)
