extends "res://Characters/Core/Character2D.gd"
## Player input adapter and first-pass player damage receiver.

signal health_changed(current_health: int, maximum_health: int)
signal died

@export_range(1, 1000, 1) var max_health: int = 5

@onready var _damage_animation_player: AnimationPlayer = get_node_or_null(
	"Player/CharacterAnimation"
) as AnimationPlayer

var health: int = 0
var _is_dead: bool = false

func _ready() -> void:
	super._ready()
	health = maxi(max_health, 1)
	add_to_group("player")
	add_to_group("damageable")
	if is_instance_valid(_damage_animation_player):
		if not _damage_animation_player.animation_finished.is_connected(_on_damage_animation_finished):
			_damage_animation_player.animation_finished.connect(_on_damage_animation_finished)
	health_changed.emit(health, max_health)

func _get_movement_input() -> Vector2:
	if _is_dead:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _get_dash_requested() -> bool:
	return not _is_dead and Input.is_action_just_pressed("dash")

func _get_aim_direction() -> Vector2:
	if _is_dead:
		return context.facing_direction
	var direction := get_global_mouse_position() - global_position
	return direction.normalized() if direction.length_squared() > 0.0001 else context.facing_direction

func _get_attack_requested() -> bool:
	return not _is_dead and Input.is_action_just_pressed("attack")

func _get_attack_direction() -> Vector2:
	return _get_aim_direction()

func is_alive() -> bool:
	return not _is_dead and health > 0

func take_damage(amount: int) -> void:
	if _is_dead or health <= 0:
		return
	health = maxi(health - maxi(amount, 0), 0)
	health_changed.emit(health, max_health)
	if health <= 0:
		_is_dead = true
		died.emit()
		velocity = Vector2.ZERO
		if is_instance_valid(attack_component):
			attack_component.cancel()
		if is_instance_valid(dash_component):
			dash_component.cancel()
		set_physics_process(false)
		return

	# The authored AnimationPlayer owns the hit reaction; code only requests it.
	if (
		is_instance_valid(_damage_animation_player)
		and _damage_animation_player.has_animation(&"take_damage")
	):
		_damage_animation_player.play(&"take_damage")

func _on_damage_animation_finished(animation_name: StringName) -> void:
	if animation_name != &"take_damage" or _is_dead:
		return
	# Restore the sprite's authored position/modulate after the hit animation.
	if is_instance_valid(_damage_animation_player) and _damage_animation_player.has_animation(&"RESET"):
		_damage_animation_player.play(&"RESET")
