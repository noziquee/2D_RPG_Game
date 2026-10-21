# Phase 1 — Character foundation and state machine

## What changed
- Added `Characters/Core/Character2D.gd` as the shared `CharacterBody2D` foundation.
- Added `Characters/Core/CharacterContext2D.gd` for shared character references, movement intent, and facing direction.
- Added `Characters/StateMachine/CharacterStateMachine.gd` and the base `CharacterState.gd` contract.
- Added `IdleState.gd` and `MoveState.gd`; these preserve the existing idle/run animation behavior.
- Reduced `player.gd` to a player-specific input adapter.
- Kept the existing player scene, sprite frames, collision shape, input action names, and 200 px/s movement default. Set the scene's initial animation to `idle` so it matches the state machine's initial state.

## Design notes
- The state machine currently supports registration, state entry/exit, physics updates, safe transitions, and a `state_changed` signal.
- `Character2D` temporarily owns velocity and `move_and_slide()` so the existing prototype remains playable. Phase 2 will extract that responsibility into `MovementComponent2D` without changing the public character contract.
- The player supplies intent through `_get_movement_input()`. An enemy character can later override this method or receive intent from its AI controller without duplicating the state machine.
- Dash and attack states are intentionally not registered yet; they will be added with their components in later phases.

## Validation limitation
The Godot executable was not available in the build environment, so this phase was reviewed statically but not launched in the Godot editor. Open the project in Godot 4.7 and run `player.tscn`; verify WASD movement, collision, idle/run animation changes, and horizontal flipping before proceeding.
