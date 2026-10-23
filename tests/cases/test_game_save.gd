extends SCTestCase
## Phase 12: the game's saved systems round-trip through the save manager, and loading
## restores a correct character state.

const PLAYER_SCENE := preload("res://player.tscn")
const CHEST_SCENE := preload("res://World/Interactables/Chest.tscn")
const PICKUP_SCENE := preload("res://World/Interactables/ItemPickup.tscn")
const COIN_SCENE := preload("res://World/Interactables/CoinPickup.tscn")
const POTION := preload("res://Items/potion_health.tres")
const KEY := preload("res://Items/key_silver.tres")

func _player() -> Node:
	var player: Node = PLAYER_SCENE.instantiate()
	add_child(player)
	return player

func test_player_health_and_position_round_trip() -> void:
	var player := _player()
	player.global_position = Vector2(120, 80)
	var saved: Dictionary = player.save_state()
	player.take_damage(10)
	player.global_position = Vector2(0, 0)
	ok(player.restore_state(saved), "restored")
	eq(player.health, saved["health"], "health restored")
	almost(player.global_position.x, 120.0, "x restored")
	almost(player.global_position.y, 80.0, "y restored")

func test_loading_a_dead_player_brings_them_back() -> void:
	var player := _player()
	var saved: Dictionary = player.save_state()
	player.take_damage(1000)
	ok(player.restore_state(saved), "restored from a dead state")
	ok(player.is_alive(), "alive again")
	eq(player.state_machine.current_state_name, &"Idle", "idle, not still dead")
	ok(player.context.can(ActionLock2D.CAPABILITY_MOVE), "can move again")

func test_load_resets_transient_state() -> void:
	var player := _player()
	var saved: Dictionary = player.save_state()
	player.attack_component.try_start(true, Vector2.RIGHT)
	player.dash_component.try_start(true, Vector2.RIGHT)
	player.context.acquire_lock(ActionLock2D.INTERACT, player)
	ok(player.restore_state(saved), "restored")
	not_ok(player.context.is_attacking, "no attack survives the load")
	not_ok(player.context.is_dashing, "no dash survives the load")
	not_ok(player.context.is_locked(ActionLock2D.INTERACT), "no interaction lock survives the load")

func test_invalid_player_data_changes_nothing() -> void:
	var player := _player()
	player.global_position = Vector2(50, 50)
	var health: int = player.health
	not_ok(player.restore_state({"health": "lots", "position": {"x": 0, "y": 0}}), "wrong type")
	not_ok(player.restore_state({"health": 100000, "position": {"x": 0, "y": 0}}), "above max health")
	not_ok(player.restore_state({"health": 5, "position": {"x": "a", "y": 0}}), "bad position")
	eq(player.health, health, "health untouched by rejected data")
	almost(player.global_position.x, 50.0, "position untouched by rejected data")

func test_inventory_round_trips_through_item_ids() -> void:
	var player := _player()
	player.inventory.add_item(POTION, 2)
	var saved: Dictionary = player._save_inventory()
	player.inventory.clear()
	ok(player._restore_inventory(saved), "restored")
	eq(player.inventory.count_item(POTION), 2, "same potions back")

func test_inventory_rejects_unknown_items_and_oversized_stacks() -> void:
	var player := _player()
	not_ok(player._restore_inventory({"capacity": 27, "slots": [{"id": "not_a_real_item", "count": 1}]}), "unknown item id")
	not_ok(player._restore_inventory({"capacity": 27, "slots": [{"id": "potion_health", "count": 999}]}), "over the stack limit")
	not_ok(player._restore_inventory({"capacity": 0, "slots": []}), "capacity out of range")
	not_ok(player._restore_inventory({"capacity": 27, "slots": "many"}), "slots must be a list")

func test_wallet_round_trips() -> void:
	var player := _player()
	player.wallet.add(&"coins", 7)
	var saved: Dictionary = player._save_wallet()
	player.wallet.set_balance(&"coins", 0)
	ok(player._restore_wallet(saved), "restored")
	eq(player.wallet.get_balance(&"coins"), 7, "coins back")
	not_ok(player._restore_wallet({"coins": -3}), "negative balances are rejected")

func test_chest_and_door_flags_restore() -> void:
	var player := _player()
	var chest := CHEST_SCENE.instantiate() as Chest
	chest.id = &"test_chest"
	add_child(chest)
	ok(chest.apply_save_state({"opened": true}), "applied")
	not_ok(chest.is_available(), "an opened chest stays closed after load")
	not_ok(chest.apply_save_state({"opened": "yes"}), "wrong type is rejected")

func test_collected_pickups_restore_hidden() -> void:
	var pickup := PICKUP_SCENE.instantiate() as ItemPickup
	pickup.item = POTION
	pickup.id = &"test_potion"
	add_child(pickup)
	ok(pickup.apply_save_state({"collected": true}), "applied")
	not_ok(pickup.visible, "hidden once collected")
	not_ok(pickup.is_available(), "cannot be picked up again")
	ok(pickup.apply_save_state({"collected": false}), "loading an uncollected state")
	ok(pickup.visible, "visible again")
	ok(pickup.is_available(), "available again")

func test_coin_pickup_saves_and_restores() -> void:
	var coin := COIN_SCENE.instantiate() as CoinPickup
	coin.id = &"test_coin"
	add_child(coin)
	eq(coin.save_state(), {"collected": false}, "the saved state")
	ok(coin.apply_save_state({"collected": true}), "applied")
	not_ok(coin.visible, "hidden once collected")

func test_end_to_end_quick_save_and_load() -> void:
	var player := _player()
	var saves := SaveManager.new()
	saves.save_dir = "user://test_saves"
	add_child(saves)
	saves.register(&"player", Callable(player, "save_state"), Callable(player, "restore_state"))
	saves.register(&"wallet", Callable(player, "_save_wallet"), Callable(player, "_restore_wallet"))
	player.wallet.add(&"coins", 4)
	ok(saves.save_game("t_e2e"), "saved")
	player.take_damage(1000)
	player.wallet.set_balance(&"coins", 0)
	ok(saves.load_game("t_e2e"), "loaded")
	ok(player.is_alive(), "player is alive again")
	eq(player.wallet.get_balance(&"coins"), 4, "wallet restored")
	saves.delete_slot("t_e2e")
