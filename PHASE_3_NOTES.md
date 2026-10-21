# Phase 3 — Dash component

## What changed
- Added `Characters/Components/Dash/DashComponent2D.gd` to handle dash requests, direction, duration, cooldown, and cancellation.
- Added `Characters/StateMachine/States/DashState.gd` so the state machine represents the dash period.
- Extended `CharacterContext2D` with shared dash state and dash velocity.
- Updated `MovementComponent2D` to apply dash velocity while dashing. It remains the only script that sets the body velocity and calls `move_and_slide()`.
- Added a `dash` input action bound to **Space**. `player.gd` only reports the input request.
- Exposed dash speed, duration, and cooldown in the Character2D Inspector.

## Default tuning
- Dash speed: 600 px/s
- Dash duration: 0.16 seconds
- Cooldown: 0.45 seconds

Dash direction follows current movement input. If no direction is pressed, it uses the last horizontal facing direction (right by default). The dash does not change the collision shape or bypass walls; normal `CharacterBody2D` collision handling remains active.

## Responsibility contract
- `player.gd`: detects the Space press.
- `Character2D`: coordinates the request, movement, and state machine.
- `DashComponent2D`: owns dash timing and cooldown, and publishes dash intent through the shared context.
- `MovementComponent2D`: sole authority for applying velocity and moving the body.
- `DashState`: manages the character's state while the dash is active.

## Validation
Static inspection and ZIP integrity checks only. A Godot executable was not available here, so this project has not been run in the Godot editor. Open the project in Godot 4.7, press WASD to move and Space to dash, then inspect the debugger for parse/runtime errors. Try dashing into a wall and repeatedly pressing Space to confirm collision and cooldown behavior.
