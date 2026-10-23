class_name ItemDatabase
extends Resource
## A registry of all item definitions — needed for deserialization
## (mapping id -> ItemDefinition).
##
## You can build it in code ([method ItemDatabase.from_items]) or
## create it as a .tres resource and fill the list in the inspector.

@export var items: Array[ItemDefinition] = []

var _by_id := {}
var _cache_dirty := true


static func from_items(item_list: Array) -> ItemDatabase:
	var db := ItemDatabase.new()
	for item in item_list:
		if item is ItemDefinition:
			db.items.append(item)
	return db


func get_item(id: StringName) -> ItemDefinition:
	if _cache_dirty:
		_rebuild_cache()
	return _by_id.get(id)


func has_item(id: StringName) -> bool:
	return get_item(id) != null


## Call after changing the items list at runtime.
func invalidate_cache() -> void:
	_cache_dirty = true


func _rebuild_cache() -> void:
	_by_id.clear()
	for item in items:
		if item == null:
			continue
		if _by_id.has(item.id):
			push_warning("ItemDatabase: duplicate id '%s'." % item.id)
		_by_id[item.id] = item
	_cache_dirty = false
