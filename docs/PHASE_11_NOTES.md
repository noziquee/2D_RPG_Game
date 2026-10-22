# Phase 11 — World interaction, loot, and inventory

## Scope
Adds the first reusable world-content loop: press **E** near an interactable; open a one-shot chest; receive a guaranteed silver key plus weighted bonus loot and coins; collect a potion pickup; spend the key to open a door. Item identity uses stable `StringName` IDs, not labels or resource paths.

## New files
- `Characters/Components/Interaction/InteractionComponent2D.gd`: nearest-target query, interact signals, interaction lock acquisition/release.
- `Characters/Components/InventoryComponent2D.gd`: stack inventory, capacity checks, remove/count, safe ID-based save data serializer and catalog-driven loader.
- `Characters/Components/CurrencyComponent2D.gd`: guarded earning/spending and state serialization.
- `Items/`: stable item definitions, stacks, weighted loot entries and tables, plus sample key/potion/coin content.
- `World/Interactables/`: one-shot chest and key door scripts/scenes.
- `World/Pickups/`: item and coin pickup scenes.
- `tests/cases/test_world_loop.gd`: inventory, currency, and loot-table assertions.

## Existing files to merge
This delivery contains replacement files for `Characters/Core/ActionLock2D.gd`, `Characters/Core/Character2D.gd`, and `player.gd`, because the interaction component is initialized and polled by the shared character pipeline. It also contains the full `project.godot` with the E-key `interact` action and the test runner updated to include the Phase 11 suite.

## Integration checklist
1. Copy the new files and resource/scenes into the same paths.
2. Replace `project.godot` with the included version, or merge only the `interact` action under `[input]` if you have local project settings you need to preserve (E key).
3. The included `tests/test_runner.gd` already includes `res://tests/cases/test_world_loop.gd` and preserves the existing suite list/reporting flow.
4. Instance `World/Interactables/Chest2D.tscn`, `World/Interactables/KeyDoor2D.tscn`, `World/Pickups/ItemPickup2D.tscn`, or `World/Pickups/CoinPickup2D.tscn` in a test level. Place them within the player's 56-pixel interaction radius and press E.
5. Confirm the project imports the referenced existing textures under `Assets/props_itens/` and `Assets/tiles/wall/`.
6. Run `godot --headless --path . res://tests/test_runner.tscn` in Godot 4.7, then manually verify chest one-shot behavior, full-inventory rejection, key consumption, and door collision disable.

## Notes and boundaries
- Chest and door/pickup scripts expose `save_state()`/`load_state()` and stable IDs for Phase 12, but no global persistence manager is introduced here.
- Save loading uses a caller-provided item catalog and never loads a path from save data.
- Item effects (e.g. drinking a potion) are not implemented; the pickup/inventory loop only collects the item.
- Interaction target selection is distance-based and uses the `interactable` group, not Area2D overlaps, so it works with StaticBody2D chests/doors and Area2D pickups.
- Static implementation only. Godot is not available in this environment, so scripts/scenes were not engine-parsed or runtime-tested.
