
extends CharacterBody2D

@export var move_speed: float = 200.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	animated_sprite.play("idle")


func _physics_process(_delta: float) -> void:
	# Read the player's movement input.
	var direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
        "move_down"
	)

	# Apply normalized movement for consistent diagonal speed.
	velocity = direction * move_speed

	# Flip the sprite only when moving horizontally.
	if direction.x < 0.0:
		animated_sprite.flip_h = true
	elif direction.x > 0.0:
		animated_sprite.flip_h = false

	# Switch between running and idle animations.
	if direction != Vector2.ZERO:
		if animated_sprite.animation != "run":
			animated_sprite.play("run")
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

	# Move the character and handle collisions.
	move_and_slide()
