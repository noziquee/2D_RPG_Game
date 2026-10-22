extends Node2D
class_name DeathEffect2D
## One-shot explosion played where a character dies. Builds its frames in code from
## the 4-frame 16x16 sheet, plays once, emits finished, and frees itself.

const SHEET: Texture2D = preload("res://Assets/effects (new)/enemy_afterdead_explosion_anim_spritesheet.png")
const FRAME_SIZE: Vector2i = Vector2i(16, 16)
const FRAME_COUNT: int = 4
const FRAMES_PER_SECOND: float = 12.0

signal finished

var _sprite: AnimatedSprite2D

## Adds an effect to host at the given global position and returns it.
static func spawn(host: Node, at_position: Vector2) -> DeathEffect2D:
	if host == null:
		return null
	var effect := DeathEffect2D.new()
	host.add_child(effect)
	effect.global_position = at_position
	return effect

func _ready() -> void:
	z_index = 5
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"explode")
	frames.set_animation_speed(&"explode", FRAMES_PER_SECOND)
	frames.set_animation_loop(&"explode", false)
	for index in range(FRAME_COUNT):
		var frame := AtlasTexture.new()
		frame.atlas = SHEET
		frame.region = Rect2(index * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame(&"explode", frame)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"explode")

func _on_animation_finished() -> void:
	finished.emit()
	queue_free()
