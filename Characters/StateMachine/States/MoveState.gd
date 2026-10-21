extends "res://Characters/StateMachine/CharacterState.gd"

func enter() -> void:
	if context.animated_sprite != null and context.animated_sprite.sprite_frames.has_animation("run"):
		context.animated_sprite.play("run")

func physics_update(_delta: float) -> void:
	if context.movement_input == Vector2.ZERO:
		state_machine.call("transition_to", &"Idle")
