# Phase 2 — Movement component extraction

## Changes
- Added `Characters/Components/Movement/MovementComponent2D.gd`.
- Moved the sole velocity assignment and `move_and_slide()` call out of `Character2D.gd` and into `MovementComponent2D.gd`.
- `Character2D` now gathers movement intent, updates facing, and coordinates the movement component and state machine.
- Kept `move_speed` exported on `Character2D` so it remains easy to tune in the Inspector; updates are forwarded to the movement component.
- Kept the existing `player.gd` input adapter, `player.tscn`, animation resources, collision shape, input action names, and 200 px/s default.
- Movement intent remains in `CharacterContext2D`, allowing future AI to submit intent without owning physics movement.

## Responsibility contract
- Controller / `player.gd`: decides requested movement direction.
- `CharacterContext2D`: carries movement intent and shared character references.
- `MovementComponent2D`: sole authority for setting `CharacterBody2D.velocity` and calling `move_and_slide()`.
- `CharacterStateMachine`: selects behavior state and animation; it does not move the body.
- `Character2D`: coordinates the above and tracks facing direction.

## Validation
Static review only; the Godot executable was not available in this environment. Open the project in Godot 4.7 and check movement, collisions, animation transitions, facing, and changing `move_speed` in the Inspector. Also check the debugger for script parse errors before proceeding to Phase 3.
