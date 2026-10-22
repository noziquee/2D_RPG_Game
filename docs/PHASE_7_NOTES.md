# Phase 7 — Death and hit reaction

## What changed
- Added `Characters/StateMachine/States/DeadState.gd`, registered as `Dead` on every `Character2D`. It accepts no input and starts no actions.
- `Character2D` now enters `Dead` when health reaches zero. Attack and dash are cancelled and the character leaves the `damageable` group before `died` is emitted. Death presentation runs after that, in `_on_death()`.
- The player no longer calls `set_physics_process(false)`. Physics keeps running in the Dead state so knockback can finish.
- Knockback: `DamageRequest2D.knockback_speed` (new) carries the impulse. `Character2D.receive_damage()` passes it to `MovementComponent2D.apply_knockback()`, which is still the only code that moves a body. A new hit replaces the previous impulse rather than stacking. A wall stops it. It decays at 700 px/s² (`KNOCKBACK_FRICTION`). The killing blow still knocks back.
- `AttackDefinition2D.knockback_speed` (default 160 px/s) is passed by `AttackComponent2D` to `AttackSlash2D`, which sets it on each request.
- `Character2D.respawn(health)` revives a dead character, clears knockback, returns to Idle, rejoins the `damageable` group, and emits `respawned`. It returns false if the character is alive. The player's `_on_respawn()` resets the hit-reaction clip.
- Enemy death: the body is hidden, collision is disabled, and a `DeathEffect2D` plays the existing 4-frame explosion sheet where it stood. The node is freed after 0.4 s so knockback can finish. Previously it was freed on the same frame.
- `DeathEffect2D` (`Characters/Effects/`) builds its frames in code and frees itself when the clip ends. No scene file was needed.
- `CharacterContext2D.play_death_animation()` plays a `death` clip when one exists, otherwise freezes the current pose.
- `PlayerHealthBar` leaves the DEAD display when health rises above zero, so a respawned player's HUD recovers.

## Behavior kept
- Lethal hits still fire `health_changed`, then `damaged`, then `died`. The HUD and the enemy health bar need no change.
- Hits on a dead character are still rejected by `DamageService2D` (target dead), so they cause no knockback either.
- The authored `take_damage` clip still plays only on non-lethal hits.

## Deferred (waiting for the player's layered rig)
- Player death clip. Until a `death` clip exists in `Player/CharacterAnimation`, the player freezes on its current pose.
- Respawn position. `respawn()` restores state only; the level decides where the player appears.

## Not touched
`player.tscn`, `BasicEnemy2D.tscn`, `node_2d.tscn`, weapon track paths, the Camera2D, `HealthComponent2D`, `DamageService2D`, and `EnemyAIController2D`.

## Known gap
`AttackComponent2D.try_start()` and `DashComponent2D.try_start()` do not check life. Dead characters are kept from acting by `Character2D._physics_process`, which only requests attacks and dashes while alive. Direct calls to the components bypass that. Moving the check into the components is a candidate for Phase 8, when action locks arrive.

## Tests
New suite `tests/cases/test_death_and_knockback.gd`: Dead state on lethal hit, attack and dash cancelled by death, knockback direction and decay, knockback on the killing blow, no knockback from rejected hits, respawn (explicit and default health), enemy death hides the body and spawns one effect. `test_character_health.gd` now asserts the Dead state instead of the old physics freeze. `test_attack_definition.gd` checks the knockback default.
Run: `godot --headless --path . res://tests/test_runner.tscn`

## Validation
Static checks only. No Godot executable was available, so nothing here has been run in the editor. Before treating Phase 7 as done, check in Godot 4.7: lethal hit on goblin and player, death during attack and dash, knockback distance on both, goblin explosion and removal, player respawn with the HUD recovering, and the test runner's exit code.
