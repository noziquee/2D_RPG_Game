@icon("res://addons/inventory_system/theme/editor_icon_inventory.svg")
class_name Inventory
extends Node
## Inventory logic — independent of the UI.
##
## Holds slots of [ItemStack] and exposes operations: adding, removing,
## moving (merge/swap/split), quick transfer between inventories,
## sorting and serialization. It reports every change through signals —
## the UI ([InventoryPanelUI]) only listens and refreshes.
##
## An empty slot = null (not an ItemStack with count 0).

## Emitted after the contents of a single slot change.
signal slot_changed(index: int)
## Emitted once after every operation that changed something (after all slot_changed).
signal contents_changed()
## Emitted when items actually entered the inventory (e.g. picking up).
signal item_added(item: ItemDefinition, count: int)
## Emitted when items left the inventory (consumption, transfer, removal).
signal item_removed(item: ItemDefinition, count: int)
## Emitted after the number of slots changes.
signal capacity_changed(new_capacity: int)

## Number of slots. Reducing the capacity truncates the extra slots
## (items from the truncated slots are lost — handle that on your side).
@export_range(1, 256) var capacity: int = 27: set = set_capacity

var _slots: Array[ItemStack] = []


func _init() -> void:
	_slots.resize(capacity)


func set_capacity(value: int) -> void:
	value = maxi(1, value)
	if value == capacity and _slots.size() == value:
		capacity = value
		return
	capacity = value
	_slots.resize(capacity)
	capacity_changed.emit(capacity)
	contents_changed.emit()


# --- Reading state ---------------------------------------------------------

## Returns the stack in a slot or null if the slot is empty or the index is out of range.
func get_slot(index: int) -> ItemStack:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


func is_slot_empty(index: int) -> bool:
	return get_slot(index) == null


## Index of the first empty slot, or -1.
func find_first_empty() -> int:
	return _slots.find(null)


func is_full() -> bool:
	return find_first_empty() == -1


## Total number of units of the given item across all slots.
func count_item(item: ItemDefinition) -> int:
	var total := 0
	for stack in _slots:
		if stack != null and stack.item == item:
			total += stack.count
	return total


func has_item(item: ItemDefinition, count: int = 1) -> bool:
	return count_item(item) >= count


## Number of occupied slots.
func get_used_slot_count() -> int:
	var used := 0
	for stack in _slots:
		if stack != null:
			used += 1
	return used


# --- Modifications ----------------------------------------------------------

## Adds items: first tops up existing stacks, then
## fills empty slots. Returns the number of units that did NOT fit.
func add_item(item: ItemDefinition, count: int = 1) -> int:
	if item == null or count <= 0:
		return maxi(0, count)
	var leftover := count
	var changed: Array[int] = []

	# 1. top up existing stacks of the same type
	for i in _slots.size():
		if leftover == 0:
			break
		var stack := _slots[i]
		if stack != null and stack.item == item and not stack.is_full():
			var put := mini(leftover, stack.space_left())
			stack.count += put
			leftover -= put
			changed.append(i)

	# 2. fill empty slots
	for i in _slots.size():
		if leftover == 0:
			break
		if _slots[i] == null:
			var put := mini(leftover, item.max_stack)
			_slots[i] = ItemStack.create(item, put)
			leftover -= put
			changed.append(i)

	if not changed.is_empty():
		for i in changed:
			slot_changed.emit(i)
		item_added.emit(item, count - leftover)
		contents_changed.emit()
	return leftover


## Convenience variant: adds a whole [ItemStack], returns the number of units that didn't fit.
func add_stack(stack: ItemStack) -> int:
	if stack == null or stack.item == null:
		return 0
	return add_item(stack.item, stack.count)


## Removes up to [param count] units of an item (from any slots).
## Returns the number of units actually removed.
func remove_item(item: ItemDefinition, count: int = 1) -> int:
	if item == null or count <= 0:
		return 0
	var to_remove := count
	var changed: Array[int] = []
	for i in _slots.size():
		if to_remove == 0:
			break
		var stack := _slots[i]
		if stack != null and stack.item == item:
			var take := mini(to_remove, stack.count)
			stack.count -= take
			to_remove -= take
			if stack.count == 0:
				_slots[i] = null
			changed.append(i)
	var removed := count - to_remove
	if removed > 0:
		for i in changed:
			slot_changed.emit(i)
		item_removed.emit(item, removed)
		contents_changed.emit()
	return removed


## Removes up to [param amount] units from a specific slot. Returns the number removed.
func remove_from_slot(index: int, amount: int = 1) -> int:
	var stack := get_slot(index)
	if stack == null or amount <= 0:
		return 0
	var take := mini(amount, stack.count)
	var item := stack.item
	stack.count -= take
	if stack.count == 0:
		_slots[index] = null
	slot_changed.emit(index)
	item_removed.emit(item, take)
	contents_changed.emit()
	return take


## Overwrites a slot. A stack with count <= 0 or without a definition is normalized to null.
## Use deliberately — it does not check max_stack or merge.
func set_slot(index: int, stack: ItemStack) -> void:
	if index < 0 or index >= _slots.size():
		push_warning("Inventory.set_slot: index %d out of range." % index)
		return
	if stack != null and (stack.item == null or stack.count <= 0):
		stack = null
	_slots[index] = stack
	slot_changed.emit(index)
	contents_changed.emit()


## Clears the whole inventory.
func clear() -> void:
	for i in _slots.size():
		if _slots[i] != null:
			_slots[i] = null
			slot_changed.emit(i)
	contents_changed.emit()


# --- Moving / drag & drop -------------------------------------------

## Moves [param amount] units (-1 = the whole stack) from slot [param from_index]
## of this inventory to slot [param to_index] of inventory [param target]
## (which may be the same inventory). Handles:
## [br]• moving onto an empty slot,
## [br]• merging with the same item type (the overflow stays at the source),
## [br]• swapping places (only when the whole stack is moved).
## Returns true if something changed. The UI uses this method for drag & drop.
func transfer_to(target: Inventory, from_index: int, to_index: int, amount: int = -1) -> bool:
	if target == null:
		return false
	if from_index < 0 or from_index >= _slots.size():
		return false
	if to_index < 0 or to_index >= target._slots.size():
		return false
	if target == self and from_index == to_index:
		return false
	var src := _slots[from_index]
	if src == null:
		return false
	var moving := src.count if amount <= 0 else clampi(amount, 1, src.count)
	var dst := target._slots[to_index]
	var changed := false

	if dst == null:
		# move onto an empty slot
		target._slots[to_index] = ItemStack.create(src.item, moving)
		src.count -= moving
		changed = true
	elif dst.item == src.item:
		# merge; if the target is full and we carry the whole stack — swap counts
		var put := mini(dst.space_left(), moving)
		if put > 0:
			dst.count += put
			src.count -= put
			changed = true
		elif moving == src.count and dst.count != src.count:
			var tmp := dst.count
			dst.count = src.count
			src.count = tmp
			changed = true
	else:
		# different items: swap places only when the whole stack is moved
		if moving != src.count:
			return false
		target._slots[to_index] = src
		_slots[from_index] = dst
		changed = true

	if not changed:
		return false
	if _slots[from_index] == src and src.count <= 0:
		_slots[from_index] = null
	slot_changed.emit(from_index)
	target.slot_changed.emit(to_index)
	contents_changed.emit()
	if target != self:
		target.contents_changed.emit()
	return true


## Quick transfer (Shift+click): moves the whole stack from a slot to [param target],
## wherever it fits. Returns the number of units moved.
func quick_transfer(from_index: int, target: Inventory) -> int:
	if target == null or target == self:
		return 0
	var src := get_slot(from_index)
	if src == null:
		return 0
	var item := src.item
	var leftover := target.add_item(item, src.count)
	var moved := src.count - leftover
	if moved > 0:
		src.count = leftover
		if leftover == 0:
			_slots[from_index] = null
		slot_changed.emit(from_index)
		item_removed.emit(item, moved)
		contents_changed.emit()
	return moved


## Sorts and merges the contents: by category, then rarity (descending),
## then name. Stacks of the same type are merged to full.
func sort_items() -> void:
	var totals := {}            # ItemDefinition -> total count
	var order: Array[ItemDefinition] = []
	for stack in _slots:
		if stack != null:
			if not totals.has(stack.item):
				totals[stack.item] = 0
				order.append(stack.item)
			totals[stack.item] += stack.count
	order.sort_custom(func(a: ItemDefinition, b: ItemDefinition) -> bool:
		if a.category != b.category:
			return String(a.category) < String(b.category)
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		return a.display_name < b.display_name
	)
	for i in _slots.size():
		_slots[i] = null
	var slot := 0
	for item in order:
		var remaining: int = totals[item]
		while remaining > 0 and slot < _slots.size():
			var put := mini(remaining, item.max_stack)
			_slots[slot] = ItemStack.create(item, put)
			remaining -= put
			slot += 1
	for i in _slots.size():
		slot_changed.emit(i)
	contents_changed.emit()


# --- Serialization ---------------------------------------------------------

## Returns the inventory state as a dictionary ready for JSON / a game save.
func serialize() -> Dictionary:
	var slots_data: Array = []
	for stack in _slots:
		if stack == null:
			slots_data.append(null)
		else:
			slots_data.append({"id": String(stack.item.id), "count": stack.count})
	return {"capacity": capacity, "slots": slots_data}


## Restores the state from [method serialize]. Item definitions are looked up
## in [param database] by id. Returns false on invalid data.
func deserialize(data: Dictionary, database: ItemDatabase) -> bool:
	if database == null or not data.has("slots"):
		return false
	set_capacity(int(data.get("capacity", capacity)))
	var slots_data: Array = data["slots"]
	for i in _slots.size():
		var entry = slots_data[i] if i < slots_data.size() else null
		if entry is Dictionary and entry.has("id"):
			var item := database.get_item(StringName(entry["id"]))
			if item != null:
				_slots[i] = ItemStack.create(item, maxi(1, int(entry.get("count", 1))))
			else:
				push_warning("Inventory.deserialize: unknown item '%s'." % entry["id"])
				_slots[i] = null
		else:
			_slots[i] = null
		slot_changed.emit(i)
	contents_changed.emit()
	return true
