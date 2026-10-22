extends "res://Characters/StateMachine/CharacterState.gd"

func enter() -> void:
	context.play_locomotion_animation(&"idle")

func physics_update(_delta: float) -> void:
	if context.movement_input != Vector2.ZERO:
		state_machine.call("transition_to", &"Move")
