class_name Interactor
extends Node2D
## Put this on the player. Each frame it finds the nearest available [Interactable] in
## range, marks it focused (so a prompt can appear), and — when the interact input is
## pressed — triggers it.
##
## [codeblock]
## var interactor := Interactor.new()
## $Player.add_child(interactor)
## interactor.focus_changed.connect(_on_focus)   # show / hide a prompt
## interactor.interacted.connect(_on_interacted)
## [/codeblock]
## The input action is resolved from [member input_action]; if that action isn't in the
## Input Map it falls back to [code]ui_accept[/code], so it works out of the box.

## Emitted when the focused interactable changes (may be null when nothing is in range).
signal focus_changed(interactable: Interactable)
## Emitted right after a successful interaction.
signal interacted(interactable: Interactable)

## How far (world units) the player can reach.
@export var range := 96.0
## Input action that triggers an interaction. Falls back to [code]ui_accept[/code] when
## it isn't defined in the Input Map.
@export var input_action: StringName = &"interact"
## Only face-forward interactables count (uses [member facing]); off = any direction.
@export var require_facing := false
## Facing direction used when [member require_facing] is on. Update it as the player turns.
@export var facing := Vector2.RIGHT
## Half-angle (radians) of the facing cone.
@export var facing_cone := 1.2

## The currently focused interactable, or null.
var current: Interactable = null

## Optional gate. When valid and it returns false, trigger() does nothing. The game uses it to
## refuse interaction while a lock is held (for example while a chest is opening).
var gate: Callable = Callable()


func _process(_delta: float) -> void:
	_update_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(_action()):
		if trigger():
			get_viewport().set_input_as_handled()


## Interacts with the focused interactable now (also callable from your own button).
## Returns true if something was triggered.
func trigger() -> bool:
	if gate.is_valid() and not bool(gate.call()):
		return false
	if current != null and current.is_available():
		var it := current
		it.interact(self)
		interacted.emit(it)
		return true
	return false


## The resolved action name (interact, or ui_accept fallback).
func _action() -> StringName:
	return input_action if InputMap.has_action(input_action) else &"ui_accept"


## A short label for the interact key ("E", "Space", "Enter", "Button 0"), for prompts.
func action_hint() -> String:
	for event in InputMap.action_get_events(_action()):
		if event is InputEventKey:
			var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(kc)
		if event is InputEventJoypadButton:
			return "Button %d" % event.button_index
	return "?"


func _update_focus() -> void:
	var best: Interactable = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var it := node as Interactable
		if it == null or not it.is_available():
			continue
		var to := it.global_position - global_position
		var reach := it.range_override if it.range_override > 0.0 else range
		var d := to.length()
		if d > reach:
			continue
		if require_facing and facing != Vector2.ZERO and d > 0.001:
			if facing.normalized().angle_to(to.normalized()) > facing_cone:
				continue
		if d < best_d:
			best_d = d
			best = it
	if best != current:
		if current != null and is_instance_valid(current):
			current.set_focused(false)
		current = best
		if current != null:
			current.set_focused(true)
		focus_changed.emit(current)
