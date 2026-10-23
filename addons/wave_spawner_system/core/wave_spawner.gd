class_name WaveSpawner
extends Node
## An enemy wave spawner with a budget director — logic independent of the UI.
##
## Instead of writing out each wave by hand, you define enemy types
## ([EnemyType]: cost, weight, from which wave) and a difficulty curve — the spawner
## composes the wave itself by "buying" enemies with a growing threat budget.
##
## Spawn modes:
## [br]• [EnemyType] with a scene + [member spawn_position_provider] — the spawner
##   instantiates the enemy, adds it under [member spawn_parent] and tracks
##   its death itself (tree_exited),
## [br]• [EnemyType] without a scene — the spawner emits [signal spawn_requested],
##   the game spawns its own way and reports death via [method notify_defeated].
##
## Plus: boss waves every N waves, spawn-pace jitter, a break between
## waves with the option to call the next one early ([method call_next_wave_early]
## returns the remaining time — pay a bonus for it like in tower defense),
## full override of the wave composition ([member custom_wave_builder]) and
## a deterministic seed for tests and repeatable runs.

## Emitted at the start of the break between waves.
signal countdown_started(time: float)
## Emitted at the start of a wave (after the break).
signal wave_started(number: int, enemy_count: int)
## Emitted on every spawn. [param node] = null in signal mode.
signal enemy_spawned(type: EnemyType, node: Node, position: Vector2)
## Emitted in scene-less mode — the game spawns the enemy itself.
signal spawn_requested(type: EnemyType, position: Vector2)
## Emitted when the whole wave queue has reached the map (waiting for it to be cleared).
signal spawning_finished(number: int)
## Emitted after all enemies of a wave are defeated.
signal wave_cleared(number: int)
## Emitted after the last wave is cleared (when max_waves > 0).
signal all_waves_cleared()

## Enemy types the director composes waves from.
@export var enemy_types: Array[EnemyType] = []

@export_group("Difficulty budget")
## Threat budget of the first wave.
@export var first_budget := 10.0
## Budget of wave N = (first_budget + budget_add×(N-1)) × budget_growth^(N-1).
@export var budget_add := 3.0
@export_range(1.0, 2.0, 0.01) var budget_growth := 1.12

@export_group("Pace")
## Base interval between spawns within a wave (seconds).
@export var spawn_interval := 0.7
## Random spread of the interval (±seconds) — waves don't tick like a metronome.
@export var interval_jitter := 0.35
## Break between waves (seconds).
@export var break_time := 6.0

@export_group("Bosses")
## Every how many waves to add a boss (0 = never).
@export_range(0, 50) var boss_every := 0
## Id of the boss type (spawned once, regardless of budget).
@export var boss_id: StringName

@export_group("Other")
## Wave limit (0 = endless).
@export var max_waves := 0
## Randomness seed (0 = random) — deterministic runs and tests.
@export var rng_seed := 0

## Callable() -> Vector2 — the position of the next spawn (e.g. a random arena edge).
var spawn_position_provider: Callable
## Parent node of instantiated enemies (defaults to the spawner's parent).
var spawn_parent: Node
## Callable(wave_number: int) -> Array[StringName] — full override of the wave
## composition (a list of ids; an empty array = fall back to the budget director).
var custom_wave_builder: Callable

enum _Phase { IDLE, COUNTDOWN, SPAWNING, CLEARING }

var _phase := _Phase.IDLE
var _wave := 0
var _queue: Array[EnemyType] = []
var _alive := 0
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed


func _process(delta: float) -> void:
	match _phase:
		_Phase.COUNTDOWN:
			_timer -= delta
			if _timer <= 0.0:
				_begin_wave()
		_Phase.SPAWNING:
			_timer -= delta
			if _timer <= 0.0:
				_spawn_next()


# --- Control --------------------------------------------------------------------

## Starts from the first wave (with an initial break).
func start() -> void:
	if _phase != _Phase.IDLE:
		return
	_wave = 0
	_start_countdown()


## Stops the spawner (doesn't touch living enemies).
func stop() -> void:
	_phase = _Phase.IDLE
	_queue.clear()


## Shortens the break — the next wave starts immediately. Returns the skipped seconds
## (pay a bonus for them). 0 when no countdown is running.
func call_next_wave_early() -> float:
	if _phase != _Phase.COUNTDOWN:
		return 0.0
	var skipped := maxf(0.0, _timer)
	_begin_wave()
	return skipped


## Report of an enemy defeated (signal mode; with auto-instantiation
## the spawner detects it itself via tree_exited).
func notify_defeated() -> void:
	_alive = maxi(0, _alive - 1)
	_check_cleared()


# --- Reading state ------------------------------------------------------------------

func get_wave() -> int:
	return _wave


func get_alive_count() -> int:
	return _alive


func get_remaining_in_queue() -> int:
	return _queue.size()


func get_countdown_left() -> float:
	return maxf(0.0, _timer) if _phase == _Phase.COUNTDOWN else 0.0


func is_running() -> bool:
	return _phase != _Phase.IDLE


## Threat budget of wave N (for previewing/tuning the curve).
func get_budget_for_wave(number: int) -> float:
	return (first_budget + budget_add * (number - 1)) \
			* pow(budget_growth, number - 1)


# --- Serialization ------------------------------------------------------------------

## Wave number for a game save (loading resumes from the break before that wave).
func to_dict() -> Dictionary:
	return {"wave": _wave}


func from_dict(data: Dictionary) -> void:
	stop()
	_wave = maxi(0, int(data.get("wave", 0)))
	_start_countdown()


# --- Budget director --------------------------------------------------------------

## Composes the wave. First [member custom_wave_builder]; when absent —
## weighted buying with the budget (more expensive enemies only from their first_wave).
func build_wave(number: int) -> Array[EnemyType]:
	if custom_wave_builder.is_valid():
		var ids: Array = custom_wave_builder.call(number)
		if not ids.is_empty():
			var custom: Array[EnemyType] = []
			for id in ids:
				var found := _find_type(id)
				if found != null:
					custom.append(found)
			return custom

	var pool: Array[EnemyType] = []
	for type in enemy_types:
		if type != null and type.first_wave <= number and type.id != boss_id:
			pool.append(type)
	var composition: Array[EnemyType] = []
	if not pool.is_empty():
		var budget := get_budget_for_wave(number)
		var cheapest := _cheapest_cost(pool)
		while budget >= cheapest:
			var pick := _pick_weighted(pool, budget)
			if pick == null:
				break
			composition.append(pick)
			budget -= pick.cost
	if boss_every > 0 and number % boss_every == 0:
		var boss := _find_type(boss_id)
		if boss != null:
			composition.append(boss)
	composition.shuffle()
	return composition


func _pick_weighted(pool: Array[EnemyType], budget: float) -> EnemyType:
	var total := 0.0
	for type in pool:
		if type.cost <= budget:
			total += type.weight
	if total <= 0.0:
		return null
	var roll := _rng.randf() * total
	for type in pool:
		if type.cost > budget:
			continue
		roll -= type.weight
		if roll <= 0.0:
			return type
	return null


# --- Wave flow ------------------------------------------------------------------

func _start_countdown() -> void:
	if max_waves > 0 and _wave >= max_waves:
		_phase = _Phase.IDLE
		all_waves_cleared.emit()
		return
	_phase = _Phase.COUNTDOWN
	_timer = break_time
	countdown_started.emit(break_time)


func _begin_wave() -> void:
	_wave += 1
	_queue = build_wave(_wave)
	_phase = _Phase.SPAWNING
	_timer = 0.0
	wave_started.emit(_wave, _queue.size())
	if _queue.is_empty():
		_finish_spawning()


func _spawn_next() -> void:
	if _queue.is_empty():
		return
	var type: EnemyType = _queue.pop_front()
	var position := Vector2.ZERO
	if spawn_position_provider.is_valid():
		position = spawn_position_provider.call()
	_alive += 1

	var node: Node = null
	if type.scene != null:
		node = type.scene.instantiate()
		var parent := spawn_parent if spawn_parent != null else get_parent()
		parent.add_child(node)
		if node is Node2D:
			(node as Node2D).global_position = position
		elif node is Control:
			(node as Control).global_position = position
		node.tree_exited.connect(notify_defeated)
	else:
		spawn_requested.emit(type, position)
	enemy_spawned.emit(type, node, position)

	if _queue.is_empty():
		_finish_spawning()
	else:
		_timer = maxf(0.05, spawn_interval
				+ _rng.randf_range(-interval_jitter, interval_jitter))


func _finish_spawning() -> void:
	_phase = _Phase.CLEARING
	spawning_finished.emit(_wave)
	_check_cleared()


func _check_cleared() -> void:
	if _phase != _Phase.CLEARING or _alive > 0:
		return
	wave_cleared.emit(_wave)
	_start_countdown()


# --- Helpers --------------------------------------------------------------------

func _find_type(id: StringName) -> EnemyType:
	for type in enemy_types:
		if type != null and type.id == id:
			return type
	return null


func _cheapest_cost(pool: Array[EnemyType]) -> float:
	var cheapest := INF
	for type in pool:
		cheapest = minf(cheapest, type.cost)
	return cheapest
