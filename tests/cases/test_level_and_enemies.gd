extends SCTestCase
## Phase 13: enemy variants, the wave types that spawn them, and the painted room.

const SLIME_SCENE := preload("res://Characters/Enemies/Slime.tscn")
const FLY_SCENE := preload("res://Characters/Enemies/FlyingEnemy.tscn")
const LEVEL_SCRIPT := preload("res://World/Level/Level.gd")

func test_slime_is_a_basic_enemy_with_its_own_stats() -> void:
	var slime := SLIME_SCENE.instantiate() as BasicEnemy2D
	add_child(slime)
	ok(slime != null, "slime is a BasicEnemy2D")
	eq(slime.max_health, 2, "slime health")
	eq(slime.health, 2, "starts at full health")
	ok(slime.is_in_group(Groups2D.ENEMY), "slime is on the enemy team")
	not_ok(slime.get_node("AnimatedSprite2D/Weapon").visible, "no knife on the slime")
	ok((slime.get_node("AnimatedSprite2D") as AnimatedSprite2D).sprite_frames.has_animation(&"run"), "has a run clip")

func test_flying_enemy_ignores_world_collision() -> void:
	var fly := FLY_SCENE.instantiate() as BasicEnemy2D
	add_child(fly)
	eq(fly.collision_mask, 0, "no world collision, so it flies over walls")
	eq(fly.max_health, 1, "fly health")
	ok(fly.is_in_group(Groups2D.DAMAGEABLE), "still damageable")

func test_wave_types_point_at_their_scenes() -> void:
	var slime_type := load("res://Waves/slime_type.tres") as EnemyType
	var fly_type := load("res://Waves/fly_type.tres") as EnemyType
	eq(slime_type.id, &"slime", "slime id")
	eq(fly_type.id, &"fly", "fly id")
	ok(slime_type.scene == SLIME_SCENE, "slime type spawns the slime scene")
	ok(fly_type.scene == FLY_SCENE, "fly type spawns the flying scene")
	ok(fly_type.first_wave > slime_type.first_wave, "flyers arrive after slimes")

func test_room_paints_walls_and_spawns_inside_them() -> void:
	var level: Node2D = LEVEL_SCRIPT.new()
	add_child(level)
	level._build_room()
	var walls := 0
	for child in level.get_children():
		if child is StaticBody2D:
			walls += 1
	ok(walls > 50, "every wall cell has a collision box (%d)" % walls)
	ok(level.wall_layer.get_used_cells().size() == walls, "one collision box per wall cell")
	ok(level.floor_layer.get_used_cells().size() > 0, "floor is painted")

	var area: Rect2 = level.interior_rect()
	for _i in 20:
		var point: Vector2 = level._random_spawn_point()
		ok(area.has_point(point), "spawn point stays inside the room")

func test_room_build_runs_once() -> void:
	var level: Node2D = LEVEL_SCRIPT.new()
	add_child(level)
	level._build_room()
	var count := level.get_child_count()
	level._build_room()
	eq(level.get_child_count(), count, "a second build changes nothing")
