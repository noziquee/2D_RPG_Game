# Wave Spawner System — enemy waves with a budget director

A portable Godot 4 component: instead of writing out 50 waves by hand you define
enemy types (cost, weight, from which wave) and a difficulty curve — the spawner
composes the makeup of each wave itself, "buying" enemies with a growing threat
budget (like a director in horde/TD games). You move it by copying the
`addons/wave_spawner_system/` folder. **Zero dependencies**.

## What it contains

| File | Class | Role |
|---|---|---|
| `core/enemy_type.gd` | `EnemyType` (Resource) | enemy type: cost, weight, from which wave, scene |
| `core/wave_spawner.gd` | `WaveSpawner` (Node) | director + wave flow — works without a UI |
| `ui/wave_status_ui.gd` | `WaveStatusUI` (Control) | HUD: wave number, countdown, "WAVE N" banner |

## Quick start

```gdscript
var spawner := WaveSpawner.new()
spawner.enemy_types = [
	EnemyType.create(&"slime",  "Slime",  1.0, 10.0),          # cheap, swarming
	EnemyType.create(&"wolf",   "Wolf",   3.0,  5.0, 2),       # from wave 2
	EnemyType.create(&"golem",  "Golem", 10.0,  1.5, 4),       # rare, expensive
	EnemyType.create(&"boss",   "Behemoth", 0.0, 0.0, 1, boss_scene),
]
spawner.boss_every = 5
spawner.boss_id = &"boss"
spawner.spawn_position_provider = func() -> Vector2:
	return arena.random_edge_point()
add_child(spawner)

spawner.wave_started.connect(func(n, count): print("Wave %d: %d enemies" % [n, count]))
spawner.wave_cleared.connect(func(n): give_reward(n))
spawner.start()

# HUD
var hud := WaveStatusUI.new()
hud.boss_every = 5
add_child(hud)
hud.spawner = spawner
hud.early_call_bonus.connect(func(sec): wallet.add(&"gold", int(sec * 10)))
```

## How the budget director works

Budget of wave N = `(first_budget + budget_add×(N-1)) × budget_growth^(N-1)` —
a linear ramp + a slight exponent. The director draws weighted types it can
afford (an expensive golem eats the budget of a dozen slimes) until the budget
runs out; `first_wave` introduces new types gradually. The spawn order
is shuffled, and the intervals have jitter — waves don't tick like a metronome.
`get_budget_for_wave(n)` lets you preview the curve while tuning.

**Full control:** `custom_wave_builder = func(n) -> Array[StringName]` —
return a list of ids and wave N will be exactly that (an empty array = fall back to
the director). **Repeatability:** `rng_seed` ≠ 0 gives deterministic runs
(speedrun-friendly, tests).

## Two spawn modes

1. **Automatic** — `EnemyType.scene` set + `spawn_position_provider`:
   the spawner instantiates the enemy under `spawn_parent` and detects its death
   itself (`tree_exited`).
2. **Signal** — `scene = null`: the spawner emits `spawn_requested(type, pos)`,
   the game spawns its own way and reports death via `notify_defeated()`.
   The modes can be mixed per type.

## API — `WaveSpawner`

**Methods:** `start()`, `stop()`, `call_next_wave_early()` → skipped seconds
(pay a bonus like in TD), `notify_defeated()`, `get_wave()`,
`get_alive_count()`, `get_remaining_in_queue()`, `get_countdown_left()`,
`is_running()`, `build_wave(n)` (composition preview), `get_budget_for_wave(n)`,
`to_dict()` / `from_dict()` (resumes from the break before the saved wave).

**Signals:** `countdown_started(time)`, `wave_started(number, enemy_count)`,
`enemy_spawned(type, node, position)`, `spawn_requested(type, position)`,
`spawning_finished(number)`, `wave_cleared(number)`, `all_waves_cleared()`.

**Exports:** budget (`first_budget`, `budget_add`, `budget_growth`), pace
(`spawn_interval`, `interval_jitter`, `break_time`), bosses (`boss_every`,
`boss_id`), `max_waves` (0 = endless), `rng_seed`.

## API — `WaveStatusUI`

A panel with the wave number and an enemy counter; during the break a countdown bar
+ a "CALL NOW" button (the `early_call_bonus(skipped_seconds)` signal).
At the start of a wave a big "WAVE N" banner (red variant on a boss —
set `boss_every` to match the spawner).

## Demo

`demo/wave_spawner_demo.tscn` — an arena: click the slimes, waves scale with budget,
every 3rd wave is a boss, calling a wave early pays gold (floating text).
