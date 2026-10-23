extends Interactable
class_name ItemPickup
## An item on the floor, picked up with the interact key. `collected` is saved state from
## day one; Phase 12 reads it. A full pack keeps the leftover on the floor.

@export var item: ItemDefinition
@export_range(1, 9999) var count: int = 1
@export var collected: bool = false

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	super._ready()
	interacted.connect(_on_interacted)
	if item != null and item.icon != null:
		_sprite.texture = item.icon
	_register_for_save()

func is_available() -> bool:
	return not collected and super.is_available()

func _on_interacted(interactor) -> void:
	if collected or item == null:
		return
	var player: Node = interactor.get_parent()
	var inventory: Inventory = player.get("inventory") if player != null else null
	if inventory == null:
		return
	var leftover := inventory.add_item(item, count)
	if leftover > 0:
		count = leftover
		CombatFeedback.announce(self, "Pack full", global_position + prompt_offset)
		return
	CombatFeedback.announce(self, "+%d %s" % [count, item.display_name], global_position + prompt_offset)
	_set_collected(true)

## Hides a collected pickup instead of freeing it, so a load can bring it back.
func _set_collected(value: bool) -> void:
	collected = value
	enabled = not value
	visible = not value

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
