extends SCTestCase
## Phase 12: the save manager's guarantees. Each test uses its own SaveManager and folder.

const DIR := "user://test_saves"

func _saves() -> SaveManager:
	var saves := SaveManager.new()
	saves.save_dir = DIR
	add_child(saves)
	return saves

func _cleanup(saves: SaveManager, slots: Array) -> void:
	for slot in slots:
		saves.delete_slot(slot)

func test_round_trip_restores_system_state() -> void:
	var saves := _saves()
	var state := {"value": 1}
	saves.register(&"demo", func() -> Dictionary: return {"value": state["value"]},
			func(data: Dictionary) -> bool:
				state["value"] = int(data["value"])
				return true)
	ok(saves.save_game("t_round"), "saved")
	state["value"] = 9
	ok(saves.load_game("t_round"), "loaded")
	eq(state["value"], 1, "restored to the saved value")
	_cleanup(saves, ["t_round"])

func test_invalid_slot_names_are_refused() -> void:
	var saves := _saves()
	not_ok(saves.save_game("../escape"), "a path cannot be a slot")
	not_ok(saves.save_game(""), "an empty slot is refused")
	not_ok(saves.is_valid_slot("with space"), "spaces are refused")
	ok(saves.is_valid_slot("slot_1-A"), "letters, digits, _ and - are allowed")

func test_missing_slot_fails_cleanly() -> void:
	var saves := _saves()
	not_ok(saves.load_game("t_missing"), "no save means no load")
	not_ok(saves.has_slot("t_missing"), "has_slot agrees")

func test_corrupt_primary_falls_back_to_backup() -> void:
	var saves := _saves()
	var state := {"value": 0}
	saves.register(&"demo", func() -> Dictionary: return {"value": state["value"]},
			func(data: Dictionary) -> bool:
				state["value"] = int(data["value"])
				return true)
	state["value"] = 1
	saves.save_game("t_backup")
	state["value"] = 2
	saves.save_game("t_backup")  # the first save is now the backup
	var file := FileAccess.open(DIR + "/t_backup.json", FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	state["value"] = 99
	ok(saves.load_game("t_backup"), "loaded from the backup")
	eq(state["value"], 1, "the backup holds the save before the last one")
	_cleanup(saves, ["t_backup"])

func test_malformed_structure_is_rejected() -> void:
	var saves := _saves()
	saves.save_game("t_shape")
	var file := FileAccess.open(DIR + "/t_shape.json", FileAccess.WRITE)
	file.store_string('{"meta": {"version": 1}, "state": [1, 2]}')
	file.close()
	DirAccess.remove_absolute(DIR + "/t_shape.json.bak")
	not_ok(saves.load_game("t_shape"), "a non-dictionary state is not a valid save")
	_cleanup(saves, ["t_shape"])

func test_a_rejecting_system_does_not_stop_the_others() -> void:
	var saves := _saves()
	var first := {"value": 0}
	var second := {"value": 0}
	saves.register(&"bad", func() -> Dictionary: return {"x": 1}, func(_data: Dictionary) -> bool: return false)
	saves.register(&"good", func() -> Dictionary: return {"value": 5},
			func(data: Dictionary) -> bool:
				second["value"] = int(data["value"])
				return true)
	saves.save_game("t_isolated")
	second["value"] = 0
	ok(saves.load_game("t_isolated"), "the load still succeeds")
	eq(second["value"], 5, "the good system still got its data")
	_cleanup(saves, ["t_isolated"])

func test_a_system_that_returns_no_dictionary_is_skipped() -> void:
	var saves := _saves()
	var state := {"value": 3}
	saves.register(&"demo", func() -> Dictionary: return {"value": state["value"]},
			func(data: Dictionary) -> bool:
				state["value"] = int(data["value"])
				return true)
	saves.register(&"broken", func() -> Variant: return 42, func(_d: Dictionary) -> bool: return true)
	ok(saves.save_game("t_skip"), "the save still succeeds")
	state["value"] = 0
	ok(saves.load_game("t_skip"), "and loads")
	eq(state["value"], 3, "the valid system kept its data")
	saves.unregister(&"broken")
	_cleanup(saves, ["t_skip"])

func test_delete_removes_primary_and_backup() -> void:
	var saves := _saves()
	saves.save_game("t_delete")
	saves.save_game("t_delete")
	saves.delete_slot("t_delete")
	not_ok(saves.has_slot("t_delete"), "gone, including the backup")
