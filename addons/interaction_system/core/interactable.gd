class_name Interactable
extends Node2D
## Something the player can interact with — a door, chest, lever, NPC.
##
## Drop it in the world, give it a [member prompt] ("Open", "Talk", "Loot"), and connect
## [signal interacted]. An [Interactor] on the player finds the nearest available one and
## triggers it; this node stays dumb — it just announces that it was used.

## Emitted when an [Interactor] interacts with this. [param interactor] is the [Interactor].
signal interacted(interactor)
## Emitted when this becomes / stops being the interactor's focused target (for a glow).
signal focus_changed(focused: bool)

## Group every interactable joins so an [Interactor] can find them.
const GROUP := &"interactables"

## Verb shown in the prompt ("Open", "Talk", "Pick up").
@export var prompt := "Interact"
## Optional stable id, so one handler can tell interactables apart.
@export var id: StringName = &""
## Uncheck to disable without removing it (a locked door). Disabled ones are never focused.
@export var enabled := true
## Interact only once, then go unavailable (a one-time pickup).
@export var one_shot := false
## Per-node range override (world units). 0 uses the interactor's range.
@export var range_override := 0.0
## Extra world-space height the prompt floats above this node's origin.
@export var prompt_offset := Vector2(0, -46)

var _used := false
var _focused := false


func _ready() -> void:
	add_to_group(GROUP)


## True when this can be interacted with right now.
func is_available() -> bool:
	return enabled and not (one_shot and _used)


## Triggers the interaction (called by the [Interactor]). Marks a one-shot as used and
## emits [signal interacted]. No-op when unavailable.
func interact(interactor) -> void:
	if not is_available():
		return
	if one_shot:
		_used = true
	interacted.emit(interactor)


## Called by the [Interactor] as focus moves on and off. Emits [signal focus_changed].
func set_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	focus_changed.emit(value)


func is_focused() -> bool:
	return _focused


## The world position the prompt should float at.
func prompt_position() -> Vector2:
	return global_position + prompt_offset
