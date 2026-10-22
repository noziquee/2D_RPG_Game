extends "res://Characters/StateMachine/CharacterState.gd"
## Visual state while the dash component temporarily overrides normal movement.

func enter() -> void:
	context.play_locomotion_animation(&"run")

func physics_update(_delta: float) -> void:
	if not context.is_dashing:
		var next_state: StringName = &"Move" if context.movement_input != Vector2.ZERO else &"Idle"
		state_machine.call("transition_to", next_state)
