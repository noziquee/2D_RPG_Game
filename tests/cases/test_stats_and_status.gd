extends SCTestCase
## Phase 10: stats math, status effect stacking and expiry, damage over time, defense,
## the attack stat, and clearing on death.

const PLAYER_SCENE := preload("res://player.tscn")

func _player() -> Character2D:
	var player := PLAYER_SCENE.instantiate() as Character2D
	add_child(player)
	return player

func _effect(id: StringName, duration: float = 2.0) -> StatusEffect2D:
	var effect := StatusEffect2D.new()
	effect.id = id
	effect.duration = duration
	return effect

func _speed_buff(flat: float, stacking: StatusEffect2D.Stacking = StatusEffect2D.Stacking.REFRESH,
		max_stacks: int = 1) -> StatusEffect2D:
	var effect := _effect(&"haste")
	effect.stacking = stacking
	effect.max_stacks = max_stacks
	var modifier := StatModifier2D.new()
	modifier.stat_id = &"move_speed"
	modifier.flat = flat
	effect.modifiers.append(modifier)
	return effect

func test_stat_is_base_plus_flat_times_percent() -> void:
	var stats := StatsComponent2D.new()
	add_child(stats)
	stats.set_base(&"attack", 10.0)
	stats.set_modifier(&"ring", &"attack", 5.0, 0.2)
	almost(stats.get_stat(&"attack"), 18.0, "(10 + 5) * 1.2")
	stats.remove_modifiers(&"ring")
	almost(stats.get_stat(&"attack"), 10.0, "removing the source restores the base")

func test_modifier_from_one_source_replaces_itself() -> void:
	var stats := StatsComponent2D.new()
	add_child(stats)
	stats.set_base(&"attack", 0.0)
	stats.set_modifier(&"ring", &"attack", 4.0, 0.0)
	stats.set_modifier(&"ring", &"attack", 6.0, 0.0)
	almost(stats.get_stat(&"attack"), 6.0, "same source and stat replaces the value")

func test_stat_changed_only_fires_when_the_value_changes() -> void:
	var stats := StatsComponent2D.new()
	add_child(stats)
	var changes := [0]
	stats.stat_changed.connect(func(_id: StringName, _v: float) -> void: changes[0] += 1)
	stats.set_base(&"defense", 0.0)
	eq(changes[0], 0, "setting an unchanged value emits nothing")
	stats.set_modifier(&"ring", &"defense", 3.0, 0.0)
	eq(changes[0], 1, "a real change emits once")

func test_status_modifier_changes_move_speed_and_expires() -> void:
	var player := _player()
	var base := player.get_stat(&"move_speed")
	ok(player.apply_status(_speed_buff(50.0)), "applied")
	almost(player.get_stat(&"move_speed"), base + 50.0, "stat reflects the buff")
	almost(player.movement_component.move_speed, base + 50.0, "movement uses the stat")
	player.status_component.physics_update(2.1)
	not_ok(player.status_component.has(&"haste"), "expired after its duration")
	almost(player.movement_component.move_speed, base, "speed restored after expiry")

func test_refresh_resets_duration_without_stacking() -> void:
	var player := _player()
	var effect := _speed_buff(10.0)
	player.apply_status(effect)
	player.status_component.physics_update(1.0)
	player.apply_status(effect)
	eq(player.status_component.stacks_of(&"haste"), 1, "refresh keeps one stack")
	almost(player.status_component.remaining_of(&"haste"), 2.0, "duration reset")

func test_add_stack_caps_at_max_and_scales_the_modifier() -> void:
	var player := _player()
	var base := player.get_stat(&"move_speed")
	var effect := _speed_buff(10.0, StatusEffect2D.Stacking.ADD_STACK, 3)
	player.apply_status(effect)
	player.apply_status(effect)
	eq(player.status_component.stacks_of(&"haste"), 2, "second application adds a stack")
	almost(player.get_stat(&"move_speed"), base + 20.0, "modifier scales with stacks")
	player.apply_status(effect)
	player.apply_status(effect)
	eq(player.status_component.stacks_of(&"haste"), 3, "stacks cap at max_stacks")
	almost(player.get_stat(&"move_speed"), base + 30.0, "capped modifier")

func test_damage_over_time_ticks_through_the_damage_path() -> void:
	var player := _player()
	var before := player.health
	var poison := _effect(&"poison", 5.0)
	poison.tick_interval = 0.5
	poison.tick_damage = 2
	player.apply_status(poison)
	player.status_component.physics_update(1.0)
	eq(player.health, before - 4, "two ticks of 2 in one second")
	not_ok(player.context.is_locked(ActionLock2D.HURT), "a tick does not start a hit reaction")

func test_death_clears_status_effects_and_their_modifiers() -> void:
	var player := _player()
	var base := player.get_stat(&"move_speed")
	player.apply_status(_speed_buff(50.0))
	player.take_damage(1000)
	not_ok(player.status_component.has(&"haste"), "effects are cleared on death")
	almost(player.get_stat(&"move_speed"), base, "no modifier outlives the character")

func test_defense_reduces_damage_with_a_floor_of_one() -> void:
	var player := _player()
	player.stats_component.set_base(&"defense", 100.0)
	var service := DamageService2D.new()
	var result := service.resolve(DamageRequest2D.create(null, 10), player)
	eq(result.final_damage, 5, "100 defense halves 10 damage")
	player.stats_component.set_base(&"defense", 300.0)
	result = service.resolve(DamageRequest2D.create(null, 1), player)
	eq(result.final_damage, 1, "a real hit always deals at least 1")

func test_attack_stat_adds_to_attack_damage() -> void:
	var player := _player()
	var base := player.attack_component.definition.damage
	player.apply_status(_attack_buff(2.0))
	eq(player.attack_component._attack_damage(), base + 2, "attack stat adds to the swing")

func _attack_buff(flat: float) -> StatusEffect2D:
	var effect := _effect(&"rage")
	var modifier := StatModifier2D.new()
	modifier.stat_id = &"attack"
	modifier.flat = flat
	effect.modifiers.append(modifier)
	return effect
