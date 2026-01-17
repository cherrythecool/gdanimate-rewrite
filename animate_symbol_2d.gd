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

var current_library: AnimateSymbolLibrary = null:
	set(value):
		if current_library == value:
			return
		if is_instance_valid(current_library):
			disconnect_from_library(current_library)

		current_library = value
		if is_instance_valid(current_library):
			connect_to_library(current_library)

		queue_redraw()

var frame_timer: float = 0.0
var internal_canvas_items: Array[RID] = []
var last_symbol_libraries_size: int = 0


func _enter_tree() -> void:
	set_process(true)

	if autoplay and not Engine.is_editor_hint():
		playing = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_PROCESS:
		process(get_process_delta_time())


func process(delta: float) -> void:
	if symbol_libraries.size() != last_symbol_libraries_size:
		last_symbol_libraries_size = symbol_libraries.size()
		notify_property_list_changed()
		frame = frame
	if symbol_libraries.is_empty():
		symbol_library_index = 0
		return

	if symbol_library_index > symbol_libraries.size() - 1:
		symbol_library_index = symbol_libraries.size() - 1
	current_library = symbol_libraries[symbol_library_index]
	if not is_instance_valid(current_library):
		return

	if not playing:
		return

	var frames_per_second: float = current_library.get_framerate()
	var seconds_per_frame: float = 1.0 / frames_per_second
	frame_timer += absf(delta * speed_scale)
	if frame_timer >= seconds_per_frame:
		var frames_added: int = floori(frame_timer * frames_per_second)
		frames_added *= int(signf(speed_scale))
		frame_timer = fmod(frame_timer, seconds_per_frame)

		var current_length: int = maxi(get_animation_length() - 1, 0)
		if loop:
			frame = wrapi(frame + frames_added, 0, current_length + 1)
		else:
			# Stop playing animation after it has finished.
			if (frame + frames_added <= 0 or
				frame + frames_added >= current_length):
				playing = false

			frame = clampi(frame + frames_added, 0, current_length)


func _validate_property(property: Dictionary) -> void:
	match property.get("name"):
		"symbol":
			property.hint = PROPERTY_HINT_PLACEHOLDER_TEXT
			property.hint_string = "Name or Prefix"

			if not is_instance_valid(current_library):
				return
			var symbols: PackedStringArray = current_library.get_symbol_list()
			if symbols.is_empty():
				return

			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = AnimateSymbolLibrary.format_symbol_list(symbols)
		"symbol_library_index":
			property.hint_string = ""
			if symbol_libraries.is_empty():
				property.hint = PROPERTY_HINT_NONE
				return

			property.hint = PROPERTY_HINT_ENUM
			for i: int in symbol_libraries.size():
				var filename: String = "N/A"
				var library: AnimateSymbolLibrary = symbol_libraries[i]
				if is_instance_valid(library):
					filename = library.get_filename()

				property.hint_string += "%d - %s" % [i, filename]
				if i != symbol_libraries.size() - 1:
					property.hint_string += ","


func _draw() -> void:
	RenderingServer.canvas_item_clear(get_canvas_item())
	if not internal_canvas_items.is_empty():
		for rid: RID in internal_canvas_items:
			if not rid.is_valid():
				continue
			RenderingServer.canvas_item_clear(rid)
			RenderingServer.free_rid(rid)

		internal_canvas_items.clear()

	if is_instance_valid(current_library):
		current_library.draw_2d(self)


func _on_symbols_changed() -> void:
	notify_property_list_changed()
	symbol = &""


func _on_redraw_requested() -> void:
	queue_redraw()


func disconnect_from_library(library: AnimateSymbolLibrary) -> void:
	if library.symbols_changed.is_connected(_on_symbols_changed):
		library.symbols_changed.disconnect(_on_symbols_changed)
	if library.redraw_requested.is_connected(_on_redraw_requested):
		library.redraw_requested.disconnect(_on_redraw_requested)


func connect_to_library(library: AnimateSymbolLibrary) -> void:
	if not library.symbols_changed.is_connected(_on_symbols_changed):
		library.symbols_changed.connect(_on_symbols_changed)
	if not library.redraw_requested.is_connected(_on_redraw_requested):
		library.redraw_requested.connect(_on_redraw_requested)


func get_animation_length() -> int:
	if is_instance_valid(current_library):
		return current_library.get_symbol_length(symbol)
	else:
		return 0


func cache_current() -> void:
	if is_instance_valid(current_library):
		current_library.cache()


func reparse_current() -> void:
	if is_instance_valid(current_library):
		current_library.parse()
