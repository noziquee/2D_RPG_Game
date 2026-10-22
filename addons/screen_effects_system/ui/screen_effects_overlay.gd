class_name ScreenEffectsOverlay
extends CanvasLayer
## A full-screen effects layer: flash, vignette and fade. Created (lazily) by
## [ScreenEffects] — you usually don't use this class directly.
##
## It sits on a high layer (100), so it covers the UI too; it doesn't catch the mouse.
##
## [b]Runs while the tree is paused[/b] ([constant Node.PROCESS_MODE_ALWAYS]). This is
## not a style choice: fades are driven by tweens bound to this node, so with the default
## process mode [code]await effects.fade_out()[/code] from a pause menu would never
## finish and the screen would stay black for good. These effects are presentation, not
## gameplay — they must keep running exactly when the game does not.

const VIGNETTE_SHADER := "
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
void fragment() {
	float dist = length(UV - vec2(0.5)) * 1.4142;
	float edge = smoothstep(0.45, 1.05, dist);
	COLOR = vec4(tint.rgb, edge * intensity);
}"

var _flash_rect: ColorRect
var _vignette_rect: ColorRect
var _vignette_material: ShaderMaterial
var _fade_rect: ColorRect
var _flash_tween: Tween
var _vignette_tween: Tween
var _fade_tween: Tween


func _init() -> void:
	layer = 100
	# See the class docs: without this, a fade started while paused never finishes.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_vignette_rect = ColorRect.new()
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = shader
	_vignette_rect.material = _vignette_material
	root.add_child(_vignette_rect)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	root.add_child(_flash_rect)

	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color(0, 0, 0, 0)
	root.add_child(_fade_rect)


## Screen flash: full strength immediately, then a fade-out.
func flash(color: Color, max_alpha: float, duration: float) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_rect.color = Color(color, max_alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, duration) \
			.set_ease(Tween.EASE_OUT)


## Sets a steady vignette (0 = none; e.g. 0.4 as a steady dungeon mood).
func set_vignette(intensity: float, tint := Color.BLACK) -> void:
	if _vignette_tween != null:
		_vignette_tween.kill()
	_vignette_material.set_shader_parameter("intensity", clampf(intensity, 0.0, 1.0))
	_vignette_material.set_shader_parameter("tint", tint)


## Vignette pulse: a quick ramp-up and a slow return to [param settle]
## (e.g. a red pulse at low HP).
func pulse_vignette(intensity: float, tint: Color, duration: float,
		settle := 0.0) -> void:
	if _vignette_tween != null:
		_vignette_tween.kill()
	_vignette_material.set_shader_parameter("tint", tint)
	_vignette_material.set_shader_parameter("intensity", clampf(intensity, 0.0, 1.0))
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_vignette_material,
			"shader_parameter/intensity", clampf(settle, 0.0, 1.0), duration) \
			.set_ease(Tween.EASE_OUT)


## Smooth fade to/from the given alpha. Returns the tween (for await).
func fade_to(alpha: float, duration: float, color := Color.BLACK) -> Tween:
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_rect.color = Color(color, _fade_rect.color.a)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", clampf(alpha, 0.0, 1.0),
			duration)
	return _fade_tween


## Sets the fade instantly (e.g. starting a scene from black).
func set_fade(alpha: float, color := Color.BLACK) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_rect.color = Color(color, clampf(alpha, 0.0, 1.0))
