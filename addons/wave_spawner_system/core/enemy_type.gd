class_name EnemyType
extends Resource
## An enemy type for [WaveSpawner]. A resource to create in the editor (.tres)
## or in code ([method create]).
##
## [member cost] and [member weight] drive the budget director: a wave has
## a threat budget, and the spawner "buys" enemies with it — more expensive ones are
## stronger and rarer, cheaper ones form the crowd.

## Unique type identifier.
@export var id: StringName

## Name for UI/logs.
@export var display_name := ""

## Cost in the wave's threat budget (a stronger enemy = a higher cost).
@export_range(0.1, 1000.0, 0.1) var cost := 1.0

## Relative chance to be drawn (when the budget allows).
@export_range(0.0, 100.0, 0.1) var weight := 1.0

## From which wave this type starts appearing (gradual introduction).
@export_range(1, 999) var first_wave := 1

## Enemy scene. When set, [WaveSpawner] instantiates it itself;
## when null — it only emits spawn_requested and the game handles spawning.
@export var scene: PackedScene

## Icon for UI (e.g. a wave composition preview).
@export var icon: Texture2D


static func create(p_id: StringName, p_name: String, p_cost: float,
		p_weight := 1.0, p_first_wave := 1, p_scene: PackedScene = null) -> EnemyType:
	var type := EnemyType.new()
	type.id = p_id
	type.display_name = p_name
	type.cost = p_cost
	type.weight = p_weight
	type.first_wave = p_first_wave
	type.scene = p_scene
	return type
