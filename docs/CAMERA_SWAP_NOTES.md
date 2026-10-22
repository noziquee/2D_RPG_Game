# Camera swap: CameraDirector replaces the player's Camera2D

## Changes
- `addons/camera_system/` adopted from the add-on, unchanged. It provides `CameraDirector`, a Camera2D with a deadzone, look-ahead, zoom easing, bounds (unused here), focus, and trauma shake.
- `player.tscn`: the player's own `Camera2D` (zoom 5) is removed. The player scene no longer owns a camera.
- `node_2d.tscn`: a `CameraDirector` node follows the player (`target = NodePath("../Player")`), keeps the zoom of 5 that the player camera had, and is the only camera in the level.
- `UI/Feedback/CombatFeedback.gd`: shake goes through `CameraDirector.add_trauma()` rather than `ScreenEffects.shake()`. The director rewrites the camera's offset every frame, so a second shaker would fight it. Flashes and hit-stop still come from `ScreenEffects`.
- Shake strengths were rebalanced for the director's shake scale (peak 28 px at full trauma, quadratic falloff). Player hit 0.7, enemy hit 0.3, crit 0.6, kill 0.8 (through `impact`).

## Notes
- The enemy health bar is a CanvasLayer that projects positions through the viewport canvas transform. It keeps working with the director's zoom and follow.
- The director's bounds are off (zero-size Rect2). Set `bounds` on the `CameraDirector` node when levels have edges.

## Tests
- `tests/cases/test_camera.gd` (from the add-on) runs in the runner: deadzone, trauma, focus, and easing.

## Validation
Static checks only. Check in Godot 4.7: the camera follows smoothly without jitter, zoom is 5, hits shake the view at the strengths above, the enemy bars stay put, and the test runner passes.
