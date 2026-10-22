extends CharacterBody2D
class_name Character2D
## Shared character foundation. Controllers provide intent; components perform behavior.

const CharacterContext2D = preload("res://Characters/Core/CharacterContext2D.gd")
const CharacterStateMachine = preload("res://Characters/StateMachine/CharacterStateMachine.gd")
const IdleState = preload("res://Characters/StateMachine/States/IdleState.gd")
const MoveState = preload("res://Characters/StateMachine/States/MoveState.gd")
const DashState = preload("res://Characters/StateMachine/States/DashState.gd")
const DeadState = preload("res://Characters/StateMachine/States/DeadState.gd")
const MovementComponentScript = preload("res://Characters/Components/Movement/MovementComponent2D.gd")
const DashComponentScript = preload("res://Characters/Components/Dash/DashComponent2D.gd")
const AttackComponentScript = preload("res://Characters/Components/Combat/AttackComponent2D.gd")
const AttackState = preload("res://Characters/StateMachine/States/AttackState.gd")
const HealthComponentScript = preload("res://Characters/Components/Health/HealthComponent2D.gd")
const StatsComponentScript = preload("res://Characters/Components/Stats/StatsComponent2D.gd")
const StatusComponentScript = preload("res://Characters/Components/Status/StatusEffectComponent2D.gd")
const DEFAULT_ATTACK_DEFINITION = preload("res://Characters/Components/Combat/DefaultAttackDefinition.tres")
const DEFAULT_ATTACK_SLASH_SCENE = preload("res://Characters/Components/Combat/AttackSlash2D.tscn")

## Authored clip names. Code requests them; the AnimationPlayer owns the timing.
const HIT_REACTION_CLIP: StringName = &"take_damage"
const HIT_RESET_CLIP: StringName = &"RESET"

## Re-emitted from the HealthComponent2D so the HUD and other observers bind to the character.
signal health_changed(current_health: int, maximum_health: int)
signal died
## Emitted after a hit removed health; carries the full DamageResult2D.
signal damage_received(result: DamageResult2D)
## Emitted after respawn() brings a dead character back.
signal respawned

@export_range(0.0, 2000.0, 1.0) var move_speed: float = 200.0:
	set(value):
		move_speed = maxf(value, 0.0)
		# The stat is the source of truth; _on_stat_changed moves the body's speed.
		if is_instance_valid(stats_component):
			stats_component.set_base(&"move_speed", move_speed)

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
var stats_component: StatsComponent2D
var status_component: StatusEffectComponent2D
## Tags of the hit currently being resolved; read by _on_damaged.
var _hit_tags: Array[StringName] = []

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

	stats_component = StatsComponentScript.new() as StatsComponent2D
	stats_component.name = "StatsComponent2D"
	add_child(stats_component)
	stats_component.set_base(&"move_speed", move_speed)
	stats_component.set_base(&"max_health", float(_get_max_health()))

	status_component = StatusComponentScript.new() as StatusEffectComponent2D
	status_component.name = "StatusEffectComponent2D"
	add_child(status_component)
	status_component.initialize(self, stats_component)

	health_component = HealthComponentScript.new() as HealthComponent2D
	health_component.name = "HealthComponent2D"
	add_child(health_component)
	health_component.initialize(_get_max_health())
	health_component.health_changed.connect(_on_health_changed)
	health_component.damaged.connect(_on_health_damaged)
	health_component.died.connect(_on_health_died)
	# Connected last: stat changes need the movement and health components to exist.
	stats_component.stat_changed.connect(_on_stat_changed)

	state_machine = CharacterStateMachine.new()
	state_machine.name = "CharacterStateMachine"
	add_child(state_machine)
	state_machine.initialize(context)
	state_machine.register_state(&"Idle", IdleState.new())
	state_machine.register_state(&"Move", MoveState.new())
	state_machine.register_state(&"Dash", DashState.new())
	state_machine.register_state(&"Attack", AttackState.new())
	state_machine.register_state(&"Dead", DeadState.new())
	state_machine.transition_to(&"Idle")

	var hit_player := _get_hit_reaction_player()
	if is_instance_valid(hit_player) and not hit_player.animation_finished.is_connected(_on_hit_reaction_finished):
		hit_player.animation_finished.connect(_on_hit_reaction_finished)

	if context.animated_sprite == null and context.character_animation_player == null:
		push_warning("Character2D '%s' has neither CharacterAnimation nor AnimatedSprite2D; locomotion animations will be skipped." % name)

	# Announce the starting health so observers that already connected can sync.
	health_changed.emit(health_component.current_health, health_component.max_health)

func _physics_process(delta: float) -> void:
	# Locks decide what is allowed; controllers only report intent. Movement intent is
	# dropped while move is blocked (for example when dead). Movement still runs so
	# knockback can finish.
	context.movement_input = _get_movement_input().normalized() if context.can(ActionLock2D.CAPABILITY_MOVE) else Vector2.ZERO
	_update_facing_direction()

	# Each try_start checks its own lock, so a refused request changes nothing.
	status_component.physics_update(delta)

	if dash_component.try_start(_get_dash_requested(), _get_dash_direction()):
		state_machine.transition_to(&"Dash")

	if attack_component.try_start(_get_attack_requested(), _get_attack_direction()):
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
	_hit_tags = request.tags if request != null else []
	var result := DamageService2D.get_default().resolve(request, self)
	_hit_tags = []
	if result.applied:
		# Knockback also applies to the killing blow, so a corpse is pushed back.
		_apply_hit_knockback(request)
		damage_received.emit(result)
	return result

## Compatibility wrapper for callers that only have a number.
func take_damage(amount: int) -> void:
	receive_damage(DamageRequest2D.create(null, amount))

## Brings a dead character back at the given health (negative means full health).
## Returns false, and changes nothing, if the character is still alive.
func respawn(health_value: int = -1) -> bool:
	if is_alive():
		return false
	if is_instance_valid(movement_component):
		movement_component.clear_knockback()
	context.release_lock(ActionLock2D.DEAD, self)
	health_component.revive(health_value)
	add_to_group(Groups2D.DAMAGEABLE)
	_reset_hit_reaction()
	state_machine.transition_to(&"Idle")
	_on_respawn()
	respawned.emit()
	return true

## Subclasses return the AnimationPlayer that holds the take_damage and RESET clips.
func _get_hit_reaction_player() -> AnimationPlayer:
	return null

func _on_hit_reaction_finished(animation_name: StringName) -> void:
	if animation_name != HIT_REACTION_CLIP or not is_alive():
		return
	_reset_hit_reaction()
	context.release_lock(ActionLock2D.HURT, self)
	state_machine.refresh_current_state()

## Restores the pose the hit clip changed. Stops the clip when there is no RESET.
func _reset_hit_reaction() -> void:
	var hit_player := _get_hit_reaction_player()
	if not is_instance_valid(hit_player):
		return
	if hit_player.has_animation(HIT_RESET_CLIP):
		hit_player.play(HIT_RESET_CLIP)
	else:
		hit_player.stop()

func _get_max_health() -> int:
	## Subclasses return their exported maximum health.
	return 1

## Current value of a stat (move_speed, max_health, attack, defense). 0 if unknown.
func get_stat(stat_id: StringName) -> float:
	return stats_component.get_stat(stat_id) if is_instance_valid(stats_component) else 0.0

## Applies a status effect (buff or debuff). Returns false if it could not be applied.
func apply_status(effect: StatusEffect2D, add_stacks: int = 1, applier: Node = null) -> bool:
	return status_component.apply(effect, add_stacks, applier)

func _on_stat_changed(stat_id: StringName, value: float) -> void:
	if stat_id == &"move_speed":
		movement_component.set_move_speed(value)
	elif stat_id == &"max_health":
		health_component.set_max_health(maxi(roundi(value), 1))

func _apply_hit_knockback(request: DamageRequest2D) -> void:
	if request == null or request.knockback_speed <= 0.0 or not is_instance_valid(movement_component):
		return
	movement_component.apply_knockback(request.direction, request.knockback_speed)

## Called only for a hit that did not kill. Holds the HURT lock until the authored
## take_damage clip finishes, which stops movement and dash. Attacks stay available.
func _on_damaged(_amount: int) -> void:
	# Damage over time ticks do not interrupt the character.
	if _hit_tags.has(&"dot"):
		return
	var hit_player := _get_hit_reaction_player()
	if not is_instance_valid(hit_player) or not hit_player.has_animation(HIT_REACTION_CLIP):
		return
	if is_instance_valid(dash_component):
		dash_component.cancel()
	context.acquire_lock(ActionLock2D.HURT, self)
	hit_player.play(HIT_REACTION_CLIP)

func _on_death() -> void:
	## Override to present the death (effects, hiding visuals, scheduling removal).
	## Runs after died is emitted and the character is already in the Dead state.
	pass

func _on_respawn() -> void:
	## Override to reset presentation after respawn(). Runs after the state returns to Idle.
	pass

func _on_health_changed(current_health: int, maximum_health: int) -> void:
	health_changed.emit(current_health, maximum_health)

func _on_health_damaged(amount: int) -> void:
	if health_component.is_alive:
		_on_damaged(amount)

func _on_health_died() -> void:
	# Shared death work happens first so every subclass and listener sees a dead,
	# inert character: no attack or dash, no damage, and no longer a damageable target.
	_begin_death()
	died.emit()
	_on_death()

func _begin_death() -> void:
	context.acquire_lock(ActionLock2D.DEAD, self)
	context.release_lock(ActionLock2D.HURT, self)
	_reset_hit_reaction()
	if is_instance_valid(status_component):
		status_component.clear()
	if is_instance_valid(attack_component):
		attack_component.cancel()
	if is_instance_valid(dash_component):
		dash_component.cancel()
	remove_from_group(Groups2D.DAMAGEABLE)
	state_machine.transition_to(&"Dead")
