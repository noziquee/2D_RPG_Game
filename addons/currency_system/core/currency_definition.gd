class_name CurrencyDefinition
extends Resource
## Definition of a single currency (gold, gems, wood…) — a resource to create
## in the editor (.tres) or in code. It does not hold a balance itself —
## balances are held by [Wallet].

## Unique identifier, e.g. &"gold".
@export var id: StringName
## Name shown in the UI / tooltips.
@export var display_name := ""
## Currency icon (shown in the [WalletBarUI] pill).
@export var icon: Texture2D
## Currency color — tints the pill border and the gain animations.
@export var color := Color("ffc23e")


static func create(p_id: StringName, p_name: String, p_icon: Texture2D = null,
		p_color := Color("ffc23e")) -> CurrencyDefinition:
	var def := CurrencyDefinition.new()
	def.id = p_id
	def.display_name = p_name
	def.icon = p_icon
	def.color = p_color
	return def
