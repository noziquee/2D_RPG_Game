# Enemy health bar: screen-space rendering

## Cause of the blur
The enemy bar was a Control under the goblin, in world space. The player's Camera2D has zoom 5, so the bar and its text were magnified five times (a 76 px bar was about 380 px on screen), which looked large and soft.

## Fix
- `EnemyHealthBar2D` is now a CanvasLayer (layer 5), still a child of the enemy so it is freed with it. Its `Bar` control has a fixed screen size of 56 x 16 px.
- Each frame, `_process()` projects the enemy's world position (plus `HEAD_OFFSET`) through `get_viewport().get_canvas_transform()`, the same approach the add-on's `InteractionPromptUI` uses. The bar tracks the goblin and does not scale with camera zoom.
- The label is 8 px. Padding is 4 px horizontally and 2 px vertically.
- `BasicEnemy2D.tscn`: the four position overrides on the bar instance were removed, because a CanvasLayer has no offsets.

## Tuning
- Bar size: `custom_minimum_size` on the `Bar` node in `EnemyHealthBar2D.tscn`.
- Height above the goblin: `HEAD_OFFSET.y` in `EnemyHealthBar2D.gd` (world units).

## Validation
Static checks only. Check in Godot 4.7: bar sits above each goblin, stays crisp while moving and when the goblin flips, hides until hit, and disappears with the goblin's death.
