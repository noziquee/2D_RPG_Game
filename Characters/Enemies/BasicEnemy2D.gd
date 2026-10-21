extends "res://Characters/Core/Character2D.gd"
class_name BasicEnemy2D
## Basic damageable enemy. AI supplies intent; shared Character2D components move and attack.

signal health_changed(current_health: int, maximum_health: int)
signal died

@export_range(1, 1000, 1) var max_health: int = 3

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _damage_animation_player: AnimationPlayer = $AnimatedSprite2D/AnimationPlayer
@onready var _ai_controller: EnemyAIController2D = $EnemyAIController2D

var health: int = 0

func _ready() -> void:
	super._ready()
	health = maxi(max_health, 1)
	add_to_group("enemy")
	add_to_group("damageable")
	_ai_controller.initialize(self)
	health_changed.emit(health, max_health)
	if _animated_sprite.sprite_frames != null and _animated_sprite.sprite_frames.has_animation(&"idle"):
		_animated_sprite.play(&"idle")

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
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

func is_alive() -> bool:
	return health > 0

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - maxi(amount, 0), 0)
	health_changed.emit(health, max_health)
	if health <= 0:
		died.emit()
		queue_free()
		return
	if _damage_animation_player.has_animation(&"take_damage"):
		_damage_animation_player.play(&"take_damage")
