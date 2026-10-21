extends RefCounted
## Shared runtime data for a 2D character and its states/components.

var character: CharacterBody2D
var animated_sprite: AnimatedSprite2D
var weapon_pivot: Node2D
var movement_input: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var aim_direction: Vector2 = Vector2.RIGHT
var attack_direction: Vector2 = Vector2.RIGHT
var is_attacking: bool = false
var is_dashing: bool = false
var dash_velocity: Vector2 = Vector2.ZERO

func _init(owner: CharacterBody2D) -> void:
	character = owner
	animated_sprite = owner.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
