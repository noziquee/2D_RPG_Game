extends Node2D
class_name Level
## The demo room. The floor and walls are painted onto TileMapLayers from a text layout,
## and every wall cell gets a collision box. A WaveSpawner sends slimes and flying enemies
## in from random points inside the room. Built once, on the first call to _build_room().

const TILE: int = 16
## Tile index of the layout's top-left corner. Layout rows map to y = ORIGIN.y + row.
const ORIGIN: Vector2i = Vector2i(10, 12)
## Legend: "#" wall, "." floor.
const LAYOUT: PackedStringArray = [
	"##########################",
	"#........................#",
	"#........................#",
	"#........................#",
	"#........#...............#",
	"#........#...............#",
	"#........................#",
	"#........................#",
	"#...............#........#",
	"#...............#........#",
	"#........................#",
	"#........................#",
	"#........................#",
	"#........................#",
	"##########################"
]

const FLOOR_A: Texture2D = preload("res://Assets/tiles/floor/floor_1.png")
const FLOOR_B: Texture2D = preload("res://Assets/tiles/floor/floor_2.png")
const WALL: Texture2D = preload("res://Assets/tiles/wall/wall_1.png")
const SLIME_TYPE: EnemyType = preload("res://Waves/slime_type.tres")
const FLY_TYPE: EnemyType = preload("res://Waves/fly_type.tres")

## Keeps spawns this far from the player so a wave does not appear on top of them.
const SPAWN_CLEARANCE: float = 80.0
const SPAWN_MARGIN: float = 8.0

var spawner: WaveSpawner
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var _built: bool = false

func _ready() -> void:
	_build_room()
	call_deferred("_start_waves")

## The room's interior in world units (the cells between the walls).
func interior_rect() -> Rect2:
	var cols := LAYOUT[0].length()
	var rows := LAYOUT.size()
	var top_left := Vector2(ORIGIN * TILE)
	return Rect2(top_left + Vector2(TILE, TILE), Vector2((cols - 2) * TILE, (rows - 2) * TILE))

func _build_room() -> void:
	if _built:
		return
	_built = true
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	_add_source(tileset, 0, FLOOR_A)
	_add_source(tileset, 1, WALL)
	_add_source(tileset, 2, FLOOR_B)

	floor_layer = TileMapLayer.new()
	floor_layer.tile_set = tileset
	floor_layer.name = "Floor"
	add_child(floor_layer)
	move_child(floor_layer, 0)

	wall_layer = TileMapLayer.new()
	wall_layer.tile_set = tileset
	wall_layer.name = "Walls"
	add_child(wall_layer)
	move_child(wall_layer, 1)

	for row in LAYOUT.size():
		var line: String = LAYOUT[row]
		for col in line.length():
			var cell := ORIGIN + Vector2i(col, row)
			if line[col] == "#":
				wall_layer.set_cell(cell, 1, Vector2i.ZERO)
				_add_wall_collision(cell)
			else:
				var source := 0 if (col + row) % 2 == 0 else 2
				floor_layer.set_cell(cell, source, Vector2i.ZERO)

func _add_source(tileset: TileSet, id: int, texture: Texture2D) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(Vector2i.ZERO)
	tileset.add_source(source, id)

func _add_wall_collision(cell: Vector2i) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = Vector2(cell * TILE) + Vector2(TILE, TILE) * 0.5
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)

func _start_waves() -> void:
	spawner = WaveSpawner.new()
	spawner.name = "WaveSpawner"
	add_child(spawner)
	spawner.enemy_types = [SLIME_TYPE, FLY_TYPE]
	spawner.spawn_parent = self
	spawner.spawn_position_provider = Callable(self, "_random_spawn_point")
	spawner.first_budget = 6.0
	spawner.budget_add = 3.0
	spawner.spawn_interval = 1.2
	spawner.break_time = 4.0
	spawner.start()

## A random point inside the room, away from the walls and from the player.
func _random_spawn_point() -> Vector2:
	var area := interior_rect().grow(-SPAWN_MARGIN)
	var player := get_tree().get_first_node_in_group(Groups2D.PLAYER) as Node2D
	var point := Vector2.ZERO
	for _attempt in 12:
		point = Vector2(
			randf_range(area.position.x, area.end.x),
			randf_range(area.position.y, area.end.y))
		if player == null or point.distance_to(player.global_position) >= SPAWN_CLEARANCE:
			break
	return point
