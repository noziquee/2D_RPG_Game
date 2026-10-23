# Procedural generation: evaluation (Phase 13)

## What the add-on provides
`procgen_system` (about 560 lines of GDScript) generates layouts procedurally. It is designed for generated dungeons with tiles, rooms, and corridors.

## Decision: defer adoption
The game is a room-based dungeon crawler, and the plan keeps the room logic free of generation rules. The first content will be hand-authored rooms, as in `World/Level/Level.gd`, for three reasons:

1. **The level has to be readable before it is generated.** Designing enemy placement, cover, and the flow of a room is easier to test with fixed layouts. Generated layouts would make a bug in the wave spawner or the walls hard to reproduce.
2. **Saves store objects by id.** Persistence (Phase 12) keys chests, doors, and pickups by a stable id. Random layouts would need a seed saved alongside the state, and the add-on does not yet provide that link.
3. **No content needs generation yet.** Two rooms are enough to test the systems. Generation becomes worth adopting when the game needs many rooms without hand-authoring each one.

## Criteria to revisit
Adopt procgen when all of these are true:
- The game needs more than about five rooms, or rooms must change between runs.
- Generated layouts can be reproduced from a saved seed, so a loaded game gets the same rooms.
- Persistence can restore an object's state by its generated id.

## Until then
- `Level.gd` builds from a text layout. A new room is a new layout string.
- Procgen stays in the add-on bundle as a reference, not in the project.
