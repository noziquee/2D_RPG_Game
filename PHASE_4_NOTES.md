# Phase 4 — Animation-driven basic sword attack

## Implemented
- Reused the authored `Sword/AnimationPlayer` clips `slash` (0.30 s) and `sword_return` (0.65 s). GDScript no longer creates a Tween for sword rotation or scale.
- Added a call-method track to the Sword `slash` animation at 0.05 s. The track calls `Character2D.spawn_slash()`, which delegates to `AttackComponent2D.spawn_slash_from_animation()`.
- `AttackComponent2D` validates attack requests, captures the aim direction, enforces cooldown/exclusivity, plays the authored `slash` animation, starts `sword_return` when `slash` finishes, and clears the attack lock when `sword_return` finishes.
- `AttackSlash2D.tscn` uses its own `SlashSprite/AnimationPlayer` `slash` clip to animate frame, scale, position, opacity, and the hitbox collision-shape `disabled` property. The effect timeline is 0.65 s and the hitbox is disabled at 0.60 s.
- `AttackSlash2D.gd` no longer calculates visual frame progression, fade, scale, movement, or hitbox duration from an elapsed-time timer. It starts the authored animation and retains only collision setup, overlap handling, target filtering, and once-per-swing hit tracking.
- Added a `take_damage` animation to the goblin scene. `BasicEnemy2D.gd` starts that clip on a nonlethal hit rather than creating a Tween for the hit flash. The visual timeline is editor-authored; the script only requests playback.
- `AttackDefinition2D` now stores attack damage, cooldown, hitbox size, and hitbox offset. Visual animation timing is authored in AnimationPlayer clips, not repeated in resource timing fields or code.
- `CharacterContext2D` caches the existing Sword node and its AnimationPlayer. `Character2D` updates sprite facing/layering without running a code-driven swing.
- The left mouse button remains bound to the `attack` Input Map action. The stationary goblin remains a damageable test target.

## Animation timelines
- Player `Sword/AnimationPlayer/slash`: 0.30 s; contains a method-call key at 0.05 s to spawn the slash effect.
- Player `Sword/AnimationPlayer/sword_return`: 0.65 s; starts after `slash` finishes. The attack lock is released when this clip finishes.
- Slash effect `SlashSprite/AnimationPlayer/slash`: 0.65 s; animates its three-frame sheet, scale, position, alpha, and hitbox collision-shape activation. The supplied spritesheet contains three frames, so the final frame is held after frame 2 rather than using the five-frame sheet from the tutorial.
- Minimum attack interval is the greater of the resource cooldown and the combined durations of `slash` and `sword_return` (0.95 s at the current clip lengths). This prevents re-triggering before the authored return animation completes.

## Responsibility contract
- `player.gd`: reads left-click and returns the mouse-aim direction.
- `Character2D.gd`: coordinates movement, dash, attack/state transitions, and exposes the `spawn_slash()` method called by the animation track.
- `CharacterContext2D.gd`: supplies shared references to the character, Sword, and Sword AnimationPlayer.
- `AttackComponent2D.gd`: owns attack eligibility, cooldown, attack lifecycle signals, animation playback/transition, and creation of the slash effect at the animation event.
- `AttackDefinition2D.gd` / `DefaultAttackDefinition.tres`: hold damage and hitbox configuration.
- `AttackSlash2D.tscn`: owns the authored slash effect animation and keyframed hitbox active window.
- `AttackSlash2D.gd`: configures hitbox dimensions, receives overlaps, filters damageable targets, and prevents the same target taking damage more than once per swing.
- A target joins `damageable` and implements `take_damage(amount)` to receive this first-pass attack.
- Dash and attack cannot start while the other action is active. Rejected attacks are not queued.

## Manual verification checklist
1. Open the project in Godot 4.7 and check the debugger for script/resource errors.
2. Run the configured main scene (`node_2d.tscn`); the player and goblin targets should be visible.
3. Move with WASD; move the mouse around the player and check left/right facing and sword front/behind ordering.
4. Left-click and confirm `slash` plays, the slash effect appears at 0.05 s, and `sword_return` starts automatically when `slash` finishes.
5. Confirm damage occurs only while the slash animation's collision-shape track is active, and each target takes damage only once per swing.
6. Confirm the sword cannot restart while the return clip is playing, and cooldown settings can lengthen but not shorten the clip-defined cycle.
7. Verify the goblin plays `take_damage` after nonlethal hits and is removed when its health reaches zero.
8. Press Space during an attack and click during a dash; neither action should begin while the other is active.
9. Move the target outside the hitbox and confirm the attack misses.

## Validation limitation
The updated source and resource paths were statically checked, but no Godot executable is available in this environment. The project still needs an engine import/run test to validate AnimationPlayer call-method execution, animation signal transitions, collision timing, and GDScript parser compatibility before Phase 5.
