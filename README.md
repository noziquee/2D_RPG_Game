# 2D Hack and Slash

## Framework progress
- Phase 1: shared `Character2D` foundation and state machine (`PHASE_1_NOTES.md`).
- Phase 2: movement component extraction (`PHASE_2_NOTES.md`).
- Phase 3: dash component and Dash state (`PHASE_3_NOTES.md`).
- Phase 4: AnimationPlayer-driven sword attack, animation call-method spawn event, keyframed slash hitbox window, and training enemy with an authored hit reaction (`PHASE_4_NOTES.md`).
- Phase 5: `EnemyAIController2D` target acquisition, chase, shared animation-driven melee attacks, target-loss grace period, return-home behavior, and a damageable player (`PHASE_5_NOTES.md`).

## Controls
- **WASD** — move
- **Left mouse button** — sword attack toward the cursor
- **Space** — dash

The configured main scene is `node_2d.tscn`. Its goblins use the Phase 5 basic AI and chase/attack the player when detected.
