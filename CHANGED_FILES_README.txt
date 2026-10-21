PHASE 5 — BASIC ENEMY AI

Apply these files to the matching paths in the existing Phase 4 animation-driven project:
- Characters/Controllers/EnemyAIController2D.gd (new)
- Characters/Components/Combat/GoblinAttackDefinition.tres (new)
- Characters/Core/CharacterContext2D.gd (updated weapon mirror pivot / animation call track routing)
- Characters/Core/Character2D.gd (updated weapon pivot mirroring)
- Characters/Components/Combat/AttackSlash2D.gd (friendly-fire filtering)
- Characters/Components/Combat/AttackSlash2D.tscn (player/enemy hitbox collision mask)
- Characters/Enemies/BasicEnemy2D.gd (now composes Character2D systems and forwards intent to AI)
- Characters/Enemies/BasicEnemy2D.tscn (AI node, knife, authored weapon animations, attack resource)
- player.gd (player group, health receiver, death disable)
- node_2d.tscn (spaced test positions)
- README.md and PHASE_5_NOTES.md (documentation)

The full-project archive is the easiest option if you want to avoid missing a dependency. Static checks were performed; Godot runtime import/playtesting was unavailable.
