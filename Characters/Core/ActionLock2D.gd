extends RefCounted
class_name ActionLock2D
## Lock identifiers and the rule for which lock blocks which capability.
const ATTACK: StringName = &"attack"
const DASH: StringName = &"dash"
const DEAD: StringName = &"dead"
const HURT: StringName = &"hurt"
const INTERACT: StringName = &"interact"
const CAPABILITY_MOVE: StringName = &"can_move"
const CAPABILITY_ATTACK: StringName = &"can_attack"
const CAPABILITY_DASH: StringName = &"can_dash"
const CAPABILITY_INTERACT: StringName = &"can_interact"
static func blocks(lock_id: StringName, capability: StringName) -> bool:
	match lock_id:
		DEAD:
			return true
		ATTACK, DASH:
			return capability == CAPABILITY_ATTACK or capability == CAPABILITY_DASH
		HURT:
			return capability == CAPABILITY_MOVE or capability == CAPABILITY_DASH
		INTERACT:
			return capability == CAPABILITY_INTERACT
	return false
