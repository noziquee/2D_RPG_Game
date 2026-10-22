# Weapon Pivot Fix

## Change summary

- Added `Player/WeaponPivot` as the authored rotation origin for the player sword.
- Reparented `Weapon` and `WeaponAnimation` under that pivot.
- Positioned the pivot at the sword hilt and adjusted `Weapon.offset` to preserve the previous resting visual position.
- Changed `slash` and `sword_return` rotation tracks to animate the pivot, while scale tracks animate `Weapon:scale`.
- Preserved the `spawn_slash()` method track and pointed it to the CharacterBody2D script.
- Updated `CharacterContext2D.gd` to find the dedicated player pivot while retaining support for enemy weapon layouts.

## New player weapon hierarchy

```text
Player (CharacterBody2D)
└── Player (Node2D visual root)
    └── WeaponPivot (Node2D)
        ├── Weapon (Sprite2D)
        └── WeaponAnimation (AnimationPlayer)
```

The sprite's hilt is positioned at the pivot origin so changing the sprite scale during the authored attack/return animations causes far less visible anchor drift. The visual root continues to control left/right mirroring.

## Validation limitation

Project resources and track paths were statically checked. Godot was not available in the environment for a runtime animation preview. After opening the project, verify that the sword rotates around its hilt when attacking to the left and right.
