# Camera Director — a 2D game camera you drop in

A portable Godot 4 component: a `Camera2D` that follows a target with a **deadzone** and
**look-ahead**, clamps the view to **world bounds**, **zooms** smoothly, blends to **focus
points** for a beat, and **shakes** on trauma. Pure node — no UI, no dependencies. You move
it by copying the `addons/camera_system/` folder.

## What it contains

| File | Class | Role |
|---|---|---|
| `core/camera_director.gd` | `CameraDirector` (Camera2D) | the whole camera: follow, deadzone, look-ahead, zoom, bounds, focus, shake |

Camera-only, so it's one file. Drop it in as your camera and set a target.

## Quick start

```gdscript
var cam := CameraDirector.new()
add_child(cam)
cam.make_current()
cam.target = $Player
cam.bounds = Rect2(0, 0, 4000, 2000)   # keep the view inside the level
cam.snap_to_target()                    # no glide on the first frame
```

That's it — it follows the player. Tune the rest live.

## Following

- **`follow_speed`** — stiffness of the follow (higher snaps faster; ≤ 0 is instant).
  Frame-rate independent.
- **`deadzone`** — half-size of a box the target moves inside freely before the camera
  follows. `Vector2.ZERO` glues the camera to the target.
- **`look_ahead`** (seconds) + **`look_ahead_speed`** — leads the camera in the direction
  the target is moving, so you see more of where you're going. `0` disables it.
- **`snap_to_target()`** — jump to the target now (scene start, teleport).

## Zoom & bounds

- **`zoom_level`** eased toward by **`zoom_speed`** (Godot 2D: `> 1` zooms in, `< 1` out).
- **`bounds`** — a world `Rect2` the *view* is kept inside, computed from the live zoom and
  viewport size. Zero-size means no clamping. If the view is larger than the bounds on an
  axis, the camera centres on the bounds there.

## Focus points

Glance somewhere and come back — a chest opening, a boss entering, a switch you just hit:

```gdscript
cam.focus_for($Boss, 1.5)         # look at the boss for 1.5 s, then return (focus_ended)
cam.focus_on($NPC)                # hold focus until…
cam.clear_focus()                 # …you release it
cam.focus_on_point(Vector2(800, 400))
```

`is_focusing()` tells you the current state; `focus_ended` fires when a timed focus returns.

## Shake

Trauma-based, so hits feel punchy without ever looking mechanical:

```gdscript
cam.add_trauma(0.6)   # stack calls for bigger hits; it bleeds off on its own
```

Trauma (0..1) decays at `trauma_decay`/sec; the shake offset and roll scale with
*trauma²*, so a light tap barely moves and a big hit kicks. `shake_max_offset` /
`shake_max_roll` set the ceilings. This is a **hook** — call it from your gameplay, or let
the Screen Effects component drive it.

## Notes

- It shakes via `offset`/`rotation`, not the follow position, so shake and follow never
  fight.
- 2D today. The same model (deadzone, look-ahead, bounds, focus, trauma) ports to a 3D
  camera rig; that's on the roadmap.

## Demo

`demo/camera_system_demo.tscn` — drive a hero around a large world with WASD/arrows and
watch the deadzone (the drawn box) and look-ahead; buttons zoom, toggle bounds, glance at
the boss and kick a shake.
