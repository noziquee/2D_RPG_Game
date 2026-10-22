extends Resource
class_name StatusEffect2D
## Data for a timed buff or debuff: stat modifiers, stacking rules, and optional ticks.

enum Stacking {
	REFRESH,    ## Re-applying resets the duration; stacks stay the same.
	ADD_STACK,  ## Re-applying adds a stack (up to max_stacks) and resets the duration.
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var is_debuff: bool = false
@export_range(0.01, 600.0, 0.01, "or_greater") var duration: float = 5.0
@export var stacking: Stacking = Stacking.REFRESH
@export_range(1, 99, 1, "or_greater") var max_stacks: int = 1
## Modifiers are multiplied by the stack count.
@export var modifiers: Array[StatModifier2D] = []
## Damage over time: tick_damage every tick_interval seconds (0 disables ticks).
@export_range(0.0, 60.0, 0.05) var tick_interval: float = 0.0
@export_range(0, 10000, 1) var tick_damage: int = 0
@export var damage_type: DamageRequest2D.DamageType = DamageRequest2D.DamageType.POISON
