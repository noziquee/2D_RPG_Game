extends "res://Characters/Core/Character2D.gd"
## Player input adapter. Health, hit reaction, and death live in Character2D.
## The take_damage and death clips are authored in Player/CharacterAnimation.
## Also owns the inventory, the wallet, the interactor, and the saved state for the player.

const COINS: CurrencyDefinition = preload("res://Items/coins.tres")
const ITEM_DATABASE: ItemDatabase = preload("res://Items/item_database.tres")
const QUICK_SLOT := "quicksave"
const MAX_COORDINATE: float = 100000.0

@export_range(1, 1000, 1) var max_health: int = 5

@onready var _damage_animation_player: AnimationPlayer = get_node_or_null(
	"Player/CharacterAnimation"
) as AnimationPlayer

var inventory: Inventory
var wallet: Wallet
var interactor: Interactor

func _ready() -> void:
	super._ready()
	add_to_group(Groups2D.PLAYER)
	add_to_group(Groups2D.DAMAGEABLE)

	inventory = Inventory.new()
	add_child(inventory)
	wallet = Wallet.new()
	add_child(wallet)
	wallet.register_currency(COINS, 0)

	interactor = Interactor.new()
	add_child(interactor)
	interactor.gate = Callable(self, "_can_interact")

	Saves.register(&"player", Callable(self, "save_state"), Callable(self, "restore_state"))
	Saves.register(&"inventory", Callable(self, "_save_inventory"), Callable(self, "_restore_inventory"))
	Saves.register(&"wallet", Callable(self, "_save_wallet"), Callable(self, "_restore_wallet"))

func _exit_tree() -> void:
	super._exit_tree()
	Saves.unregister(&"player")
	Saves.unregister(&"inventory")
	Saves.unregister(&"wallet")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		Saves.save_game(QUICK_SLOT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"quick_load"):
		Saves.load_game(QUICK_SLOT)
		get_viewport().set_input_as_handled()

func _get_hit_reaction_player() -> AnimationPlayer:
	return _damage_animation_player

func _get_max_health() -> int:
	return maxi(max_health, 1)

func _get_movement_input() -> Vector2:
	if not is_alive():
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _get_dash_requested() -> bool:
	return is_alive() and Input.is_action_just_pressed("dash")

func _get_aim_direction() -> Vector2:
	if not is_alive():
		return context.facing_direction
	var direction := get_global_mouse_position() - global_position
	return direction.normalized() if direction.length_squared() > 0.0001 else context.facing_direction

func _get_attack_requested() -> bool:
	return is_alive() and Input.is_action_just_pressed("attack")

func _get_attack_direction() -> Vector2:
	return _get_aim_direction()

## Interaction is refused while dead or while a lock (an opening chest) is held.
func _can_interact() -> bool:
	return is_alive() and context.can(ActionLock2D.CAPABILITY_INTERACT)

# --- Saved state ---------------------------------------------------------------------
# Every restore checks its whole input first and changes nothing if any part is invalid.

## Health and position. Transient state (attacks, dashes, statuses, locks) is never saved.
func save_state() -> Dictionary:
	return {
		"health": health,
		"position": {"x": global_position.x, "y": global_position.y},
	}

func restore_state(data: Dictionary) -> bool:
	var saved_health: Variant = data.get("health")
	if not _is_number(saved_health):
		return false
	var hp := roundi(float(saved_health))
	if hp < 1 or hp > health_component.max_health:
		return false
	var position: Variant = data.get("position")
	if not (position is Dictionary) or not _is_coordinate(position.get("x")) or not _is_coordinate(position.get("y")):
		return false

	_reset_transient_state()
	if is_alive():
		health_component.load_state({"current_health": hp})
	else:
		respawn(hp)
	global_position = Vector2(float(position["x"]), float(position["y"]))
	return true

## Puts the character back into a clean idle state after a load.
func _reset_transient_state() -> void:
	attack_component.cancel()
	dash_component.cancel()
	status_component.clear()
	movement_component.clear_knockback()
	context.release_lock(ActionLock2D.HURT, self)
	context.release_lock(ActionLock2D.INTERACT, self)
	_reset_hit_reaction()
	state_machine.transition_to(&"Idle")

func _save_inventory() -> Dictionary:
	return inventory.serialize()

func _restore_inventory(data: Dictionary) -> bool:
	if not _is_valid_inventory(data):
		return false
	return inventory.deserialize(data, ITEM_DATABASE)

## Every slot must name a known item and stay within its stack limit.
func _is_valid_inventory(data: Dictionary) -> bool:
	var capacity: Variant = data.get("capacity")
	if not _is_number(capacity) or roundi(float(capacity)) < 1 or roundi(float(capacity)) > 256:
		return false
	var slots: Variant = data.get("slots")
	if not (slots is Array) or slots.size() > 256:
		return false
	for entry in slots:
		if entry == null:
			continue
		if not (entry is Dictionary) or not (entry.get("id") is String) or not _is_number(entry.get("count")):
			return false
		var count := roundi(float(entry["count"]))
		var item := ITEM_DATABASE.get_item(StringName(entry["id"]))
		if item == null or count < 1 or count > item.max_stack:
			return false
	return true

func _save_wallet() -> Dictionary:
	return wallet.to_dict()

func _restore_wallet(data: Dictionary) -> bool:
	for key in data:
		if not _is_number(data[key]) or roundi(float(data[key])) < 0:
			return false
	wallet.from_dict(data)
	return true

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

static func _is_coordinate(value: Variant) -> bool:
	return _is_number(value) and absf(float(value)) <= MAX_COORDINATE
