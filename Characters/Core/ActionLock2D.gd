extends RefCounted
class_name ActionLock2D
## Lock identifiers and the rule for which lock blocks which capability.
## Locks are acquired and released only through CharacterContext2D, so the start and
## finish signals always fire, including on cancel and interrupt paths.

#==============================================================================
# Lock Identifiers
#==============================================================================
const ATTACK: StringName = &"attack"
const DASH: StringName = &"dash"
const DEAD: StringName = &"dead"
## Held while a hit reaction plays. Stops movement and dash; attacks stay available.
const HURT: StringName = &"hurt"

#==============================================================================
# Capabilities
#==============================================================================
const CAPABILITY_MOVE: StringName = &"can_move"
const CAPABILITY_ATTACK: StringName = &"can_attack"
const CAPABILITY_DASH: StringName = &"can_dash"

## True when the active lock prevents the capability.
## Dead blocks everything. An attack blocks attacks and dashes but not movement.
## A dash blocks attacks and other dashes but not movement, which the dash itself drives.
static func blocks(lock_id: StringName, capability: StringName) -> bool:
	match lock_id:
		DEAD:
			return true
		ATTACK:
			return capability == CAPABILITY_ATTACK or capability == CAPABILITY_DASH
		DASH:
			return capability == CAPABILITY_ATTACK or capability == CAPABILITY_DASH
		HURT:
			return capability == CAPABILITY_MOVE or capability == CAPABILITY_DASH
	return false
