extends StaticBody2D
class_name ChestInteractable2D
## One-shot chest. `opened` is world state and must be persisted in Phase 12.
signal opened_by(actor: Node)
signal loot_granted(item_id: StringName, quantity: int)
@export var stable_id: StringName = &"chest_001"
@export var loot_table: LootTable2D
@export var guaranteed_item: ItemDefinition2D
@export_range(1, 99, 1) var guaranteed_quantity: int = 1
@export_range(0, 999999, 1) var bonus_coins: int = 0
@export var opened_texture: Texture2D
@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
var opened: bool = false
func _ready() -> void:
	add_to_group(&"interactable")
	if stable_id == &"": push_warning("ChestInteractable2D '%s' needs a stable_id." % name)
	_update_appearance()
func interact(actor: Node) -> Dictionary:
	if opened: return {"ok": false, "reason": "This chest is already open."}
	if actor == null or not is_instance_valid(actor): return {"ok": false, "reason": "No valid actor."}
	var inventory := _find_inventory(actor)
	var currency := actor.get_node_or_null("CurrencyComponent2D") as CurrencyComponent2D
	if bonus_coins > 0 and currency == null:
		return {"ok": false, "reason": "Actor has no currency component."}
	var rolled: Array[ItemStack2D] = loot_table.roll() if loot_table != null else []
	if guaranteed_item != null and guaranteed_item.id != &"":
		var guaranteed := ItemStack2D.new()
		guaranteed.item = guaranteed_item
		guaranteed.quantity = maxi(guaranteed_quantity, 1)
		rolled.push_front(guaranteed)
	if not rolled.is_empty() and inventory == null:
		return {"ok": false, "reason": "Actor has no inventory component."}
	for stack in rolled:
		if not inventory.can_add(stack.item, stack.quantity):
			return {"ok": false, "reason": "Inventory is full; chest remains unopened."}
	var granted: Array[ItemStack2D] = []
	for stack in rolled:
		var remainder := inventory.add_item(stack.item, stack.quantity)
		if remainder > 0:
			var accepted := stack.quantity - remainder
			if accepted > 0: inventory.remove_item(stack.item.id, accepted)
			for previous in granted: inventory.remove_item(previous.item.id, previous.quantity)
			return {"ok": false, "reason": "Inventory changed before loot could be granted."}
		granted.append(stack)
	if bonus_coins > 0 and currency != null: currency.earn(bonus_coins)
	opened = true
	_update_appearance()
	opened_by.emit(actor)
	for stack in rolled: loot_granted.emit(stack.item.id, stack.quantity)
	return {"ok": true, "reason": "Chest opened."}
func save_state() -> Dictionary: return {"stable_id": String(stable_id), "opened": opened}
func load_state(data: Dictionary) -> void:
	if str(data.get("stable_id", "")) != String(stable_id): return
	opened = bool(data.get("opened", false))
	_update_appearance()
func _update_appearance() -> void:
	if is_instance_valid(_sprite) and opened and opened_texture != null: _sprite.texture = opened_texture
func _find_inventory(actor: Node) -> InventoryComponent2D:
	return actor.get_node_or_null("InventoryComponent2D") as InventoryComponent2D
