extends SCTestCase
## Phase 8: action locks decide what a character can do, and lock signals fire from the
## lock layer. Also closes the Phase 7 gap: components refuse actions while dead.

const PLAYER_SCENE := preload("res://player.tscn")

func _player() -> Character2D:
	var player := PLAYER_SCENE.instantiate() as Character2D
	add_child(player)
	return player

func test_blocking_table() -> void:
	ok(ActionLock2D.blocks(ActionLock2D.DEAD, ActionLock2D.CAPABILITY_MOVE), "dead blocks move")
	ok(ActionLock2D.blocks(ActionLock2D.DEAD, ActionLock2D.CAPABILITY_ATTACK), "dead blocks attack")
	ok(ActionLock2D.blocks(ActionLock2D.DEAD, ActionLock2D.CAPABILITY_DASH), "dead blocks dash")
	ok(ActionLock2D.blocks(ActionLock2D.ATTACK, ActionLock2D.CAPABILITY_ATTACK), "attack blocks re-attack")
	ok(ActionLock2D.blocks(ActionLock2D.ATTACK, ActionLock2D.CAPABILITY_DASH), "attack blocks dash")
	not_ok(ActionLock2D.blocks(ActionLock2D.ATTACK, ActionLock2D.CAPABILITY_MOVE), "attack does not block move")
	ok(ActionLock2D.blocks(ActionLock2D.DASH, ActionLock2D.CAPABILITY_ATTACK), "dash blocks attack")
	ok(ActionLock2D.blocks(ActionLock2D.DASH, ActionLock2D.CAPABILITY_DASH), "dash blocks re-dash")
	not_ok(ActionLock2D.blocks(ActionLock2D.DASH, ActionLock2D.CAPABILITY_MOVE), "dash does not block move")

func test_signals_fire_on_first_acquire_and_last_release() -> void:
	var context := _player().context
	var events: Array[String] = []
	context.lock_started.connect(func(id: StringName) -> void: events.append("start:%s" % id))
	context.lock_finished.connect(func(id: StringName) -> void: events.append("finish:%s" % id))
	var first := Node.new()
	var second := Node.new()
	add_child(first)
	add_child(second)
	context.acquire_lock(ActionLock2D.DASH, first)
	context.acquire_lock(ActionLock2D.DASH, second)
	context.acquire_lock(ActionLock2D.DASH, first)
	eq(events, ["start:dash"] as Array[String], "one start even with several holders")
	context.release_lock(ActionLock2D.DASH, first)
	ok(context.is_locked(ActionLock2D.DASH), "still held by the second owner")
	context.release_lock(ActionLock2D.DASH, second)
	not_ok(context.is_locked(ActionLock2D.DASH), "released")
	context.release_lock(ActionLock2D.DASH, second)
	eq(events, ["start:dash", "finish:dash"] as Array[String], "one finish, and a repeat release is ignored")

func test_attack_refuses_dash_and_dash_refuses_attack() -> void:
	var player := _player()
	ok(player.attack_component.try_start(true, Vector2.RIGHT), "attack starts")
	not_ok(player.dash_component.try_start(true, Vector2.RIGHT), "dash refused during attack")
	player.context.release_lock(ActionLock2D.ATTACK, player.attack_component)
	ok(player.dash_component.try_start(true, Vector2.RIGHT), "dash starts once the attack lock is gone")
	not_ok(player.attack_component.try_start(true, Vector2.RIGHT), "attack refused during dash")

func test_dead_refuses_attack_and_dash() -> void:
	var player := _player()
	player.take_damage(1000)
	ok(player.context.is_locked(ActionLock2D.DEAD), "dead lock held")
	not_ok(player.context.can(ActionLock2D.CAPABILITY_MOVE), "cannot move")
	not_ok(player.attack_component.try_start(true, Vector2.RIGHT), "attack refused while dead")
	not_ok(player.dash_component.try_start(true, Vector2.RIGHT), "dash refused while dead")

func test_respawn_releases_dead_lock() -> void:
	var player := _player()
	player.take_damage(1000)
	ok(player.respawn(3), "respawned")
	not_ok(player.context.is_locked(ActionLock2D.DEAD), "dead lock released")
	ok(player.context.can(ActionLock2D.CAPABILITY_MOVE), "can move again")
	ok(player.attack_component.try_start(true, Vector2.RIGHT), "can attack again")

func test_death_cancels_attack_and_signals_release() -> void:
	var player := _player()
	var finished: Array[StringName] = []
	player.context.lock_finished.connect(func(id: StringName) -> void: finished.append(id))
	player.attack_component.try_start(true, Vector2.RIGHT)
	player.take_damage(1000)
	ok(finished.has(ActionLock2D.ATTACK), "attack lock finished on death")
	not_ok(player.context.is_attacking, "is_attacking view follows the lock")

func test_read_only_views_follow_locks() -> void:
	var player := _player()
	not_ok(player.context.is_dashing, "not dashing at start")
	player.dash_component.try_start(true, Vector2.RIGHT)
	ok(player.context.is_dashing, "dash view true while the dash lock is held")
	player.dash_component.cancel()
	not_ok(player.context.is_dashing, "dash view false after cancel")
	eq(player.context.dash_velocity, Vector2.ZERO, "dash velocity cleared on cancel")
