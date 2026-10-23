extends Interactable
class_name Door
## A locked door. It takes one key from the player's inventory to open, and stays open after.
## `opened` is saved state from day one, like Chest.

const CLOSED_TEXTURE: Texture2D = preload("res://Assets/tiles/wall/door_closed.png")
const OPEN_TEXTURE: Texture2D = preload("res://Assets/tiles/wall/door_fullyopen.png")

@export var key: ItemDefinition
@export var opened: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _blocker: CollisionShape2D = $Blocker/CollisionShape2D

func _ready() -> void:
	super._ready()
	interacted.connect(_on_interacted)
	_apply_state()
	_register_for_save()

func is_available() -> bool:
	return not opened and super.is_available()

func _on_interacted(interactor) -> void:
	if opened or key == null:
		return
	var player: Node = interactor.get_parent()
	var inventory: Inventory = player.get("inventory") if player != null else null
	if inventory == null:
		return
	if not inventory.has_item(key):
		CombatFeedback.announce(self, "Needs a key", global_position + prompt_offset)
		return
	inventory.remove_item(key, 1)
	opened = true
	_apply_state()
	CombatFeedback.announce(self, "Unlocked", global_position + prompt_offset)

func _apply_state() -> void:
	_sprite.texture = OPEN_TEXTURE if opened else CLOSED_TEXTURE
	_blocker.set_deferred("disabled", opened)

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
	return {"opened": opened}

func apply_save_state(data: Dictionary) -> bool:
	if not (data.get("opened") is bool):
		return false
	opened = data["opened"]
	_apply_state()
	return true
