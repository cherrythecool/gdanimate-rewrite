@tool
@abstract
extends Resource
class_name AnimateAtlas


@export_storage var format: String = "placeholder"

@export_tool_button("Parse", "Reload") var parse_atlas: Callable = parse
@export_tool_button("Cache", "Save") var cache_atlas: Callable = cache
var ask_redraw: bool = true


func free() -> void:
	clean()


func parse() -> void:
	ask_redraw = true


func cache() -> void:
	pass


func draw_on(canvas_item: RID, draw_info: AnimateDrawInfo) -> void:
	pass


func get_framerate() -> float:
	return 24.0


func get_filename() -> String:
	return "Unknown"


func wants_redraw() -> bool:
	var prev: bool = ask_redraw
	ask_redraw = false
	return prev


func clean() -> void:
	pass
