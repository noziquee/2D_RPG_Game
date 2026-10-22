# Floating Text System — floating combat text

A portable Godot 4 component: damage, healing and XP numbers and messages
(MISS/DODGE/BLOCK) floating above characters, with three animation variants
and a separate crit style. You move it by copying the
`addons/floating_text_system/` folder. **Zero dependencies** on other components.

## What it contains

| File | Class | Role |
|---|---|---|
| `core/floating_text_spawner.gd` | `FloatingTextSpawner` (Node2D) | a label factory: presets + full control |
| `ui/floating_label.gd` | `FloatingLabel` (Node2D) | a single animated label (cleans itself up) |
| `ui/floating_text_style.gd` | `FloatingTextStyle` | preset palette + a font with a thick outline |

## Quick start

```gdscript
var fct := FloatingTextSpawner.new()
add_child(fct)   # works in a 2D world and under HUD Controls

# positions in global canvas coordinates (e.g. above an enemy's head):
fct.show_damage(24, enemy.global_position + Vector2(0, -40))
fct.show_damage(87, pos, true)    # CRIT — bigger, gold, pops with scale
fct.show_heal(15, player_pos)     # +15 in green
fct.show_xp(120, player_pos)      # +120 XP in purple
fct.show_gold(50, chest_pos)      # +50 gold, falls in an arc (ARC)
fct.show_miss(enemy_pos)          # MISS  (there are also show_dodge / show_block)
fct.show_damage_taken(9, player_pos)
```

## Animation variants

Each label has one of three variants (`FloatingLabel.Anim`):

- **RISE** — the classic upward rise with a fade (default for numbers),
- **ARC** — pops in a random direction and falls under gravity (default for
  gold; great for loot),
- **POP** — pops with scale in place and drifts slightly (default for crits).

You change the default assignments with the `default_anim` / `crit_anim` exports,
and a single label with the full method:

```gdscript
fct.show_text("LEVEL UP!", pos, Color("ffc23e"),
		FloatingLabel.Anim.POP, 30, 2.2)   # size 30, scale "punch" ×2.2
```

`show_text` returns a [FloatingLabel] — you can still tune its fields
(`lifetime`, `gravity`, `rise_distance`…) before the first frame runs.

## API — `FloatingTextSpawner`

**Exports:** `default_anim`, `crit_anim`, `font_size`, `crit_font_size`,
`lifetime`, `spread` (random horizontal spread — series of numbers don't overlap).

**Methods:** `show_damage(amount, pos, crit)`, `show_damage_taken`,
`show_heal`, `show_mana`, `show_xp`, `show_gold`, `show_miss`, `show_dodge`,
`show_block`, `show_text(text, pos, color, anim, size, punch)`, `clear_all()`.

**Signal:** `text_spawned(label)` — a hook for hit sounds etc.

## Styling

Preset colors and the font — in `ui/floating_text_style.gd` (the thick outline
ensures readability on any background). The Fredoka font is in `theme/fonts/`
inside the addon; without it the component uses the theme's font.

## Demo

`demo/floating_text_demo.tscn` — a clickable slime: damage with crits
(wired to screen_effects — a shake on a crit), all presets,
a comparison of the animation variants, an auto-attack mode.
