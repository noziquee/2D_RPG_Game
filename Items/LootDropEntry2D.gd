extends Resource
class_name LootDropEntry2D
@export var item: ItemDefinition2D
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export_range(1, 99, 1) var minimum_quantity: int = 1
@export_range(1, 99, 1) var maximum_quantity: int = 1
