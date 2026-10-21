extends Node2D
class_name AttackSlash2D
## Short-lived slash effect with a hitbox enabled only during active attack frames.

signal hit_confirmed(target: Node, damage: int)

var source: Node2D
var damage: int = 1
var direction: Vector2 = Vector2.RIGHT
var windup_duration: float = 0.04
var active_duration: float = 0.16
var hitbox_size: Vector2 = Vector2(26.0, 16.0)
var hitbox_offset: Vector2 = Vector2(18.0, 0.0)
var slash_visual_scale: Vector2 = Vector2(1.5, 1.5)

@onready var _slash_sprite: Sprite2D = $SlashSprite
@onready var _hitbox: Area2D = $Hitbox
@onready var _collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D

var _elapsed: float = 0.0
var _hitbox_active: bool = false
var _hitbox_started: bool = false
var _hit_targets: Dictionary = {}

func _ready() -> void:
	global_rotation = direction.angle()
	_slash_sprite.position = hitbox_offset
	_slash_sprite.scale = slash_visual_scale
	_slash_sprite.frame = 0

	_collision_shape.position = hitbox_offset
	if _collision_shape.shape is RectangleShape2D:
		var rectangle := (_collision_shape.shape as RectangleShape2D).duplicate() as RectangleShape2D
		rectangle.size = hitbox_size
		_collision_shape.shape = rectangle

	_hitbox.body_entered.connect(_on_body_entered)
	_hitbox.monitoring = false
	_collision_shape.disabled = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	var active_start := maxf(windup_duration, 0.0)
	var active_end := active_start + maxf(active_duration, 0.01)

	if not _hitbox_started and _elapsed >= active_start:
		_hitbox_started = true
		if _elapsed < active_end:
			_enable_hitbox()

	if _hitbox_active and _elapsed >= active_end:
		_disable_hitbox()

	if _hitbox_active and _hitbox.monitoring:
		for body in _hitbox.get_overlapping_bodies():
			_try_hit(body)

	if _elapsed >= active_end:
		queue_free()
		return

	if _elapsed >= active_start:
		var progress := clampf((_elapsed - active_start) / maxf(active_duration, 0.01), 0.0, 0.999)
		_slash_sprite.frame = clampi(int(progress * 3.0), 0, 2)
		_slash_sprite.modulate.a = 1.0 - progress * 0.2

func _enable_hitbox() -> void:
	_hitbox_active = true
	_collision_shape.set_deferred("disabled", false)
	_hitbox.set_deferred("monitoring", true)

func _disable_hitbox() -> void:
	_hitbox_active = false
	_hitbox.set_deferred("monitoring", false)
	_collision_shape.set_deferred("disabled", true)

func _on_body_entered(body: Node2D) -> void:
	if _hitbox_active:
		_try_hit(body)

func _try_hit(target: Node) -> void:
	if (
		not _hitbox_active
		or target == source
		or not target.is_in_group("damageable")
		or not target.has_method("take_damage")
	):
		return

	var target_id := target.get_instance_id()
	if _hit_targets.has(target_id):
		return

	_hit_targets[target_id] = true
	target.call("take_damage", damage)
	hit_confirmed.emit(target, damage)
