@icon("res://addons/inventory_system/theme/editor_icon_item.svg")
class_name ItemDefinition
extends Resource
## An item definition (template). One .tres resource per item type.
##
## The definition describes WHAT the item is (name, icon, maximum stack).
## Concrete instances in an inventory are represented by [ItemStack] (definition + count).

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

const RARITY_NAMES := {
	Rarity.COMMON: "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE: "Rare",
	Rarity.EPIC: "Epic",
	Rarity.LEGENDARY: "Legendary",
}

const RARITY_COLORS := {
	Rarity.COMMON: Color("8d99a6"),
	Rarity.UNCOMMON: Color("4caf50"),
	Rarity.RARE: Color("3d8be0"),
	Rarity.EPIC: Color("ab47cf"),
	Rarity.LEGENDARY: Color("f5a623"),
}

## Unique identifier — used when saving/loading the inventory state.
@export var id: StringName

## Name shown in the UI (tooltip, etc.).
@export var display_name: String

## Description shown in the tooltip.
@export_multiline var description: String

## The item icon.
@export var icon: Texture2D

## Maximum number of units in a single slot (1 = non-stackable item).
@export_range(1, 9999) var max_stack: int = 64

## Rarity — affects the slot background color and the name in the tooltip.
@export var rarity: Rarity = Rarity.COMMON

## Category (e.g. &"food", &"weapon", &"material") — used among other things for sorting.
@export var category: StringName = &"misc"

## Arbitrary game-specific data (damage, nutrition value, etc.).
## The component does not interpret it — this is the place to integrate with your game.
@export var custom_data: Dictionary = {}


func get_rarity_name() -> String:
	return RARITY_NAMES.get(rarity, "?")


func get_rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)
