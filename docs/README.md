# 2D Hack and Slash

## Framework progress
- Phase 1: shared `Character2D` foundation and state machine (`PHASE_1_NOTES.md`).
- Phase 2: movement component extraction (`PHASE_2_NOTES.md`).
- Phase 3: dash component and Dash state (`PHASE_3_NOTES.md`).
- Phase 4: AnimationPlayer-driven sword attack, animation call-method spawn event, keyframed slash hitbox window, and training enemy with an authored hit reaction (`PHASE_4_NOTES.md`).
- Phase 5: `EnemyAIController2D` target acquisition, chase, shared animation-driven melee attacks, target-loss grace period, return-home behavior, and a damageable player (`PHASE_5_NOTES.md`).
- Phase 6: shared `HealthComponent2D`, structured `DamageRequest2D` / `DamageResult2D` through `DamageService2D`, `Groups2D` (`PHASE_6_NOTES.md`).
- Phase 7: Dead state, knockback through `MovementComponent2D`, respawn hook, enemy death explosion (`PHASE_7_NOTES.md`).
- Phase 8: action locks in `CharacterContext2D` decide move, attack, and dash; `BaseComponent2D` shared by components (`PHASE_8_NOTES.md`).

## Controls
- **WASD** — move
- **Left mouse button** — sword attack toward the cursor
- **Space** — dash

The configured main scene is `node_2d.tscn`. Its goblins use the Phase 5 basic AI and chase/attack the player when detected.
- Dynamic health bars: player HUD bar with delayed damage trail/color thresholds, and floating enemy bars that appear when damaged.
- Dynamic health bars: player HUD bar with delayed damage trail/color thresholds, and floating enemy bars that appear when damaged. See `HEALTH_BAR_NOTES.md`.

- Player body locomotion uses the authored `idle` and `run` clips in `Player/CharacterAnimation`; `take_damage` plays through that same AnimationPlayer. Enemy scenes remain compatible with their existing `AnimatedSprite2D` animations.
