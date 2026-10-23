extends SCTestCase
## Phase 11: the interact lock, chests paying once, doors using keys, pickups, and coins.

const PLAYER_SCENE := preload("res://player.tscn")
const CHEST_SCENE := preload("res://World/Interactables/Chest.tscn")
const DOOR_SCENE := preload("res://World/Interactables/Door.tscn")
const PICKUP_SCENE := preload("res://World/Interactables/ItemPickup.tscn")
const COIN_SCENE := preload("res://World/Interactables/CoinPickup.tscn")
const KEY := preload("res://Items/key_silver.tres")
const POTION := preload("res://Items/potion_health.tres")

func _player() -> Node:
	var player: Node = PLAYER_SCENE.instantiate()
	add_child(player)
	return player

func test_interact_lock_blocks_actions_and_interaction() -> void:
	var player := _player()
	player.context.acquire_lock(ActionLock2D.INTERACT, player)
	not_ok(player.context.can(ActionLock2D.CAPABILITY_MOVE), "cannot move")
	not_ok(player.context.can(ActionLock2D.CAPABILITY_ATTACK), "cannot attack")
	not_ok(player.context.can(ActionLock2D.CAPABILITY_DASH), "cannot dash")
	not_ok(player._can_interact(), "the interactor is gated")
	player.context.release_lock(ActionLock2D.INTERACT, player)
	ok(player._can_interact(), "interaction allowed again after release")

func test_interactor_gate_is_wired_to_the_player() -> void:
	var player := _player()
	ok(player.interactor.gate.is_valid(), "the player's interactor has a gate")

func test_chest_pays_its_loot_once() -> void:
	var player := _player()
	var chest := CHEST_SCENE.instantiate() as Chest
	add_child(chest)
	chest._on_interacted(player.interactor)
	ok(chest.opened, "opened")
	not_ok(chest.is_available(), "unavailable after opening")
	ok(player.inventory.has_item(KEY, 1), "the guaranteed key is in the loot")
	var keys := player.inventory.count_item(KEY)
	chest._on_interacted(player.interactor)
	eq(player.inventory.count_item(KEY), keys, "a second open pays nothing")
	ok(player.context.is_locked(ActionLock2D.INTERACT), "locked while the lid opens")
	player.context.release_lock(ActionLock2D.INTERACT, player)

func test_door_needs_a_key_and_spends_it() -> void:
	var player := _player()
	var door := DOOR_SCENE.instantiate() as Door
	add_child(door)
	door._on_interacted(player.interactor)
	not_ok(door.opened, "stays locked without a key")
	player.inventory.add_item(KEY, 1)
	door._on_interacted(player.interactor)
	ok(door.opened, "opens with the key")
	eq(player.inventory.count_item(KEY), 0, "the key was spent")
	not_ok(door.is_available(), "an open door is no longer interactable")

func test_item_pickup_collects_once() -> void:
	var player := _player()
	var pickup := PICKUP_SCENE.instantiate() as ItemPickup
	pickup.item = POTION
	add_child(pickup)
	pickup._on_interacted(player.interactor)
	eq(player.inventory.count_item(POTION), 1, "one potion in the pack")
	ok(pickup.collected, "marked collected")
	not_ok(pickup.is_available(), "not available after collecting")

func test_coin_pickup_adds_to_the_wallet() -> void:
	var player := _player()
	var coin := COIN_SCENE.instantiate() as CoinPickup
	add_child(coin)
	var before: int = player.wallet.get_balance(&"coins")
	coin._on_body_entered(player)
	eq(player.wallet.get_balance(&"coins"), before + coin.amount, "coins added")
	ok(coin.collected, "marked collected")
	coin._on_body_entered(player)
	eq(player.wallet.get_balance(&"coins"), before + coin.amount, "a second touch pays nothing")
