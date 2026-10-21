extends Resource
class_name AttackDefinition2D
## Data for damage, cooldown, and the collision area of an animation-driven attack.

@export_range(0, 10000, 1) var damage: int = 1
@export_range(0.0, 5.0, 0.01) var cooldown_duration: float = 0.55
@export var hitbox_size: Vector2 = Vector2(50.0, 16.0)
@export var hitbox_offset: Vector2 = Vector2(25.0, 0.0)
