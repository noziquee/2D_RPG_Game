class_name CameraDirector
extends Camera2D
## A drop-in 2D game camera: follow a target with a deadzone and look-ahead, clamp to
## world bounds, zoom smoothly, blend to focus points for a beat, and shake on trauma.
##
## Pure node — drop it in as your [Camera2D], set [member target], done. Everything is a
## property you can tune live, and it owns nothing about your game. The shake is a hook:
## call [method add_trauma] from a hit, or let another system drive it.
## [codeblock]
## var cam := CameraDirector.new()
## add_child(cam)
## cam.target = $Player
## cam.bounds = Rect2(0, 0, 4000, 2000)   # keep the view inside the level
## cam.add_trauma(0.6)                      # a punchy knock on a hit
## cam.focus_for($Boss, 1.5)                # glance at the boss, then return
## [/codeblock]

## Emitted when a [method focus_for] hold ends and the camera returns to [member target].
signal focus_ended()

## The node the camera follows. Null holds the current position (drive it by hand).
@export var target: Node2D
## Follow stiffness. Higher snaps faster; 0 or less is instant (no smoothing).
@export var follow_speed := 6.0
## Half-size of the box the target may move in before the camera follows (0 = glued).
@export var deadzone := Vector2(72, 48)
## Seconds of the target's velocity to lead the camera by (anticipates movement). 0 off.
@export var look_ahead := 0.18
## How fast the look-ahead offset eases in/out.
@export var look_ahead_speed := 3.0
## Desired zoom (Godot 2D: >1 zooms in, <1 out). Eased toward by [member zoom_speed].
@export var zoom_level := 1.0
@export var zoom_speed := 6.0
## World rectangle the view is kept inside. Zero-size (default) means no clamping.
@export var bounds := Rect2()

## Shake tuning: peak pixel offset and peak rotation (radians) at full trauma.
@export var shake_max_offset := 28.0
@export var shake_max_roll := 0.06
## How fast trauma bleeds off per second.
@export var trauma_decay := 1.3

var _trauma := 0.0
var _look := Vector2.ZERO
var _target_vel := Vector2.ZERO
var _last_target_pos := Vector2.ZERO
var _have_last := false
var _focus_node: Node2D = null
var _focus_point := Vector2.ZERO
var _focus_use_point := false
var _focus_time_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if target != null:
		global_position = _follow_point()
		_last_target_pos = _follow_point()
		_have_last = true


func _process(delta: float) -> void:
	var focus_pt: Variant = _current_focus()
	if focus_pt != null:
		_focus_time_left -= delta
		if _focus_time_left <= 0.0 and (_focus_node != null or _focus_use_point):
			_clear_focus()

	# --- desired centre from follow target (or focus) ---
	var goal := _follow_point()
	if focus_pt != null:
		goal = focus_pt as Vector2
	else:
		goal = _apply_deadzone(goal, delta)

	# --- look-ahead (skip while focusing) ---
	if focus_pt == null and look_ahead > 0.0:
		var desired_look := _target_vel * look_ahead
		_look = _look.lerp(desired_look, _ease(look_ahead_speed, delta))
	else:
		_look = _look.lerp(Vector2.ZERO, _ease(look_ahead_speed, delta))
	goal += _look

	# --- move ---
	if follow_speed <= 0.0:
		global_position = goal
	else:
		global_position = global_position.lerp(goal, _ease(follow_speed, delta))

	# --- zoom ---
	var zt := Vector2(zoom_level, zoom_level)
	zoom = zoom.lerp(zt, _ease(zoom_speed, delta)) if zoom_speed > 0.0 else zt

	# --- bounds clamp (after zoom, using the actual view size) ---
	global_position = _clamp_to_bounds(global_position)

	# --- shake (via offset/rotation so it doesn't fight the follow position) ---
	_apply_shake(delta)


# --- Public API ---------------------------------------------------------------

## Adds camera trauma (0..1). Trauma shakes the camera and bleeds off on its own; stack
## calls for bigger hits. This is the shake hook other systems drive.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Snaps to the target with no smoothing this frame (scene start, teleport).
func snap_to_target() -> void:
	if target != null:
		global_position = _clamp_to_bounds(_follow_point())
		_look = Vector2.ZERO


## Focuses on [param node] until [method clear_focus]. The camera blends to it with the
## usual follow smoothing.
func focus_on(node: Node2D) -> void:
	_focus_node = node
	_focus_use_point = false
	_focus_time_left = INF


## Focuses on a fixed world [param point] until [method clear_focus].
func focus_on_point(point: Vector2) -> void:
	_focus_use_point = true
	_focus_point = point
	_focus_node = null
	_focus_time_left = INF


## Focuses on [param node] for [param seconds], then returns to the target (emits
## [signal focus_ended]).
func focus_for(node: Node2D, seconds: float) -> void:
	focus_on(node)
	_focus_time_left = seconds


## Returns focus to [member target] and emits [signal focus_ended].
func clear_focus() -> void:
	_clear_focus()


func is_focusing() -> bool:
	return _focus_node != null or _focus_use_point


# --- Internals ----------------------------------------------------------------

func _clear_focus() -> void:
	var was := is_focusing()
	_focus_node = null
	_focus_use_point = false
	_focus_time_left = 0.0
	if was:
		focus_ended.emit()


func _current_focus() -> Variant:
	if _focus_node != null and is_instance_valid(_focus_node):
		return _focus_node.global_position
	if _focus_use_point:
		return _focus_point
	return null


func _follow_point() -> Vector2:
	if target != null and is_instance_valid(target):
		var pos := target.global_position
		if _have_last:
			var dt := get_process_delta_time()
			if dt > 0.0:
				_target_vel = (pos - _last_target_pos) / dt
		_last_target_pos = pos
		_have_last = true
		return pos
	return global_position


## Keeps the camera still while the target stays within the deadzone box, then follows.
func _apply_deadzone(target_pos: Vector2, _delta: float) -> Vector2:
	if deadzone == Vector2.ZERO:
		return target_pos
	var cam := global_position
	var offset := target_pos - cam
	var goal := cam
	if offset.x > deadzone.x:
		goal.x = target_pos.x - deadzone.x
	elif offset.x < -deadzone.x:
		goal.x = target_pos.x + deadzone.x
	if offset.y > deadzone.y:
		goal.y = target_pos.y - deadzone.y
	elif offset.y < -deadzone.y:
		goal.y = target_pos.y + deadzone.y
	return goal


func _clamp_to_bounds(center: Vector2) -> Vector2:
	if bounds.size == Vector2.ZERO:
		return center
	var half := get_viewport_rect().size * 0.5 / zoom
	var min_c := bounds.position + half
	var max_c := bounds.end - half
	# If the view is bigger than the bounds on an axis, centre on the bounds.
	var out := center
	out.x = (bounds.position.x + bounds.end.x) * 0.5 if min_c.x > max_c.x else clampf(center.x, min_c.x, max_c.x)
	out.y = (bounds.position.y + bounds.end.y) * 0.5 if min_c.y > max_c.y else clampf(center.y, min_c.y, max_c.y)
	return out


func _apply_shake(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		rotation = 0.0
		return
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	var amt := _trauma * _trauma   # quadratic — small trauma barely moves, big trauma kicks
	offset = Vector2(
		_rng.randf_range(-1.0, 1.0) * shake_max_offset * amt,
		_rng.randf_range(-1.0, 1.0) * shake_max_offset * amt)
	rotation = _rng.randf_range(-1.0, 1.0) * shake_max_roll * amt


## Frame-rate-independent lerp weight for a given stiffness.
func _ease(speed: float, delta: float) -> float:
	return 1.0 - exp(-speed * delta)
