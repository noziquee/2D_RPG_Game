extends BaseComponent2D
class_name DashComponent2D
## Owns dash timing and intent; MovementComponent2D remains the only movement executor.
## A dash holds the DASH lock while it runs, so attacks and other dashes are refused.

const CharacterContext2D = preload("res://Characters/Core/CharacterContext2D.gd")

signal dash_started(direction: Vector2)
signal dash_ended

@export_range(0.0, 3000.0, 1.0) var dash_speed: float = 600.0
@export_range(0.01, 2.0, 0.01) var dash_duration: float = 0.16
@export_range(0.0, 5.0, 0.05) var dash_cooldown: float = 0.45

var _remaining_duration: float = 0.0
var _cooldown_remaining: float = 0.0

func initialize(shared_context: CharacterContext2D) -> void:
	context = shared_context
	_initialized = context != null and context.character is CharacterBody2D
	if not _initialized:
		push_error("DashComponent2D requires a CharacterContext2D with a CharacterBody2D.")

func try_start(requested: bool, direction: Vector2 = Vector2.ZERO) -> bool:
	if not _initialized or not requested or _cooldown_remaining > 0.0:
		return false
	if not context.can(ActionLock2D.CAPABILITY_DASH):
		return false
	var dash_direction := direction.normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = context.facing_direction.normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.RIGHT
	context.dash_velocity = dash_direction * maxf(dash_speed, 0.0)
	context.acquire_lock(ActionLock2D.DASH, self)
	_remaining_duration = maxf(dash_duration, 0.01)
	_cooldown_remaining = maxf(dash_cooldown, 0.0)
	dash_started.emit(dash_direction)
	return true

func physics_update(delta: float) -> void:
	if not _initialized:
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if not context.is_dashing:
		return
	_remaining_duration -= delta
	if _remaining_duration <= 0.0:
		_end_dash()

func cancel() -> void:
	if not _initialized or not context.is_dashing:
		return
	_remaining_duration = 0.0
	_end_dash()

func is_on_cooldown() -> bool:
	return _cooldown_remaining > 0.0

func _end_dash() -> void:
	context.dash_velocity = Vector2.ZERO
	context.release_lock(ActionLock2D.DASH, self)
	dash_ended.emit()
