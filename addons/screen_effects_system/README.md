# Screen Effects System — screen effects ("juice")

A portable Godot 4 component: camera shake, flashes, hit-stop, slow motion,
vignette, zoom punch and scene transitions — one node, a full set of
variants. You move it by copying the `addons/screen_effects_system/` folder.
**Zero dependencies** on other components.

## What it contains

| File | Class | Role |
|---|---|---|
| `core/screen_effects.gd` | `ScreenEffects` (Node) | the whole effects API |
| `ui/screen_effects_overlay.gd` | `ScreenEffectsOverlay` (CanvasLayer) | the flash/vignette/fade layer (creates itself) |

## Quick start

```gdscript
var fx := ScreenEffects.new()
fx.camera = $Camera2D     # optional; without a camera set fx.shake_target
add_child(fx)

fx.shake(0.5)             # shake (trauma-based — hit series accumulate)
fx.flash(Color.RED, 0.3)  # red damage flash
fx.hitstop()              # freeze time for 0.08 s — the blow "lands"
fx.slow_motion(0.3, 0.7)  # bullet-time
fx.vignette_pulse()       # red pulse of pain on the screen edges
fx.zoom_punch()           # a jolt of zoom
fx.impact(0.6)            # a ready-made combo: shake + flash + hitstop
```

## Variants

- **Shake (`shake(amount)`)** — a trauma model: each hit adds trauma
  (0..1), the amplitude decays quadratically, so small blows barely tremble
  while a series accumulates into a shake. With a camera it uses `camera.offset`
  + a slight rotation (it doesn't ruin the camera position); without a camera it moves
  `shake_target` (e.g. the HUD body). You tune it with the `max_shake_offset`,
  `max_shake_rotation`, `shake_decay` exports.
- **Flash (`flash(color, max_alpha, duration)`)** — white hit, red
  damage, green healing…
- **Hit-stop (`hitstop(duration, time_scale)`)** — a brief freeze of
  `Engine.time_scale`; safe when stacked (the last one wins,
  time always returns to 1.0).
- **Slow motion (`slow_motion(time_scale, duration)`)** — a longer variant
  (finisher, bullet-time).
- **Vignette** — `vignette_pulse(intensity, tint, duration, settle)` (a pulse
  of pain; `settle` > 0 leaves it on permanently — a low-HP screen) and
  `set_vignette(intensity, tint)` (steady dungeon mood). The shader is built in,
  no files.
- **Zoom punch (`zoom_punch(strength, duration)`)** — a jolt of the Camera2D
  zoom that springs back.
- **Fade / scene transitions** — `await fade_out()`, `fade_in()`,
  `transition_to_scene(path)`; a target scene with
  `fade_in_on_ready` enabled brightens itself from black (works without autoloads).
- **Combo (`impact(strength)`)** — shake + flash + (for strong ones) hitstop
  in one line; 0.2 = a regular hit, 0.6 = a crit, 1.0 = an explosion.

**Signals:** `faded_out`, `faded_in`.

## Pause safety

The overlay runs with `process_mode = PROCESS_MODE_ALWAYS`, so **fades and flashes keep
working while `get_tree().paused` is true**. This is not cosmetic: fades are driven by
tweens bound to the overlay, so with the default process mode

```gdscript
await effects.fade_out()      # from a pause menu
```

would never return and the screen would stay black with no way out. Effects are
presentation, not gameplay — they have to run exactly when the game does not.

Your own transitions need the same care. A tween from `SceneTree.create_tween()` stops
with the tree unless you say otherwise:

```gdscript
var tween := get_tree().create_tween()
tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # or it hangs while paused
```

Note the asymmetry that makes these bugs feel random: `get_tree().create_timer(1.0)`
**ignores** pause by default, while tweens do not.

See `docs/PAUSE.md` for the pack-wide convention, and
`demo/pause_menu_demo.tscn` for a worked pause menu.

## Demo

`demo/screen_effects_demo.tscn` — buttons for all variants on a
busy scene with a camera + a fade transition to another demo. The crits in
`demo/floating_text_demo.tscn` show the integration with floating_text_system.
