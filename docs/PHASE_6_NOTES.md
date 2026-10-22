# Phase 6 — Health and damage foundation

## What changed
- `HealthComponent2D` now owns health, invulnerability and death for every `Character2D`. Death fires once.
- `DamageRequest2D`, `DamageResult2D` and `DamageService2D` replace the bare `take_damage(int)` path. The service validates (missing target, dead, self, friendly fire, invulnerable, zero damage), mitigates (critical multiplier only for now), applies, then emits `damage_resolved` on the shared instance.
- `Character2D` creates the health component, re-emits `health_changed(int, int)` and `died` (the HUD is untouched), adds `damage_received(result)`, `receive_damage(request)`, `is_alive()` and `health`. `take_damage(int)` still works as a wrapper.
- `player.gd` and `BasicEnemy2D.gd` no longer track health. They keep their exported `max_health` and override `_get_max_health()`, `_on_damaged()` and `_on_death()`.
- `AttackSlash2D` builds a request and no longer holds the team rule.
- `Groups2D` holds the group names and the same-team rule (the small part of Phase 0 that Phase 6 needs).

## Behavior kept
Player death still freezes physics; enemies still `queue_free()` on death; the authored `take_damage` hit animation still plays only on non-lethal hits.

## Not touched
`player.tscn`, every other scene, `project.godot`, the HUD scripts, and `EnemyAIController2D`.

## Tests
`godot --headless --path . res://tests/test_runner.tscn` (exit code = failed assertions). Add new suites to `SUITES` in `tests/test_runner.gd`. `test_case.gd` and `test_runner.gd` come from the game-components add-on.

## Hooks for later phases
- Phase 7: knockback reads `request.direction`; Dead state replaces `_on_death()`; `HealthComponent2D.revive()` is the respawn hook.
- Phase 9: listen to `DamageService2D.get_default().damage_resolved` for shake, hit-stop and damage numbers.
- Phase 10: armor and stats go in `DamageService2D._mitigate()`.
- Phase 12: `HealthComponent2D.save_state()` and `load_state()`.
