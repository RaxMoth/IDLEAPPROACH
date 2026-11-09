## A monster race and its trait. Traits are plain data so new races need no
## code: fast beasts, goblins in bigger groups, undead that get up once,
## armored elementals weak to crits, demons that escalate faster.
## Where it sits on the race wheel: CampaignConfig.race_matchups.
##
## Dependencies: UnitRace
class_name MonsterRace
extends UnitRace
## Player-facing trait line ("Fast", "Gets up once at 30% health").
@export var trait_description: String = ""

@export_group("Trait")
@export var speed_multiplier: float = 1.0
## Added to the monster's defense (still capped by CampaignConfig.max_defense).
@export_range(0.0, 0.9) var defense_bonus: float = 0.0
## Critical hits on this race are multiplied by this.
@export var crit_damage_taken_multiplier: float = 1.0
## Multiplies how fast enemy escalation grows for this race during a stage.
@export var escalation_multiplier: float = 1.0
## Extra copies sent whenever the enemy base sends one of this race.
@export var extra_spawns: int = 0
## > 0: gets up once at this share of its health after dying.
@export_range(0.0, 1.0) var revive_health_fraction: float = 0.0
