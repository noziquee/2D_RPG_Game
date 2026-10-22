extends Node
class_name InventoryComponent2D
## Small stack inventory. Item IDs are stable save/content keys, never display names.
signal inventory_changed
signal item_added(item_id: StringName, quantity: int)
signal item_removed(item_id: StringName, quantity: int)
@export_range(1, 200, 1) var slot_capacity: int = 24
var _stacks: Array[ItemStack2D] = []
func slots_used() -> int: return _stacks.size()
func get_stacks() -> Array[ItemStack2D]:
	var copy: Array[ItemStack2D] = []
	for stack in _stacks: copy.append(stack.duplicate_stack())
	return copy
func count(item_id: StringName) -> int:
	var total := 0
	for stack in _stacks:
		if stack.item.id == item_id: total += stack.quantity
	return total
func has_item(item_id: StringName, quantity: int = 1) -> bool: return quantity > 0 and count(item_id) >= quantity
func can_add(item: ItemDefinition2D, quantity: int = 1) -> bool:
	if item == null or item.id == &"" or quantity <= 0: return false
	var remaining := quantity
	if not item.unique:
		for stack in _stacks:
			if stack.item.id == item.id:
				remaining -= mini(remaining, maxi(item.max_stack - stack.quantity, 0))
				if remaining <= 0: return true
	var stack_size := 1 if item.unique else maxi(item.max_stack, 1)
	var needed_slots := ceili(float(remaining) / float(stack_size))
	return _stacks.size() + needed_slots <= slot_capacity
func add_item(item: ItemDefinition2D, quantity: int = 1) -> int:
	if item == null or item.id == &"" or quantity <= 0: return quantity
	var remaining := quantity
	if not item.unique:
		for stack in _stacks:
			if stack.item.id == item.id and stack.quantity < item.max_stack:
				var moved := mini(remaining, item.max_stack - stack.quantity)
				stack.quantity += moved
				remaining -= moved
				if remaining == 0: break
	while remaining > 0 and _stacks.size() < slot_capacity:
		var moved := mini(remaining, 1 if item.unique else maxi(item.max_stack, 1))
		var stack := ItemStack2D.new()
		stack.item = item
		stack.quantity = moved
		_stacks.append(stack)
		remaining -= moved
	var accepted := quantity - remaining
	if accepted > 0:
		item_added.emit(item.id, accepted)
		inventory_changed.emit()
	return remaining
func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	if quantity <= 0 or not has_item(item_id, quantity): return false
	var remaining := quantity
	for index in range(_stacks.size() - 1, -1, -1):
		var stack := _stacks[index]
		if stack.item.id != item_id: continue
		var removed := mini(remaining, stack.quantity)
		stack.quantity -= removed
		remaining -= removed
		if stack.quantity <= 0: _stacks.remove_at(index)
		if remaining == 0: break
	item_removed.emit(item_id, quantity)
	inventory_changed.emit()
	return true
func save_state() -> Dictionary:
	var data: Array[Dictionary] = []
	for stack in _stacks: data.append({"id": String(stack.item.id), "quantity": stack.quantity})
	return {"version": 1, "stacks": data}
## Resolver is supplied by the caller; never load a resource path from save data.
func load_state(data: Dictionary, item_catalog: Dictionary) -> void:
	_stacks.clear()
	var raw: Variant = data.get("stacks", [])
	if typeof(raw) != TYPE_ARRAY: inventory_changed.emit(); return
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY: continue
		var id := StringName(str(entry.get("id", "")))
		var item: ItemDefinition2D = item_catalog.get(id) as ItemDefinition2D
		var quantity: int = int(entry.get("quantity", 0))
		if item == null or id == &"" or quantity <= 0: continue
		var remainder := add_item(item, quantity)
		if remainder > 0: break
	inventory_changed.emit()
