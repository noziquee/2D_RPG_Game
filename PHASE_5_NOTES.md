# Phase 5 — Basic enemy AI and combat loop

## Implemented
- Added `Characters/Controllers/EnemyAIController2D.gd` as an intent-only controller. It acquires the nearest live node in the configured player group, chases it, requests attacks in range only when the shared `AttackComponent2D` is ready, and returns to its home point after the target is lost.
- Converted `BasicEnemy2D.gd` from a standalone `CharacterBody2D` damage target into a `Character2D` subclass. It now uses the same movement, state machine, dash component, attack component, and animation-driven attack lifecycle as the player.
- Added a knife visual and authored `slash` / `sword_return` AnimationPlayer clips to the goblin scene. The attack component is still used for hitbox spawning and attack rules; no AI-specific damage implementation was added.
- Added `GoblinAttackDefinition.tres` for per-enemy damage/hitbox/cooldown tuning.
- Added first-pass player health and `take_damage()` so enemies can attack the player. At zero health, player input/physics is disabled and `died` is emitted.
- Added `player` / `enemy` groups and basic same-team hit filtering so goblins do not damage one another.
- Expanded the slash Area2D collision mask to include both player (layer 1) and enemy (layer 2) bodies.
- Moved the two goblins farther from the player in `node_2d.tscn` so detection and chase can be observed when running the main scene.
- Updated `CharacterContext2D` to place the weapon under a `WeaponFlipPivot`, keeping the sword's left-facing mirroring consistent for both player and enemy. Animation call-method tracks are retargeted to the Character2D root.

## AI behavior
1. Idle at the scene-start/home position when no player is detected.
2. Acquire the nearest live node in `target_group` within `detection_radius`.
3. Chase by returning a normalized direction as movement intent; `MovementComponent2D` remains the only code that sets normal movement velocity and calls `move_and_slide()`.
4. Stop and request an animation-driven attack within `attack_range`, respecting the shared attack cooldown and current attack lifecycle.
5. Retain a target briefly when it moves beyond `disengage_radius`; after `lost_target_grace_duration`, return home. The enemy can reacquire a player who comes back within detection range.

## Scene changes
- `BasicEnemy2D.tscn` now has the same `AnimatedSprite2D`, `CollisionShape2D`, weapon + AnimationPlayer, and `EnemyAIController2D` configuration. The enemy root script subclasses `Character2D`.
- `node_2d.tscn` remains the main scene. The player and two goblins are spaced to demonstrate chasing.

## Controls
- WASD: move
- Left mouse: animation-driven sword attack toward cursor
- Space: dash

## Known scope limits
- AI uses direct normalized chasing; no obstacle pathfinding, patrol route, line-of-sight, or ranged behavior was added.
- Player death disables physics/input and emits `died`; a dedicated Dead state, respawn flow, and health UI remain future work.
- Health is intentionally a minimal first-pass receiver on player/enemy scripts, not yet a standalone HealthComponent2D.

## Validation
Static source/resource checks only. A Godot 4.7 executable was not available in this environment, so open/import the project and test chase, range, cooldown, collision, death, and target-loss behavior in the editor before treating the phase as runtime-verified.
