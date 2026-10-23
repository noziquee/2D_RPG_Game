# Phase 12 — Persistence

## Save manager (adopted, then hardened)
`addons/save_system/core/save_manager.gd` is the add-on's SaveManager with the audit's hardening points:
- **Atomic writes.** The save goes to `<slot>.json.tmp`, is checked (it must encode as JSON), and only then replaces the slot. The previous save is kept as `<slot>.json.bak`. If the replace fails, the backup is restored, so a failed write never loses the last good save.
- **Slot validation.** Names must match `[A-Za-z0-9_-]{1,32}`. A slot can never be a path.
- **Corruption fallback.** A corrupt or malformed primary file falls back to the backup.
- **Shape checks.** A file must have a `meta` and a `state` dictionary. Each system's data must be a dictionary before the system receives it.
- **Error isolation.** A system that rejects its data (returns false) is reported and skipped. The other systems still load.
- **Versioning.** `save_version` (1) is checked; `migrator` handles older versions when one is set.
- The add-on's autosave and its save-panel UI are not adopted. The save panel belongs to the HUD migration.
- `save_migrations.gd` is copied unchanged.
- Registered as the autoload `Saves` in `project.godot`.

## What is saved
| System | Key | Contents | Load behavior |
| --- | --- | --- | --- |
| Player | `player` | health, position | Validated in full before anything changes. Clears attacks, dashes, statuses, knockback, hurt and interact locks, and returns to Idle. A dead player is respawned at the saved health. |
| Inventory | `inventory` | capacity, slots as `{id, count}` | Every item id must exist in `Items/item_database.tres`, and counts must fit the stack limit. No resource paths are stored or loaded. |
| Wallet | `wallet` | balances by currency id | Negative or non-numeric balances rejected. |
| Chest | `world:<id>` | `opened` | Restores the closed or open sprite. |
| Door | `world:<id>` | `opened` | Restores the open sprite and disables its blocker. |
| Item pickup | `world:<id>` | `collected` | Hidden and disabled when collected, restored visible otherwise. |
| Coin pickup | `world:<id>` | `collected` | Hidden and stops detecting when collected. |

Pickups hide instead of freeing, so loading can bring them back without reloading the level.

## Controls
- **F5** quick-saves to slot `quicksave`. **F9** quick-loads it.

## Known limits
- GDScript cannot catch an exception thrown inside a system's load function. Isolation works by validating data first and by rejecting bad data with false. Each system must keep its own load function validating its input.
- Level state is saved per object `id`. Every saved object needs a unique id; objects without one are not saved (a warning is printed).
- Transient combat state is never saved. A loaded character always starts Idle.

## Tests
- `tests/cases/test_persistence.gd`: round trips, invalid slot names, missing saves, corrupt primary falling back to the backup, malformed structure, isolation of a rejecting system, a system returning a non-dictionary, and delete.
- `tests/cases/test_game_save.gd`: player health and position, dead-player load, transient state reset, rejection of invalid player data with no partial change, inventory by id with unknown and oversized rejects, wallet, chest and door flags, pickups restored hidden and visible, and an end-to-end save and load.

## Validation
Static checks only. Check in Godot 4.7: collect a potion and open the chest, press F5, take damage and spend coins, press F9, and confirm health, position, potions, coins, the open chest, and the collected pickups all match the save. Then delete `user://saves/quicksave.json` and confirm F9 does nothing. Also check the test runner's exit code.
