extends Node
class_name CurrencyComponent2D
signal balance_changed(new_balance: int, delta: int)
@export_range(0, 2147483647, 1) var starting_balance: int = 0
var balance: int = 0
func _ready() -> void: balance = maxi(starting_balance, 0)
func earn(amount: int) -> int:
	if amount <= 0: return 0
	var before := balance
	balance = mini(balance + amount, 2147483647)
	balance_changed.emit(balance, balance - before)
	return balance - before
func spend(amount: int) -> bool:
	if amount <= 0 or balance < amount: return false
	balance -= amount
	balance_changed.emit(balance, -amount)
	return true
func save_state() -> Dictionary: return {"balance": balance}
func load_state(data: Dictionary) -> void:
	var value: Variant = data.get("balance", 0)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var next := clampi(int(value), 0, 2147483647)
		var delta := next - balance
		balance = next
		if delta != 0: balance_changed.emit(balance, delta)
