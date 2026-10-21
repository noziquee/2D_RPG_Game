extends Node
class_name AttackComponent2D
## Owns the attack request, lock/recovery lifecycle, cooldown, and weapon swing.

const CharacterContext2D = preload("res://Characters/Core/CharacterContext2D.gd")

signal attack_started(direction: Vector2)
signal attack_hit(target: Node, damage: int)
signal attack_finished

var context: CharacterContext2D
var definition: AttackDefinition2D
var slash_scene: PackedScene

var _remaining_attack: float = 0.0
var _cooldown_remaining: float = 0.0
var _initialized: bool = false
var _weapon_tween: Tween
var _active_slash: AttackSlash2D

func initialize(
	shared_context: CharacterContext2D,
	attack_definition: AttackDefinition2D,
	attack_scene: PackedScene
) -> void:
	context = shared_context
	definition = attack_definition
	slash_scene = attack_scene
	_initialized = (
		context != null
		and context.character is CharacterBody2D
		and definition != null
		and slash_scene != null
	)
	if not _initialized:
		push_error("AttackComponent2D requires a CharacterBody2D context, definition, and slash scene.")
		return
	if not slash_scene.can_instantiate():
		push_error("AttackComponent2D: the configured slash scene cannot be instantiated.")
		_initialized = false

func try_start(requested: bool, direction: Vector2 = Vector2.ZERO) -> bool:
	if (
		not _initialized
		or not requested
		or context.is_attacking
		or context.is_dashing
		or _cooldown_remaining > 0.0
	):
		return false

	var attack_direction := direction.normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = context.aim_direction.normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = context.facing_direction.normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2.RIGHT

	context.aim_direction = attack_direction
	context.attack_direction = attack_direction
	context.is_attacking = true
	_remaining_attack = _total_attack_duration()
	if not _spawn_slash(attack_direction):
		context.is_attacking = false
		_remaining_attack = 0.0
		_cooldown_remaining = 0.0
		return false

	_cooldown_remaining = maxf(definition.cooldown_duration, _remaining_attack)
	_animate_weapon(attack_direction)
	attack_started.emit(attack_direction)
	return true

func physics_update(delta: float) -> void:
	if not _initialized:
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if not context.is_attacking:
		return

	_remaining_attack -= delta
	if _remaining_attack <= 0.0:
		context.is_attacking = false
		if is_instance_valid(context.weapon_pivot):
			context.weapon_pivot.global_rotation = context.aim_direction.angle()
		attack_finished.emit()

func cancel() -> void:
	if not _initialized:
		return
	if _weapon_tween != null and _weapon_tween.is_running():
		_weapon_tween.kill()
	if is_instance_valid(_active_slash):
		_active_slash.queue_free()
	_active_slash = null
	if context != null:
		context.is_attacking = false
		if is_instance_valid(context.weapon_pivot):
			context.weapon_pivot.global_rotation = context.aim_direction.angle()
	_remaining_attack = 0.0

func is_on_cooldown() -> bool:
	return _cooldown_remaining > 0.0

func _total_attack_duration() -> float:
	return (
		maxf(definition.windup_duration, 0.0)
		+ maxf(definition.active_duration, 0.01)
		+ maxf(definition.recovery_duration, 0.01)
	)

func _spawn_slash(direction: Vector2) -> bool:
	var slash := slash_scene.instantiate() as AttackSlash2D
	if slash == null:
		push_error("AttackComponent2D: slash scene root must use AttackSlash2D.gd.")
		return false

	slash.source = context.character
	slash.damage = maxi(definition.damage, 0)
	slash.direction = direction
	slash.windup_duration = maxf(definition.windup_duration, 0.0)
	slash.active_duration = maxf(definition.active_duration, 0.01)
	slash.hitbox_size = definition.hitbox_size
	slash.hitbox_offset = definition.hitbox_offset
	slash.slash_visual_scale = definition.slash_visual_scale
	slash.hit_confirmed.connect(_on_slash_hit)

	var host: Node = context.character.get_parent()
	if host == null:
		host = context.character
	host.add_child(slash)
	slash.global_position = context.character.global_position
	_active_slash = slash
	return true

func _animate_weapon(direction: Vector2) -> void:
	if not is_instance_valid(context.weapon_pivot):
		return

	if _weapon_tween != null and _weapon_tween.is_running():
		_weapon_tween.kill()

	var pivot := context.weapon_pivot
	var start_angle := direction.angle()
	var half_sweep := deg_to_rad(definition.swing_angle_degrees) * 0.5
	pivot.global_rotation = start_angle - half_sweep
	_weapon_tween = create_tween()
	if definition.windup_duration > 0.0:
		_weapon_tween.tween_interval(definition.windup_duration)
	_weapon_tween.tween_property(
		pivot,
		"global_rotation",
		start_angle + half_sweep,
		maxf(definition.active_duration, 0.01)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_weapon_tween.tween_property(
		pivot,
		"global_rotation",
		start_angle,
		maxf(definition.recovery_duration, 0.01)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_slash_hit(target: Node, dealt_damage: int) -> void:
	attack_hit.emit(target, dealt_damage)
