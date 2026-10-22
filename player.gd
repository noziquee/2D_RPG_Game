extends "res://Characters/Core/Character2D.gd"
## Player input adapter. Health, interaction, inventory and currency live in shared components.
@export_range(1, 1000, 1) var max_health: int = 5
@onready var _damage_animation_player: AnimationPlayer = get_node_or_null("Player/CharacterAnimation") as AnimationPlayer
func _ready() -> void:
	super._ready()
	add_to_group(Groups2D.PLAYER)
	add_to_group(Groups2D.DAMAGEABLE)
func _get_hit_reaction_player() -> AnimationPlayer: return _damage_animation_player
func _get_max_health() -> int: return maxi(max_health, 1)
func _get_movement_input() -> Vector2:
	if not is_alive(): return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
func _get_dash_requested() -> bool: return is_alive() and Input.is_action_just_pressed("dash")
func _get_aim_direction() -> Vector2:
	if not is_alive(): return context.facing_direction
	var direction := get_global_mouse_position() - global_position
	return direction.normalized() if direction.length_squared() > 0.0001 else context.facing_direction
func _get_attack_requested() -> bool: return is_alive() and Input.is_action_just_pressed("attack")
func _get_interact_requested() -> bool: return is_alive() and Input.is_action_just_pressed("interact")
func _get_attack_direction() -> Vector2: return _get_aim_direction()
