class_name SaveManager
extends Node
## Saves and loads registered game systems to JSON slots. Adopted from the game-components
## add-on's save_system, then hardened per the bundle audit:
## - atomic writes: data goes to a temporary file, is checked, and only then replaces the slot;
##   the previous save is kept as a .bak backup, and a failed write leaves the old save intact
## - slot names are validated (letters, digits, - and _), so a slot can never be a path
## - a corrupt primary file falls back to its backup
## - each system's data is type-checked before the system gets it; a system that rejects its
##   data is reported and the other systems still load

signal game_saved(slot: String)
signal game_loaded(slot: String)
signal save_failed(slot: String, reason: String)
signal load_failed(slot: String, reason: String)
signal slots_changed()

@export var save_dir := "user://saves"
@export var save_version := 1

## Optional migration for older saves: Callable(state: Dictionary, from_version: int) -> Dictionary.
var migrator: Callable

var _providers := {}  # StringName -> { "save": Callable, "load": Callable }
var _playtime := 0.0
var _slot_pattern := RegEx.create_from_string("^[A-Za-z0-9_-]{1,32}$")

func _process(delta: float) -> void:
	_playtime += delta

## Registers a system. save_func returns a Dictionary (JSON-ready); load_func takes that
## Dictionary and returns false if it rejects the data.
func register(id: StringName, save_func: Callable, load_func: Callable) -> void:
	_providers[id] = {"save": save_func, "load": load_func}

func unregister(id: StringName) -> void:
	_providers.erase(id)

func is_valid_slot(slot: String) -> bool:
	return _slot_pattern.search(slot) != null

func save_game(slot: String, label := "") -> bool:
	if not is_valid_slot(slot):
		save_failed.emit(slot, "Invalid slot name")
		return false
	DirAccess.make_dir_recursive_absolute(save_dir)

	var state := {}
	for id in _providers:
		var value: Variant = _providers[id]["save"].call()
		if value is Dictionary:
			state[String(id)] = value
		else:
			push_warning("SaveManager: system '%s' returned no dictionary; skipped." % id)
	var data := {
		"meta": {
			"version": save_version,
			"timestamp": Time.get_unix_time_from_system(),
			"date_text": Time.get_datetime_string_from_system(false, true),
			"label": label,
			"playtime": _playtime,
		},
		"state": state,
	}
	var text := JSON.stringify(data, "  ")
	if JSON.parse_string(text) == null:
		save_failed.emit(slot, "Save data could not be encoded")
		return false

	var path := _slot_path(slot)
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		save_failed.emit(slot, "Could not create the save file")
		return false
	file.store_string(text)
	file.close()

	if FileAccess.file_exists(path):
		if not _keep_backup(slot):
			DirAccess.remove_absolute(temp)
			save_failed.emit(slot, "Could not back up the previous save")
			return false
		DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(temp, path) != OK:
		# Put the previous save back so a failed write never loses the last good file.
		if FileAccess.file_exists(_backup_path(slot)):
			DirAccess.copy_absolute(_backup_path(slot), path)
		save_failed.emit(slot, "Could not replace the save file")
		return false
	game_saved.emit(slot)
	slots_changed.emit()
	return true

## Loads a slot and hands each system its data. Returns false only if no valid save
## exists or the version cannot be migrated. A system that rejects its data is warned
## about; the others still load.
func load_game(slot: String) -> bool:
	if not is_valid_slot(slot):
		load_failed.emit(slot, "Invalid slot name")
		return false
	var data := _read_valid(slot)
	if data.is_empty():
		load_failed.emit(slot, "No save, or the save is corrupted")
		return false
	var meta: Dictionary = data["meta"]
	var state: Dictionary = data["state"]
	var version := int(meta.get("version", 0))
	if version != save_version:
		if not migrator.is_valid():
			load_failed.emit(slot, "Incompatible save version (%d)" % version)
			return false
		var migrated: Variant = migrator.call(state, version)
		if not (migrated is Dictionary):
			load_failed.emit(slot, "Save could not be migrated from version %d" % version)
			return false
		state = migrated

	var problems: Array[String] = []
	for id in _providers:
		var key := String(id)
		if not state.has(key):
			continue
		var value: Variant = state[key]
		if not (value is Dictionary):
			problems.append("%s: data is not a dictionary" % key)
			continue
		var accepted: Variant = _providers[id]["load"].call(value)
		if accepted is bool and not accepted:
			problems.append("%s: rejected its data" % key)
	_playtime = maxf(float(meta.get("playtime", 0.0)), 0.0)
	if not problems.is_empty():
		push_warning("SaveManager: %s loaded with problems: %s" % [slot, "; ".join(problems)])
	game_loaded.emit(slot)
	return true

func has_slot(slot: String) -> bool:
	return is_valid_slot(slot) and (FileAccess.file_exists(_slot_path(slot)) or FileAccess.file_exists(_backup_path(slot)))

func delete_slot(slot: String) -> void:
	if not is_valid_slot(slot):
		return
	for path in [_slot_path(slot), _backup_path(slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	slots_changed.emit()

## Slot metadata ({} when empty or corrupted): version, timestamp, date_text, label, playtime.
func get_slot_info(slot: String) -> Dictionary:
	if not is_valid_slot(slot):
		return {}
	return _read_valid(slot).get("meta", {})

func get_playtime() -> float:
	return _playtime

## "1 h 23 min" / "12 min" / "40 s".
static func format_playtime(seconds: float) -> String:
	var total := int(seconds)
	@warning_ignore("integer_division")
	var hours := total / 3600
	@warning_ignore("integer_division")
	var minutes := (total % 3600) / 60
	if hours > 0:
		return "%d h %d min" % [hours, minutes]
	if minutes > 0:
		return "%d min" % minutes
	return "%d s" % total

# --- Internal ----------------------------------------------------------------------

func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [save_dir, slot]

func _backup_path(slot: String) -> String:
	return _slot_path(slot) + ".bak"

## Copies the current save to the backup, replacing any older backup.
func _keep_backup(slot: String) -> bool:
	var backup := _backup_path(slot)
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	return DirAccess.copy_absolute(_slot_path(slot), backup) == OK

## The primary save if it is valid, otherwise the backup, otherwise {}.
func _read_valid(slot: String) -> Dictionary:
	var primary := _read_file(_slot_path(slot))
	if not primary.is_empty():
		return primary
	return _read_file(_backup_path(slot))

func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return {}
	if not (parsed.get("meta") is Dictionary) or not (parsed.get("state") is Dictionary):
		return {}
	return parsed
