extends RefCounted
## Shared runtime data for a 2D character and its states/components.
## Supports AnimationPlayer-driven layered sprites and legacy AnimatedSprite2D scenes.

var character: CharacterBody2D
var visual_root: Node2D
var character_animation_player: AnimationPlayer
var animated_sprite: AnimatedSprite2D
var weapon_pivot: Node2D
var weapon_animation_player: AnimationPlayer
var movement_input: Vector2 = Vector2.ZERO
## Horizontal facing chosen by locomotion; preserved while attacking.
var movement_facing_direction: Vector2 = Vector2.RIGHT
## Current visible facing. Temporarily follows attack direction during an attack.
var facing_direction: Vector2 = Vector2.RIGHT
var aim_direction: Vector2 = Vector2.RIGHT
var attack_direction: Vector2 = Vector2.RIGHT
var dash_velocity: Vector2 = Vector2.ZERO

## Read-only views over the action locks. Components acquire and release locks;
## nothing else sets these.
var is_attacking: bool:
	get:
		return is_locked(ActionLock2D.ATTACK)

var is_dashing: bool:
	get:
		return is_locked(ActionLock2D.DASH)

#==============================================================================
# Action Locks
#==============================================================================
## Emitted when a lock gains its first holder. Emitted by this lock layer only.
signal lock_started(lock_id: StringName)
## Emitted when a lock loses its last holder. Emitted by this lock layer only.
signal lock_finished(lock_id: StringName)

## lock_id -> { owner instance id -> true }. Tracking holders per owner makes release idempotent.
var _lock_holders: Dictionary = {}

## Marks owner as holding lock_id. A repeat call from the same owner changes nothing.
func acquire_lock(lock_id: StringName, owner: Object) -> void:
	if owner == null:
		push_error("CharacterContext2D.acquire_lock needs an owner.")
		return
	var holders: Dictionary = _lock_holders.get(lock_id, {})
	var was_free := holders.is_empty()
	holders[owner.get_instance_id()] = true
	_lock_holders[lock_id] = holders
	if was_free:
		lock_started.emit(lock_id)

## Removes owner's hold on lock_id. Releasing a lock the owner does not hold does nothing.
func release_lock(lock_id: StringName, owner: Object) -> void:
	if owner == null or not _lock_holders.has(lock_id):
		return
	var holders: Dictionary = _lock_holders[lock_id]
	if not holders.erase(owner.get_instance_id()):
		return
	if holders.is_empty():
		_lock_holders.erase(lock_id)
		lock_finished.emit(lock_id)

func is_locked(lock_id: StringName) -> bool:
	return _lock_holders.has(lock_id)

## True when any active lock blocks the capability.
func is_blocked(capability: StringName) -> bool:
	for lock_id in _lock_holders:
		if ActionLock2D.blocks(lock_id, capability):
			return true
	return false

func can(capability: StringName) -> bool:
	return not is_blocked(capability)

func _init(owner: CharacterBody2D) -> void:
	character = owner
	# The player uses a layered Node2D rig with CharacterAnimation and a dedicated
	# WeaponPivot. Enemies may still use AnimatedSprite2D and a legacy weapon node.
	visual_root = owner.get_node_or_null("Player") as Node2D
	if visual_root != null:
		character_animation_player = visual_root.get_node_or_null("CharacterAnimation") as AnimationPlayer
	if character_animation_player == null:
		character_animation_player = owner.get_node_or_null("CharacterAnimation") as AnimationPlayer
	animated_sprite = owner.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	var layered_weapon_pivot := owner.get_node_or_null("Player/WeaponPivot") as Node2D
	var weapon: Sprite2D
	if layered_weapon_pivot != null:
		weapon = layered_weapon_pivot.get_node_or_null("Weapon") as Sprite2D
	if weapon == null:
		weapon = owner.get_node_or_null("Player/Weapon") as Sprite2D
	if weapon == null:
		weapon = owner.get_node_or_null("AnimatedSprite2D/Weapon") as Sprite2D
	if weapon == null:
		weapon = owner.get_node_or_null("WeaponFlipPivot/Weapon") as Sprite2D
	if weapon == null:
		weapon = owner.get_node_or_null("WeaponFlipPivot/Sword") as Sprite2D
	if weapon == null:
		weapon = owner.get_node_or_null("Weapon") as Sprite2D
	if weapon == null:
		weapon = owner.get_node_or_null("Sword") as Sprite2D

	if weapon == null:
		push_warning("CharacterContext2D: '%s' has no Weapon/Sprite2D node." % owner.name)
		return

	var legacy_pivot := owner.get_node_or_null("WeaponFlipPivot") as Node2D
	if layered_weapon_pivot != null:
		weapon_pivot = layered_weapon_pivot
	elif legacy_pivot != null:
		weapon_pivot = legacy_pivot
	else:
		# Legacy enemy weapons still animate their own rotation, so preserve them as pivots.
		weapon_pivot = weapon

	weapon_animation_player = null
	if is_instance_valid(layered_weapon_pivot):
		weapon_animation_player = layered_weapon_pivot.get_node_or_null("WeaponAnimation") as AnimationPlayer
	if weapon_animation_player == null:
		weapon_animation_player = weapon.get_node_or_null("WeaponAnimation") as AnimationPlayer
	if weapon_animation_player == null:
		weapon_animation_player = weapon.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if weapon_animation_player == null and is_instance_valid(legacy_pivot):
		weapon_animation_player = legacy_pivot.get_node_or_null("WeaponAnimation") as AnimationPlayer

	if weapon_animation_player == null:
		push_warning("CharacterContext2D: '%s' weapon has no AnimationPlayer." % owner.name)
		return

	# Both supported layouts resolve the animation root to the weapon pivot:
	# Player/WeaponPivot for the layered player, or Weapon for legacy enemies.
	# ../.. then targets CharacterBody2D, where spawn_slash() is defined.
	for animation_name in weapon_animation_player.get_animation_list():
		var animation := weapon_animation_player.get_animation(animation_name)
		for track_index in range(animation.get_track_count()):
			if animation.track_get_type(track_index) == Animation.TYPE_METHOD:
				animation.track_set_path(track_index, NodePath("../.."))

## Play idle/run for AnimationPlayer-based characters or fall back to AnimatedSprite2D.
## Do not let locomotion interrupt the authored take_damage/RESET animation sequence.
func play_locomotion_animation(animation_name: StringName) -> void:
	if is_instance_valid(character_animation_player):
		var current := character_animation_player.current_animation
		if (
			character_animation_player.is_playing()
			and (current == &"take_damage" or current == &"RESET")
		):
			return
		if character_animation_player.has_animation(animation_name):
			if current != animation_name or not character_animation_player.is_playing():
				character_animation_player.play(animation_name)
			return

	if (
		animated_sprite != null
		and animated_sprite.sprite_frames != null
		and animated_sprite.sprite_frames.has_animation(animation_name)
	):
		if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
			animated_sprite.play(animation_name)

## Plays a "death" clip when the character has one. Otherwise freezes the current pose,
## so a dead character never keeps looping its idle or run animation.
func play_death_animation() -> void:
	if is_instance_valid(character_animation_player):
		if character_animation_player.has_animation(&"death"):
			character_animation_player.play(&"death")
		else:
			character_animation_player.stop(true)
		return
	if animated_sprite != null:
		if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(&"death"):
			animated_sprite.play(&"death")
		else:
			animated_sprite.pause()
