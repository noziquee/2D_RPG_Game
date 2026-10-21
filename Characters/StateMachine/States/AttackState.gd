extends "res://Characters/StateMachine/CharacterState.gd"
## Keeps the attack lifecycle authoritative while locomotion remains responsive.

func physics_update(_delta: float) -> void:
	if context.animated_sprite != null:
		var desired_animation: StringName = &"run" if context.movement_input != Vector2.ZERO else &"idle"
		if (
			context.animated_sprite.sprite_frames.has_animation(desired_animation)
			and context.animated_sprite.animation != desired_animation
		):
			context.animated_sprite.play(desired_animation)

	if not context.is_attacking:
		var next_state: StringName = &"Move" if context.movement_input != Vector2.ZERO else &"Idle"
		state_machine.call("transition_to", next_state)
