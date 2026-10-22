extends Node
class_name StatsComponent2D
## Base stat values plus the modifiers that change them.
## Derived value = (base + sum of flat) * (1 + sum of percent).
## Modifiers are grouped by source, so a status effect removes exactly what it added.

signal stat_changed(stat_id: StringName, value: float)

var _base: Dictionary = {}       # stat_id -> float
var _modifiers: Dictionary = {}  # source id -> { stat_id -> Vector2(flat, percent) }

func set_base(stat_id: StringName, value: float) -> void:
	var old := get_stat(stat_id)
	_base[stat_id] = value
	_emit_if_changed(stat_id, old)

func get_base(stat_id: StringName) -> float:
	return float(_base.get(stat_id, 0.0))

func get_stat(stat_id: StringName) -> float:
	var flat := 0.0
	var percent := 0.0
	for source in _modifiers:
		var per_stat: Dictionary = _modifiers[source]
		if per_stat.has(stat_id):
			var pair: Vector2 = per_stat[stat_id]
			flat += pair.x
			percent += pair.y
	return (get_base(stat_id) + flat) * (1.0 + percent)

## Sets the modifier that source applies to stat. Calling again replaces it.
func set_modifier(source: StringName, stat_id: StringName, flat: float, percent: float) -> void:
	var old := get_stat(stat_id)
	if not _modifiers.has(source):
		_modifiers[source] = {}
	var per_stat: Dictionary = _modifiers[source]
	per_stat[stat_id] = Vector2(flat, percent)
	_emit_if_changed(stat_id, old)

## Removes every modifier that source applied.
func remove_modifiers(source: StringName) -> void:
	if not _modifiers.has(source):
		return
	var per_stat: Dictionary = _modifiers[source]
	var before := {}
	for stat_id in per_stat:
		before[stat_id] = get_stat(stat_id)
	_modifiers.erase(source)
	for stat_id in before:
		_emit_if_changed(stat_id, before[stat_id])

func _emit_if_changed(stat_id: StringName, old_value: float) -> void:
	var now := get_stat(stat_id)
	if not is_equal_approx(now, old_value):
		stat_changed.emit(stat_id, now)
