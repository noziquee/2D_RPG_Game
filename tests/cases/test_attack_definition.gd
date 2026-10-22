extends SCTestCase
## AttackDefinition2D defaults and the shipped default resource.

func test_script_defaults() -> void:
	var definition := AttackDefinition2D.new()
	eq(definition.damage, 1, "default damage")
	almost(definition.cooldown_duration, 0.55, "default cooldown")
	eq(definition.hitbox_size, Vector2(50.0, 16.0), "default hitbox size")
	eq(definition.hitbox_offset, Vector2(25.0, 0.0), "default hitbox offset")

func test_default_resource_loads() -> void:
	var definition := load("res://Characters/Components/Combat/DefaultAttackDefinition.tres") as AttackDefinition2D
	not_null(definition, "default attack definition loads")
	if definition != null:
		ok(definition.damage >= 1, "default attack deals damage")
		ok(definition.cooldown_duration >= 0.0, "cooldown is not negative")
