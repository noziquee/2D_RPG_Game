extends Node
## Headless test runner. Reused from the game-components add-on (test_case.gd and this file).
##
## Loads every suite in [constant SUITES], runs each `test_*` method, and reports
## the totals. Run it headless for CI:
## [codeblock]
## godot --headless --path . res://tests/test_runner.tscn
## [/codeblock]
## The process exit code equals the number of failed assertions (0 = all passed),
## so it slots straight into a build script. A report is also written to
## `res://tests/last_run.txt` and shown on screen when run from the editor.

const SUITES: Array[String] = [
	"res://tests/cases/test_attack_definition.gd",
	"res://tests/cases/test_health_component.gd",
	"res://tests/cases/test_damage_service.gd",
	"res://tests/cases/test_character_health.gd",
	"res://tests/cases/test_death_and_knockback.gd",
	"res://tests/cases/test_action_locks.gd",
]


func _ready() -> void:
	var report := _run_all()
	var text: String = report["text"]
	var fails: int = report["failures"]

	var f := FileAccess.open("res://tests/last_run.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()

	# On-screen output for editor runs (headless has no display).
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.text = text
	add_child(label)

	print(text)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(mini(fails, 255))


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
		for m in suite.get_method_list():
			var mname: String = m["name"]
			if mname.begins_with("test_") and (m["args"] as Array).is_empty():
				suite._set_current(mname)
				suite.call(mname)
				for child in suite.get_children():
					child.free()
		var mark := "OK  " if suite.failures.is_empty() else "FAIL"
		lines.append("[%s] %-20s %d passed, %d failed"
			% [mark, suite.suite_name(), suite.passes, suite.failures.size()])
		total_pass += suite.passes
		all_failures.append_array(suite.failures)
		suite.free()

	var header := "=== 2D RPG Game tests ===\n"
	var body := "\n".join(lines)
	var summary := "\n\n%d assertions passed, %d failed" % [total_pass, all_failures.size()]
	var detail := ""
	if not all_failures.is_empty():
		detail = "\n\nFailures:\n  " + "\n  ".join(all_failures)
	var verdict := "\n\nRESULT: " + ("ALL PASS" if all_failures.is_empty() else "FAILURES")
	return {
		"text": header + body + summary + detail + verdict,
		"failures": all_failures.size(),
		"passes": total_pass,
	}
