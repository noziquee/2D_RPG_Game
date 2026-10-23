class_name LootEntry
extends Resource
## One possible drop in a [LootTable]: an item (or a nested table) plus how much
## and how likely.
##
## Two roles, depending on [member guaranteed]:
## [br]• [b]weighted[/b] (default) — competes in the table's weighted picks; the
##   relative [member weight] decides how often it is chosen,
## [br]• [b]guaranteed[/b] — rolled on its own each time the table is rolled,
##   dropping when an independent [member chance] check passes (1.0 = always).
##
## An entry yields a random count in [[member min_count], [member max_count]]. Set
## [member table] instead of [member item] to nest another table (rolled recursively).

## The item that drops. Leave null when this entry nests a [member table].
@export var item: ItemDefinition
## A nested table, rolled recursively. Alternative to [member item].
@export var table: LootTable
## Relative weight among the table's weighted entries (ignored when [member guaranteed]).
@export_range(0.0, 1000.0, 0.1, "or_greater") var weight := 1.0
## Minimum units dropped.
@export_range(1, 9999) var min_count := 1
## Maximum units dropped.
@export_range(1, 9999) var max_count := 1
## When true, this entry is rolled independently (not in the weighted pool).
@export var guaranteed := false
## Drop chance for a [member guaranteed] entry (0..1; 1 = always drops).
@export_range(0.0, 1.0, 0.01) var chance := 1.0

@export_group("Pity")
## Force this entry to drop once it has missed this many [method LootTable.roll]s in a
## row. 0 = no pity. [code]pity_after = 30[/code] reads as "at least one every 30 rolls":
## after 29 misses the 30th roll drops it whatever the dice said.
## [br][br]
## Works for weighted and chance-based entries alike. Needs a stable [method pity_key].
@export_range(0, 999, 1, "or_greater") var pity_after := 0
## Stable key for pity bookkeeping and saves. Defaults to the item's id, so you only
## need to set it for a nested table (which has no item) or when two entries share one
## item but should count pity separately.
@export var id: StringName = &""


## Key this entry's pity counter is stored under. Empty = this entry cannot use pity.
func pity_key() -> StringName:
	if id != &"":
		return id
	if item != null:
		return item.id
	return &""


## Whether this entry takes part in pity bookkeeping.
func has_pity() -> bool:
	return pity_after > 0 and pity_key() != &""


static func create(p_item: ItemDefinition, p_min := 1, p_max := 1, p_weight := 1.0) -> LootEntry:
	var e := LootEntry.new()
	e.item = p_item
	e.min_count = p_min
	e.max_count = maxi(p_min, p_max)
	e.weight = p_weight
	return e


## A guaranteed entry that always (or, with [param p_chance] < 1, sometimes) drops.
static func create_guaranteed(p_item: ItemDefinition, p_min := 1, p_max := 1,
		p_chance := 1.0) -> LootEntry:
	var e := create(p_item, p_min, p_max)
	e.guaranteed = true
	e.chance = p_chance
	return e


## A weighted entry with pity: rare by the dice, but never absent for longer than
## [param p_pity_after] rolls. The roguelite "legendary at least every 30 chests".
static func create_with_pity(p_item: ItemDefinition, p_pity_after: int,
		p_min := 1, p_max := 1, p_weight := 1.0) -> LootEntry:
	var e := create(p_item, p_min, p_max, p_weight)
	e.pity_after = p_pity_after
	return e


## A nested table reference (its own roll is merged into the result).
static func create_table(p_table: LootTable, p_guaranteed := true, p_chance := 1.0) -> LootEntry:
	var e := LootEntry.new()
	e.table = p_table
	e.guaranteed = p_guaranteed
	e.chance = p_chance
	return e


## Random unit count for one drop of this entry.
func roll_count(rng: RandomNumberGenerator) -> int:
	if max_count <= min_count:
		return min_count
	return rng.randi_range(min_count, max_count)
