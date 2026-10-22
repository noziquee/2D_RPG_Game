extends StaticBody2D
class_name KeyDoor2D
signal unlocked(actor: Node)
@export var stable_id: StringName = &"door_001"
@export var required_key_id: StringName = &"silver_key"
@export var consume_key: bool = true
@export var open_texture: Texture2D
@export var disable_collision_when_open: bool = true
@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var _collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
var is_open: bool = false
func _ready() -> void:
	add_to_group(&"interactable")
	_update_appearance()
func interact(actor: Node) -> Dictionary:
	if is_open: return {"ok": false, "reason": "The door is already open."}
	if actor == null or not is_instance_valid(actor): return {"ok": false, "reason": "No valid actor."}
	var inventory := actor.get_node_or_null("InventoryComponent2D") as InventoryComponent2D
	if inventory == null or not inventory.has_item(required_key_id):
		return {"ok": false, "reason": "Requires key: %s" % String(required_key_id)}
	if consume_key and not inventory.remove_item(required_key_id):
		return {"ok": false, "reason": "Could not consume required key."}
	is_open = true
	_update_appearance()
	unlocked.emit(actor)
	return {"ok": true, "reason": "Door unlocked."}
func save_state() -> Dictionary: return {"stable_id": String(stable_id), "is_open": is_open}
func load_state(data: Dictionary) -> void:
	if str(data.get("stable_id", "")) != String(stable_id): return
	is_open = bool(data.get("is_open", false))
	_update_appearance()
func _update_appearance() -> void:
	if is_instance_valid(_sprite) and is_open and open_texture != null: _sprite.texture = open_texture
	if is_instance_valid(_collision) and disable_collision_when_open: _collision.set_deferred("disabled", is_open)
