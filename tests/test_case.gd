class_name SCTestCase
extends Node
## Base class for the headless test suites in `tests/cases/`.
##
## Subclasses define zero-argument methods named `test_*`; the [TestRunner]
## discovers and runs each one. GDScript has no exceptions, so the assertion
## helpers below simply record a pass or a failure instead of throwing — a suite
## keeps running after a failed assertion.
##
## Each test gets a fresh node context: nodes you `add_child()` are freed by the
## runner after the method returns, so suites stay isolated.

var passes := 0
var failures: Array[String] = []
var _current := ""


func _set_current(method: String) -> void:
	_current = method


func suite_name() -> String:
	return get_script().resource_path.get_file().trim_suffix(".gd")


func _fail(msg: String) -> void:
	failures.append("%s::%s — %s" % [suite_name(), _current, msg])


# --- Assertions ---------------------------------------------------------------

func ok(cond: bool, label := "expected true") -> void:
	if cond:
		passes += 1
	else:
		_fail(label)


func not_ok(cond: bool, label := "expected false") -> void:
	ok(not cond, label)


func eq(actual: Variant, expected: Variant, label := "") -> void:
	if actual == expected:
		passes += 1
	else:
		_fail("%s (got %s, expected %s)" % [label, str(actual), str(expected)])


func almost(actual: float, expected: float, label := "", eps := 0.0001) -> void:
	if absf(actual - expected) <= eps:
		passes += 1
	else:
		_fail("%s (got %s, expected ~%s)" % [label, str(actual), str(expected)])


func not_null(value: Variant, label := "expected non-null") -> void:
	ok(value != null, label)


func is_null(value: Variant, label := "expected null") -> void:
	ok(value == null, label)
