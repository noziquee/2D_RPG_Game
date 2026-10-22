class_name FloatingTextStyle
extends RefCounted
## The central look of the floating_text_system component: palette and font.
##
## The palette is consistent with the rest of the component library, but the file
## is intentionally duplicated in every addon — a component moves by copying its
## folder. To match your own game, change the constants here.

static var COLOR_OUTLINE := Color("241c1c")

## Colors of the combat number/text presets.
static var COLOR_DAMAGE := Color("ff6354")       # damage dealt
static var COLOR_DAMAGE_TAKEN := Color("ff8d98") # damage taken (lighter)
static var COLOR_CRIT := Color("ffc23e")         # critical hit
static var COLOR_HEAL := Color("6fdc73")
static var COLOR_MANA := Color("6f9bff")
static var COLOR_XP := Color("c08af0")
static var COLOR_GOLD := Color("ffd23e")
static var COLOR_MISS := Color("b9ac9c")         # MISS / DODGE / BLOCK
static var COLOR_TEXT := Color("f7f1e5")

static var _font_base: Font
static var _font_variants := {}


## Returns the font (Fredoka) at the given weight (400–700).
## When the font file does not exist, returns null — the component then uses
## the theme's default font and still works.
static func get_font(weight := 700) -> Font:
	if _font_variants.has(weight):
		return _font_variants[weight]
	if _font_base == null:
		var path := "res://addons/floating_text_system/theme/fonts/Fredoka-Variable.ttf"
		if not ResourceLoader.exists(path):
			return null
		_font_base = load(path)
	var variation := FontVariation.new()
	variation.base_font = _font_base
	variation.variation_opentype = {"wght": weight}
	_font_variants[weight] = variation
	return variation


## Sets the font and colors on a Label (with a thick outline — readability
## on any background is essential for combat numbers).
static func style_label(label: Label, size: int, color: Color,
		outline_size := 5) -> void:
	var font := get_font(700)
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", outline_size)


# --- Central theming ---------------------------------------------------
##
## The values above are this component's built-in look, and stay authoritative when
## the component is used on its own. [code]ComponentTheme[/code] / [code]ThemeDirector[/code]
## (addons/ui_theme_system) are optional: install them and every style file in the pack
## can be driven from a single resource. Nothing here references that addon — the theme
## is duck-typed, so this file still works when it is not installed.

static var _theme_defaults := {}


## Remembers the built-in look on first use, so [method reset_theme] can restore it.
static func _capture_theme_defaults() -> void:
	if not _theme_defaults.is_empty():
		return
	_theme_defaults = {
		&"outline": COLOR_OUTLINE,
		&"damage": COLOR_DAMAGE,
		&"damage_taken": COLOR_DAMAGE_TAKEN,
		&"crit": COLOR_CRIT,
		&"heal": COLOR_HEAL,
		&"mana": COLOR_MANA,
		&"xp": COLOR_XP,
		&"gold": COLOR_GOLD,
		&"miss": COLOR_MISS,
		&"text": COLOR_TEXT,
		&"__font": _font_base,
	}


## Applies a shared theme, overriding the values above.
## [br][br]
## [param theme] is any object exposing [code]get_color(role, fallback)[/code],
## [code]get_metric(role, fallback)[/code] and a [code]font[/code] property — normally a
## [code]ComponentTheme[/code]. Roles the theme does not define keep the built-in value,
## so a partial theme is fine. Pass null to restore the built-in look.
## [br][br]
## Call before your UI is built, or follow with [code]ThemeDirector.refresh(root)[/code].
static func apply_theme(theme) -> void:
	if theme == null:
		reset_theme()
		return
	_capture_theme_defaults()
	COLOR_OUTLINE = theme.get_color(&"outline", _theme_defaults[&"outline"])
	COLOR_DAMAGE = theme.get_color(&"damage", _theme_defaults[&"damage"])
	COLOR_DAMAGE_TAKEN = theme.get_color(&"damage_taken", _theme_defaults[&"damage_taken"])
	COLOR_CRIT = theme.get_color(&"crit", _theme_defaults[&"crit"])
	COLOR_HEAL = theme.get_color(&"heal", _theme_defaults[&"heal"])
	COLOR_MANA = theme.get_color(&"mana", _theme_defaults[&"mana"])
	COLOR_XP = theme.get_color(&"xp", _theme_defaults[&"xp"])
	COLOR_GOLD = theme.get_color(&"gold", _theme_defaults[&"gold"])
	COLOR_MISS = theme.get_color(&"miss", _theme_defaults[&"miss"])
	COLOR_TEXT = theme.get_color(&"text", _theme_defaults[&"text"])
	_font_base = theme.font if theme.font != null else _theme_defaults[&"__font"]
	_font_variants.clear()


## Restores the built-in look. No-op when no theme was ever applied.
static func reset_theme() -> void:
	if _theme_defaults.is_empty():
		return
	COLOR_OUTLINE = _theme_defaults[&"outline"]
	COLOR_DAMAGE = _theme_defaults[&"damage"]
	COLOR_DAMAGE_TAKEN = _theme_defaults[&"damage_taken"]
	COLOR_CRIT = _theme_defaults[&"crit"]
	COLOR_HEAL = _theme_defaults[&"heal"]
	COLOR_MANA = _theme_defaults[&"mana"]
	COLOR_XP = _theme_defaults[&"xp"]
	COLOR_GOLD = _theme_defaults[&"gold"]
	COLOR_MISS = _theme_defaults[&"miss"]
	COLOR_TEXT = _theme_defaults[&"text"]
	_font_base = _theme_defaults[&"__font"]
	_font_variants.clear()
