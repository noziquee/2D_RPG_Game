extends RefCounted
class_name DamageResult2D
## What happened to one DamageRequest2D. Returned to the attacker and broadcast as an event.

const REJECT_NONE: StringName = &""
const REJECT_NO_REQUEST: StringName = &"no_request"
const REJECT_NO_TARGET: StringName = &"no_target"
const REJECT_NOT_DAMAGEABLE: StringName = &"not_damageable"
const REJECT_TARGET_DEAD: StringName = &"target_dead"
const REJECT_SELF_DAMAGE: StringName = &"self_damage"
const REJECT_FRIENDLY_FIRE: StringName = &"friendly_fire"
const REJECT_INVULNERABLE: StringName = &"invulnerable"
const REJECT_NO_DAMAGE: StringName = &"no_damage"

var request: DamageRequest2D
var target: Node

#==============================================================================
# Damage Values
#==============================================================================
var incoming_damage: int = 0
var final_damage: int = 0

#==============================================================================
# Outcome
#==============================================================================
## True only when health was actually removed.
var applied: bool = false
var rejection: StringName = REJECT_NONE
var critical: bool = false
var killed: bool = false
var health_before: int = 0
var health_after: int = 0
