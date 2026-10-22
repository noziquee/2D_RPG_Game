extends Resource
class_name LootTable2D
## Each roll selects one entry by weight. Set rolls > 1 for multiple independent drops.
@export var entries: Array[LootDropEntry2D] = []
@export_range(0, 20, 1) var rolls: int = 1
func roll(rng: RandomNumberGenerator = null) -> Array[ItemStack2D]:
	var random := rng if rng != null else RandomNumberGenerator.new()
	if rng == null: random.randomize()
	var result: Array[ItemStack2D] = []
	for _roll_index in range(rolls):
		var total := 0.0
		for entry in entries:
			if entry != null and entry.item != null and entry.item.id != &"" and entry.weight > 0.0:
				total += entry.weight
		if total <= 0.0: continue
		var ticket := random.randf_range(0.0, total)
		for entry in entries:
			if entry == null or entry.item == null or entry.item.id == &"" or entry.weight <= 0.0: continue
			ticket -= entry.weight
			if ticket <= 0.0:
				var stack := ItemStack2D.new()
				stack.item = entry.item
				stack.quantity = random.randi_range(mini(entry.minimum_quantity, entry.maximum_quantity), maxi(entry.minimum_quantity, entry.maximum_quantity))
				result.append(stack)
				break
	return result
