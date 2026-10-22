extends Node2D
class_name CombatFeedback
## Turns the shared damage event into feedback: floating numbers, camera shake, flashes,
## and hit-stop. It owns one ScreenEffects and one FloatingTextSpawner from the adopted
## add-ons, and listens only to DamageService2D.damage_resolved. Combat code never calls it.
##
## Shake goes through CameraDirector.add_trauma(). The director rewrites the camera's offset
## every frame, so screen effects must not shake the camera itself (it would fight the
## director). Flashes and hit-stop come from ScreenEffects as before.

## Where numbers appear, relative to the target's origin (world units).
const HEAD_OFFSET: Vector2 = Vector2(0.0, -16.0)
const PLAYER_FLASH_COLOR: Color = Color(1.0, 0.25, 0.25)

@export_range(0.0, 1.0, 0.05) var enemy_hit_shake: float = 0.3
@export_range(0.0, 1.0, 0.05) var player_hit_shake: float = 0.7
## Strength passed to ScreenEffects.impact() for crits and kills; 0.4+ adds hit-stop.
@export_range(0.0, 1.0, 0.05) var crit_impact: float = 0.6
@export_range(0.0, 1.0, 0.05) var kill_impact: float = 0.8

var effects: ScreenEffects
var spawner: FloatingTextSpawner

func _ready() -> void:
	spawner = FloatingTextSpawner.new()
	add_child(spawner)
	effects = ScreenEffects.new()
	add_child(effects)
	DamageService2D.get_default().damage_resolved.connect(_on_damage_resolved)

func _on_damage_resolved(result: DamageResult2D) -> void:
	var target := result.target as Node2D
	if target == null or not is_instance_valid(target):
		return
	var head := target.global_position + HEAD_OFFSET

	if target.is_in_group(Groups2D.PLAYER):
		spawner.show_damage_taken(result.final_damage, head)
		_shake(player_hit_shake)
		effects.flash(PLAYER_FLASH_COLOR, 0.35, 0.2)
		return

	spawner.show_damage(result.final_damage, head, result.critical)
	if result.killed:
		_impact(kill_impact)
	elif result.critical:
		_impact(crit_impact)
	else:
		_shake(enemy_hit_shake)

## Adds trauma to the active camera if it is a CameraDirector. Without one, nothing shakes.
func _shake(amount: float) -> void:
	var camera := get_viewport().get_camera_2d() as CameraDirector
	if camera != null:
		camera.add_trauma(amount)

## Same feel as ScreenEffects.impact(), but the shake goes through the director.
func _impact(strength: float) -> void:
	_shake(strength)
	effects.flash(Color.WHITE, 0.15 + 0.3 * strength, 0.12 + 0.1 * strength)
	if strength >= 0.4:
		effects.hitstop(0.04 + 0.07 * strength)
