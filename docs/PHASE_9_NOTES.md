# Phase 9 — Combat feedback

## Adopted from the game-components add-on (copied unchanged except as noted)
- `addons/screen_effects_system/`: `ScreenEffects` (shake, flash, hit-stop, vignette, fades) and its overlay.
  - **Changed:** the hit-stop restore. The original set `Engine.time_scale = 1.0` when a hit-stop ended, which discarded any other scale in use. It now records the scale when the first slowdown starts and restores that value. Overlapping hit-stops restore only once, in order. A node leaving the tree mid-hit-stop restores the scale too. This is the time-scale fix flagged by the bundle audit.
- `addons/floating_text_system/`: `FloatingTextSpawner`, `FloatingLabel`, `FloatingTextStyle`, and the Fredoka font it loads from its own folder. The font is a second copy of `UI/HUD/Fredoka-Variable.ttf`. Remove it when the HUD moves to `ui_theme_system` (deferred item in the plan).

## New
- `UI/Feedback/CombatFeedback.gd` (a Node2D in `node_2d.tscn`). It listens only to `DamageService2D.damage_resolved`:
  - Enemy hit: a number above the enemy, a small shake. A crit adds a larger impact with hit-stop. A kill adds a stronger impact.
  - Player hit: a "-N" number above the player, a larger shake, and a red flash.
  - The screen effects are bound to the player's existing `Camera2D` by group lookup. `player.tscn` is unchanged.

## Deferred
- **Camera Director swap.** The plan removes the player's raw `Camera2D` only after the layered player rig is finished. Until you confirm that, `player.tscn` keeps its Camera2D and `camera_system` is not adopted yet.

## Tests
`tests/cases/test_combat_feedback.gd`: hit-stop restores the previous scale, overlapping hit-stops, leaving the tree mid-hit-stop, and enemy and player damage producing numbers.

## Validation
Static checks only. Check in Godot 4.7: enemy hit (number, small shake), crit and kill (hit-stop feels brief, and the game returns to normal speed), player hit (red flash and shake), a scene change during a hit-stop, and the test runner's exit code.
