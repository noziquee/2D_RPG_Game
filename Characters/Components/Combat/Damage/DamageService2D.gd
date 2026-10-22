extends RefCounted
class_name DamageService2D
## Resolves a DamageRequest2D against a target: validation, mitigation, application, event.
## A reduced version of the RPG project's DamagePipeline. Armor, buffs, and stagger
## become new steps between validation and application in later phases.

#==============================================================================
# Signals
#==============================================================================
## Emitted after every hit that actually removed health.
signal damage_resolved(result: DamageResult2D)

#==============================================================================
# Shared Instance
#==============================================================================
static var _default: DamageService2D = null

static func get_default() -> DamageService2D:
	if _default == null:
		_default = DamageService2D.new()
	return _default

#==============================================================================
# Public API
#==============================================================================
## Resolves one hit. Never returns null; check result.applied and result.rejection.
func resolve(request: DamageRequest2D, target: Node) -> DamageResult2D:
	var result := DamageResult2D.new()
	result.request = request
	result.target = target

	if request == null:
		result.rejection = DamageResult2D.REJECT_NO_REQUEST
		return result
	result.incoming_damage = request.base_damage

	var health := _get_health(target, result)
	if health == null:
		return result
	var rejection := _validate(request, target, health)
	if rejection != DamageResult2D.REJECT_NONE:
		result.rejection = rejection
		return result

	result.critical = request.critical
	result.final_damage = _mitigate(request)
	_apply(result, health)

	if result.applied:
		damage_resolved.emit(result)
	return result

#==============================================================================
# Internal
#==============================================================================
func _get_health(target: Node, result: DamageResult2D) -> HealthComponent2D:
	if target == null or not is_instance_valid(target):
		result.rejection = DamageResult2D.REJECT_NO_TARGET
		return null
	if not target.has_method(&"get_health_component"):
		result.rejection = DamageResult2D.REJECT_NOT_DAMAGEABLE
		return null
	var health := target.call(&"get_health_component") as HealthComponent2D
	if health == null:
		result.rejection = DamageResult2D.REJECT_NOT_DAMAGEABLE
	return health

func _validate(request: DamageRequest2D, target: Node, health: HealthComponent2D) -> StringName:
	if health.is_dead:
		return DamageResult2D.REJECT_TARGET_DEAD
	if request.source != null:
		if request.source == target:
			return DamageResult2D.REJECT_SELF_DAMAGE
		if Groups2D.is_same_team(request.source, target):
			return DamageResult2D.REJECT_FRIENDLY_FIRE
	if health.is_invulnerable:
		return DamageResult2D.REJECT_INVULNERABLE
	if request.base_damage <= 0:
		return DamageResult2D.REJECT_NO_DAMAGE
	return DamageResult2D.REJECT_NONE

## Placeholder for armor and resistances: today it only applies the critical multiplier.
func _mitigate(request: DamageRequest2D) -> int:
	var amount := float(request.base_damage)
	if request.critical:
		amount *= request.critical_multiplier
	return maxi(roundi(amount), 0)

func _apply(result: DamageResult2D, health: HealthComponent2D) -> void:
	result.health_before = health.current_health
	var removed := health.damage(result.final_damage)
	result.final_damage = removed
	result.health_after = health.current_health
	result.applied = removed > 0
	result.killed = result.applied and health.is_dead
	if not result.applied:
		result.rejection = DamageResult2D.REJECT_NO_DAMAGE
