extends SCTestCase
## Integration: the real player and goblin scenes use the shared health path.

const PLAYER_SCENE := preload("res://player.tscn")
const ENEMY_SCENE := preload("res://Characters/Enemies/BasicEnemy2D.tscn")

func test_enemy_dies_once_and_signals_hud() -> void:
	var enemy := ENEMY_SCENE.instantiate() as BasicEnemy2D
	var changes: Array[String] = []
	var deaths := [0]
	enemy.health_changed.connect(func(current: int, maximum: int) -> void: changes.append("%d/%d" % [current, maximum]))
	enemy.died.connect(func() -> void: deaths[0] += 1)
	add_child(enemy)
	eq(enemy.health, enemy.max_health, "starts at max health")
	ok(enemy.is_in_group(Groups2D.ENEMY), "enemy group")
	ok(enemy.is_in_group(Groups2D.DAMAGEABLE), "damageable group")
	ok(enemy.is_alive(), "alive")
	enemy.take_damage(1)
	eq(enemy.health, enemy.max_health - 1, "wrapper damages")
	enemy.take_damage(1000)
	eq(deaths[0], 1, "died once")
	enemy.take_damage(1000)
	eq(deaths[0], 1, "still once")
	not_ok(enemy.is_alive(), "dead")
	eq(changes[0], "%d/%d" % [enemy.max_health, enemy.max_health], "initial health announced")
	eq(changes[changes.size() - 1], "0/%d" % enemy.max_health, "last change is zero")

func test_player_death_stops_processing() -> void:
	var player := PLAYER_SCENE.instantiate() as Character2D
	var deaths := [0]
	player.died.connect(func() -> void: deaths[0] += 1)
	add_child(player)
	ok(player.is_in_group(Groups2D.PLAYER), "player group")
	eq(player.health, int(player.get("max_health")), "starts at max health")
	player.take_damage(1)
	ok(player.is_alive(), "survives one hit")
	player.take_damage(1000)
	eq(deaths[0], 1, "died once")
	not_ok(player.is_alive(), "dead")
	not_ok(player.is_physics_processing(), "physics stopped like before")

func test_receive_damage_returns_result_and_emits_event() -> void:
	var enemy := ENEMY_SCENE.instantiate() as BasicEnemy2D
	add_child(enemy)
	var seen: Array[DamageResult2D] = []
	enemy.damage_received.connect(func(result: DamageResult2D) -> void: seen.append(result))
	var result := enemy.receive_damage(DamageRequest2D.create(null, 1))
	ok(result.applied, "applied")
	eq(seen.size(), 1, "damage_received emitted")
	var rejected := enemy.receive_damage(DamageRequest2D.create(null, 0))
	not_ok(rejected.applied, "zero rejected")
	eq(seen.size(), 1, "no event for rejected hit")

func test_enemy_cannot_hurt_enemy_but_player_can() -> void:
	var player := PLAYER_SCENE.instantiate() as Character2D
	var enemy_a := ENEMY_SCENE.instantiate() as BasicEnemy2D
	var enemy_b := ENEMY_SCENE.instantiate() as BasicEnemy2D
	add_child(player)
	add_child(enemy_a)
	add_child(enemy_b)
	eq(enemy_b.receive_damage(DamageRequest2D.create(enemy_a, 1)).rejection, DamageResult2D.REJECT_FRIENDLY_FIRE, "friendly fire")
	ok(enemy_b.receive_damage(DamageRequest2D.create(player, 1)).applied, "player damages enemy")
	ok(player.receive_damage(DamageRequest2D.create(enemy_a, 1)).applied, "enemy damages player")
