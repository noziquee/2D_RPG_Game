# Loot Table System — weighted drops

A portable Godot 4 component: weighted loot tables with guaranteed and conditional
entries, random drop counts, nested tables and a seedable RNG. A roll produces
[ItemStack]s ready to hand to an inventory. You move it by copying the
`addons/loot_table_system/` folder.

> **Dependency:** requires `addons/inventory_system/` — drops are [ItemStack] /
> [ItemDefinition] and [method LootTable.roll_into] adds them to an [Inventory].
> The results UI reuses [InventoryStyle]. Copy both folders.

## What it contains

| File | Class | Role |
|---|---|---|
| `core/loot_entry.gd` | `LootEntry` (Resource) | one possible drop: item/nested table, weight, count, chance |
| `core/loot_table.gd` | `LootTable` (Resource) | the table — `roll()` produces merged ItemStacks |
| `ui/loot_results_ui.gd` | `LootResultsUI` (PanelContainer) | rarity-tinted tiles for a roll's drops |

## Quick start

```gdscript
# build a table in code (or as a .tres resource)
var chest := LootTable.create([
	LootEntry.create(iron_ingot, 1, 3, 5.0),          # weight 5, drops 1–3
	LootEntry.create(diamond, 1, 1, 0.5),             # weight 0.5 (rare)
	LootEntry.create_guaranteed(gold_coin, 10, 25),   # always: 10–25 coins
], 2)                                                 # 2 weighted picks per roll

var drops := chest.roll()                             # Array[ItemStack], merged
chest.roll_into(player_inventory)                     # or roll straight into an inventory

# UI
var results := LootResultsUI.new()
add_child(results)
results.show_loot(drops)
```

A roll resolves in two passes: every **guaranteed** entry is rolled independently
(dropping when its `chance` passes), then **`rolls`** weighted picks are taken over
the remaining entries. Same-item drops are merged into one stack.

## API — `LootEntry`

**Exports:** `item` (ItemDefinition) or `table` (nested LootTable), `weight`,
`min_count` / `max_count`, `guaranteed`, `chance` (for guaranteed entries),
`pity_after`, `id` (pity key). Builders: `create(item, min, max, weight)`,
`create_guaranteed(item, min, max, chance)`,
`create_with_pity(item, pity_after, min, max, weight)`,
`create_table(table, guaranteed, chance)`.
Helpers: `pity_key()`, `has_pity()`.

## API — `LootTable`

**Exports:** `entries` (Array[LootEntry]), `rolls` (weighted picks per roll),
`rng_seed` (0 = random; non-zero = reproducible).

**Methods:** `roll(rng = null)` → `Array[ItemStack]` (pass a shared RNG for nested /
reproducible rolls), `roll_into(inventory, rng = null)` (rolls and adds to an
[Inventory]), `make_rng()` (an RNG honouring `rng_seed`).

**Nested tables:** a `LootEntry` with a `table` rolls that table recursively and
merges its drops — use it for tiered loot ("10% chance to roll the rare table").

**Reproducibility:** set `rng_seed` (or pass your own seeded RNG) for identical
drops across runs — handy for tests and seeded gameplay. Pity is part of that: the same
seed and the same starting counters give the same drops.

## Pity — "at least one X every N rolls"

Weights alone let a player open 40 chests and see no legendary. `pity_after` puts a
ceiling on the dry streak:

```gdscript
var legendary := LootEntry.create_with_pity(sword, 30, 1, 1, 0.5)  # rare, but never absent
var table := LootTable.create([common, uncommon, legendary] as Array[LootEntry], 1)

table.roll(rng)                       # ... 29 unlucky rolls ...
table.roll(rng)                       # the 30th drops the sword whatever the dice said
```

**How it counts.** Pity counts **rolls** (calls to `roll()`), not weighted picks, so
`pity_after = 30` reads exactly as "at least one every 30 rolls". Pity runs **after** the
normal roll, so the dice get first refusal: an entry that drops on its own resets its
counter and is never forced on top of itself. It works for weighted and `chance`-based
entries alike.

**A counter needs a key.** It defaults to the item's id. Set `id` explicitly for a
nested-table entry (no item to borrow an id from), or when two entries drop the same item
but should count separately:

```gdscript
boss_entry.id = &"legend_from_bosses"   # counts apart from the chest entry
```

An entry with `pity_after > 0` and no key warns and is skipped rather than silently
counting under an empty key.

**Pity is state, not definition.** Counters live on the table instance and are *not*
saved into the `.tres` — a table shared by every chest would otherwise carry a save
inside itself:

| Want | Do |
|---|---|
| one streak shared by all chests | share the table (the default) |
| a separate streak per target | `table.duplicate()` per target |
| the streak to survive quitting | save `to_dict()` / `from_dict()` |
| a fresh run | `reset_pity()` |

```gdscript
# with save_system:
saves.register(&"loot_pity", table.to_dict, table.from_dict)
```

Persisting it matters: without it, quitting resets everyone's streak — players notice,
and it is the kind of bug that only shows up in production.

**For the UI:** `rolls_until_pity(key)` returns how many rolls are left before the
guarantee fires (0 = the next one), so you can show a "guaranteed in 3" counter.
`get_pity(key)` is the raw streak.

## Demo

`demo/loot_table_demo.tscn` — a common crate, a treasure chest and a boss cache
(with a nested jackpot table), a seeded roll that drops the same loot every time,
and a lifetime tally of everything dropped.
