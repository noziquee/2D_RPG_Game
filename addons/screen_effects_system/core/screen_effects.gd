class_name ScreenEffects
extends Node
## Screen effects ("juice") — one node, a full set of variants:
##
## [br]• [method shake] — camera shake (trauma model: hit series
##   accumulate, amplitude decays quadratically),
## [br]• [method flash] — screen flash (white hit, red damage…),
## [br]• [method hitstop] — freezing time for a fraction of a second on a hit,
## [br]• [method slow_motion] — a longer slowdown of time,
## [br]• [method vignette_pulse] / [method set_vignette] — vignette (pulse of pain,
##   steady mood),
## [br]• [method zoom_punch] — a jolt of camera zoom,
## [br]• [method fade_out] / [method fade_in] / [method transition_to_scene] —
##   fades and transitions between scenes,
## [br]• [method impact] — a ready-made combo: shake + flash + hitstop in one line.
##
## Shake and zoom act on [member camera] (Camera2D, via offset — it doesn't
## ruin the camera position). In scenes without a camera set [member shake_target]
## (any CanvasItem, e.g. the HUD body) — it will be moved instead.
## The overlay (flash/vignette/fade) creates itself on first use.

## Emitted after fade_out / fade_in finishes.
signal faded_out()
signal faded_in()

## Camera for shake and zoom punch (optional).
@export var camera: Camera2D
## Shake target when there is no camera (e.g. the scene's main Control).
@export var shake_target: CanvasItem
## Maximum shake offset (px) at full trauma.
@export var max_shake_offset := Vector2(16, 12)
## Maximum camera rotation at full trauma (radians; camera only).
@export var max_shake_rotation := 0.035
## How much trauma decays per second.
@export var shake_decay := 1.5
## Start the scene from black and brighten — for transitions between scenes
## ([method transition_to_scene] on the other side).
@export var fade_in_on_ready := false
@export var fade_in_duration := 0.4

var _trauma := 0.0
var _overlay: ScreenEffectsOverlay
var _base_pos := Vector2.ZERO
var _shake_active := false
var _timescale_token := 0
## Time scale to restore once the last slowdown ends. Captured when a slowdown starts,
## so a game running at a non-default scale (or a pause menu) is returned to its own value.
var _saved_time_scale := 1.0
var _timescale_active := false
var _base_zoom := Vector2.ONE
var _zoom_tween: Tween


func _ready() -> void:
	if fade_in_on_ready:
		_get_overlay().set_fade(1.0)
		fade_in(fade_in_duration)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		if _shake_active:
			_end_shake()
		return
	_trauma = maxf(0.0, _trauma - shake_decay * delta)
	var amount := _trauma * _trauma  # squared — small traumas barely tremble
	var offset := Vector2(
			randf_range(-1.0, 1.0) * max_shake_offset.x * amount,
			randf_range(-1.0, 1.0) * max_shake_offset.y * amount)
	if camera != null:
		_shake_active = true
		camera.offset = offset
		camera.rotation = randf_range(-1.0, 1.0) * max_shake_rotation * amount
	elif shake_target != null:
		if not _shake_active:
			_base_pos = shake_target.position
			_shake_active = true
		shake_target.position = _base_pos + offset


# --- Shake -------------------------------------------------------------------

## Adds trauma (0..1). Shakes accumulate: a series of hits = a stronger
## shake. 0.2 = a nudge, 0.5 = a solid blow, 1.0 = explosion.
func shake(amount := 0.5) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _end_shake() -> void:
	_shake_active = false
	if camera != null:
		camera.offset = Vector2.ZERO
		camera.rotation = 0.0
	elif shake_target != null:
		shake_target.position = _base_pos


# --- Flash / vignette -------------------------------------------------------------

## Screen flash (white hit by default). Red = damage, green = healing.
func flash(color := Color.WHITE, max_alpha := 0.4, duration := 0.18) -> void:
	_get_overlay().flash(color, max_alpha, duration)


## Vignette pulse, e.g. red when taking damage.
## [param settle] > 0 leaves the vignette on permanently (e.g. a low-HP screen).
func vignette_pulse(intensity := 0.65, tint := Color(0.55, 0.05, 0.05),
		duration := 0.5, settle := 0.0) -> void:
	_get_overlay().pulse_vignette(intensity, tint, duration, settle)


## Steady vignette (0 = off).
func set_vignette(intensity: float, tint := Color.BLACK) -> void:
	_get_overlay().set_vignette(intensity, tint)


# --- Time ----------------------------------------------------------------------

## Hit-stop: freezing time for a fraction of a second (the blow "lands").
func hitstop(duration := 0.08, time_scale := 0.05) -> void:
	_run_timescale(time_scale, duration)


## A longer slowdown of time (finisher, last blow, bullet-time dodge).
func slow_motion(time_scale := 0.3, duration := 0.7) -> void:
	_run_timescale(time_scale, duration)


func _run_timescale(time_scale: float, duration: float) -> void:
	var token := _begin_timescale(time_scale)
	# the timer ignores time_scale — otherwise hitstop would last forever
	await get_tree().create_timer(duration, true, false, true).timeout
	_finish_timescale(token)

## Applies a time scale and returns a token. The first slowdown records the current scale.
func _begin_timescale(time_scale: float) -> int:
	if not _timescale_active:
		_saved_time_scale = Engine.time_scale
		_timescale_active = true
	_timescale_token += 1
	Engine.time_scale = time_scale
	return _timescale_token

## Restores the saved scale only when this token is the latest slowdown, so an older
## hitstop finishing early does not cut a newer one short.
func _finish_timescale(token: int) -> void:
	if token != _timescale_token or not _timescale_active:
		return
	Engine.time_scale = _saved_time_scale
	_timescale_active = false

func _exit_tree() -> void:
	# A scene change during a hitstop must not leave the game in slow motion.
	if _timescale_active:
		Engine.time_scale = _saved_time_scale
		_timescale_active = false


# --- Zoom ----------------------------------------------------------------------

## A jolt of camera zoom (requires [member camera]).
func zoom_punch(strength := 0.07, duration := 0.3) -> void:
	if camera == null:
		push_warning("ScreenEffects.zoom_punch: no camera assigned.")
		return
	if _zoom_tween != null and _zoom_tween.is_running():
		_zoom_tween.kill()
		camera.zoom = _base_zoom
	_base_zoom = camera.zoom
	camera.zoom = _base_zoom * (1.0 + strength)
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(camera, "zoom", _base_zoom, duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


# --- Fade / scene transitions --------------------------------------------------------

## Fade to full black (or another color). You can await it:
## `await effects.fade_out()`.
func fade_out(duration := 0.4, color := Color.BLACK) -> void:
	await _get_overlay().fade_to(1.0, duration, color).finished
	faded_out.emit()


## Brighten back in.
func fade_in(duration := 0.4) -> void:
	await _get_overlay().fade_to(0.0, duration).finished
	faded_in.emit()


## Fades the screen out and changes the scene. The target scene brightens itself
## if its ScreenEffects has [member fade_in_on_ready] enabled.
func transition_to_scene(scene_path: String, duration := 0.4) -> void:
	await fade_out(duration)
	get_tree().change_scene_to_file(scene_path)


# --- Combo ----------------------------------------------------------------------

## A ready-made "blow": shake + white flash + (for strong ones) hitstop.
## [param strength] 0..1: 0.2 = a regular hit, 0.6 = a crit, 1.0 = a boss weakens.
func impact(strength := 0.5) -> void:
	shake(strength)
	flash(Color.WHITE, 0.15 + 0.3 * strength, 0.12 + 0.1 * strength)
	if strength >= 0.4:
		hitstop(0.04 + 0.07 * strength)


# --- Internal -------------------------------------------------------------------

func _get_overlay() -> ScreenEffectsOverlay:
	if _overlay == null:
		_overlay = ScreenEffectsOverlay.new()
		add_child(_overlay)
	return _overlay
