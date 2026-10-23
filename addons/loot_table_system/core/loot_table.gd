class_name LootTable
extends Resource
## A weighted loot table: rolls produce item stacks ready to hand to an [Inventory].
##
## Each call to [method roll] does three things:
## [br]• rolls every [b]guaranteed[/b] entry independently (drops when its chance passes),
## [br]• performs [member rolls] [b]weighted[/b] picks over the remaining entries,
## [br]• applies [b]pity[/b] — forces any entry that has missed
##   [member LootEntry.pity_after] rolls in a row ("at least one every N").
##
## Entries can nest other tables ([member LootEntry.table]) for tiered/conditional loot,
## and a non-zero [member rng_seed] makes drops reproducible (tests, seeded runs).
## Build tables as .tres resources or in code via [method create].
##
## [b]Pity is state, not definition.[/b] Counters live on the table instance and are not
## saved into the .tres — persist them with [method to_dict] / [method from_dict], and
## call [method duplicate] if two targets must not share one streak.
##
## [b]Dependency:[/b] produces [ItemStack]s from the Inventory System and can drop
## straight into an [Inventory] with [method roll_into].

## The possible drops.
@export var entries: Array[LootEntry] = []
## Number of weighted picks performed per [method roll].
@export_range(0, 50, 1, "or_greater") var rolls := 1
## RNG seed for reproducible drops (0 = use a fresh random seed each run).
@export var rng_seed := 0


static func create(p_entries: Array[LootEntry], p_rolls := 1) -> LootTable:
	var t := LootTable.new()
	t.entries = p_entries
	t.rolls = p_rolls
	return t


## A [RandomNumberGenerator] honouring [member rng_seed] (call once, reuse for a run).
func make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	return rng


## Rolls the table. Pass a shared [param rng] for reproducible/nested rolls;
## omit it to use one seeded from [member rng_seed]. Returns merged [ItemStack]s
## (same item types combined), ready to add to an inventory.
func roll(rng: RandomNumberGenerator = null) -> Array[ItemStack]:
	if rng == null:
		rng = make_rng()
	var result: Array[ItemStack] = []
	var dropped := {}   # LootEntry -> true, so pity knows what the dice already gave

	# 1. guaranteed / independent entries
	for entry in entries:
		if entry == null or not entry.guaranteed:
			continue
		if rng.randf() <= entry.chance:
			_yield_entry(entry, rng, result)
			dropped[entry] = true

	# 2. weighted pool
	var pool: Array[LootEntry] = []
	var total_weight := 0.0
	for entry in entries:
		if entry != null and not entry.guaranteed and entry.weight > 0.0:
			pool.append(entry)
			total_weight += entry.weight
	if total_weight > 0.0:
		for _i in rolls:
			var pick := _pick_weighted(pool, total_weight, rng)
			if pick != null:
				_yield_entry(pick, rng, result)
				dropped[pick] = true

	# 3. pity: force anything that has missed too many rolls in a row
	_apply_pity(result, rng, dropped)
	return result


## Rolls and adds the drops to [param inventory]. Returns the rolled stacks
## (note: the inventory may reject some if it is full — check its leftovers).
func roll_into(inventory: Inventory, rng: RandomNumberGenerator = null) -> Array[ItemStack]:
	var drops := roll(rng)
	if inventory != null:
		for stack in drops:
			inventory.add_item(stack.item, stack.count)
	return drops


# --- Pity ---------------------------------------------------------------------

## Rolls since each pity entry last dropped, keyed by [method LootEntry.pity_key].
## Deliberately not exported: this is [b]state[/b], while the table is a [b]definition[/b].
## A .tres shared by every chest in the game would otherwise ship a save inside itself.
var _pity := {}


## How many rolls this entry has missed in a row.
func get_pity(key: StringName) -> int:
	return _pity.get(key, 0)


## Rolls left until [param key] is forced to drop (0 = the next roll drops it).
## Handy for a "guaranteed in 3" pity counter in the UI.
func rolls_until_pity(key: StringName) -> int:
	for entry in entries:
		if entry != null and entry.has_pity() and entry.pity_key() == key:
			return maxi(0, entry.pity_after - get_pity(key) - 1)
	return -1   # no pity entry with that key


## Forgets every pity counter (new run, new character).
func reset_pity() -> void:
	_pity.clear()


## Pity counters for a save. Feed to [method SaveManager.register] alongside the rest of
## your run state — without this, quitting resets everyone's pity, which players notice.
func to_dict() -> Dictionary:
	var out := {}
	for key: StringName in _pity:
		if _pity[key] > 0:
			out[String(key)] = _pity[key]
	return {"pity": out}


func from_dict(data: Dictionary) -> void:
	_pity.clear()
	for key: String in data.get("pity", {}):
		_pity[StringName(key)] = int(data["pity"][key])


## Forces any pity entry that has run out, and updates every counter.
##
## Runs after the normal roll, so the dice get first refusal: an entry that dropped on
## its own resets its counter and is never forced on top of itself.
func _apply_pity(result: Array[ItemStack], rng: RandomNumberGenerator,
		dropped: Dictionary) -> void:
	for entry in entries:
		if entry == null or entry.pity_after <= 0:
			continue
		var key := entry.pity_key()
		if key == &"":
			push_warning("LootTable: entry with pity_after=%d has no pity_key "
				% entry.pity_after + "(set its `id`, or give it an item) — pity ignored.")
			continue
		if dropped.has(entry):
			_pity[key] = 0
			continue
		var missed: int = get_pity(key) + 1
		if missed >= entry.pity_after:
			_yield_entry(entry, rng, result)
			missed = 0
		_pity[key] = missed


# --- Internal -----------------------------------------------------------------

func _pick_weighted(pool: Array[LootEntry], total_weight: float,
		rng: RandomNumberGenerator) -> LootEntry:
	var roll_value := rng.randf() * total_weight
	for entry in pool:
		roll_value -= entry.weight
		if roll_value <= 0.0:
			return entry
	return pool.back() if not pool.is_empty() else null


## Resolves one entry into the result list (recursing into a nested table).
func _yield_entry(entry: LootEntry, rng: RandomNumberGenerator,
		result: Array[ItemStack]) -> void:
	if entry.table != null:
		for stack in entry.table.roll(rng):
			_add_stack(result, stack.item, stack.count)
	elif entry.item != null:
		_add_stack(result, entry.item, entry.roll_count(rng))


## Adds units of an item, merging with an existing stack of the same type.
func _add_stack(result: Array[ItemStack], item: ItemDefinition, count: int) -> void:
	if item == null or count <= 0:
		return
	for stack in result:
		if stack.item == item:
			stack.count += count
			return
	result.append(ItemStack.create(item, count))
