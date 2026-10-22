extends "res://Characters/StateMachine/CharacterState.gd"
## Terminal state after death. Accepts no input and starts no actions.
## Physics keeps running in the base character so knockback can finish.

func enter() -> void:
	context.play_death_animation()

func physics_update(_delta: float) -> void:
	pass
