extends Resource
class_name StatModifier2D
## One change a status effect makes to a stat while it is active.
## Flat is added to the base. Percent scales the result (0.2 = +20%, -0.5 = -50%).

@export var stat_id: StringName = &"move_speed"
@export var flat: float = 0.0
@export var percent: float = 0.0
