extends Node
class_name BaseComponent2D
## Shared base for character components. Holds the shared context and whether the
## component is initialized. Each subclass keeps its own behavior.

const ContextScript = preload("res://Characters/Core/CharacterContext2D.gd")

var context: ContextScript
var _initialized: bool = false

func is_initialized() -> bool:
	return _initialized

## Called once per physics frame by Character2D. Subclasses override.
func physics_update(_delta: float) -> void:
	pass
