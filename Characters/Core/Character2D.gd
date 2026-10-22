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
const HealthComponentScript = preload("res://Characters/Components/Health/HealthComponent2D.gd")
const DEFAULT_ATTACK_DEFINITION = preload("res://Characters/Components/Combat/DefaultAttackDefinition.tres")
const DEFAULT_ATTACK_SLASH_SCENE = preload("res://Characters/Components/Combat/AttackSlash2D.tscn")

## Re-emitted from the HealthComponent2D so the HUD and other observers bind to the character.
signal health_changed(current_health: int, maximum_health: int)
signal died
## Emitted after a hit removed health; carries the full DamageResult2D.
signal damage_received(result: DamageResult2D)

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
var health_component: HealthComponent2D

## Current health, read from the HealthComponent2D (0 before the character is ready).
var health: int:
	get:
		return health_component.current_health if health_component != null else 0

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

	health_component = HealthComponentScript.new() as HealthComponent2D
	health_component.name = "HealthComponent2D"
	add_child(health_component)
	health_component.initialize(_get_max_health())
	health_component.health_changed.connect(_on_health_changed)
	health_component.damaged.connect(_on_health_damaged)
	health_component.died.connect(_on_health_died)

	state_machine = CharacterStateMachine.new()
	state_machine.name = "CharacterStateMachine"
	add_child(state_machine)
	state_machine.initialize(context)
	state_machine.register_state(&"Idle", IdleState.new())
	state_machine.register_state(&"Move", MoveState.new())
	state_machine.register_state(&"Dash", DashState.new())
	state_machine.register_state(&"Attack", AttackState.new())
	state_machine.transition_to(&"Idle")

	if context.animated_sprite == null and context.character_animation_player == null:
		push_warning("Character2D '%s' has neither CharacterAnimation nor AnimatedSprite2D; locomotion animations will be skipped." % name)

	# Announce the starting health so observers that already connected can sync.
	health_changed.emit(health_component.current_health, health_component.max_health)

func _physics_process(delta: float) -> void:
	context.movement_input = _get_movement_input().normalized()
	_update_facing_direction()

	if not context.is_attacking and dash_component.try_start(_get_dash_requested(), _get_dash_direction()):
		state_machine.transition_to(&"Dash")

	var attack_requested := _get_attack_requested()
	if attack_requested and attack_component.try_start(true, _get_attack_direction()):
		state_machine.transition_to(&"Attack")
		# Apply attack-facing in the same physics frame the authored slash starts.
		_update_facing_direction()

	movement_component.physics_update(delta)
	state_machine.physics_update(delta)
	dash_component.physics_update(delta)
	attack_component.physics_update(delta)

func _update_facing_direction() -> void:
	# Locomotion owns the normal left/right facing. Vertical movement and idle
	# preserve the last horizontal movement direction rather than following the mouse.
	if context.movement_input.x < -0.001:
		context.movement_facing_direction = Vector2.LEFT
	elif context.movement_input.x > 0.001:
		context.movement_facing_direction = Vector2.RIGHT

	var visible_facing := context.movement_facing_direction
	if context.is_attacking:
		# The attack direction is captured once when the attack request succeeds.
		if context.attack_direction.x < -0.001:
			visible_facing = Vector2.LEFT
		elif context.attack_direction.x > 0.001:
			visible_facing = Vector2.RIGHT

	context.facing_direction = visible_facing
	context.aim_direction = context.attack_direction if context.is_attacking else context.movement_facing_direction

	if is_instance_valid(context.visual_root):
		# The player's layered body and Weapon share this visual root, so flipping
		# it mirrors the body and weapon animation together.
		var horizontal_scale := absf(context.visual_root.scale.x)
		context.visual_root.scale.x = -horizontal_scale if context.facing_direction.x < 0.0 else horizontal_scale
	elif context.animated_sprite != null:
		# Keep compatibility with enemy/legacy AnimatedSprite2D characters.
		var horizontal_scale := absf(context.animated_sprite.scale.x)
		context.animated_sprite.scale.x = -horizontal_scale if context.facing_direction.x < 0.0 else horizontal_scale
		context.animated_sprite.flip_h = false

	if is_instance_valid(context.weapon_pivot):
		# The dedicated player pivot rotates around the weapon hilt and stays in
		# front of the layered body. The animation scales only its child Weapon.
		context.weapon_pivot.z_index = 1

## Called by the Weapon AnimationPlayer's slash call-method track.
func spawn_slash() -> void:
	if is_instance_valid(attack_component):
		attack_component.spawn_slash_from_animation()

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

#==============================================================================
# Health and Damage
#==============================================================================
func get_health_component() -> HealthComponent2D:
	return health_component

func is_alive() -> bool:
	return health_component != null and health_component.is_alive

## Resolves a structured hit against this character. Prefer this over take_damage().
func receive_damage(request: DamageRequest2D) -> DamageResult2D:
	var result := DamageService2D.get_default().resolve(request, self)
	if result.applied:
		damage_received.emit(result)
	return result

## Compatibility wrapper for callers that only have a number.
func take_damage(amount: int) -> void:
	receive_damage(DamageRequest2D.create(null, amount))

func _get_max_health() -> int:
	## Subclasses return their exported maximum health.
	return 1

func _on_damaged(_amount: int) -> void:
	## Override to play a hit reaction. Only called when the hit did not kill.
	pass

func _on_death() -> void:
	## Override to stop, animate, or remove the character after died is emitted.
	pass

func _on_health_changed(current_health: int, maximum_health: int) -> void:
	health_changed.emit(current_health, maximum_health)

func _on_health_damaged(amount: int) -> void:
	if health_component.is_alive:
		_on_damaged(amount)

func _on_health_died() -> void:
	died.emit()
	_on_death()
