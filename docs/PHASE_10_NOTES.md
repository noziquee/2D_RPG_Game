# Phase 10 — Stats and status effects

## Decision: rebuild, not adopt
The add-on's `stats_system` is a pool model (value, max, regen) and its `status_effects_system` modifies a Stat's maximum. Both are built around their own Stat nodes, so adopting them would mean a second health model next to `HealthComponent2D`, and rewiring damage and death. The plan's rule puts this kind of system on the rebuild side, so these are our own components, following the add-on's design: flat and percent modifiers, refresh or stack stacking, and timed ticks.

## New
- `Characters/Components/Stats/StatsComponent2D.gd`: base values plus modifiers grouped by source. Derived value = (base + Σflat) × (1 + Σpercent). `stat_changed` fires only on a real change.
- `Characters/Components/Stats/StatModifier2D.gd`: one stat change (flat, percent) as a Resource.
- `Characters/Components/Status/StatusEffect2D.gd`: a timed effect (duration, REFRESH or ADD_STACK stacking, max stacks, modifiers, optional damage-over-time tick).
- `Characters/Components/Status/StatusEffectComponent2D.gd`: applies, stacks, expires, and removes effects. Ticks go through `receive_damage()` with the tag `dot`, so defense and death apply and the character is not stunned by a tick.

## Changed
- `Character2D`: owns a stats and a status component. Base `move_speed` and `max_health` are stats. A `move_speed` change moves the body, and a `max_health` change calls `HealthComponent2D.set_max_health`. `get_stat()` and `apply_status()` are the public API. Death clears all effects so no modifier outlives the character. A `dot` hit does not start a hit reaction.
- `DamageService2D._mitigate()`: defense applies as 100 / (100 + defense), with a floor of 1 damage for any hit that deals damage. This replaces the placeholder.
- `AttackComponent2D`: the attack stat adds to the attack definition's damage.
- `MovementComponent2D`: unchanged. Speed comes from the stat through `Character2D`, so the movement file needs no edits.

## Stat names in use
`move_speed`, `max_health`, `attack` (flat, added to attack damage), `defense` (mitigation). Other names are ignored until a system reads them.

## Tests
`tests/cases/test_stats_and_status.gd`: stat math, modifier replacement, change signals, speed buff and expiry, refresh and stack caps, damage-over-time through the damage path, death clearing effects, defense with its floor, and the attack stat.

## Validation
Static checks only. Check in Godot 4.7: a speed buff changes the player's speed and expires, a debuff with ticks hurts and does not stun, defense reduces goblin damage, and death clears effects. Then run the test runner.
