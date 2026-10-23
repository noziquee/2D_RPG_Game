# Interaction & Prompts — "press E to…"

A portable Godot 4 component: interactables register a prompt, an interactor on the
player finds the **nearest available one in range**, marks it focused, and triggers it on
the interact input — with a floating prompt that tracks the target (and the camera). Logic
(`core/`) is separate from the UI (`ui/`). You move it by copying the
`addons/interaction_system/` folder. **Zero dependencies.**

## What it contains

| File | Class | Role |
|---|---|---|
| `core/interactable.gd` | `Interactable` (Node2D) | a thing you can interact with: prompt, id, enabled, one-shot |
| `core/interactor.gd` | `Interactor` (Node2D) | on the player: finds the nearest interactable, triggers it on input |
| `ui/interaction_prompt_ui.gd` | `InteractionPromptUI` (Control) | the floating "[E] Open" bubble that follows the target |
| `ui/interaction_style.gd` | `InteractionStyle` | palette + font |

## Quick start

```gdscript
# On each interactable in the world:
var door := Interactable.new()
door.prompt = "Open"
door.id = &"door"
world.add_child(door)
door.interacted.connect(func(_who): open_the_door())

# One interactor on the player:
var interactor := Interactor.new()
interactor.range = 96.0
$Player.add_child(interactor)

# A prompt on a CanvasLayer over the game:
var prompt := InteractionPromptUI.new()
prompt.interactor = interactor
$HUD.add_child(prompt)
```

Walk near the door and a "[E] Open" bubble appears; press the key and `interacted` fires.
No per-object wiring beyond one signal.

## How focus works

Each frame the interactor scans everything in the `Interactable` group, drops anything
unavailable (disabled or a spent one-shot) or out of range, and keeps the **nearest**.
When the focus changes it emits `focus_changed(interactable)` (null when nothing's in
range) and toggles `set_focused()` on the interactables so they can glow.

- **`range`** — reach in world units. An interactable can override it with
  `range_override`.
- **`require_facing`** — only count interactables inside a cone around `facing`
  (`facing_cone` half-angle). Update `facing` as the player turns.
- **`trigger()`** — interact with the focused target from code (e.g. a touch button),
  not just the input action.

## The interact input

`input_action` (default `&"interact"`) triggers the interaction. If that action isn't in
your Input Map, the interactor falls back to **`ui_accept`**, so the demo and a fresh
project work with no setup. `action_hint()` returns a short key label ("E", "Space",
"Button 0") for the prompt.

## Interactables

- **`prompt`** — the verb shown ("Open", "Talk", "Loot"). Change it live (a door that
  toggles to "Close").
- **`enabled`** — turn off a locked door without removing it.
- **`one_shot`** — interact once, then it's unavailable (a pickup). `is_available()`
  reflects both.
- **`prompt_offset`** — where the bubble floats relative to the node.
- Signals: `interacted(interactor)` and `focus_changed(focused: bool)`.

## The prompt UI

`InteractionPromptUI` shows the interact key (a little cap) plus the prompt, and follows
the focused interactable by projecting its world position through the viewport's canvas
transform — so it tracks **camera pan and zoom** (pairs naturally with the Camera Director
component). It hides itself when nothing is in range. Put it on a `CanvasLayer`.

## Styling

`InteractionStyle` holds the palette and Fredoka font. Edit its constants to reskin, or
install `ui_theme_system` to restyle the whole pack from one resource — this component
exposes `apply_theme()` and needs no dependency on it.

## Demo

`demo/interaction_system_demo.tscn` — walk a hero around a door (toggles), a chest
(one-shot loot), a lever (toggles) and a sign (reads out); the prompt tracks whichever is
closest.
