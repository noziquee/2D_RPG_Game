class_name ItemStack
extends Resource
## A stack of items: definition + count. This is the content of a single slot.
##
## NOTE: resources in Godot are shared by reference. [Inventory]
## always creates new instances when splitting a stack — if you operate on
## stacks manually, use [method create] instead of reassigning references.

## The item definition.
@export var item: ItemDefinition

## The number of units in the stack.
@export_range(1, 9999) var count: int = 1


static func create(p_item: ItemDefinition, p_count: int) -> ItemStack:
	var stack := ItemStack.new()
	stack.item = p_item
	stack.count = p_count
	return stack


## Has the stack reached its maximum size?
func is_full() -> bool:
	return item != null and count >= item.max_stack


## How many more units will fit?
func space_left() -> int:
	if item == null:
		return 0
	return maxi(0, item.max_stack - count)


## Can this stack be merged with [param other] (the same item type)?
func can_merge_with(other: ItemStack) -> bool:
	return other != null and item != null and other.item == item
