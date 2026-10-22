extends SCTestCase
## DamageService2D: validation, team rules, application, and the damage event.

class Target extends Node2D:
	var health := HealthComponent2D.new()
	func _init(maximum: int = 10) -> void:
		add_child(health)
		health.initialize(maximum)
	func get_health_component() -> HealthComponent2D:
		return health

func _target(maximum: int = 10, group: StringName = &"") -> Target:
	var target := Target.new(maximum)
	add_child(target)
	if group != &"":
		target.add_to_group(group)
	return target

func test_applies_damage_and_reports_result() -> void:
	var service := DamageService2D.new()
	var target := _target(10)
	var result := service.resolve(DamageRequest2D.create(null, 4), target)
	ok(result.applied, "applied")
	eq(result.final_damage, 4, "final damage")
	eq(result.health_before, 10, "before")
	eq(result.health_after, 6, "after")
	not_ok(result.killed, "not killed")
	eq(result.rejection, DamageResult2D.REJECT_NONE, "no rejection")
	eq(target.health.current_health, 6, "target health")

func test_kill_is_reported_once() -> void:
	var service := DamageService2D.new()
	var target := _target(3)
	var first := service.resolve(DamageRequest2D.create(null, 10), target)
	ok(first.killed, "killed")
	eq(first.final_damage, 3, "damage capped to remaining health")
	var second := service.resolve(DamageRequest2D.create(null, 1), target)
	not_ok(second.applied, "dead target takes nothing")
	eq(second.rejection, DamageResult2D.REJECT_TARGET_DEAD, "target dead")

func test_event_fires_only_for_applied_hits() -> void:
	var service := DamageService2D.new()
	var events: Array[DamageResult2D] = []
	service.damage_resolved.connect(func(result: DamageResult2D) -> void: events.append(result))
	var target := _target(10)
	service.resolve(DamageRequest2D.create(null, 2), target)
	service.resolve(DamageRequest2D.create(null, 0), target)
	service.resolve(null, target)
	eq(events.size(), 1, "one event")
	eq(events[0].final_damage, 2, "event carries the result")

func test_rejects_missing_inputs() -> void:
	var service := DamageService2D.new()
	eq(service.resolve(null, _target()).rejection, DamageResult2D.REJECT_NO_REQUEST, "no request")
	eq(service.resolve(DamageRequest2D.create(null, 1), null).rejection, DamageResult2D.REJECT_NO_TARGET, "no target")
	var plain := Node.new()
	add_child(plain)
	eq(service.resolve(DamageRequest2D.create(null, 1), plain).rejection, DamageResult2D.REJECT_NOT_DAMAGEABLE, "not damageable")

func test_zero_damage_rejected() -> void:
	var service := DamageService2D.new()
	var target := _target()
	var result := service.resolve(DamageRequest2D.create(null, 0), target)
	eq(result.rejection, DamageResult2D.REJECT_NO_DAMAGE, "no damage")
	eq(target.health.current_health, 10, "unchanged")

func test_self_damage_rejected() -> void:
	var service := DamageService2D.new()
	var target := _target()
	var result := service.resolve(DamageRequest2D.create(target, 3), target)
	eq(result.rejection, DamageResult2D.REJECT_SELF_DAMAGE, "self damage")

func test_team_rules() -> void:
	var service := DamageService2D.new()
	var player := _target(10, Groups2D.PLAYER)
	var other_player := _target(10, Groups2D.PLAYER)
	var enemy := _target(10, Groups2D.ENEMY)
	var other_enemy := _target(10, Groups2D.ENEMY)
	eq(service.resolve(DamageRequest2D.create(player, 1), other_player).rejection, DamageResult2D.REJECT_FRIENDLY_FIRE, "player vs player")
	eq(service.resolve(DamageRequest2D.create(enemy, 1), other_enemy).rejection, DamageResult2D.REJECT_FRIENDLY_FIRE, "enemy vs enemy")
	ok(service.resolve(DamageRequest2D.create(player, 1), enemy).applied, "player hits enemy")
	ok(service.resolve(DamageRequest2D.create(enemy, 1), player).applied, "enemy hits player")
	ok(service.resolve(DamageRequest2D.create(null, 1), other_player).applied, "environment hits anyone")

func test_invulnerable_rejected() -> void:
	var service := DamageService2D.new()
	var target := _target()
	target.health.set_invulnerable(true)
	var result := service.resolve(DamageRequest2D.create(null, 5), target)
	eq(result.rejection, DamageResult2D.REJECT_INVULNERABLE, "invulnerable")
	eq(target.health.current_health, 10, "unchanged")

func test_critical_multiplier() -> void:
	var service := DamageService2D.new()
	var target := _target(20)
	var request := DamageRequest2D.create(null, 4)
	request.critical = true
	request.critical_multiplier = 2.0
	var result := service.resolve(request, target)
	eq(result.final_damage, 8, "doubled")
	ok(result.critical, "critical flagged")
	eq(target.health.current_health, 12, "target health")

func test_default_instance_is_shared() -> void:
	ok(DamageService2D.get_default() == DamageService2D.get_default(), "same instance")

func test_groups_team_helper() -> void:
	var a := Node.new()
	var b := Node.new()
	add_child(a)
	add_child(b)
	not_ok(Groups2D.is_same_team(a, b), "no groups")
	not_ok(Groups2D.is_same_team(a, null), "null")
	a.add_to_group(Groups2D.ENEMY)
	b.add_to_group(Groups2D.PLAYER)
	not_ok(Groups2D.is_same_team(a, b), "different factions")
