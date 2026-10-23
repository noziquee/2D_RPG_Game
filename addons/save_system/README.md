# Save System — saving and loading game state

A portable Godot 4 component: save slots on disk (readable JSON),
autosave, versioning with migration, playtime and a ready-made slot panel.
You move it by copying the `addons/save_system/` folder.
**Zero dependencies** on other components — you attach systems with Callables.

## What it contains

| File | Class | Role |
|---|---|---|
| `core/save_manager.gd` | `SaveManager` (Node) | system registry, slots, autosave — works without a UI |
| `core/save_migrations.gd` | `SaveMigrations` (RefCounted) | chains per-version migration steps so old saves keep loading |
| `ui/save_panel_ui.gd` | `SavePanelUI` (PanelContainer) | slot list with SAVE/LOAD/DELETE |
| `ui/save_style.gd` | `SaveStyle` | palette, font, StyleBoxes |

## Quick start

```gdscript
var save := SaveManager.new()
save.autosave_interval = 120.0    # autosave every 2 minutes (0 = disabled)
add_child(save)

# each game system registers a pair: save -> Dictionary, load from Dictionary
save.register(&"inventory", backpack.serialize,
		func(d): backpack.deserialize(d, database))
save.register(&"wallet", wallet.to_dict, wallet.from_dict)
save.register(&"health", health.to_dict, health.from_dict)
save.register(&"hero", func(): return {"level": level, "pos": [pos.x, pos.y]},
		func(d): level = d["level"])

save.save_game("slot_1", "Before the boss")   # label shown in the UI
save.load_game("slot_1")

# UI
var panel := SavePanelUI.new()
panel.slot_count = 3
add_child(panel)
panel.manager = save
```

The components of this library fit out of the box: `Inventory.serialize/deserialize`,
`Wallet.to_dict/from_dict`, `Stat.to_dict/from_dict`.

## File format and versioning

One slot = one readable file `user://saves/<slot>.json`:
`meta` (version, timestamp, label, playtime) + `state`
(one entry per registered system). When you raise
`save_version`, old saves go through [member SaveManager.migrator]
(`Callable(state, from_version) -> state`); without a migrator they are rejected
with the `load_failed` signal.

## Migrating a save across schema versions

This is the part that decides whether you can adopt a save system early, so here is
the whole thing worked through.

**What a migrator sees.** `state` is keyed by the ids you passed to `register()`, and
each value is whatever that system's save function returned. A `v1` file looks like:

```json
{
  "meta":  { "version": 1, "playtime": 812.0, "label": "Cave run" },
  "state": { "gold": { "amount": 320 }, "inventory": { "slots": [] } }
}
```

So a migration is almost always one of: **rename a system**, **reshape one system's
dictionary**, or **default a system that did not exist yet**.

**Write one step per version bump.** `SaveMigrations` chains them, so a player who last
played on v1 and returns at v3 runs 1→2→3 with no 1→3 path written by hand:

```gdscript
var migrations := SaveMigrations.new()
migrations.target_version = 3

# v1 → v2: the "gold" system became "wallet", and reshaped
migrations.add(1, func(state: Dictionary) -> Dictionary:
	var old: Dictionary = state.get("gold", {})
	state["wallet"] = {"gold": old.get("amount", 0)}
	state.erase("gold")
	return state)

# v2 → v3: settings are new; give old saves a sane default
migrations.add(2, func(state: Dictionary) -> Dictionary:
	state["settings"] = {"difficulty": "normal"}
	return state)

saves.save_version = 3
saves.migrator = migrations.as_callable()
```

That is it — `load_game()` now accepts v1, v2 and v3 files.

**Rules that keep migrations boring** (which is what you want):

- **Always `.get(key, default)`, never `[key]`.** A save from an older build may be
  missing anything, including keys you are certain about.
- **Never delete a step.** Steps are permanent history; a v1 save can show up years
  later. They are cheap to keep — each is a few lines.
- **Bump `save_version` and add the step in the same commit.** The two drifting apart is
  how saves get corrupted rather than rejected.
- **Check before you trust:** `migrations.can_migrate(version)` tells you whether a save
  can reach the current schema, so you can say "this save is too old" instead of loading
  half-migrated data. A gap in the chain warns rather than passing silently.
- Systems with **no data in the file are skipped** entirely — they keep their current
  state. That means adding a new system needs no migration at all unless it must be
  seeded from old data.

**API — `SaveMigrations`:** `target_version`, `add(from_version, step)` (chainable),
`migrate(state, from_version)`, `can_migrate(from_version)`, `as_callable()`, `steps()`.

`tests/cases/test_save.gd` runs all of this end to end, including writing a real v1 file
to disk and loading it on a v3 build.

## API — `SaveManager`

**Exports:** `save_dir`, `save_version`, `autosave_interval`,
`autosave_slot`.

**Methods:** `register(id, save_func, load_func)`, `unregister(id)`,
`save_game(slot, label)`, `load_game(slot)`, `has_slot(slot)`,
`delete_slot(slot)`, `get_slot_info(slot)` (metadata for your own UI),
`get_playtime()`, `SaveManager.format_playtime(s)`.

**Signals:** `game_saved(slot)`, `game_loaded(slot)`,
`save_failed(slot, reason)`, `load_failed(slot, reason)`,
`slots_changed()` (the UI refreshes the list).

Systems without an entry in the file are skipped on load (they keep their state) —
so adding a new system doesn't break old saves.

## API — `SavePanelUI`

**Exports/properties:** `manager`, `title`, `slot_count` (slots
`slot_1..slot_N`), `show_autosave` (an autosave row without the SAVE button).
**Signal:** `slot_loaded(slot)` — e.g. close the menu after loading.

## Demo

`demo/save_demo.tscn` — a mini game state (level, gold, hero HP),
3 slots + autosave every 10 s, labels, playtime, deletion.
