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
const InteractionComponentScript = preload("res://Characters/Components/Interaction/InteractionComponent2D.gd")
const InventoryComponentScript = preload("res://Characters/Components/InventoryComponent2D.gd")
const CurrencyComponentScript = preload("res://Characters/Components/CurrencyComponent2D.gd")
const DEFAULT_ATTACK_DEFINITION = preload("res://Characters/Components/Combat/DefaultAttackDefinition.tres")
const DEFAULT_ATTACK_SLASH_SCENE = preload("res://Characters/Components/Combat/AttackSlash2D.tscn")
const HIT_REACTION_CLIP: StringName = &"take_damage"
const HIT_RESET_CLIP: StringName = &"RESET"
signal health_changed(current_health: int, maximum_health: int)
signal died
signal damage_received(result: DamageResult2D)
signal respawned
@export_range(0.0, 2000.0, 1.0) var move_speed: float = 200.0:
	set(value):
		move_speed = maxf(value, 0.0)
		if is_instance_valid(stats_component): stats_component.set_base(&"move_speed", move_speed)
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
var interaction_component: InteractionComponent2D
var inventory_component: InventoryComponent2D
var currency_component: CurrencyComponent2D
var _hit_tags: Array[StringName] = []
var health: int:
	get: return health_component.current_health if health_component != null else 0
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
	stats_component.stat_changed.connect(_on_stat_changed)
	interaction_component = InteractionComponentScript.new() as InteractionComponent2D
	interaction_component.name = "InteractionComponent2D"
	add_child(interaction_component)
	interaction_component.initialize(self, context)
	inventory_component = InventoryComponentScript.new() as InventoryComponent2D
	inventory_component.name = "InventoryComponent2D"
	add_child(inventory_component)
	currency_component = CurrencyComponentScript.new() as CurrencyComponent2D
	currency_component.name = "CurrencyComponent2D"
	add_child(currency_component)
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
	health_changed.emit(health_component.current_health, health_component.max_health)
func _physics_process(delta: float) -> void:
	context.movement_input = _get_movement_input().normalized() if context.can(ActionLock2D.CAPABILITY_MOVE) else Vector2.ZERO
	_update_facing_direction()
	status_component.physics_update(delta)
	interaction_component.physics_update(delta, _get_interact_requested() and context.can(ActionLock2D.CAPABILITY_INTERACT))
	if dash_component.try_start(_get_dash_requested(), _get_dash_direction()): state_machine.transition_to(&"Dash")
	if attack_component.try_start(_get_attack_requested(), _get_attack_direction()):
		state_machine.transition_to(&"Attack")
		_update_facing_direction()
	movement_component.physics_update(delta)
	state_machine.physics_update(delta)
	dash_component.physics_update(delta)
	attack_component.physics_update(delta)
func _update_facing_direction() -> void:
	if context.movement_input.x < -0.001: context.movement_facing_direction = Vector2.LEFT
	elif context.movement_input.x > 0.001: context.movement_facing_direction = Vector2.RIGHT
	var visible_facing := context.movement_facing_direction
	if context.is_attacking:
		if context.attack_direction.x < -0.001: visible_facing = Vector2.LEFT
		elif context.attack_direction.x > 0.001: visible_facing = Vector2.RIGHT
	context.facing_direction = visible_facing
	context.aim_direction = context.attack_direction if context.is_attacking else context.movement_facing_direction
	if is_instance_valid(context.visual_root):
		var horizontal_scale := absf(context.visual_root.scale.x)
		context.visual_root.scale.x = -horizontal_scale if context.facing_direction.x < 0.0 else horizontal_scale
	elif context.animated_sprite != null:
		var horizontal_scale := absf(context.animated_sprite.scale.x)
		context.animated_sprite.scale.x = -horizontal_scale if context.facing_direction.x < 0.0 else horizontal_scale
		context.animated_sprite.flip_h = false
	if is_instance_valid(context.weapon_pivot): context.weapon_pivot.z_index = 1
func spawn_slash() -> void:
	if is_instance_valid(attack_component): attack_component.spawn_slash_from_animation()
func _get_aim_direction() -> Vector2:
	if context != null and context.movement_input.length_squared() > 0.0001: return context.movement_input
	return context.facing_direction if context != null else Vector2.RIGHT
func _get_attack_requested() -> bool: return false
func _get_interact_requested() -> bool: return false
func _get_attack_direction() -> Vector2: return _get_aim_direction()
func _exit_tree() -> void:
	if is_instance_valid(attack_component): attack_component.cancel()
	if is_instance_valid(dash_component): dash_component.cancel()
func _get_movement_input() -> Vector2: return Vector2.ZERO
func _get_dash_requested() -> bool: return false
func _get_dash_direction() -> Vector2: return context.movement_input if context != null else Vector2.ZERO
func get_health_component() -> HealthComponent2D: return health_component
func is_alive() -> bool: return health_component != null and health_component.is_alive
func receive_damage(request: DamageRequest2D) -> DamageResult2D:
	_hit_tags = request.tags if request != null else []
	var result := DamageService2D.get_default().resolve(request, self)
	_hit_tags = []
	if result.applied:
		_apply_hit_knockback(request)
		damage_received.emit(result)
	return result
func take_damage(amount: int) -> void: receive_damage(DamageRequest2D.create(null, amount))
func respawn(health_value: int = -1) -> bool:
	if is_alive(): return false
	if is_instance_valid(movement_component): movement_component.clear_knockback()
	context.release_lock(ActionLock2D.DEAD, self)
	health_component.revive(health_value)
	add_to_group(Groups2D.DAMAGEABLE)
	_reset_hit_reaction()
	state_machine.transition_to(&"Idle")
	_on_respawn()
	respawned.emit()
	return true
func _get_hit_reaction_player() -> AnimationPlayer: return null
func _on_hit_reaction_finished(animation_name: StringName) -> void:
	if animation_name != HIT_REACTION_CLIP or not is_alive(): return
	_reset_hit_reaction()
	context.release_lock(ActionLock2D.HURT, self)
	state_machine.refresh_current_state()
func _reset_hit_reaction() -> void:
	var hit_player := _get_hit_reaction_player()
	if not is_instance_valid(hit_player): return
	if hit_player.has_animation(HIT_RESET_CLIP): hit_player.play(HIT_RESET_CLIP)
	else: hit_player.stop()
func _get_max_health() -> int: return 1
func get_stat(stat_id: StringName) -> float: return stats_component.get_stat(stat_id) if is_instance_valid(stats_component) else 0.0
func apply_status(effect: StatusEffect2D, add_stacks: int = 1, applier: Node = null) -> bool: return status_component.apply(effect, add_stacks, applier)
func _on_stat_changed(stat_id: StringName, value: float) -> void:
	if stat_id == &"move_speed": movement_component.set_move_speed(value)
	elif stat_id == &"max_health": health_component.set_max_health(maxi(roundi(value), 1))
func _apply_hit_knockback(request: DamageRequest2D) -> void:
	if request == null or request.knockback_speed <= 0.0 or not is_instance_valid(movement_component): return
	movement_component.apply_knockback(request.direction, request.knockback_speed)
func _on_damaged(_amount: int) -> void:
	if _hit_tags.has(&"dot"): return
	var hit_player := _get_hit_reaction_player()
	if not is_instance_valid(hit_player) or not hit_player.has_animation(HIT_REACTION_CLIP): return
	if is_instance_valid(dash_component): dash_component.cancel()
	context.acquire_lock(ActionLock2D.HURT, self)
	hit_player.play(HIT_REACTION_CLIP)
func _on_death() -> void: pass
func _on_respawn() -> void: pass
func _on_health_changed(current_health: int, maximum_health: int) -> void: health_changed.emit(current_health, maximum_health)
func _on_health_damaged(amount: int) -> void:
	if health_component.is_alive: _on_damaged(amount)
func _on_health_died() -> void:
	_begin_death()
	died.emit()
	_on_death()
func _begin_death() -> void:
	context.acquire_lock(ActionLock2D.DEAD, self)
	context.release_lock(ActionLock2D.HURT, self)
	_reset_hit_reaction()
	if is_instance_valid(status_component): status_component.clear()
	if is_instance_valid(attack_component): attack_component.cancel()
	if is_instance_valid(dash_component): dash_component.cancel()
	remove_from_group(Groups2D.DAMAGEABLE)
	state_machine.transition_to(&"Dead")
