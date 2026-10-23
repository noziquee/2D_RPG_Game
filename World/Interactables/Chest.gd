extends Interactable
class_name Chest
## A chest that pays its loot once. `opened` is saved state from day one, so a reloaded
## chest never pays out again. Phase 12 reads and restores it.

const CLOSED_TEXTURE: Texture2D = preload("res://Assets/props_itens/chest_closed_anim_f0.png")
const OPEN_TEXTURE: Texture2D = preload("res://Assets/props_itens/chest_open.png")
## How long the player is locked while the lid opens.
const OPEN_LOCK_SECONDS: float = 0.35

@export var loot: LootTable
@export var opened: bool = false

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	super._ready()
	interacted.connect(_on_interacted)
	_sprite.texture = OPEN_TEXTURE if opened else CLOSED_TEXTURE
	_register_for_save()

func is_available() -> bool:
	return not opened and super.is_available()

func _on_interacted(interactor) -> void:
	if opened:
		return
	opened = true
	_sprite.texture = OPEN_TEXTURE
	var player: Node = interactor.get_parent()
	var inventory: Inventory = player.get("inventory") if player != null else null
	if loot != null and inventory != null:
		for stack in loot.roll_into(inventory):
			CombatFeedback.announce(self, "+%d %s" % [stack.count, stack.item.display_name], global_position + prompt_offset)
	_lock_while_opening(player)

## Holds the interact lock on the character until the lid has opened.
func _lock_while_opening(player: Node) -> void:
	var character := player as Character2D
	if character == null:
		return
	character.context.acquire_lock(ActionLock2D.INTERACT, character)
	get_tree().create_timer(OPEN_LOCK_SECONDS).timeout.connect(_release_lock.bind(character))

func _release_lock(character: Character2D) -> void:
	if is_instance_valid(character):
		character.context.release_lock(ActionLock2D.INTERACT, character)

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
	_sprite.texture = OPEN_TEXTURE if opened else CLOSED_TEXTURE
	return true
