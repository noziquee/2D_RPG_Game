extends Node
class_name InteractionComponent2D
## Finds nearby nodes in the `interactable` group and interacts with the nearest one.
signal target_changed(target: Node)
signal interaction_succeeded(target: Node)
signal interaction_failed(target: Node, reason: String)
@export_range(8.0, 256.0, 1.0) var interaction_radius: float = 56.0
@export var interact_action: StringName = &"interact"
var _actor: CharacterBody2D
var _context: Variant
var _target: Node2D
var _cooldown: float = 0.0
func initialize(actor: CharacterBody2D, character_context: Variant) -> void:
	_actor = actor
	_context = character_context
func physics_update(delta: float, requested: bool) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_refresh_target()
	if requested and _cooldown <= 0.0 and is_instance_valid(_target):
		_cooldown = 0.18
		if _target.has_method(&"interact"):
			if _context != null:
				_context.acquire_lock(ActionLock2D.INTERACT, self)
			var response: Variant = _target.call(&"interact", _actor)
			if _context != null:
				_context.release_lock(ActionLock2D.INTERACT, self)
			if response is Dictionary and bool(response.get("ok", false)):
				interaction_succeeded.emit(_target)
			else:
				var reason := str(response.get("reason", "Interaction failed.")) if response is Dictionary else "Target does not implement a valid interaction."
				interaction_failed.emit(_target, reason)
		else:
			interaction_failed.emit(_target, "Target has no interact(actor) method.")
func get_target() -> Node2D: return _target
func _refresh_target() -> void:
	var next: Node2D
	var best_distance := interaction_radius * interaction_radius
	if is_instance_valid(_actor):
		for candidate in get_tree().get_nodes_in_group(&"interactable"):
			var node := candidate as Node2D
			if node == null or not is_instance_valid(node): continue
			var distance := _actor.global_position.distance_squared_to(node.global_position)
			if distance <= best_distance:
				best_distance = distance
				next = node
	if next != _target:
		_target = next
		target_changed.emit(_target)
