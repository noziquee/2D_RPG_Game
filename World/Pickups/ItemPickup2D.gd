extends Area2D
class_name ItemPickup2D
signal collected(actor: Node, item_id: StringName, quantity: int)
@export var stable_id: StringName = &"pickup_001"
@export var item: ItemDefinition2D
@export_range(1, 999, 1) var quantity: int = 1
@export var remove_on_collect: bool = true
@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
var collected_once: bool = false
func _ready() -> void:
	add_to_group(&"interactable")
	if item != null and _sprite != null and item.icon != null: _sprite.texture = item.icon
func interact(actor: Node) -> Dictionary:
	if collected_once: return {"ok": false, "reason": "Already collected."}
	if actor == null or not is_instance_valid(actor): return {"ok": false, "reason": "No valid actor."}
	if item == null or item.id == &"": return {"ok": false, "reason": "Pickup has no valid item definition."}
	if item.category == "currency":
		var currency := actor.get_node_or_null("CurrencyComponent2D") as CurrencyComponent2D
		if currency == null: return {"ok": false, "reason": "Actor has no currency component."}
		currency.earn(quantity)
	else:
		var inventory := actor.get_node_or_null("InventoryComponent2D") as InventoryComponent2D
		if inventory == null: return {"ok": false, "reason": "Actor has no inventory component."}
		if inventory.add_item(item, quantity) > 0: return {"ok": false, "reason": "Inventory is full."}
	collected_once = true
	collected.emit(actor, item.id, quantity)
	if remove_on_collect: queue_free()
	return {"ok": true, "reason": "Collected %s x%d." % [item.display_name, quantity]}
func save_state() -> Dictionary: return {"stable_id": String(stable_id), "collected": collected_once}
func load_state(data: Dictionary) -> void:
	if str(data.get("stable_id", "")) != String(stable_id): return
	collected_once = bool(data.get("collected", false))
	visible = not collected_once
	monitoring = not collected_once
