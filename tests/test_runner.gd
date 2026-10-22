extends Node
## Phase 11 replacement runner, preserving all existing suites and reporting behavior.
const SUITES: Array[String] = [
	"res://tests/cases/test_attack_definition.gd",
	"res://tests/cases/test_health_component.gd",
	"res://tests/cases/test_damage_service.gd",
	"res://tests/cases/test_character_health.gd",
	"res://tests/cases/test_death_and_knockback.gd",
	"res://tests/cases/test_action_locks.gd",
	"res://tests/cases/test_enemy_health_bar.gd",
	"res://tests/cases/test_combat_feedback.gd",
	"res://tests/cases/test_camera.gd",
	"res://tests/cases/test_stats_and_status.gd",
	"res://tests/cases/test_world_loop.gd",
]
func _ready() -> void:
	var report := _run_all()
	var report_text: String = report["text"]
	var failures: int = report["failures"]
	var file := FileAccess.open("res://tests/last_run.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(report_text)
		file.close()
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.text = report_text
	add_child(label)
	print(report_text)
	if DisplayServer.get_name() == "headless": get_tree().quit(mini(failures, 255))
func _run_all() -> Dictionary:
	var lines: Array[String] = []
	var all_failures: Array[String] = []
	var total_pass := 0
	for path in SUITES:
		var script: Script = load(path)
		if script == null:
			all_failures.append("could not load suite: " + path)
			continue
		var suite: SCTestCase = script.new()
		add_child(suite)
		for method_info in suite.get_method_list():
			var method_name: String = method_info["name"]
			if method_name.begins_with("test_") and (method_info["args"] as Array).is_empty():
				suite._set_current(method_name)
				suite.call(method_name)
				for child in suite.get_children(): child.free()
		var mark := "OK  " if suite.failures.is_empty() else "FAIL"
		lines.append("[%s] %-20s %d passed, %d failed" % [mark, suite.suite_name(), suite.passes, suite.failures.size()])
		total_pass += suite.passes
		all_failures.append_array(suite.failures)
		suite.free()
	var header := "=== 2D RPG Game tests ===\n"
	var body := "\n".join(lines)
	var summary := "\n\n%d assertions passed, %d failed" % [total_pass, all_failures.size()]
	var detail := ""
	if not all_failures.is_empty(): detail = "\n\nFailures:\n  " + "\n  ".join(all_failures)
	var verdict := "\n\nRESULT: " + ("ALL PASS" if all_failures.is_empty() else "FAILURES")
	return {"text": header + body + summary + detail + verdict, "failures": all_failures.size(), "passes": total_pass}
