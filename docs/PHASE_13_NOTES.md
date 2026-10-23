# Phase 13 — Enemy variety, spawning, and a painted level

## Enemies
- `Characters/Enemies/Slime.tscn`: inherits `BasicEnemy2D.tscn`. Overrides: its own idle and run sprites (6 frames each, from the slime sheets), 2 health, move speed 40, a 1-damage attack with a 0.9 s cooldown and 120 px/s knockback. The knife is hidden.
- `Characters/Enemies/FlyingEnemy.tscn`: inherits `BasicEnemy2D.tscn`. Overrides: the fly sheet (4 frames, used for both idle and run), 1 health, move speed 70, `collision_mask = 0` so it ignores walls. The knife is hidden.
- Both share the goblin's AI, animation, hit reaction, death, and health bar code. Behavior is set in the scene, not in code.

## Limitations (to finish with the art)
- **No death clip** on either enemy. Their death uses the 1-second fallback removal with a warning. Add a non-looping `death` animation to each SpriteFrames to remove the warning.
- **No attack clip.** They use the shared slash timing and hitbox, with the knife hidden. A bespoke bite or dive needs its own clip.
- **The flying enemy is not visually airborne** (no bobbing). It only ignores walls.

## Spawning (adopted `wave_spawner_system`)
- `addons/wave_spawner_system/core/`: `WaveSpawner`, `EnemyType`. No UI adopted.
- `Waves/slime_type.tres` (cost 1, weight 2, from wave 1) and `Waves/fly_type.tres` (cost 2, weight 1, from wave 2).
- Enemies are counted by their `tree_exited`, so the existing death path updates the spawner. No change to enemy code was needed.
- `EnemyAIController2D` is unchanged. Detection uses its existing radius. A timer-based or Area2D detection and NavigationAgent2D are deferred: the room has no navigation mesh yet, and the current radius works for the demo.

## Level
- `World/Level/Level.gd` on the root of `node_2d.tscn`. It paints a 26×15-tile room from a text layout (`#` wall, `.` floor) onto two `TileMapLayer`s. Floor uses `floor_1`/`floor_2`, walls use `wall_1`, each as its own one-tile atlas source. Every wall cell gets a collision box on layer 1, and two pillars give cover.
- The room wraps the demo objects that were already placed (chest, door, pickups, coin, goblins, player).
- The spawner starts one frame after the level is ready. Spawn points are random inside the room, at least 80 px from the player.

## Procgen
Evaluated and deferred: see `PROCGEN_EVALUATION.md`.

## Tests
`tests/cases/test_level_and_enemies.gd`: slime and fly stats and overrides, the fly ignoring walls, wave types pointing at their scenes, the room painting walls with one collision box per wall cell, spawn points inside the room, and the room building only once.

## Validation
Static checks only. Check in Godot 4.7: the room draws with floor and walls, the player cannot walk through walls or pillars, waves start after a few seconds, slimes appear in wave 1 and flyers from wave 2, flyers pass over walls, enemies chase the player, and each kill lowers the count so the next wave starts. Then run the test runner.
