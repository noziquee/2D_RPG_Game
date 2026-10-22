extends Node
class_name HealthComponent2D
## Owns current health, invulnerability, and death for one character.
## Written once and shared by the player and every enemy.
## Ported in shape from the RPG project's HealthComponent, using whole-number health.

#==============================================================================
# Signals
#==============================================================================
signal health_changed(current_health: int, maximum_health: int)
signal damaged(amount: int)
signal healed(amount: int)
## Emitted exactly once per life, after health_changed and damaged.
signal died

#==============================================================================
# State
#==============================================================================
var _max_health: int = 1
var _current_health: int = 0
var _dead: bool = false
var _invulnerable: bool = false

#==============================================================================
# Public Properties
#==============================================================================
var max_health: int:
	get:
		return _max_health

var current_health: int:
	get:
		return _current_health

var is_dead: bool:
	get:
		return _dead

var is_alive: bool:
	get:
		return not _dead

var is_invulnerable: bool:
	get:
		return _invulnerable

#==============================================================================
# Lifecycle
#==============================================================================
## Sets the maximum and starting health. A negative starting value means full health.
## Does not emit; the owner decides when to announce the initial value.
func initialize(maximum_health: int, starting_health: int = -1) -> void:
	_max_health = maxi(maximum_health, 1)
	_current_health = _max_health if starting_health < 0 else clampi(starting_health, 0, _max_health)
	_dead = _current_health <= 0

#==============================================================================
# Public API
#==============================================================================
## Removes health and returns the amount actually removed (0 when rejected).
func damage(amount: int) -> int:
	if _dead or _invulnerable or amount <= 0:
		return 0
	var applied := mini(amount, _current_health)
	_current_health -= applied
	# Mark death before any signal runs so a listener cannot damage a dead target
	# or trigger a second death.
	var lethal := _current_health <= 0
	if lethal:
		_dead = true
	health_changed.emit(_current_health, _max_health)
	damaged.emit(applied)
	if lethal:
		died.emit()
	return applied

## Adds health and returns the amount actually restored. Dead characters cannot heal.
func heal(amount: int) -> int:
	if _dead or amount <= 0:
		return 0
	var restored := mini(amount, _max_health - _current_health)
	if restored <= 0:
		return 0
	_current_health += restored
	health_changed.emit(_current_health, _max_health)
	healed.emit(restored)
	return restored

func set_invulnerable(value: bool) -> void:
	_invulnerable = value

## Changes the maximum. Current health is clamped down but never raised.
func set_max_health(value: int) -> void:
	var new_max := maxi(value, 1)
	if new_max == _max_health:
		return
	_max_health = new_max
	_current_health = mini(_current_health, _max_health)
	health_changed.emit(_current_health, _max_health)

## Kills the character even through invulnerability.
func kill() -> void:
	if _dead:
		return
	_invulnerable = false
	damage(_current_health)

## Brings a dead (or living) character back. A negative value means full health.
func revive(health: int = -1) -> void:
	_current_health = _max_health if health < 0 else clampi(health, 1, _max_health)
	_dead = false
	health_changed.emit(_current_health, _max_health)

func get_health_percent() -> float:
	return float(_current_health) / float(_max_health)

#==============================================================================
# Persistence
#==============================================================================
func save_state() -> Dictionary:
	return {"current_health": _current_health}

## Ignores missing or wrongly typed data instead of trusting it.
func load_state(data: Dictionary) -> void:
	var value: Variant = data.get("current_health")
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return
	_current_health = clampi(int(value), 0, _max_health)
	_dead = _current_health <= 0
	health_changed.emit(_current_health, _max_health)
