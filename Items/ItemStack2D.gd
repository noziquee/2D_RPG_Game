extends Resource
class_name ItemStack2D
@export var item: ItemDefinition2D
@export_range(1, 999, 1) var quantity: int = 1
func is_valid_stack() -> bool:
	return item != null and item.id != &"" and quantity > 0
func duplicate_stack() -> ItemStack2D:
	var copy := ItemStack2D.new()
	copy.item = item
	copy.quantity = quantity
	return copy
