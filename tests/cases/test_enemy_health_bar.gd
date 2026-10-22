extends SCTestCase
## Enemy health bar: a screen-space CanvasLayer that stays hidden until the enemy is hit.

const ENEMY_SCENE := preload("res://Characters/Enemies/BasicEnemy2D.tscn")

func test_bar_is_screen_space_and_hidden_until_damaged() -> void:
	var enemy := ENEMY_SCENE.instantiate() as BasicEnemy2D
	add_child(enemy)
	var bar_layer := enemy.get_node("EnemyHealthBar2D")
	ok(bar_layer is CanvasLayer, "bar is a CanvasLayer, so camera zoom does not scale it")
	not_ok((bar_layer.get_node("Bar") as Control).visible, "hidden until the enemy takes damage")
