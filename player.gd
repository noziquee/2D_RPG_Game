extends "res://Characters/Core/Character2D.gd"
## Player-specific input adapter. Shared movement and state behavior lives in Character2D.

func _get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _get_dash_requested() -> bool:
	return Input.is_action_just_pressed("dash")

func _get_aim_direction() -> Vector2:
	var direction := get_global_mouse_position() - global_position
	return direction.normalized() if direction.length_squared() > 0.0001 else context.facing_direction

func _get_attack_requested() -> bool:
	return Input.is_action_just_pressed("attack")

func _get_attack_direction() -> Vector2:
	return _get_aim_direction()
