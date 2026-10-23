class_name Wallet
extends Node
## The player's wallet — balances of multiple currencies. Logic independent of the UI.
##
## Currencies are registered through [method register_currency] ([CurrencyDefinition]
## definitions), then you operate on balances: [method add],
## [method try_spend], [method can_afford]. It reports every change through
## signals — the UI ([WalletBarUI]) only listens.
##
## Balances are int (as in most games). When you need fractions
## (e.g. 2.5 of a crystal), store the value in a smaller unit (250 shards).

## Emitted after a new currency is registered.
signal currency_registered(definition: CurrencyDefinition)
## Emitted after every balance change (also via [method set_balance]).
signal balance_changed(id: StringName, old_value: int, new_value: int)
## Emitted when a balance increased via [method add].
signal gained(id: StringName, amount: int)
## Emitted after a successful spend ([method try_spend]).
signal spent(id: StringName, amount: int)
## Emitted on a failed spend attempt (e.g. the UI can shake the pill).
signal spend_denied(id: StringName, amount: int, missing: int)

## Currency definitions for automatic registration at startup
## (convenient when configuring in the editor; in code use register_currency).
@export var currencies: Array[CurrencyDefinition] = []

var _definitions := {}  # id -> CurrencyDefinition
var _balances := {}     # id -> int


func _ready() -> void:
	for def in currencies:
		if def != null and not _definitions.has(def.id):
			register_currency(def)


# --- Registration ------------------------------------------------------------

## Registers a currency with a starting balance. Re-registering the same
## id only replaces the definition (the balance stays).
func register_currency(definition: CurrencyDefinition, starting_balance := 0) -> void:
	assert(definition.id != &"", "CurrencyDefinition requires a non-empty id")
	var is_new: bool = not _definitions.has(definition.id)
	_definitions[definition.id] = definition
	if is_new:
		_balances[definition.id] = maxi(0, starting_balance)
		currency_registered.emit(definition)


func has_currency(id: StringName) -> bool:
	return _definitions.has(id)


func get_definition(id: StringName) -> CurrencyDefinition:
	return _definitions.get(id)


## Currency identifiers in registration order.
func get_currency_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in _definitions:
		ids.append(id)
	return ids


# --- Balance operations ------------------------------------------------------

func get_balance(id: StringName) -> int:
	return _balances.get(id, 0)


## Adds funds. Returns the new balance.
func add(id: StringName, amount: int) -> int:
	assert(_definitions.has(id), "Unknown currency: %s" % id)
	if amount <= 0:
		return get_balance(id)
	var old: int = _balances[id]
	_balances[id] = old + amount
	balance_changed.emit(id, old, _balances[id])
	gained.emit(id, amount)
	return _balances[id]


func can_afford(id: StringName, amount: int) -> bool:
	return get_balance(id) >= amount


## Can the player afford a basket in multiple currencies, e.g. {&"gold": 100, &"wood": 5}?
func can_afford_all(costs: Dictionary) -> bool:
	for id in costs:
		if not can_afford(id, costs[id]):
			return false
	return true


## Tries to spend funds. On insufficient funds returns false, changes nothing
## and emits [signal spend_denied].
func try_spend(id: StringName, amount: int) -> bool:
	assert(_definitions.has(id), "Unknown currency: %s" % id)
	if amount <= 0:
		return true
	var old: int = _balances[id]
	if old < amount:
		spend_denied.emit(id, amount, amount - old)
		return false
	_balances[id] = old - amount
	balance_changed.emit(id, old, _balances[id])
	spent.emit(id, amount)
	return true


## Tries to pay for a basket in multiple currencies — all or nothing.
func try_spend_all(costs: Dictionary) -> bool:
	if not can_afford_all(costs):
		for id in costs:
			if not can_afford(id, costs[id]):
				spend_denied.emit(id, costs[id], costs[id] - get_balance(id))
		return false
	for id in costs:
		try_spend(id, costs[id])
	return true


## Sets the balance directly (e.g. when loading a save or in cheats).
func set_balance(id: StringName, value: int) -> void:
	assert(_definitions.has(id), "Unknown currency: %s" % id)
	value = maxi(0, value)
	var old: int = _balances[id]
	if old == value:
		return
	_balances[id] = value
	balance_changed.emit(id, old, value)


# --- Serialization -----------------------------------------------------------

## Balances for a game save (a Dictionary ready for JSON).
func to_dict() -> Dictionary:
	var data := {}
	for id in _balances:
		data[String(id)] = _balances[id]
	return data


## Restores balances saved by [method to_dict].
## Currencies must be registered beforehand; unknown ids are skipped.
func from_dict(data: Dictionary) -> void:
	for key in data:
		var id := StringName(key)
		if _definitions.has(id):
			set_balance(id, int(data[key]))
