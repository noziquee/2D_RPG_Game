extends BaseComponent2D
class_name AttackComponent2D
## Owns attack eligibility and lifecycle; AnimationPlayer controls the visual timing.

const CharacterContext2D = preload("res://Characters/Core/CharacterContext2D.gd")

signal attack_started(direction: Vector2)
signal attack_hit(target: Node, damage: int)
signal attack_finished

var definition: AttackDefinition2D
var slash_scene: PackedScene

var _cooldown_remaining: float = 0.0
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
		and is_instance_valid(context.weapon_pivot)
		and is_instance_valid(context.weapon_animation_player)
	)
	if not _initialized:
		push_error("AttackComponent2D requires a CharacterBody2D, attack definition, slash scene, Weapon, and Weapon/WeaponAnimation.")
		return

	var animation_player := context.weapon_animation_player
	if not animation_player.has_animation(&"slash") or not animation_player.has_animation(&"sword_return"):
		push_error("AttackComponent2D requires Weapon animations named 'slash' and 'sword_return'.")
		_initialized = false
		return
	if not slash_scene.can_instantiate():
		push_error("AttackComponent2D: the configured slash scene cannot be instantiated.")
		_initialized = false
		return
	if not animation_player.animation_finished.is_connected(_on_weapon_animation_finished):
		animation_player.animation_finished.connect(_on_weapon_animation_finished)

func try_start(requested: bool, direction: Vector2 = Vector2.ZERO) -> bool:
	if (
		not _initialized
		or not requested
		or not context.can(ActionLock2D.CAPABILITY_ATTACK)
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
	context.acquire_lock(ActionLock2D.ATTACK, self)
	_cooldown_remaining = maxf(definition.cooldown_duration, _weapon_cycle_duration())
	context.weapon_animation_player.play(&"slash")
	attack_started.emit(attack_direction)
	return true

func physics_update(delta: float) -> void:
	if _initialized:
		_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)

## Called by the AnimationPlayer's slash call-method track at 0.05 seconds.
func spawn_slash_from_animation() -> void:
	if not _initialized or not context.is_attacking:
		return
	if is_instance_valid(_active_slash):
		_active_slash.queue_free()

	var slash := slash_scene.instantiate() as AttackSlash2D
	if slash == null:
		push_error("AttackComponent2D: slash scene root must use AttackSlash2D.gd.")
		return

	slash.source = context.character
	slash.damage = maxi(definition.damage, 0)
	slash.direction = context.attack_direction
	slash.hitbox_size = definition.hitbox_size
	slash.hitbox_offset = definition.hitbox_offset
	slash.knockback_speed = maxf(definition.knockback_speed, 0.0)
	slash.hit_confirmed.connect(_on_slash_hit)

	var host: Node = context.character.get_parent()
	if host == null:
		host = context.character
	host.add_child(slash)
	slash.global_position = context.character.global_position
	_active_slash = slash

func cancel() -> void:
	if not _initialized:
		return
	if is_instance_valid(_active_slash):
		_active_slash.queue_free()
	_active_slash = null
	_cooldown_remaining = 0.0
	context.release_lock(ActionLock2D.ATTACK, self)
	if is_instance_valid(context.weapon_animation_player):
		context.weapon_animation_player.stop()
		if context.weapon_animation_player.has_animation(&"RESET"):
			context.weapon_animation_player.play(&"RESET")

func is_on_cooldown() -> bool:
	return _cooldown_remaining > 0.0

func _weapon_cycle_duration() -> float:
	var animation_player := context.weapon_animation_player
	var slash_animation := animation_player.get_animation(&"slash")
	var return_animation := animation_player.get_animation(&"sword_return")
	var playback_speed := maxf(absf(animation_player.speed_scale), 0.001)
	return (slash_animation.length + return_animation.length) / playback_speed

func _on_weapon_animation_finished(animation_name: StringName) -> void:
	if not _initialized or not context.is_attacking:
		return
	if animation_name == &"slash":
		context.weapon_animation_player.play(&"sword_return")
	elif animation_name == &"sword_return":
		context.release_lock(ActionLock2D.ATTACK, self)
		attack_finished.emit()

func _on_slash_hit(target: Node, dealt_damage: int) -> void:
	attack_hit.emit(target, dealt_damage)
