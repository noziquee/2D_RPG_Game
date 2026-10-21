extends Resource
class_name AttackDefinition2D
## Inspector-tunable values for a single directional melee attack.

@export_range(0, 10000, 1) var damage: int = 1
@export_range(0.0, 1.0, 0.01) var windup_duration: float = 0.04
@export_range(0.01, 1.0, 0.01) var active_duration: float = 0.16
@export_range(0.0, 2.0, 0.01) var recovery_duration: float = 0.32
@export_range(0.0, 5.0, 0.01) var cooldown_duration: float = 0.55
@export_range(0.0, 360.0, 1.0) var swing_angle_degrees: float = 110.0
@export var hitbox_size: Vector2 = Vector2(26.0, 16.0)
@export var hitbox_offset: Vector2 = Vector2(18.0, 0.0)
@export var slash_visual_scale: Vector2 = Vector2(1.5, 1.5)
