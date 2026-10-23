# Phase 11 — World interaction, loot, and inventory

## Adopted from the game-components add-on (core only)
- `addons/interaction_system/core/`: `Interactable`, `Interactor`. **Changed:** `Interactor` gets an optional `gate` Callable. When it returns false, `trigger()` does nothing. The player's gate refuses interaction while dead or while the INTERACT lock is held.
- `addons/loot_table_system/core/`: `LootTable`, `LootEntry` (weighted picks, guaranteed entries, pity counters).
- `addons/inventory_system/core/`: `Inventory`, `ItemDefinition`, `ItemDatabase`, `ItemStack`, plus the item icon used by `ItemDefinition`.
- `addons/currency_system/core/`: `Wallet`, `CurrencyDefinition`.
- UI panels (inventory, wallet bar, loot results, interaction prompt) are not adopted yet. They belong to the deferred HUD theme migration. Messages use the existing floating text.

## Locks
- `ActionLock2D.INTERACT`: held while a chest lid opens. It blocks move, attack, dash, and other interactions.
- The chest holds the lock on the character and releases it after 0.35 s.

## Stable IDs and saved state
- Every item and currency has an id: `potion_health`, `key_silver`, `coins`.
- Every world object has an `id` (Interactable export, or an export on CoinPickup): `chest_start`, `door_east`, `potion_start`, `key_floor`, `coins_start`.
- Saved state exists from day one: `Chest.opened`, `Door.opened`, `ItemPickup.collected`, `CoinPickup.collected`. Phase 12 reads and restores these.

## World content
- `Items/`: `potion_health.tres`, `key_silver.tres`, `coins.tres`, `chest_loot.tres`. The chest loot guarantees one key and rolls a potion, so the demo is always solvable. Tune the chance in `chest_loot.tres`.
- `World/Interactables/`: `Chest`, `Door` (blocks movement until opened), `ItemPickup`, `CoinPickup` (Area2D, collected on contact). Each has a `.tscn`.
- `node_2d.tscn`: one chest, one door, two item pickups, one coin pickup near the spawn.

## Input
- `project.godot`: new action `interact` on **E**. Space stays dash, and `ui_accept` also uses Space, so the add-on's fallback is not used.

## Player
- `player.gd`: owns `inventory`, `wallet` (registers `coins`), and `interactor` (created in code, with the gate).

## Tests
`tests/cases/test_world_interaction.gd`: interact lock blocking, the gate wiring, chest paying once and locking while open, door needing and spending a key, item pickup once, coin pickup once.

## Validation
Static checks only. Check in Godot 4.7: walk to the chest and press E (lid opens, you are briefly locked, the key and potion messages appear), press E at the door without a key ("Needs a key"), then with the key (door opens, the key is spent, the door stops blocking), pick up the potion and key, collect coins, and run the test runner.
