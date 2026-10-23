class_name SaveMigrations
extends RefCounted
## Chains per-version migration steps for [SaveManager], so old saves keep loading.
##
## You write one small step per version bump — "v1 » v2" — and this walks a save from
## whatever version it was written at up to the current one, applying each step in turn.
## A player who last played on v1 and comes back at v4 runs 1»2»3»4 with no extra code.
##
## [b]What a step actually receives[/b]: the state [Dictionary] [SaveManager] builds, keyed
## by the ids you passed to [method SaveManager.register], where each value is whatever
## that system's save function returned. So migrations are usually "rename a system" or
## "reshape one system's dictionary" — not free-form surgery.
##
## [codeblock]
## # v1: register(&"gold",   ...) saved {"amount": 320}
## # v2: renamed to &"wallet",     saves {"gold": 320}
## # v3: added register(&"settings", ...)
## var migrations := SaveMigrations.new()
## migrations.target_version = 3
## migrations.add(1, func(state: Dictionary) -> Dictionary:
##     var old: Dictionary = state.get("gold", {})
##     state["wallet"] = {"gold": old.get("amount", 0)}
##     state.erase("gold")
##     return state)
## migrations.add(2, func(state: Dictionary) -> Dictionary:
##     state["settings"] = {"difficulty": "normal"}   # a default for old saves
##     return state)
##
## saves.save_version = 3
## saves.migrator = migrations.as_callable()
## [/codeblock]
##
## Why steps rather than one big [code]if version == 1: ... elif version == 2: ...[/code]:
## each step only has to know about one bump — the bump you were actually thinking about
## when you made the change. The chain composes them for you, and a player who last
## played on v1 runs 1»2»3 without you writing a 1»3 path by hand.
##
## Each step takes the state [Dictionary] and returns it (mutated or rebuilt). Use
## [code].get(key, default)[/code] rather than [code][key][/code]: a save from an older
## build may be missing anything.

## The version steps should reach — normally the same as [member SaveManager.save_version].
## 0 = chain as far as the registered steps go.
var target_version := 0

var _steps := {}   # from_version -> Callable(state) -> Dictionary


## Registers the step that turns a [param from_version] save into a
## [code]from_version + 1[/code] one. Returns self, so calls chain.
func add(from_version: int, step: Callable) -> SaveMigrations:
	if _steps.has(from_version):
		push_warning("SaveMigrations: replacing the existing step for v%d." % from_version)
	_steps[from_version] = step
	return self


## Whether a save written at [param from_version] can reach [member target_version].
## Use it to tell the player "this save is too old" instead of loading half-migrated data.
func can_migrate(from_version: int) -> bool:
	var v := from_version
	var goal := _goal()
	if v > goal:
		return false          # a save from the future: a newer build wrote it
	while v < goal:
		if not _steps.has(v):
			return false
		v += 1
	return true


## Walks [param state] from [param from_version] up to [member target_version].
##
## Returns the migrated state. A gap in the chain is a programming error, not a player
## error: it warns loudly and returns the state it managed to reach rather than
## pretending it succeeded — check [method can_migrate] first if you want to refuse.
func migrate(state: Dictionary, from_version: int) -> Dictionary:
	var v := from_version
	var goal := _goal()
	while v < goal:
		if not _steps.has(v):
			push_warning("SaveMigrations: no step for v%d » v%d; the save stops at v%d."
				% [v, v + 1, v])
			break
		state = _steps[v].call(state)
		v += 1
	return state


## The [code]Callable(state, from_version)[/code] [member SaveManager.migrator] expects.
func as_callable() -> Callable:
	return func(state: Dictionary, from_version: int) -> Dictionary:
		return migrate(state, from_version)


## Versions with a registered step, ascending. Handy in a test or a debug console.
func steps() -> Array:
	var out := _steps.keys()
	out.sort()
	return out


func _goal() -> int:
	if target_version > 0:
		return target_version
	# No explicit target: the newest version any step can produce.
	var highest := 0
	for from_version: int in _steps:
		highest = maxi(highest, from_version + 1)
	return highest
