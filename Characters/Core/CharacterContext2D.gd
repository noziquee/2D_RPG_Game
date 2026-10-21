extends RefCounted
## Shared runtime data for a 2D character and its states/components.

var character: CharacterBody2D
var animated_sprite: AnimatedSprite2D
var weapon_pivot: Node2D
var weapon_animation_player: AnimationPlayer
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

	var weapon := owner.get_node_or_null("WeaponFlipPivot/Sword") as Sprite2D
	var pivot := owner.get_node_or_null("WeaponFlipPivot") as Node2D
	if weapon == null:
		weapon = owner.get_node_or_null("Sword") as Sprite2D

	if weapon == null:
		return

	if pivot == null:
		pivot = Node2D.new()
		pivot.name = "WeaponFlipPivot"
		owner.add_child(pivot)
		owner.move_child(pivot, weapon.get_index())
		weapon.reparent(pivot, false)

	weapon_pivot = pivot
	weapon_animation_player = weapon.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if weapon_animation_player == null:
		return

	# The weapon's method track must call the Character2D root after the
	# Sword sprite is placed under WeaponFlipPivot.
	for animation_name in weapon_animation_player.get_animation_list():
		var animation := weapon_animation_player.get_animation(animation_name)
		for track_index in range(animation.get_track_count()):
			if animation.track_get_type(track_index) == Animation.TYPE_METHOD:
				animation.track_set_path(track_index, NodePath("../.."))
