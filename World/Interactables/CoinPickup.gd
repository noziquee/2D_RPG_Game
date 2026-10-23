extends Area2D
class_name CoinPickup
## Coins collected on contact with the player. `collected` is saved state from day one;
## Phase 12 reads it.

const COINS_ID: StringName = &"coins"

## Stable id, so saves can tell pickups apart.
@export var id: StringName = &""
@export var amount: int = 5
@export var collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_register_for_save()

func _on_body_entered(body: Node) -> void:
	if collected:
		return
	var wallet: Wallet = body.get("wallet")
	if wallet == null:
		return
	wallet.add(COINS_ID, amount)
	collected = true
	CombatFeedback.announce(self, "+%d coins" % amount, global_position + Vector2(0, -10))
	_set_collected(true)

## Hides a collected coin and stops it detecting, so a load can bring it back.
func _set_collected(value: bool) -> void:
	collected = value
	visible = not value
	set_deferred("monitoring", not value)

## Saved-state hooks. The key is unique per object; an object with no id is not saved.
func _save_key() -> StringName:
	return StringName("world:" + str(id))

func _register_for_save() -> void:
	if String(id) == "":
		push_warning(name + " has no id, so its state will not be saved.")
		return
	Saves.register(_save_key(), Callable(self, "save_state"), Callable(self, "apply_save_state"))

func _exit_tree() -> void:
	if String(id) != "":
		Saves.unregister(_save_key())

func save_state() -> Dictionary:
	return {"collected": collected}

func apply_save_state(data: Dictionary) -> bool:
	if not (data.get("collected") is bool):
		return false
	_set_collected(data["collected"])
	return true
