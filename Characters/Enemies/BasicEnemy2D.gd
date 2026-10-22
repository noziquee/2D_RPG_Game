extends "res://Characters/Core/Character2D.gd"
class_name BasicEnemy2D
## Basic damageable enemy. AI supplies intent; shared Character2D components move and attack.

## How long the corpse lingers so its knockback can finish before the node is freed.
const DEATH_LINGER_SECONDS: float = 0.4

@export_range(1, 1000, 1) var max_health: int = 3

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _damage_animation_player: AnimationPlayer = $AnimatedSprite2D/AnimationPlayer
@onready var _ai_controller: EnemyAIController2D = $EnemyAIController2D

func _ready() -> void:
	super._ready()
	add_to_group(Groups2D.ENEMY)
	add_to_group(Groups2D.DAMAGEABLE)
	_ai_controller.initialize(self)
	if _animated_sprite.sprite_frames != null and _animated_sprite.sprite_frames.has_animation(&"idle"):
		_animated_sprite.play(&"idle")

func _get_max_health() -> int:
	return maxi(max_health, 1)

func _physics_process(delta: float) -> void:
	# AI steers only a living enemy. The base still runs movement so knockback can finish.
	if is_alive():
		_ai_controller.physics_update(delta)
	super._physics_process(delta)

func _get_movement_input() -> Vector2:
	return _ai_controller.get_movement_intent()

func _get_aim_direction() -> Vector2:
	return _ai_controller.get_aim_direction()

func _get_attack_requested() -> bool:
	return _ai_controller.consume_attack_request()

func _get_attack_direction() -> Vector2:
	return _ai_controller.get_attack_direction()

func _get_dash_requested() -> bool:
	return false

func _on_damaged(_amount: int) -> void:
	if _damage_animation_player.has_animation(&"take_damage"):
		_damage_animation_player.play(&"take_damage")

func _on_death() -> void:
	# The died signal has already fired. Hide the body, stop it blocking others, and
	# play the explosion where it stood. The node is freed after a short linger.
	_animated_sprite.visible = false
	set_deferred("collision_layer", 0)
	DeathEffect2D.spawn(get_parent(), global_position)
	if is_inside_tree():
		get_tree().create_timer(DEATH_LINGER_SECONDS).timeout.connect(queue_free)
