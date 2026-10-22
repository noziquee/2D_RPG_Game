extends "res://Characters/Core/Character2D.gd"
class_name BasicEnemy2D
## Basic damageable enemy. AI supplies intent; shared Character2D components move and attack.
## The take_damage and death clips are authored on AnimatedSprite2D and its AnimationPlayer.

## Used only if the death clip is missing or loops, so the enemy is still removed.
const DEATH_FALLBACK_SECONDS: float = 1.0

@export_range(1, 1000, 1) var max_health: int = 3

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _damage_animation_player: AnimationPlayer = $AnimatedSprite2D/AnimationPlayer
@onready var _weapon: Sprite2D = $AnimatedSprite2D/Weapon
@onready var _ai_controller: EnemyAIController2D = $EnemyAIController2D

func _ready() -> void:
	super._ready()
	add_to_group(Groups2D.ENEMY)
	add_to_group(Groups2D.DAMAGEABLE)
	_ai_controller.initialize(self)
	if _animated_sprite.sprite_frames != null and _animated_sprite.sprite_frames.has_animation(&"idle"):
		_animated_sprite.play(&"idle")

func _get_hit_reaction_player() -> AnimationPlayer:
	return _damage_animation_player

func _get_max_health() -> int:
	return maxi(max_health, 1)

func _physics_process(delta: float) -> void:
	# AI steers only a living enemy. The base still runs movement so knockback can finish.
	if is_alive():
		_ai_controller.physics_update(delta)
	super._physics_process(delta)

func _get_movement_input() -> Vector2:
	return _ai_controller.get_movement_intent()

func _get_aim_direction() -> Vector2:
	return _ai_controller.get_aim_direction()

func _get_attack_requested() -> bool:
	return _ai_controller.consume_attack_request()

func _get_attack_direction() -> Vector2:
	return _ai_controller.get_attack_direction()

func _get_dash_requested() -> bool:
	return false

func _on_death() -> void:
	# The Dead state has already started the authored "death" clip on AnimatedSprite2D.
	# Stop blocking others, hide the knife, and remove the enemy when the clip ends.
	set_deferred("collision_layer", 0)
	_weapon.visible = false
	var frames := _animated_sprite.sprite_frames
	if frames != null and frames.has_animation(&"death") and not frames.get_animation_loop(&"death"):
		_animated_sprite.animation_finished.connect(_on_sprite_animation_finished)
		return
	push_warning("BasicEnemy2D '%s': the death animation is missing or loops, so it is removed after %.1f s." % [name, DEATH_FALLBACK_SECONDS])
	if is_inside_tree():
		get_tree().create_timer(DEATH_FALLBACK_SECONDS).timeout.connect(queue_free)

func _on_sprite_animation_finished() -> void:
	if _animated_sprite.animation == &"death":
		queue_free()
