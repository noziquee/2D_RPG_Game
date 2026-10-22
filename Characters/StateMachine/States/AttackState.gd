extends "res://Characters/StateMachine/CharacterState.gd"
## Keeps the attack lifecycle authoritative while locomotion remains responsive.

func physics_update(_delta: float) -> void:
	var desired_animation: StringName = &"run" if context.movement_input != Vector2.ZERO else &"idle"
	context.play_locomotion_animation(desired_animation)

	if not context.is_attacking:
		var next_state: StringName = &"Move" if context.movement_input != Vector2.ZERO else &"Idle"
		state_machine.call("transition_to", next_state)
