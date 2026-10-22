# Phase 8 — Action locks and component base

## What changed
- `Characters/Core/ActionLock2D.gd` (new): lock identifiers (`ATTACK`, `DASH`, `DEAD`), capability names (`CAPABILITY_MOVE`, `CAPABILITY_ATTACK`, `CAPABILITY_DASH`), and the blocking table in `blocks()`.
  - Dead blocks move, attack, and dash.
  - An attack blocks attack and dash, but not movement.
  - A dash blocks attack and dash, but not movement (the dash drives movement itself).
- `CharacterContext2D` holds the lock store: `acquire_lock(lock, owner)`, `release_lock(lock, owner)`, `is_locked`, `is_blocked`, and `can(capability)`.
  - Holders are tracked per owner, so acquiring twice and releasing twice are safe.
  - `lock_started` fires on the first holder and `lock_finished` on the last. Only the lock layer emits them.
  - `is_attacking` and `is_dashing` are now read-only properties computed from the ATTACK and DASH locks. Writing to them is a compile error, so any leftover writer fails loudly.
- `Characters/Components/BaseComponent2D.gd` (new): shared `context`, `_initialized`, `is_initialized()`, and a virtual `physics_update`. `MovementComponent2D`, `DashComponent2D`, and `AttackComponent2D` extend it.
- `DashComponent2D` and `AttackComponent2D` acquire their lock on start and release it on finish and on cancel. Their guards check `context.can(...)` instead of the old boolean flags.
- `MovementComponent2D` drops movement intent when move is blocked. Movement still runs so knockback can finish.
- `Character2D`:
  - Death acquires the DEAD lock. Respawn releases it.
  - Input gating uses the move capability instead of `is_alive()`.
  - Each `try_start` checks its own lock, so the controller no longer has to.

## Closed from Phase 7
`AttackComponent2D.try_start()` and `DashComponent2D.try_start()` now refuse while the character is dead. Previously only the controller path enforced this.

## Not changed
- The state classes (`IdleState`, `MoveState`, `DashState`, `AttackState`, `DeadState`) read `is_attacking` and `is_dashing`. Those views still behave the same, so the states needed no edits. The plan named the states for modification; I left them unchanged to keep the regression surface small.
- `HealthComponent2D`, `DamageService2D`, the enemy AI, the player and enemy scenes, and the Camera2D.

## Known limits
- The lock layer does not yet know about stagger, interaction, or cooldown locks. Those arrive with Phases 9 to 11.
- Attack locks release when the `sword_return` animation finishes or when the attack is cancelled. A missing `sword_return` clip would leave the attack lock stuck, so the AnimationPlayer must keep that clip.

## Tests
New suite `tests/cases/test_action_locks.gd`: the blocking table, signal behavior on first acquire and last release, attack and dash refusing each other, dead refusing attack and dash, respawn releasing the dead lock, death cancelling an attack with the signal fired, and the read-only views following the locks.
Run: `godot --headless --path . res://tests/test_runner.tscn`

## Validation
Static checks only. No Godot executable was available, so nothing here has been run in the editor. Before treating Phase 8 as done, check in Godot 4.7: attack then dash, dash then attack, a full attack cycle (the attack lock must release so the next swing works), death mid-attack and mid-dash, respawn and then attacking, and the goblin still chasing and attacking.
