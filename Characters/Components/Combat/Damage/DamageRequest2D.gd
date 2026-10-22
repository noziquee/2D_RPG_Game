extends RefCounted
class_name DamageRequest2D
## Describes one hit before it is resolved. Built by the attacker, read by DamageService2D.

enum DamageType { PHYSICAL, FIRE, ICE, LIGHTNING, POISON, TRUE_DAMAGE }

#==============================================================================
# Source
#==============================================================================
## Who dealt the damage; null for the environment or a bare take_damage() call.
var source: Node

#==============================================================================
# Damage
#==============================================================================
var base_damage: int = 0
var damage_type: DamageType = DamageType.PHYSICAL
var critical: bool = false
var critical_multiplier: float = 1.5

#==============================================================================
# Hit Data
#==============================================================================
var hit_position: Vector2 = Vector2.ZERO
## Direction the hit travelled; knockback pushes the target along it.
var direction: Vector2 = Vector2.ZERO
var tags: Array[StringName] = []

#==============================================================================
# Knockback
#==============================================================================
## Initial knockback speed in pixels per second along direction. 0 means none.
## Applied by Character2D through MovementComponent2D, never by the damage service.
var knockback_speed: float = 0.0

#==============================================================================
# Factory
#==============================================================================
static func create(attacker: Node, amount: int) -> DamageRequest2D:
	var request := DamageRequest2D.new()
	request.source = attacker
	request.base_damage = amount
	return request
