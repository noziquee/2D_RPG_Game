extends SCTestCase
## Phase 9: hit-stop restores the scale it found, and the damage event drives feedback.

func test_hitstop_restores_the_scale_it_found() -> void:
	var before := Engine.time_scale
	Engine.time_scale = 0.5
	var effects := ScreenEffects.new()
	add_child(effects)
	var token := effects._begin_timescale(0.05)
	eq(Engine.time_scale, 0.05, "slowed")
	effects._finish_timescale(token)
	eq(Engine.time_scale, 0.5, "restored to the scale before the hit, not 1.0")
	Engine.time_scale = before

func test_overlapping_hitstops_restore_once_in_order() -> void:
	var before := Engine.time_scale
	Engine.time_scale = 0.5
	var effects := ScreenEffects.new()
	add_child(effects)
	var first := effects._begin_timescale(0.05)
	var second := effects._begin_timescale(0.1)
	effects._finish_timescale(first)
	eq(Engine.time_scale, 0.1, "an older hit-stop does not cut the newer one short")
	effects._finish_timescale(second)
	eq(Engine.time_scale, 0.5, "restored after the last one")
	Engine.time_scale = before

func test_leaving_the_tree_mid_hitstop_restores_the_scale() -> void:
	var before := Engine.time_scale
	Engine.time_scale = 0.5
	var effects := ScreenEffects.new()
	add_child(effects)
	effects._begin_timescale(0.05)
	effects.free()
	eq(Engine.time_scale, 0.5, "a scene change mid-hit-stop does not leave slow motion on")
	Engine.time_scale = before

func test_enemy_damage_spawns_a_number() -> void:
	var feedback := CombatFeedback.new()
	add_child(feedback)
	var enemy := Node2D.new()
	add_child(enemy)
	var result := DamageResult2D.new()
	result.target = enemy
	result.final_damage = 3
	feedback._on_damage_resolved(result)
	eq(feedback.spawner.get_child_count(), 1, "one floating number for an enemy hit")

func test_player_damage_spawns_a_taken_number() -> void:
	var feedback := CombatFeedback.new()
	add_child(feedback)
	var player := Node2D.new()
	player.add_to_group(Groups2D.PLAYER)
	add_child(player)
	var result := DamageResult2D.new()
	result.target = player
	result.final_damage = 3
	feedback._on_damage_resolved(result)
	eq(feedback.spawner.get_child_count(), 1, "one floating number for the player")
	var label := feedback.spawner.get_child(0) as FloatingLabel
	ok(label != null and label.text.begins_with("-"), "player damage is shown as a loss")
