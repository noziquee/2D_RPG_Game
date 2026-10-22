extends Resource
class_name ItemDefinition2D
## Stable content identity. Keep `id` unchanged after release; display names may change.
@export var id: StringName = &""
@export var display_name: String = "Unnamed Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_enum("quest", "consumable", "key", "currency", "material") var category: String = "material"
@export_range(1, 999, 1) var max_stack: int = 99
@export var unique: bool = false
