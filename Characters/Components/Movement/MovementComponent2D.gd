extends BaseComponent2D
class_name MovementComponent2D
## Sole authority for applying character velocity and moving its CharacterBody2D.
## Knockback is an impulse that decays here, so no other component moves a body.

const CharacterContext2D = preload("res://Characters/Core/CharacterContext2D.gd")
## Deceleration applied to knockback, in pixels per second squared.
const KNOCKBACK_FRICTION: float = 700.0

var move_speed: float = 200.0
var knockback_velocity: Vector2 = Vector2.ZERO

func initialize(shared_context: CharacterContext2D, speed: float = 200.0) -> void:
	context = shared_context
	move_speed = maxf(speed, 0.0)
	_initialized = context != null and context.character is CharacterBody2D
	if not _initialized:
		push_error("MovementComponent2D requires a CharacterContext2D with a CharacterBody2D.")

func set_move_speed(value: float) -> void:
	move_speed = maxf(value, 0.0)

## Starts a knockback impulse along direction. A new hit replaces the previous impulse
## instead of stacking on it, so repeated hits cannot launch a character.
func apply_knockback(direction: Vector2, speed: float) -> void:
	if not _initialized:
		return
	var away := direction.normalized()
	if away == Vector2.ZERO or speed <= 0.0:
		return
	knockback_velocity = away * speed

func clear_knockback() -> void:
	knockback_velocity = Vector2.ZERO

## Reduces knockback toward zero. Runs after each movement step.
func decay_knockback(delta: float) -> void:
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * maxf(delta, 0.0))

func physics_update(delta: float) -> void:
	if not _initialized:
		return

	var body := context.character as CharacterBody2D
	var intended := Vector2.ZERO
	if context.is_dashing:
		intended = context.dash_velocity
	elif context.can(ActionLock2D.CAPABILITY_MOVE):
		intended = context.movement_input * move_speed
	body.velocity = intended + knockback_velocity
	body.move_and_slide()
	# A wall stops the knockback rather than pushing the character through it.
	if body.is_on_wall():
		knockback_velocity = Vector2.ZERO
	decay_knockback(delta)
