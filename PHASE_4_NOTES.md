# Phase 4 — Basic directional sword attack

## Implemented
- Added `AttackDefinition2D` as a Resource for attack damage, windup, active frames, recovery, cooldown, swing angle, hitbox size/offset, and slash-effect scale.
- Added `AttackComponent2D` to validate requests, capture the aim direction, enforce the attack/recovery lock and cooldown, animate the sword pivot, spawn the slash scene, and publish attack lifecycle/hit signals.
- Added `AttackState` to represent the attack lock while still allowing movement and keeping idle/run visuals responsive.
- Added `AttackSlash2D.tscn` and `AttackSlash2D.gd`. The active Area2D hitbox is disabled outside the defined active window. Each damageable target can be hit only once per swing; separate targets can be hit by the same swing.
- Added a sword sprite to the existing Player scene and mouse-directed aiming/facing in `player.gd`.
- Added the `attack` Input Map action on the left mouse button.
- Added a stationary goblin training target implementing `take_damage(amount)` and the `damageable` group.
- Added `combat_test_arena.tscn` as the main scene so the player and target are present for immediate testing.

## Default attack tuning
- Damage: 1
- Windup: 0.04 s
- Active hitbox: 0.16 s
- Recovery: 0.32 s
- Minimum effective cooldown: 0.55 s
- Swing arc: 110 degrees
- The hitbox is centered in front of the player and rotated into the captured mouse-aim direction.

Tune these values on the Player's **Attack** resource in the Inspector or in `Characters/Components/Combat/DefaultAttackDefinition.tres`.

## Responsibility contract
- `player.gd`: reads attack input and provides aim direction.
- `Character2D.gd`: coordinates movement, dash, attack, and state transitions.
- `AttackComponent2D.gd`: owns attack eligibility, timing/recovery/cooldown, sword-pivot tween, and slash spawn.
- `AttackDefinition2D.gd`: holds per-attack tuning data.
- `AttackSlash2D.gd`: owns its brief visual effect, active hitbox, and per-target-per-swing hit tracking.
- A target joins `damageable` and implements `take_damage(amount)` to receive this first-pass attack.
- Dash and attack cannot start while the other action is active. The attack does not currently queue rejected inputs.

## Test checklist
1. Run the main scene. The player and goblin should be visible.
2. Move with WASD; move the mouse around the player to aim and flip horizontally.
3. Left-click while the goblin is in front of the sword to swing and deal one damage.
4. Hold/click repeatedly and verify attacks respect recovery/cooldown rather than restarting every frame.
5. Verify the goblin only loses one health per swing, flashes after nonlethal hits, and is removed at zero health.
6. Press Space during an attack and click during a dash. Neither action should interrupt/start during the other action's lock.
7. Move the enemy just outside the hitbox and verify the slash does not damage it.

## Validation limitation
The source was statically inspected, but a Godot executable was not available in this environment. Open the project in Godot 4.7 and run the main scene to validate parsing, import, hit detection, and animation timing in-engine before extending the combat system.
