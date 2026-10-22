extends "res://tests/test_case.gd"
func test_inventory_stack_and_capacity() -> void:
	var inventory := InventoryComponent2D.new()
	inventory.slot_capacity = 2
	var item := ItemDefinition2D.new()
	item.id = &"test_material"
	item.max_stack = 5
	eq(inventory.add_item(item, 4), 0, "first stack fully accepted")
	eq(inventory.count(&"test_material"), 4, "inventory count reflects accepted items")
	eq(inventory.add_item(item, 6), 0, "stack overflow fills a second slot")
	eq(inventory.count(&"test_material"), 10, "two stacks sum correctly")
	eq(inventory.add_item(item, 1), 1, "full inventory returns unaccepted quantity")
	ok(inventory.remove_item(&"test_material", 6), "remove checks quantity before mutation")
	eq(inventory.count(&"test_material"), 5, "removal consumes across stacks")
	inventory.free()
func test_currency_rejects_invalid_spending() -> void:
	var currency := CurrencyComponent2D.new()
	currency.balance = 12
	not_ok(currency.spend(13), "cannot overspend")
	eq(currency.balance, 12, "failed spend preserves balance")
	ok(currency.spend(5), "valid spend succeeds")
	eq(currency.balance, 7, "valid spend deducts balance")
	eq(currency.earn(3), 3, "earn returns accepted amount")
	eq(currency.balance, 10, "earn increments balance")
	currency.free()
func test_loot_table_returns_stable_item_stacks() -> void:
	var item := ItemDefinition2D.new()
	item.id = &"test_loot"
	var entry := LootDropEntry2D.new()
	entry.item = item
	entry.weight = 1.0
	entry.minimum_quantity = 2
	entry.maximum_quantity = 2
	var table := LootTable2D.new()
	table.entries.append(entry)
	table.rolls = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var drops := table.roll(rng)
	eq(drops.size(), 2, "one entry selected per roll")
	if drops.size() == 2:
		eq(drops[0].item.id, &"test_loot", "drop keeps stable item ID")
		eq(drops[0].quantity, 2, "drop respects quantity range")
