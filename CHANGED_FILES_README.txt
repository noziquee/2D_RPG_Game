Phase 4 — Basic Sword Attack
=============================

This bundle contains only the new or modified files from the implementation.

Modified existing files:
- README.md
- project.godot
- player.gd
- player.tscn
- Characters/Core/Character2D.gd
- Characters/Core/CharacterContext2D.gd

New files:
- Characters/Components/Combat/AttackDefinition2D.gd
- Characters/Components/Combat/AttackComponent2D.gd
- Characters/Components/Combat/AttackSlash2D.gd
- Characters/Components/Combat/AttackSlash2D.tscn
- Characters/Components/Combat/DefaultAttackDefinition.tres
- Characters/StateMachine/States/AttackState.gd
- Characters/Enemies/BasicEnemy2D.gd
- Characters/Enemies/BasicEnemy2D.tscn
- combat_test_arena.tscn
- PHASE_4_NOTES.md

Input:
- WASD: move
- Left mouse button: aim and attack
- Space: dash

Open the full project in Godot 4.7 and run the main scene to validate. Static checks passed, but a Godot executable was unavailable in the build environment, so runtime parsing and gameplay were not exercised here.
