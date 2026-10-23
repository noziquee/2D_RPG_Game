# Inventory System — a portable inventory component (Godot 4)

A complete, self-contained Minecraft-style inventory system: slots, stacking,
drag & drop (move / merge / swap / split), tooltips, quick transfer
between inventories, sorting and serialization to JSON.

Zero external dependencies. Zero autoloads. Logic separated from the UI.

---

## 1. Installation in another project

1. Copy the **entire directory** `addons/inventory_system/` into your project
   (the path must stay `res://addons/inventory_system/` — the files reference it
   in `@icon(...)` and when loading the font).
2. Open the project in the editor — Godot scans the scripts and registers the
   global classes (`Inventory`, `ItemDefinition`, `ItemStack`, `ItemDatabase`,
   `InventoryPanelUI`, `InventorySlotUI`, `InventoryTooltip`, `InventoryStyle`).
3. That's all. The component does not need to be enabled in *Project Settings → Plugins*
   (it isn't an editor plugin — it's a pure script module).

> The `demo/` directory with the sample scene and items **is not part of the
> component** — copy it only if you want examples on hand.

## 2. Architecture

```
addons/inventory_system/
├── core/                    LOGIC (no UI — usable headless/on a server)
│   ├── item_definition.gd   ItemDefinition — an item template (Resource)
│   ├── item_stack.gd        ItemStack — definition + count (slot content)
│   ├── inventory.gd         Inventory — slots and all operations (Node)
│   └── item_database.gd     ItemDatabase — id -> definition registry (Resource)
├── ui/                      VIEW LAYER (listens to core signals)
│   ├── inventory_panel_ui.gd  InventoryPanelUI — a ready-made panel with a slot grid
│   ├── inventory_slot_ui.gd   InventorySlotUI — slot + drag & drop + tooltip
│   ├── inventory_tooltip.gd   InventoryTooltip — a bubble with the item description
│   └── inventory_style.gd     InventoryStyle — palette, font, StyleBoxes
└── theme/
    └── fonts/Fredoka-Variable.ttf  (+ OFL license)
```

The data flow is one-directional:

```
game ──(API: add_item, transfer_to...)──► Inventory ──(signals)──► InventoryPanelUI
```

The UI **never** modifies slots directly — all operations go through the
`Inventory` API, so every change (including from game code) refreshes the view immediately.

## 3. Quick start

```gdscript
# 1. Define items as .tres resources (RMB in FileSystem → New Resource →
#    ItemDefinition) or in code:
var apple := ItemDefinition.new()
apple.id = &"apple"
apple.display_name = "Apple"
apple.icon = preload("res://demo/icons/apple.svg")
apple.max_stack = 64

# 2. Create the inventory (logic):
var inv := Inventory.new()
inv.capacity = 27
add_child(inv)

# 3. Create the panel (UI) and attach the inventory:
var panel := InventoryPanelUI.new()
panel.title = "BACKPACK"
panel.columns = 9
add_child(panel)
panel.inventory = inv

# 4. Operate on the inventory — the UI refreshes itself:
var leftover := inv.add_item(apple, 80)   # 64 + 16 across two slots, leftover = 0
```

The panel can also be added in the editor: *Add Child Node → InventoryPanelUI*,
then assign the `Inventory` node in the inspector and set `columns` and `title`.

## 4. Controls (built into InventorySlotUI)

### Mouse

| Action                        | Effect                                               |
|-------------------------------|------------------------------------------------------|
| LMB drag                      | moves the **whole stack**                            |
| Ctrl + drag                   | moves **half** the stack (rounded up)                |
| Alt + drag                    | moves **1 unit**                                     |
| Drop onto the same item       | **merges** (overflow above max_stack returns to source) |
| Drop a full stack onto another item | **swaps places**                               |
| Shift + LMB                   | `quick_transfer_requested` signal (quick transfer)   |
| RMB                           | `slot_clicked` signal (e.g. use — the game decides)  |
| Hover                         | tooltip with name, rarity, description and count     |

### Keyboard / gamepad

Every mouse operation has a keyboard equivalent, so a game that hides the cursor loses
nothing. On by default (`keyboard_navigation`), driven only by Godot's built-in `ui_*`
actions — nothing to add to your Input Map.

| Action                        | Effect                                               |
|-------------------------------|------------------------------------------------------|
| Arrows / left stick           | move focus between slots (Godot's focus system)      |
| `ui_accept`                   | **pick up** the stack, then again on another slot to **place** it |
| Ctrl + `ui_accept`            | pick up **half** (same modifier as dragging)         |
| Alt + `ui_accept`             | pick up **1 unit**                                   |
| `ui_accept` on the source     | put the stack back                                   |
| `ui_cancel`                   | put a carried stack back                             |

Placing follows exactly the same merge / swap / overflow rules as dropping — both paths
share one validity check, so they cannot drift apart. An illegal placement is refused and
you keep carrying, rather than silently losing the stack.

`ui_cancel` is only swallowed **while carrying**, so it still closes your menu the rest of
the time. Starting a mouse drag mid-carry cancels the carry rather than fighting it.

```gdscript
panel.focus_on_ready = true    # or: panel.grab_first_focus()
panel.keyboard_navigation = false   # opt out entirely (mouse-only, as before)
```

A pad has no Ctrl or Alt. If yours needs split-stack, bind your own actions — the slot
reads them only when set:

```gdscript
slot.split_half_action = &"pad_split_half"
slot.split_one_action = &"pad_split_one"
slot.quick_transfer_action = &"pad_quick_transfer"   # the Shift+LMB equivalent
```

Carrying is **static state**, shared by every slot in the process. That is deliberate: it
is what lets a carry cross from the backpack panel to the chest panel, exactly like a
drag does. `InventorySlotUI.is_carrying()` / `get_carry_stack()` / `cancel_carry()` are
public, so your own drop targets can accept a keyboard carry too — that is how
shop_system's sell zone does it.

Drag & drop works **between any panels** in the scene tree (backpack ↔
chest ↔ quick-access bar), because the drag data carries a reference to the
source `Inventory`. Safety rule: a partial stack (Ctrl/Alt) can only be
dropped onto an empty slot or the same item type — swapping requires
dragging the whole stack.

## 5. API — the most important parts

### Inventory (Node)

| Method | Description |
|---|---|
| `add_item(item, count) -> int` | adds; returns the number of units that did **not** fit |
| `remove_item(item, count) -> int` | removes from any slots; returns the number removed |
| `remove_from_slot(index, amount) -> int` | removes from a specific slot |
| `transfer_to(target, from, to, amount=-1) -> bool` | move/merge/swap — the UI calls this on drop |
| `quick_transfer(from_index, target) -> int` | moves the stack wherever it fits |
| `count_item(item)` / `has_item(item, n)` | counting / checking |
| `get_slot(index) -> ItemStack` | `null` = empty slot |
| `sort_items()` | merges and sorts (category → rarity → name) |
| `clear()` | clears everything |
| `serialize() -> Dictionary` | state for JSON / a save |
| `deserialize(data, database) -> bool` | restores the state (needs an `ItemDatabase`) |

Signals: `slot_changed(index)`, `contents_changed()`, `item_added(item, count)`,
`item_removed(item, count)`, `capacity_changed(n)`.

### ItemDefinition (Resource)

`id` (the save key!), `display_name`, `description`, `icon`, `max_stack`
(1 = non-stackable), `rarity` (COMMON…LEGENDARY — tints the slot and tooltip),
`category` (sorting, game logic), `custom_data` (Dictionary — your stats:
damage, healing, etc.; the component doesn't interpret it).

### InventoryPanelUI (PanelContainer)

Properties: `inventory`, `columns`, `slot_size`, `title`.
Signals: `slot_clicked(index, event)`, `quick_transfer_requested(index)`.
`get_slot_ui(index)` gives access to the slot control (e.g. for your own markers).

## 6. Integration patterns (signals)

**Chest / trading — two inventories:**
```gdscript
backpack_panel.quick_transfer_requested.connect(
    func(i): backpack.quick_transfer(i, chest))
chest_panel.quick_transfer_requested.connect(
    func(i): chest.quick_transfer(i, backpack))
```

**Using an item (RMB):**
```gdscript
panel.slot_clicked.connect(func(index, event):
    var stack := inv.get_slot(index)
    if stack and stack.item.category == &"food":
        player.eat(stack.item.custom_data.get("hunger", 0))
        inv.remove_from_slot(index, 1)
)
```

**Quest goals / achievements:**
```gdscript
inv.item_added.connect(func(item, count):
    quest_system.notify_collected(item.id, count))
```

**Game save:**
```gdscript
save_data["inventory"] = inv.serialize()
# ...after loading:
inv.deserialize(save_data["inventory"], item_database)
```

The easiest way to build an `ItemDatabase` is in code from a list of resources
(`ItemDatabase.from_items([...])`) or to create it as a `.tres` and fill it
in the inspector. The `id` identifiers must be stable between game versions —
they are what the save is restored by.

## 7. Look and font

The whole look is defined by **a single file**: `ui/inventory_style.gd` — the palette
(dark background `#231d1d`, brown panel `#4a3a31`, gold accent `#ffc23e`),
roundings, border widths and StyleBox factories. Slots with items are
tinted by rarity color (gray / green / blue / purple / gold),
like in modern casual game UIs. You change the values — everything changes.

Restyling **the whole pack** from one place is what the optional `ui_theme_system`
component is for: one `ComponentTheme` resource (font, colors by role, corner radius)
pushed into every installed component by `ThemeDirector.apply()`. This file has no
knowledge of it — it just exposes `apply_theme()` / `reset_theme()` and is fine if the
addon is not installed. See `addons/ui_theme_system/README.md`.

```gdscript
var theme := ComponentTheme.new()
theme.accent = Color("53d8c4")
theme.corner_radius = 0                    # square slots for a pixel-art game
ThemeDirector.apply(theme)                 # before your UI is built
```

Font: **Fredoka** (variable, weights 300–700, SIL OFL license — file
`theme/fonts/OFL.txt`). It's a rounded, "soft" typeface typical of this style.
The component loads it via `InventoryStyle.get_font(weight)`; if you delete the
font file, the UI falls back to the theme's default font and keeps working.
Reasonable substitutes with a similar character: *Baloo 2*, *Nunito (ExtraBold)*.

## 8. Design decisions / limitations

- **An empty slot = `null`**, never an `ItemStack` with `count == 0`.
- `ItemStack` is a `Resource` — when splitting, the component always creates **new**
  instances (`ItemStack.create`), never sharing references between slots.
- Reducing `capacity` truncates the trailing slots — the items in them are lost;
  if that's possible in your game, move them out first (`quick_transfer`).
- Dropping outside any slot = canceling the drag (Godot's built-in
  behavior). If you want "drop on the ground", handle
  `_drop_data` on your own background control and call `remove_from_slot`.
- The component **adds nothing to your `Input Map`**. Mouse shortcuts are raw events and
  modifier keys; keyboard navigation uses only `ui_accept` / `ui_cancel` and the arrow
  actions, which every Godot project has by default. The optional pad actions
  (`split_half_action` and friends) are read only if you set them, and are ignored when
  the action does not exist.
- **A carry is global, not per panel.** Two inventories cannot each be carrying something
  at the same time — the same is true of dragging, and it is what makes backpack ↔ chest
  work. Freeing the source slot (e.g. a capacity change rebuilding the panel) cancels the
  carry rather than leaving a dangling reference.

## 9. Compatibility

Built and tested on **Godot 4.6** (`config/features=4.6`). It doesn't use API
beyond Godot 4.2+ (node exports in `@export`, static variables), so it also works
on older 4.x releases ≥ 4.2.
