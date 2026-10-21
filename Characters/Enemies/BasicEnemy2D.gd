extends CharacterBody2D
class_name BasicEnemy2D
## Stationary training target used to validate the first melee attack.

signal health_changed(current_health: int, maximum_health: int)
signal died

@export_range(1, 1000, 1) var max_health: int = 3

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int = 0
var _hit_tween: Tween

func _ready() -> void:
	health = maxi(max_health, 1)
	add_to_group("damageable")
	health_changed.emit(health, max_health)
	if _animated_sprite.sprite_frames != null and _animated_sprite.sprite_frames.has_animation("idle"):
		_animated_sprite.play("idle")

func take_damage(amount: int) -> void:
	if health <= 0:
		return

	health = maxi(health - maxi(amount, 0), 0)
	health_changed.emit(health, max_health)
	if health <= 0:
		died.emit()
		queue_free()
		return

	if _hit_tween != null and _hit_tween.is_running():
		_hit_tween.kill()
	_animated_sprite.modulate = Color(1.0, 0.45, 0.45, 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_property(_animated_sprite, "modulate", Color.WHITE, 0.18)
