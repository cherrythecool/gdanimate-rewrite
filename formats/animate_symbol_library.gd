@tool
@abstract
extends Resource
class_name AnimateSymbolLibrary


@export_tool_button("Parse", "Reload") var parse_button: Callable = parse
@export_tool_button("Cache", "Save") var cache_button: Callable = cache

signal redraw_requested
signal symbols_changed


func get_framerate() -> float:
	return 24.0


func get_filename() -> String:
	return "Unknown"


func get_symbol_list() -> PackedStringArray:
	return []


func get_symbol_length(key: StringName) -> int:
	return 0


func get_symbol_rect(key: StringName) -> Rect2:
	return Rect2()


func parse() -> void:
	pass


func cache() -> void:
	pass


func draw_2d(target: AnimateSymbol2D) -> void:
	pass


static func format_symbol_list(symbols: PackedStringArray) -> String:
	var keys: Array = Array(symbols)
	keys.sort_custom(sort_alphabetical)

	var string_builder: String
	for symbol_name: StringName in keys:
		string_builder += "%s," % [symbol_name.json_escape()]
	if not string_builder.is_empty():
		string_builder.remove_char(string_builder.length() - 1)
	else:
		return " "

	return " ," + string_builder


static func sort_alphabetical(a: Variant, b: Variant) -> bool:
	if "to_lower" in a and "to_lower" in b:
		return a.to_lower() < b.to_lower()
	return a < b
