## Node that plays out a Flash/Adobe Animate symbol.
##
## Symbols can be stored in different formats but are accepted
## as any [AnimateSymbolLibrary]
@tool
@icon("animate_symbol_2d.svg")
extends Node2D
class_name AnimateSymbol2D


@export_group("Symbol", "symbol_")
@export var symbol_libraries: Array[AnimateSymbolLibrary] = []
@export var symbol_library_index: int = 0:
	set(value):
		value = clampi(value, 0, maxi(symbol_libraries.size() - 1, 0))

		if not symbol_libraries.is_empty():
			value %= symbol_libraries.size()
		if symbol_library_index != value:
			notify_property_list_changed()
			queue_redraw()
		symbol_library_index = value
		frame = frame

@export_tool_button("Reparse Current", "Reload") var symbol_reparse: Callable = reparse_current
@export_tool_button("Cache Current", "Save") var symbol_cache: Callable = cache_current

@export_group("Animation")
@export var symbol: String = "":
	set(value):
		if symbol != value:
			queue_redraw()
		symbol = value
		frame = frame

@export var frame: int = 0:
	set(value):
		value = clampi(value, 0, maxi(get_animation_length() - 1, 0))
		if frame != value:
			queue_redraw()
		frame = value
@export var speed_scale: float = 1.0

@export var playing: bool = false
@export var loop: bool = false
@export var autoplay: bool = false

@export_group("Offset")
@export var centered: bool = true:
	set(value):
		if centered != value:
			queue_redraw()
		centered = value
@export var offset: Vector2 = Vector2.ZERO:
	set(value):
		if offset != value:
			queue_redraw()
		offset = value
@export var flip_h: bool = false:
	set(value):
		if flip_h != value:
			queue_redraw()
		flip_h = value
@export var flip_v: bool = false:
	set(value):
		if flip_v != value:
			queue_redraw()
		flip_v = value

var frame_timer: float = 0.0
var internal_canvas_items: Array[RID] = []
var last_symbol_libraries_size: int = 0
var adobe_atlas_material: ShaderMaterial = null
var current_library: AnimateSymbolLibrary = null:
	set(v):
		if current_library == v:
			return
		if is_instance_valid(current_library):
			if current_library.symbols_changed.is_connected(_on_symbols_changed):
				current_library.symbols_changed.disconnect(_on_symbols_changed)
			if current_library.redraw_requested.is_connected(_on_redraw_requested):
				current_library.redraw_requested.disconnect(_on_redraw_requested)

		current_library = v
		queue_redraw()
		if is_instance_valid(current_library):
			if not current_library.symbols_changed.is_connected(_on_symbols_changed):
				current_library.symbols_changed.connect(_on_symbols_changed)
			if not current_library.redraw_requested.is_connected(_on_redraw_requested):
				current_library.redraw_requested.connect(_on_redraw_requested)


func _enter_tree() -> void:
	set_process(true)
	if autoplay and not Engine.is_editor_hint():
		playing = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_PROCESS:
		var delta: float = get_process_delta_time()
		process(delta)


func process(delta: float) -> void:
	if symbol_libraries.size() != last_symbol_libraries_size:
		last_symbol_libraries_size = symbol_libraries.size()
		notify_property_list_changed()
		frame = frame
	if symbol_libraries.is_empty():
		symbol_library_index = 0
		return
	if symbol_library_index > symbol_libraries.size() - 1:
		symbol_library_index = maxi(symbol_libraries.size() - 1, 0)
	current_library = symbol_libraries[symbol_library_index]
	if not is_instance_valid(current_library):
		return
	if not playing:
		return

	var frames_per_second: float = current_library.get_framerate()
	var seconds_per_frame: float = 1.0 / frames_per_second
	var sign: float = signf(speed_scale)
	frame_timer += absf(delta) * absf(speed_scale)
	if frame_timer >= seconds_per_frame * sign:
		var added: int = floori(frame_timer * frames_per_second) * int(sign)
		if loop:
			frame = wrapi(frame + added, 0, get_animation_length())
		else:
			# Stop playing animation after it has finished.
			if added > 0 and frame == get_animation_length() - 1:
				playing = false
			frame = clampi(frame + added, 0, maxi(get_animation_length() - 1, 0))
		frame_timer = fmod(frame_timer, seconds_per_frame)


func _validate_property(property: Dictionary) -> void:
	if property.name == "symbol":
		property.hint = PROPERTY_HINT_PLACEHOLDER_TEXT
		property.hint_string = "Name or Prefix"

		if symbol_libraries.is_empty():
			return
		if not is_instance_valid(current_library):
			return
		var symbols: PackedStringArray = current_library.get_symbol_list()
		if symbols.is_empty():
			return
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = AnimateSymbolLibrary.format_symbol_list(
			current_library.get_symbol_list()
		)
	if property.name == "symbol_library_index":
		property.hint_string = ""
		if symbol_libraries.is_empty():
			property.hint = PROPERTY_HINT_NONE
			return

		property.hint = PROPERTY_HINT_ENUM
		for i: int in symbol_libraries.size():
			var library: AnimateSymbolLibrary = symbol_libraries[i]
			if not is_instance_valid(library):
				property.hint_string += "%d - N/A" % [i]
				continue
			property.hint_string += "%d - %s" % [i, library.get_filename()]
			if i != symbol_libraries.size() - 1:
				property.hint_string += ","


func _draw() -> void:
	RenderingServer.canvas_item_clear(get_canvas_item())
	if not internal_canvas_items.is_empty():
		for rid: RID in internal_canvas_items:
			RenderingServer.canvas_item_clear(rid)
			RenderingServer.free_rid(rid)
		internal_canvas_items.clear()
	if is_instance_valid(current_library):
		current_library.draw_2d(self)


func get_animation_length() -> int:
	if is_instance_valid(current_library):
		return current_library.get_symbol_length(symbol)
	return 0


func cache_current() -> void:
	if symbol_libraries.is_empty():
		return
	var library: AnimateSymbolLibrary = symbol_libraries[symbol_library_index]
	if is_instance_valid(library):
		library.cache()


func reparse_current() -> void:
	if symbol_libraries.is_empty():
		return
	var library: AnimateSymbolLibrary = symbol_libraries[symbol_library_index]
	if is_instance_valid(library):
		library.parse()
		queue_redraw()


func _on_symbols_changed() -> void:
	notify_property_list_changed()
	symbol = &""


func _on_redraw_requested() -> void:
	queue_redraw()
