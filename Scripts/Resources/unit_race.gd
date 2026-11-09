## What hero races (HeroRace) and monster races (MonsterRace) share: a name,
## a color and an emblem. Having one base lets the race wheel
## (CampaignConfig.race_matchups) pair a hero race with a monster race.
##
## Dependencies: none
class_name UnitRace
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
## Emblem shown next to the race in popups.
@export var icon: Texture2D
