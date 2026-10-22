extends "res://Characters/Core/Character2D.gd"
## Player input adapter. Health and damage live in Character2D's HealthComponent2D.

@export_range(1, 1000, 1) var max_health: int = 5

@onready var _damage_animation_player: AnimationPlayer = get_node_or_null(
	"Player/CharacterAnimation"
) as AnimationPlayer

func _ready() -> void:
	super._ready()
	add_to_group(Groups2D.PLAYER)
	add_to_group(Groups2D.DAMAGEABLE)
	if is_instance_valid(_damage_animation_player):
		if not _damage_animation_player.animation_finished.is_connected(_on_damage_animation_finished):
			_damage_animation_player.animation_finished.connect(_on_damage_animation_finished)

func _get_max_health() -> int:
	return maxi(max_health, 1)

func _get_movement_input() -> Vector2:
	if not is_alive():
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _get_dash_requested() -> bool:
	return is_alive() and Input.is_action_just_pressed("dash")

func _get_aim_direction() -> Vector2:
	if not is_alive():
		return context.facing_direction
	var direction := get_global_mouse_position() - global_position
	return direction.normalized() if direction.length_squared() > 0.0001 else context.facing_direction

func _get_attack_requested() -> bool:
	return is_alive() and Input.is_action_just_pressed("attack")

func _get_attack_direction() -> Vector2:
	return _get_aim_direction()

func _on_damaged(_amount: int) -> void:
	# The authored AnimationPlayer owns the hit reaction; code only requests it.
	if (
		is_instance_valid(_damage_animation_player)
		and _damage_animation_player.has_animation(&"take_damage")
	):
		_damage_animation_player.play(&"take_damage")

func _on_respawn() -> void:
	# Clear any hit reaction left over from before death.
	if is_instance_valid(_damage_animation_player):
		_damage_animation_player.stop()
		if _damage_animation_player.has_animation(&"RESET"):
			_damage_animation_player.play(&"RESET")

func _on_damage_animation_finished(animation_name: StringName) -> void:
	if animation_name != &"take_damage" or not is_alive():
		return
	# Restore the sprite's authored position/modulate after the hit animation.
	if is_instance_valid(_damage_animation_player) and _damage_animation_player.has_animation(&"RESET"):
		_damage_animation_player.play(&"RESET")
