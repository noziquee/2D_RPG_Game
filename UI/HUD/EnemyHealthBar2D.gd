extends CanvasLayer
## Floating enemy health bar. It lives on its own CanvasLayer, so it is drawn at a fixed
## screen size and the player camera's 5x zoom does not enlarge it. Each frame it projects
## the enemy's world position through the viewport canvas transform, the same approach the
## add-on's InteractionPromptUI uses. It listens only to health_changed and died.

const HealthStyle = preload("res://UI/HUD/HealthBarStyle.gd")

## Bottom-centre of the bar, in world units above the enemy's origin.
const HEAD_OFFSET: Vector2 = Vector2(0.0, -10.0)

@onready var _bar: Control = $Bar
@onready var card: PanelContainer = $Bar/Card
@onready var health_label: Label = $Bar/Card/Padding/BarStack/HealthLabel
@onready var progress_bar: ProgressBar = $Bar/Card/Padding/BarStack/ProgressBar
@onready var damage_bar: ProgressBar = $Bar/Card/Padding/BarStack/DamageBar
@onready var damage_timer: Timer = $DamageTimer

var _enemy: Node
var _last_health: float = 0.0
var _maximum_health: float = 1.0
var _displayed_health: float = 0.0
var _main_tween: Tween
var _damage_tween: Tween
var _counter_tween: Tween
var _impact_tween: Tween
var _intro_tween: Tween
var _critical_tween: Tween
var _dead: bool = false

func _ready() -> void:
	_bar.visible = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_ui()
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	call_deferred("_bind_to_enemy")

func _process(_delta: float) -> void:
	if not _bar.visible:
		return
	var enemy := _enemy as Node2D
	if enemy == null:
		return
	var screen := get_viewport().get_canvas_transform() * (enemy.global_position + HEAD_OFFSET)
	var bar_size := _bar.custom_minimum_size
	_bar.position = screen - Vector2(bar_size.x * 0.5, bar_size.y)

func _style_ui() -> void:
	card.add_theme_stylebox_override("panel", HealthStyle.panel_style(true))
	HealthStyle.style_label(health_label, 8, HealthStyle.COLOR_TEXT, 700, 2)
	damage_bar.add_theme_stylebox_override("background", HealthStyle.bar_background(true))
	damage_bar.add_theme_stylebox_override("fill", HealthStyle.damage_fill(true))
	progress_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	progress_bar.add_theme_stylebox_override("fill", HealthStyle.health_fill(HealthStyle.COLOR_HEALTH_HIGH, true))

func _bind_to_enemy() -> void:
	_enemy = get_parent()
	if _enemy == null or not _enemy.has_signal("health_changed"):
		push_warning("EnemyHealthBar2D: parent has no health_changed signal.")
		return

	_maximum_health = maxf(float(_enemy.get("max_health")), 1.0)
	var current := clampf(float(_enemy.get("health")), 0.0, _maximum_health)
	_last_health = current
	_displayed_health = current
	_set_values(current, _maximum_health)

	var health_callable := Callable(self, "_on_health_changed")
	if not _enemy.is_connected("health_changed", health_callable):
		_enemy.connect("health_changed", health_callable)
	var died_callable := Callable(self, "_on_died")
	if _enemy.has_signal("died") and not _enemy.is_connected("died", died_callable):
		_enemy.connect("died", died_callable)

func _on_health_changed(current_health: int, maximum_health: int) -> void:
	if _dead:
		return
	var current := clampf(float(current_health), 0.0, maxf(float(maximum_health), 1.0))
	var maximum := maxf(float(maximum_health), 1.0)
	var previous := _last_health
	_maximum_health = maximum
	progress_bar.max_value = maximum
	damage_bar.max_value = maximum
	_update_health_color(current / maximum)
	_animate_counter(current)
	_kill_tween(_main_tween)
	_main_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_main_tween.tween_property(progress_bar, "value", current, 0.16 if current < previous else 0.22)

	if current < previous:
		damage_bar.value = clampf(maxf(damage_bar.value, previous), 0.0, maximum)
		damage_timer.start()
		_show_and_pulse()
		_kill_tween(_damage_tween)
	elif current > previous:
		damage_timer.stop()
		_kill_tween(_damage_tween)
		_damage_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_damage_tween.tween_property(damage_bar, "value", current, 0.22)
	else:
		damage_bar.value = minf(damage_bar.value, maximum)
	_last_health = current

func _animate_counter(target: float) -> void:
	_kill_tween(_counter_tween)
	_counter_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_counter_tween.tween_method(_set_counter_value, _displayed_health, target, 0.18)

func _set_counter_value(value: float) -> void:
	_displayed_health = value
	health_label.text = "%d / %d" % [roundi(value), roundi(_maximum_health)]

func _update_health_color(ratio: float) -> void:
	var color: Color
	if ratio <= 0.25:
		color = HealthStyle.COLOR_HEALTH_LOW
	elif ratio <= 0.5:
		color = HealthStyle.COLOR_HEALTH_MID
	else:
		color = HealthStyle.COLOR_HEALTH_HIGH
	progress_bar.add_theme_stylebox_override("fill", HealthStyle.health_fill(color, true))
	_update_critical_pulse(ratio <= 0.25 and ratio > 0.0 and not _dead)

func _update_critical_pulse(enabled: bool) -> void:
	if enabled and (_critical_tween == null or not _critical_tween.is_running()):
		progress_bar.self_modulate = Color.WHITE
		_critical_tween = create_tween().set_loops()
		_critical_tween.tween_property(progress_bar, "self_modulate:a", 0.62, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_critical_tween.tween_property(progress_bar, "self_modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif not enabled:
		_kill_tween(_critical_tween)
		_critical_tween = null
		progress_bar.self_modulate = Color.WHITE

func _show_and_pulse() -> void:
	if not _bar.visible:
		_bar.visible = true
		_bar.modulate.a = 0.0
		card.scale = Vector2(0.86, 0.86)
		card.pivot_offset = card.size * 0.5
		_kill_tween(_intro_tween)
		_intro_tween = create_tween().set_parallel(true)
		_intro_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_intro_tween.tween_property(_bar, "modulate:a", 1.0, 0.20)
		_intro_tween.tween_property(card, "scale", Vector2.ONE, 0.24)
	_kill_tween(_impact_tween)
	card.pivot_offset = card.size * 0.5
	card.self_modulate = Color(1.0, 0.82, 0.82, 1.0)
	_impact_tween = create_tween().set_parallel(true)
	_impact_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_impact_tween.tween_property(card, "scale", Vector2(1.06, 1.14), 0.08)
	_impact_tween.tween_property(card, "self_modulate", Color.WHITE, 0.18)
	_impact_tween.chain().tween_property(card, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_damage_timer_timeout() -> void:
	var enemy := _enemy as Node
	if not is_instance_valid(enemy) or _dead:
		return
	_kill_tween(_damage_tween)
	_damage_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_damage_tween.tween_property(damage_bar, "value", float(enemy.get("health")), 0.34)

func _on_died() -> void:
	_dead = true
	damage_timer.stop()
	_kill_tween(_main_tween)
	_kill_tween(_damage_tween)
	_kill_tween(_counter_tween)
	_kill_tween(_impact_tween)
	_kill_tween(_intro_tween)
	_kill_tween(_critical_tween)
	_critical_tween = null
	progress_bar.self_modulate = Color.WHITE
	_bar.visible = false

func _set_values(current: float, maximum: float) -> void:
	progress_bar.min_value = 0.0
	progress_bar.max_value = maximum
	progress_bar.value = current
	damage_bar.min_value = 0.0
	damage_bar.max_value = maximum
	damage_bar.value = current
	health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]
	_update_health_color(current / maximum if maximum > 0.0 else 0.0)

func _kill_tween(tween: Tween) -> void:
	if is_instance_valid(tween) and tween.is_running():
		tween.kill()
