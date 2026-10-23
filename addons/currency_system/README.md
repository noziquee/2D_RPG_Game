# Currency System — currencies and the player's wallet

A portable Godot 4 component: a multi-currency wallet (gold, gems, resources…)
with a bar of animated counters. You move it to another game by copying the
`addons/currency_system/` folder. **Zero dependencies** on other components.

## What it contains

| File | Class | Role |
|---|---|---|
| `core/currency_definition.gd` | `CurrencyDefinition` (Resource) | currency definition: id, name, icon, color |
| `core/wallet.gd` | `Wallet` (Node) | balances + operations — works without a UI |
| `ui/wallet_bar_ui.gd` | `WalletBarUI` (HBoxContainer) | pills with animated counters |
| `ui/wallet_style.gd` | `WalletStyle` | palette, font, StyleBoxes, "1.5K" format |

## Quick start

```gdscript
# logic
var wallet := Wallet.new()
add_child(wallet)
wallet.register_currency(
	CurrencyDefinition.create(&"gold", "Gold",
		preload("res://icons/coin.svg"), Color("ffc23e")),
	starting_balance = 100)
wallet.register_currency(
	CurrencyDefinition.create(&"gems", "Gems",
		preload("res://icons/gem.svg"), Color("58c4f0")))

# UI
var bar := WalletBarUI.new()
hud.add_child(bar)
bar.wallet = wallet     # the pills build themselves, then just listen
```

Operations:

```gdscript
wallet.add(&"gold", 250)                    # the counter rolls, "+250" floats up
if wallet.try_spend(&"gold", 100):          # false = the pill shakes red
	give_player_a_sword()
wallet.can_afford_all({&"gold": 50, &"wood": 5})   # multi-currency costs
wallet.try_spend_all({&"gold": 50, &"wood": 5})    # all or nothing
```

Currency definitions can also be created as `.tres` files in the editor and plugged
into the exported `currencies` array of the `Wallet` node — they register themselves.

## API — `Wallet`

**Methods:** `register_currency(def, starting_balance)`, `get_balance(id)`,
`add(id, amount)`, `can_afford(id, amount)`, `try_spend(id, amount)`,
`can_afford_all(costs)`, `try_spend_all(costs)` (all or nothing),
`set_balance(id, value)`, `get_currency_ids()`, `get_definition(id)`,
`to_dict()` / `from_dict(data)` (serialization for a game save).

**Signals:** `currency_registered(definition)`,
`balance_changed(id, old, new)`, `gained(id, amount)`, `spent(id, amount)`,
`spend_denied(id, amount, missing)` — the UI reacts to the last one
(a shake), but you can also e.g. play an error sound.

Balances are `int` — when you need fractions, store the value
in a smaller unit (250 shards instead of 2.5 crystals).

## API — `WalletBarUI`

**Properties:** `wallet` (wallet attachment), `icon_size`, `font_size`,
`compact_numbers` ("1.5K" notation / full numbers).

**Built-in effects:** a rolling counter, a scale pop and a floating "+N"
on a gain, a shake with a red flash on a denied spend.

## Styling

All colors and StyleBoxes come from `ui/wallet_style.gd` — matching it to
your own game is a matter of changing the constants in this one file. The Fredoka font is in
`theme/fonts/` inside the addon; without it the component uses the theme's font.

## Demo

`demo/currency_demo.tscn` (in the library project, outside the addon) — a shop:
earning gold, buying with different currencies, refusal when funds are insufficient.
