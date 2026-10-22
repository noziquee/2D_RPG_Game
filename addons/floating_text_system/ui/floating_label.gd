class_name FloatingLabel
extends Node2D
## A single floating combat label. Created by [FloatingTextSpawner] —
## you usually don't use this class directly, but you can: set the fields
## and add it to the tree, the animation starts on its own, the node cleans up after itself.
##
## Animation variants:
## [br]• RISE — the classic upward rise with a fade,
## [br]• ARC — pops in a random direction and falls under gravity (like loot in an ARPG),
## [br]• POP — pops with scale in place and drifts gently (crits, headers).

enum Anim { RISE, ARC, POP }

var text := ""
var color := Color.WHITE
var font_size := 19
var outline_size := 5
var anim := Anim.RISE
## Lifetime in seconds.
var lifetime := 0.9
## Scale of the initial "punch" (1 = none; crits ~1.9).
var punch := 1.0
## Rise distance for RISE (px).
var rise_distance := 56.0
## Gravity for ARC (px/s²).
var gravity := 520.0
## Initial horizontal speed for ARC, randomized from ±this range (px/s).
var arc_side_speed := 80.0

var _label: Label
var _elapsed := 0.0
var _started := false
var _start_pos := Vector2.ZERO
var _velocity := Vector2.ZERO


func _ready() -> void:
	z_index = 200

	_label = Label.new()
	_label.text = text
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FloatingTextStyle.style_label(_label, font_size, color, outline_size)
	add_child(_label)
	_label.reset_size()
	_label.position = -_label.size / 2.0  # center the label on the spawn point

	if anim == Anim.ARC:
		_velocity = Vector2(randf_range(-arc_side_speed, arc_side_speed),
				-randf_range(160.0, 220.0))

	if punch > 1.0:
		scale = Vector2.ONE * punch
		rotation = deg_to_rad(randf_range(-6.0, 6.0))
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ONE, 0.22) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _process(delta: float) -> void:
	# we grab the start position on the first frame — the spawner sets
	# global_position only AFTER add_child (i.e. after _ready)
	if not _started:
		_started = true
		_start_pos = position
	_elapsed += delta
	var t := _elapsed / lifetime
	if t >= 1.0:
		queue_free()
		return

	match anim:
		Anim.RISE:
			var eased := 1.0 - pow(1.0 - t, 2.2)
			position = _start_pos + Vector2(0, -rise_distance * eased)
		Anim.ARC:
			_velocity.y += gravity * delta
			position += _velocity * delta
		Anim.POP:
			position = _start_pos + Vector2(0, -14.0 * t)

	# fade out in the last part of the lifetime
	const FADE_START := 0.55
	if t > FADE_START:
		modulate.a = 1.0 - (t - FADE_START) / (1.0 - FADE_START)
