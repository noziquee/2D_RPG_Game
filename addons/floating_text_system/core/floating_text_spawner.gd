class_name FloatingTextSpawner
extends Node2D
## A factory for floating combat text.
##
## Add one spawner to the scene (works both in a 2D world and under HUD Controls
## — positions are given in global canvas coordinates) and call the show_*
## methods. The labels clean themselves up.
##
## Presets: damage (with crits), damage taken, heal, mana,
## XP, gold, MISS/DODGE/BLOCK plus any text via [method show_text].
## Each preset can be overridden with a different animation variant
## ([enum FloatingLabel.Anim]: RISE / ARC / POP).

## Emitted after a label is created — a chance for sound, stats, etc.
signal text_spawned(label: FloatingLabel)

## Default number animation (RISE = the classic rise).
@export var default_anim := FloatingLabel.Anim.RISE
## Crit animation (POP = a scale pop in place).
@export var crit_anim := FloatingLabel.Anim.POP
## Font size of regular numbers.
@export var font_size := 19
## Font size of crits.
@export var crit_font_size := 28
## Label lifetime (seconds).
@export var lifetime := 0.9
## Random horizontal spread of the spawn point (px) — so series don't overlap.
@export var spread := 16.0


# --- Ready-made presets -----------------------------------------------------------

## Damage dealt. [param crit] enlarges, golds and pops with scale.
func show_damage(amount: float, pos: Vector2, crit := false) -> FloatingLabel:
	if crit:
		return show_text(_fmt(amount) + "!", pos, FloatingTextStyle.COLOR_CRIT,
				crit_anim, crit_font_size, 1.9)
	return show_text(_fmt(amount), pos, FloatingTextStyle.COLOR_DAMAGE,
			default_anim, font_size)


## Damage taken by the player (lighter pink, slightly smaller).
func show_damage_taken(amount: float, pos: Vector2) -> FloatingLabel:
	return show_text("-" + _fmt(amount), pos,
			FloatingTextStyle.COLOR_DAMAGE_TAKEN, default_anim, font_size - 2)


func show_heal(amount: float, pos: Vector2) -> FloatingLabel:
	return show_text("+" + _fmt(amount), pos, FloatingTextStyle.COLOR_HEAL,
			default_anim, font_size)


func show_mana(amount: float, pos: Vector2) -> FloatingLabel:
	return show_text("+" + _fmt(amount), pos, FloatingTextStyle.COLOR_MANA,
			default_anim, font_size)


func show_xp(amount: float, pos: Vector2) -> FloatingLabel:
	return show_text("+%s XP" % _fmt(amount), pos, FloatingTextStyle.COLOR_XP,
			default_anim, font_size - 2)


func show_gold(amount: float, pos: Vector2) -> FloatingLabel:
	return show_text("+%s" % _fmt(amount), pos, FloatingTextStyle.COLOR_GOLD,
			FloatingLabel.Anim.ARC, font_size)


func show_miss(pos: Vector2) -> FloatingLabel:
	return show_text("MISS", pos, FloatingTextStyle.COLOR_MISS,
			default_anim, font_size - 3)


func show_dodge(pos: Vector2) -> FloatingLabel:
	return show_text("DODGE", pos, FloatingTextStyle.COLOR_MISS,
			default_anim, font_size - 3)


func show_block(pos: Vector2) -> FloatingLabel:
	return show_text("BLOCK", pos, FloatingTextStyle.COLOR_MISS,
			default_anim, font_size - 3)


# --- Full control -------------------------------------------------------------

## Any label: text, color, animation variant, size, scale "punch".
## Returns the created [FloatingLabel] (you can still tune it).
func show_text(p_text: String, pos: Vector2, color := FloatingTextStyle.COLOR_TEXT,
		p_anim := FloatingLabel.Anim.RISE, p_font_size := 0,
		p_punch := 1.0) -> FloatingLabel:
	var label := FloatingLabel.new()
	label.text = p_text
	label.color = color
	label.anim = p_anim
	label.font_size = p_font_size if p_font_size > 0 else font_size
	label.lifetime = lifetime
	label.punch = p_punch
	add_child(label)
	label.global_position = pos + Vector2(randf_range(-spread, spread), 0)
	text_spawned.emit(label)
	return label


## Removes all active labels (e.g. when changing arena).
func clear_all() -> void:
	for child in get_children():
		if child is FloatingLabel:
			child.queue_free()


static func _fmt(amount: float) -> String:
	return str(roundi(amount))
