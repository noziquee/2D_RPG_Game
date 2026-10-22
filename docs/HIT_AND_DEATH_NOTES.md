# Hit reaction and death: authored clips

## Behavior
- A hit that does not kill plays `take_damage` on the character's AnimationPlayer and holds the HURT lock. HURT blocks movement and dash, and cancels an active dash. Attacks stay available.
- When `take_damage` finishes, the character plays `RESET`, releases HURT, and re-runs its current state so the idle or run clip resumes. This fixes the frozen last frame and the run clip that only appeared after returning to idle.
- A lethal hit releases HURT, resets the pose, and enters the Dead state, which plays the authored `death` clip. The player uses `Player/CharacterAnimation`; the goblin uses `AnimatedSprite2D`.
- The goblin is removed when its `death` clip finishes. The goblin's knife is hidden during death. Knockback still applies to the killing blow.

## Scripts
- `ActionLock2D`: new `HURT` lock; HURT blocks move and dash.
- `CharacterStateMachine.refresh_current_state()`: re-runs the current state's enter().
- `CharacterContext2D.play_locomotion_animation()`: yields to HURT and DEAD locks instead of checking clip names.
- `Character2D`: owns the hit-reaction flow. Subclasses only override `_get_hit_reaction_player()`.
- `player.gd`, `BasicEnemy2D.gd`: remove their own hit and death code.
- `DeathEffect2D` (removed): the code-driven explosion, replaced by the authored clips.

## Scene requirements (set in the editor)
- **BasicEnemy2D, AnimatedSprite2D, SpriteFrames: the `death` animation must have Loop turned off.** A looping clip never finishes, so the goblin is only removed by a 1-second fallback and a warning. Also set the default animation back to `idle`; the scene currently starts on `death`.
- **Player, CharacterAnimation: the `death` clip must exist** (it does in your current scene). Its `take_damage` and `RESET` clips must not loop.

## Validation
Static checks only. Not run in Godot. Check in Godot 4.7: walk and get hit (movement stops, the hit plays, movement resumes, the run clip continues), dash into a hit, die during a hit, die while walking, goblin death removal, and the test runner's exit code.
