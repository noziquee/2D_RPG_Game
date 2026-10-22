extends RefCounted
class_name Groups2D
## Single definition of the group names and team rules shared by combat code.
## Prefer these constants over string literals so a rename happens in one place.

#==============================================================================
# Group Names
#==============================================================================
const PLAYER: StringName = &"player"
const ENEMY: StringName = &"enemy"
const DAMAGEABLE: StringName = &"damageable"

#==============================================================================
# Team Rules
#==============================================================================
## True when both nodes belong to the same faction (player/player or enemy/enemy).
static func is_same_team(a: Node, b: Node) -> bool:
	if a == null or b == null:
		return false
	return (
		(a.is_in_group(PLAYER) and b.is_in_group(PLAYER))
		or (a.is_in_group(ENEMY) and b.is_in_group(ENEMY))
	)
