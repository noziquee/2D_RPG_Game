extends SCTestCase
## Tests for camera_system — CameraDirector's viewport-independent logic: deadzone,
## trauma clamp, focus state/signals, snap and the frame-rate-independent ease.
## (Follow smoothing and bounds clamping depend on a live viewport and are verified in
## the demo.)


func _cam() -> CameraDirector:
	var c := CameraDirector.new()
	add_child(c)
	c.position = Vector2.ZERO
	return c


func _target(at: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = at
	add_child(n)
	return n


func test_deadzone_holds_inside_box() -> void:
	var c := _cam()
	c.deadzone = Vector2(100, 50)
	var goal := c._apply_deadzone(Vector2(80, 40), 0.0)
	eq(goal, Vector2.ZERO, "target inside the deadzone keeps the camera still")


func test_deadzone_follows_outside_box() -> void:
	var c := _cam()
	c.deadzone = Vector2(100, 50)
	var goal := c._apply_deadzone(Vector2(300, 0), 0.0)
	eq(goal.x, 200.0, "camera trails the target by the deadzone half-width")
	eq(goal.y, 0.0, "the untouched axis does not move")
	var up := c._apply_deadzone(Vector2(0, 90), 0.0)
	eq(up.y, 40.0, "vertical follow trails by the deadzone half-height")


func test_zero_deadzone_glues_to_target() -> void:
	var c := _cam()
	c.deadzone = Vector2.ZERO
	eq(c._apply_deadzone(Vector2(123, 45), 0.0), Vector2(123, 45), "no deadzone = exact follow")


func test_add_trauma_clamps() -> void:
	var c := _cam()
	c.add_trauma(0.4)
	c.add_trauma(0.9)
	ok(c._trauma <= 1.0 and c._trauma > 0.0, "trauma clamps to at most 1.0")


func test_focus_state_and_signal() -> void:
	var c := _cam()
	var box := {"ended": 0}
	c.focus_ended.connect(func() -> void: box["ended"] += 1)
	not_ok(c.is_focusing(), "not focusing by default")
	c.focus_on(_target(Vector2(500, 0)))
	ok(c.is_focusing(), "focus_on engages focus")
	c.clear_focus()
	not_ok(c.is_focusing(), "clear_focus releases it")
	eq(box["ended"], 1, "focus_ended fired once")


func test_focus_on_point() -> void:
	var c := _cam()
	c.focus_on_point(Vector2(800, 400))
	ok(c.is_focusing(), "a point focus is a focus")
	eq(c._current_focus(), Vector2(800, 400), "focus resolves to the point")


func test_snap_to_target_no_bounds() -> void:
	var c := _cam()
	c.bounds = Rect2()   # no clamping → exact
	c.target = _target(Vector2(640, 360))
	c.snap_to_target()
	eq(c.global_position, Vector2(640, 360), "snaps exactly onto the target")


func test_ease_is_a_unit_weight() -> void:
	var c := _cam()
	var w := c._ease(6.0, 0.016)
	ok(w > 0.0 and w < 1.0, "ease weight is in (0,1) for a normal frame")
	eq(c._ease(6.0, 0.0), 0.0, "zero delta = no movement")
