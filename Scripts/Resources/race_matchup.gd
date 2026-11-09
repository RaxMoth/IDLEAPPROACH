## One link of the race wheel (rock, paper, scissors): [member strong_race]
## deals more damage to [member weak_race] and takes less from it. The amounts
## are CampaignConfig.race_counter_bonus / race_counter_penalty. Hero races
## and monster races alternate around the wheel, so every race beats one race
## of the other side and loses to another.
##
## Instances are sub-resources of Ressources/campaign.tres (race_matchups).
##
## Dependencies: UnitRace
class_name RaceMatchup
extends Resource

@export var strong_race: UnitRace
@export var weak_race: UnitRace
