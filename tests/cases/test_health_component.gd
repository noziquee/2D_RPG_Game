extends SCTestCase
## HealthComponent2D: damage, heal, clamping, invulnerability, death fires once.

var _events: Array[String] = []

func _make(maximum: int = 10, starting: int = -1) -> HealthComponent2D:
	var health := HealthComponent2D.new()
	add_child(health)
	health.initialize(maximum, starting)
	_events.clear()
	health.health_changed.connect(func(current: int, maximum_health: int) -> void: _events.append("changed:%d/%d" % [current, maximum_health]))
	health.damaged.connect(func(amount: int) -> void: _events.append("damaged:%d" % amount))
	health.healed.connect(func(amount: int) -> void: _events.append("healed:%d" % amount))
	health.died.connect(func() -> void: _events.append("died"))
	return health

func test_initialize() -> void:
	var health := _make(10)
	eq(health.current_health, 10, "starts full")
	eq(health.max_health, 10, "max")
	ok(health.is_alive, "alive")
	var partial := _make(10, 4)
	eq(partial.current_health, 4, "explicit starting health")
	var clamped := _make(10, 99)
	eq(clamped.current_health, 10, "starting health clamps to max")
	var invalid := _make(0)
	eq(invalid.max_health, 1, "max health is at least 1")

func test_damage_reduces_and_emits_in_order() -> void:
	var health := _make(10)
	eq(health.damage(3), 3, "returns applied amount")
	eq(health.current_health, 7, "health after damage")
	eq(_events, ["changed:7/10", "damaged:3"] as Array[String], "signal order")

func test_damage_rejects_non_positive() -> void:
	var health := _make(10)
	eq(health.damage(0), 0, "zero")
	eq(health.damage(-5), 0, "negative")
	eq(health.current_health, 10, "unchanged")
	ok(_events.is_empty(), "no signals")

func test_overkill_clamps_and_dies_once() -> void:
	var health := _make(5)
	eq(health.damage(99), 5, "applied is capped to remaining health")
	eq(health.current_health, 0, "zero health")
	ok(health.is_dead, "dead")
	eq(_events, ["changed:0/5", "damaged:5", "died"] as Array[String], "death order")
	eq(health.damage(1), 0, "dead cannot be damaged")
	eq(_events.count("died"), 1, "died fired once")

func test_listener_cannot_cause_second_death() -> void:
	var health := _make(3)
	health.health_changed.connect(func(_c: int, _m: int) -> void: health.damage(5))
	health.damage(3)
	eq(_events.count("died"), 1, "reentrant damage does not re-kill")

func test_invulnerable_blocks_damage() -> void:
	var health := _make(10)
	health.set_invulnerable(true)
	eq(health.damage(4), 0, "blocked")
	eq(health.current_health, 10, "unchanged")
	health.set_invulnerable(false)
	eq(health.damage(4), 4, "damage works again")

func test_heal() -> void:
	var health := _make(10, 4)
	eq(health.heal(3), 3, "restores")
	eq(health.current_health, 7, "health")
	eq(health.heal(50), 3, "capped at max")
	eq(health.heal(1), 0, "already full")
	eq(health.heal(-2), 0, "negative heal ignored")

func test_dead_cannot_heal() -> void:
	var health := _make(5)
	health.damage(5)
	eq(health.heal(3), 0, "no healing the dead")
	ok(health.is_dead, "still dead")

func test_kill_ignores_invulnerability() -> void:
	var health := _make(5)
	health.set_invulnerable(true)
	health.kill()
	ok(health.is_dead, "killed")
	eq(_events.count("died"), 1, "died once")
	health.kill()
	eq(_events.count("died"), 1, "second kill does nothing")

func test_revive() -> void:
	var health := _make(10)
	health.kill()
	health.revive()
	ok(health.is_alive, "alive again")
	eq(health.current_health, 10, "full health")
	health.kill()
	health.revive(3)
	eq(health.current_health, 3, "explicit revive health")
	health.kill()
	eq(_events.count("died"), 3, "can die again after revive")

func test_set_max_health() -> void:
	var health := _make(10)
	health.set_max_health(5)
	eq(health.current_health, 5, "current clamps down")
	health.set_max_health(20)
	eq(health.current_health, 5, "current is not raised")
	eq(health.max_health, 20, "max raised")

func test_health_percent() -> void:
	var health := _make(10, 5)
	almost(health.get_health_percent(), 0.5, "half")

func test_save_and_load_state() -> void:
	var health := _make(10)
	health.damage(6)
	var saved := health.save_state()
	var other := _make(10)
	other.load_state(saved)
	eq(other.current_health, 4, "restored")
	other.load_state({"current_health": 999})
	eq(other.current_health, 10, "clamped to max")
	other.load_state({"current_health": "lots"})
	eq(other.current_health, 10, "wrong type ignored")
	other.load_state({})
	eq(other.current_health, 10, "missing key ignored")
	other.load_state({"current_health": 0})
	ok(other.is_dead, "zero health loads as dead")
