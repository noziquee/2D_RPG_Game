extends SCTestCase
## Phase 7: Dead state, cancelled actions on death, knockback through MovementComponent2D,
## respawn, and enemy death presentation.

const PLAYER_SCENE := preload("res://player.tscn")
const ENEMY_SCENE := preload("res://Characters/Enemies/BasicEnemy2D.tscn")

func _hit(target: Character2D, amount: int, direction: Vector2 = Vector2.RIGHT, knockback: float = 0.0) -> DamageResult2D:
	var request := DamageRequest2D.create(null, amount)
	request.direction = direction
	request.knockback_speed = knockback
	return target.receive_damage(request)

func _count_death_effects() -> int:
	var count := 0
	for child in get_children():
		if child is DeathEffect2D:
			count += 1
	return count

func test_lethal_hit_enters_dead_state() -> void:
	var player := PLAYER_SCENE.instantiate() as Character2D
	add_child(player)
	var deaths := [0]
	player.died.connect(func() -> void: deaths[0] += 1)
	_hit(player, 1000)
	eq(deaths[0], 1, "died once")
	eq(player.state_machine.current_state_name, &"Dead", "dead state")
	not_ok(player.is_alive(), "not alive")
	not_ok(player.is_in_group(Groups2D.DAMAGEABLE), "no longer a damageable target")

func test_death_mid_attack_cancels_attack() -> void:
	var player := PLAYER_SCENE.instantiate() as Character2D
	add_child(player)
	ok(player.attack_component.try_start(true, Vector2.RIGHT), "attack starts")
	ok(player.context.is_attacking, "attacking before death")
	_hit(player, 1000)
	not_ok(player.context.is_attacking, "attack cancelled by death")
	not_ok(player.attack_component.is_on_cooldown(), "no cooldown left from the cancelled swing")

func test_death_mid_dash_cancels_dash() -> void:
	var player := PLAYER_SCENE.instantiate() as Character2D
	add_child(player)
	ok(player.dash_component.try_start(true, Vector2.RIGHT), "dash starts")
	ok(player.context.is_dashing, "dashing before death")
	_hit(player, 1000)
	not_ok(player.context.is_dashing, "dash cancelled by death")
	eq(player.context.dash_velocity, Vector2.ZERO, "dash velocity cleared")

func test_hit_applies_knockback_through_movement() -> void:
	var player := PLAYER_SCENE.instantiate() as Character2D
	add_child(player)
	var result := _hit(player, 1, Vector2.RIGHT, 160.0)
	ok(result.applied, "hit applied")
	almost(player.movement_component.knockback_velocity.x, 160.0, "knockback speed along direction")
	almost(player.movement_component.knockback_velocity.y, 0.0, "no vertical knockback")
	player.movement_component.decay_knockback(0.1)
	almost(player.movement_component.knockback_velocity.x, 90.0, "decays by friction over 0.1 s")

func test_zero_knockback_is_ignored() -> void:
	var player := PLAYER_SCENE.instantiate() as Character2D
	add_child(player)
	_hit(player, 1, Vector2.RIGHT, 0.0)
	eq(player.movement_component.knockback_velocity, Vector2.ZERO, "no knockback without a speed")

func test_knockback_applies_to_killing_blow() -> void:
	var player := PLAYER_SCENE.instantiate() as Character2D
	add_child(player)
	_hit(player, 1000, Vector2.LEFT, 160.0)
	eq(player.state_machine.current_state_name, &"Dead", "dead")
	almost(player.movement_component.knockback_velocity.x, -160.0, "corpse is pushed back")

func test_rejected_hit_does_not_knock_back() -> void:
	var player := PLAYER_SCENE.instantiate() as Character2D
	add_child(player)
	_hit(player, 1000, Vector2.LEFT, 160.0)
	var before := player.movement_component.knockback_velocity
	var rejected := _hit(player, 1, Vector2.RIGHT, 160.0)
	not_ok(rejected.applied, "dead target rejects the hit")
	eq(player.movement_component.knockback_velocity, before, "no knockback from a rejected hit")

func test_respawn_restores_character() -> void:
	var player := PLAYER_SCENE.instantiate() as Character2D
	add_child(player)
	_hit(player, 1000, Vector2.LEFT, 160.0)
	var respawns := [0]
	player.respawned.connect(func() -> void: respawns[0] += 1)
	ok(player.respawn(3), "respawn succeeds")
	ok(player.is_alive(), "alive again")
	eq(player.health, 3, "explicit respawn health")
	eq(player.state_machine.current_state_name, &"Idle", "back to idle")
	ok(player.is_in_group(Groups2D.DAMAGEABLE), "damageable again")
	eq(player.movement_component.knockback_velocity, Vector2.ZERO, "knockback cleared")
	eq(respawns[0], 1, "respawned emitted once")
	not_ok(player.respawn(), "a living character is not respawned")

func test_respawn_defaults_to_full_health() -> void:
	var player := PLAYER_SCENE.instantiate() as Character2D
	add_child(player)
	_hit(player, 1000)
	player.respawn()
	eq(player.health, player.get_health_component().max_health, "full health")

func test_enemy_death_hides_body_and_spawns_effect() -> void:
	var enemy := ENEMY_SCENE.instantiate() as BasicEnemy2D
	add_child(enemy)
	_hit(enemy, 1000)
	not_ok(enemy.get_node("AnimatedSprite2D").visible, "body hidden")
	not_ok(enemy.is_in_group(Groups2D.DAMAGEABLE), "corpse is not a target")
	eq(enemy.state_machine.current_state_name, &"Dead", "dead state")
	eq(_count_death_effects(), 1, "one death effect spawned beside the enemy")

func test_death_effect_spawns_only_once_per_death() -> void:
	var enemy := ENEMY_SCENE.instantiate() as BasicEnemy2D
	add_child(enemy)
	_hit(enemy, 1000)
	_hit(enemy, 1000)
	eq(_count_death_effects(), 1, "further hits do not spawn more effects")
