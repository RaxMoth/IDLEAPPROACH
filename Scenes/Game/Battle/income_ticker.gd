## Runs the timed gold sources: fills every owned source's cycle and pays
## its gold (times the stage and gold relic multipliers) whenever a cycle completes. Pauses
## with the game; progress is stored in Profile.income.
##
## Dependencies: Profile, Types autoloads, CampaignConfig, CombatStats, IncomeSourceData
class_name IncomeTicker
extends Node

## A source finished one or more cycles and paid [param gold].
signal cycle_completed(source: IncomeSourceData, gold: float)

var campaign: CampaignConfig


func _ready() -> void:
	campaign = GameConfig.get_default().campaign


func _process(delta: float) -> void:
	for source: IncomeSourceData in campaign.income_sources:
		var level: int = Profile.income.get_level(source.id)
		if level <= 0:
			continue
		var progress: float = Profile.income.get_progress(source.id) + delta / maxf(source.cycle_seconds, 0.01)
		var completed_cycles: int = floori(progress)
		if completed_cycles > 0:
			progress -= completed_cycles
			var gold: float = source.get_gold_per_cycle(level) * completed_cycles * CombatStats.get_income_multiplier()
			Profile.idle_wallet.add(Types.CURRENCY_GOLD, gold)
			cycle_completed.emit(source, gold)
		Profile.income.set_progress(source.id, progress)
