extends Node
class_name StatusEffectComponent2D
## Timed buffs and debuffs on one character. Modifiers go to StatsComponent2D. Tick damage
## goes through the character's receive_damage(), so defense, rejection, and death rules
## all apply. Ticks are tagged "dot", so they do not trigger a hit reaction.

signal effect_applied(effect_id: StringName, stacks: int)
signal effect_removed(effect_id: StringName)

## Runtime state for one applied effect.
class ActiveEffect extends RefCounted:
	var definition: StatusEffect2D
	var stacks: int = 1
	var remaining: float = 0.0
	var tick_accum: float = 0.0
	var source: Node

	func _init(effect: StatusEffect2D, initial_stacks: int, applier: Node) -> void:
		definition = effect
		stacks = initial_stacks
		remaining = effect.duration
		source = applier

var _character: Character2D
var _stats: StatsComponent2D
var _active: Dictionary = {}  # effect id -> ActiveEffect

func initialize(character: Character2D, stats: StatsComponent2D) -> void:
	_character = character
	_stats = stats

## Applies an effect, or re-applies it according to its stacking rule.
## Returns false when the effect is invalid or the character cannot take it.
func apply(effect: StatusEffect2D, add_stacks: int = 1, applier: Node = null) -> bool:
	if effect == null or effect.id == &"" or effect.duration <= 0.0:
		push_error("StatusEffectComponent2D.apply needs an effect with an id and a positive duration.")
		return false
	if _character == null or not _character.is_alive():
		return false

	var active: ActiveEffect = _active.get(effect.id)
	if active == null:
		active = ActiveEffect.new(effect, clampi(add_stacks, 1, effect.max_stacks), applier)
		_active[effect.id] = active
		_refresh_modifiers(active)
		effect_applied.emit(effect.id, active.stacks)
		return true

	if effect.stacking == StatusEffect2D.Stacking.ADD_STACK:
		var before := active.stacks
		active.stacks = mini(active.stacks + maxi(add_stacks, 1), effect.max_stacks)
		if active.stacks != before:
			_refresh_modifiers(active)
	active.remaining = effect.duration
	if applier != null:
		active.source = applier
	return true

## Removes one effect and its modifiers. Does nothing if the effect is not active.
func remove(effect_id: StringName) -> void:
	if not _active.has(effect_id):
		return
	_active.erase(effect_id)
	_stats.remove_modifiers(effect_id)
	effect_removed.emit(effect_id)

## Removes every effect. Called on death so no modifier outlives the character.
func clear() -> void:
	for effect_id in _active.keys():
		remove(effect_id)

func has(effect_id: StringName) -> bool:
	return _active.has(effect_id)

func stacks_of(effect_id: StringName) -> int:
	var active: ActiveEffect = _active.get(effect_id)
	return active.stacks if active != null else 0

func remaining_of(effect_id: StringName) -> float:
	var active: ActiveEffect = _active.get(effect_id)
	return active.remaining if active != null else 0.0

## Advances durations and ticks. Called once per physics frame by Character2D.
func physics_update(delta: float) -> void:
	for effect_id in _active.keys():
		if not _active.has(effect_id):
			continue  # removed during this frame (for example by a death)
		var active: ActiveEffect = _active[effect_id]
		if active.definition.tick_interval > 0.0 and active.definition.tick_damage > 0:
			active.tick_accum += delta
			while active.tick_accum >= active.definition.tick_interval and _active.has(effect_id):
				active.tick_accum -= active.definition.tick_interval
				_tick(active)
		if _active.has(effect_id):
			active.remaining -= delta
			if active.remaining <= 0.0:
				remove(effect_id)

func _refresh_modifiers(active: ActiveEffect) -> void:
	for modifier in active.definition.modifiers:
		if modifier == null:
			continue
		_stats.set_modifier(active.definition.id, modifier.stat_id,
				modifier.flat * active.stacks, modifier.percent * active.stacks)

func _tick(active: ActiveEffect) -> void:
	if _character == null or not _character.is_alive():
		return
	var source := active.source if is_instance_valid(active.source) else null
	var request := DamageRequest2D.create(source, active.definition.tick_damage * active.stacks)
	request.damage_type = active.definition.damage_type
	request.tags.append(&"dot")
	_character.receive_damage(request)
