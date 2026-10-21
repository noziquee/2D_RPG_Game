extends CharacterBody2D
class_name Character2D
## Shared character foundation. Controllers provide intent; components perform behavior.

const CharacterContext2D = preload("res://Characters/Core/CharacterContext2D.gd")
const CharacterStateMachine = preload("res://Characters/StateMachine/CharacterStateMachine.gd")
const IdleState = preload("res://Characters/StateMachine/States/IdleState.gd")
const MoveState = preload("res://Characters/StateMachine/States/MoveState.gd")
const DashState = preload("res://Characters/StateMachine/States/DashState.gd")
const MovementComponentScript = preload("res://Characters/Components/Movement/MovementComponent2D.gd")
const DashComponentScript = preload("res://Characters/Components/Dash/DashComponent2D.gd")
const AttackComponentScript = preload("res://Characters/Components/Combat/AttackComponent2D.gd")
const AttackState = preload("res://Characters/StateMachine/States/AttackState.gd")
const DEFAULT_ATTACK_DEFINITION = preload("res://Characters/Components/Combat/DefaultAttackDefinition.tres")
const DEFAULT_ATTACK_SLASH_SCENE = preload("res://Characters/Components/Combat/AttackSlash2D.tscn")

@export_range(0.0, 2000.0, 1.0) var move_speed: float = 200.0:
	set(value):
		move_speed = maxf(value, 0.0)
		if is_instance_valid(movement_component):
			movement_component.set_move_speed(move_speed)

@export_group("Dash")
@export_range(0.0, 3000.0, 1.0) var dash_speed: float = 600.0
@export_range(0.01, 2.0, 0.01) var dash_duration: float = 0.16
@export_range(0.0, 5.0, 0.05) var dash_cooldown: float = 0.45

@export_group("Attack")
@export var attack_definition: AttackDefinition2D = DEFAULT_ATTACK_DEFINITION
@export var attack_slash_scene: PackedScene = DEFAULT_ATTACK_SLASH_SCENE

var context: CharacterContext2D
var state_machine: CharacterStateMachine
var movement_component: MovementComponent2D
var dash_component: DashComponent2D
var attack_component: AttackComponent2D

func _ready() -> void:
	context = CharacterContext2D.new(self)

	movement_component = MovementComponentScript.new() as MovementComponent2D
	movement_component.name = "MovementComponent2D"
	add_child(movement_component)
	movement_component.initialize(context, move_speed)

	dash_component = DashComponentScript.new() as DashComponent2D
	dash_component.name = "DashComponent2D"
	dash_component.dash_speed = dash_speed
	dash_component.dash_duration = dash_duration
	dash_component.dash_cooldown = dash_cooldown
	add_child(dash_component)
	dash_component.initialize(context)

	attack_component = AttackComponentScript.new() as AttackComponent2D
	attack_component.name = "AttackComponent2D"
	add_child(attack_component)
	attack_component.initialize(context, attack_definition, attack_slash_scene)

	state_machine = CharacterStateMachine.new()
	state_machine.name = "CharacterStateMachine"
	add_child(state_machine)
	state_machine.initialize(context)
	state_machine.register_state(&"Idle", IdleState.new())
	state_machine.register_state(&"Move", MoveState.new())
	state_machine.register_state(&"Dash", DashState.new())
	state_machine.register_state(&"Attack", AttackState.new())
	state_machine.transition_to(&"Idle")

	if context.animated_sprite == null:
		push_warning("Character2D '%s' has no AnimatedSprite2D child; animation states will be skipped." % name)

func _physics_process(delta: float) -> void:
	context.movement_input = _get_movement_input().normalized()
	_update_facing_direction()

	if not context.is_attacking and dash_component.try_start(_get_dash_requested(), _get_dash_direction()):
		state_machine.transition_to(&"Dash")
	if attack_component.try_start(_get_attack_requested(), _get_attack_direction()):
		state_machine.transition_to(&"Attack")

	movement_component.physics_update(delta)
	state_machine.physics_update(delta)
	dash_component.physics_update(delta)
	attack_component.physics_update(delta)

func _update_facing_direction() -> void:
	if not context.is_attacking:
		var desired_aim := _get_aim_direction()
		if desired_aim.length_squared() > 0.0001:
			context.aim_direction = desired_aim.normalized()

	if context.aim_direction.x < -0.001:
		context.facing_direction = Vector2.LEFT
	elif context.aim_direction.x > 0.001:
		context.facing_direction = Vector2.RIGHT

	if context.animated_sprite != null:
		context.animated_sprite.flip_h = context.facing_direction.x < 0.0

	if is_instance_valid(context.weapon_pivot):
		context.weapon_pivot.z_index = -1 if context.aim_direction.y < -0.15 else 1
		if not context.is_attacking:
			context.weapon_pivot.global_rotation = context.aim_direction.angle()

func _get_aim_direction() -> Vector2:
	## Controllers may override this; the base character aims along movement/facing.
	if context != null and context.movement_input.length_squared() > 0.0001:
		return context.movement_input
	return context.facing_direction if context != null else Vector2.RIGHT

func _get_attack_requested() -> bool:
	## Controllers override this to request an attack.
	return false

func _get_attack_direction() -> Vector2:
	return _get_aim_direction()

func _exit_tree() -> void:
	if is_instance_valid(attack_component):
		attack_component.cancel()
	if is_instance_valid(dash_component):
		dash_component.cancel()

func _get_movement_input() -> Vector2:
	## Override in a controller-specific character script; AI can provide its own intent.
	return Vector2.ZERO

func _get_dash_requested() -> bool:
	## Controllers override this to request a dash; components own its behavior.
	return false

func _get_dash_direction() -> Vector2:
	## Defaults to movement intent; the dash component falls back to facing direction.
	return context.movement_input if context != null else Vector2.ZERO
