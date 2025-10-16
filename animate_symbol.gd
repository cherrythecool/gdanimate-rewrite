@tool
@icon("symbol.svg")
extends Node2D
class_name AnimateSymbol


@export_placeholder("Name or Prefix") var symbol: String = "":
	set(value):
		if symbol != value:
			queue_redraw()
		symbol = value

@export var frame: int = 0:
	set(value):
		var length: int = get_animation_length()
		value = _validate_frame(value, length)
		if frame != value:
			queue_redraw()

		frame = value

@export_range(0.0, 10.0, 0.01, "or_greater") var speed_scale: float = 1.0

@export var playing: bool = false
@export var loop: bool = false

@export_group("Offset")

## Tries to center the current sprite based on the size of the frame.
## This may not work on certain formats like texture atlases for now
## due to them not providing any bounding box.
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

@export_group("Atlas")
@export var atlases: Array[AnimateAtlas] = []
@export var atlas_index: int = 0:
	set(value):
		# TODO: maybe find a better solution, but this works for now!
		for atlas: AnimateAtlas in atlases:
			atlas.clean()
		
		if value < 0:
			value = absi(value)
		value %= atlases.size()

		if atlas_index != value:
			queue_redraw()
		atlas_index = value

var frame_timer: float = 0.0


func _validate_property(property: Dictionary) -> void:
	if property.name == "symbol":
		property.hint = PROPERTY_HINT_PLACEHOLDER_TEXT
		property.hint_string = "Name or Prefix"
		
		if atlases.is_empty():
			return
		var atlas: AnimateAtlas = atlases[atlas_index]
		if not is_instance_valid(atlas):
			return
		if atlas is AdobeAtlas:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = atlas.get_symbols()


func _ready() -> void:
	set_notify_local_transform(true)


func _validate_frame(value: int, length: int = -1) -> int:
	if length == -1:
		length = get_animation_length()

	if value < 0:
		value = 0
	if value > length - 1:
		if loop:
			value = wrapi(value, 0, length)
		else:
			value = clampi(value, 0, length - 1)
	if length == 0:
		value = 0

	return value


func _process(delta: float) -> void:
	if atlases.is_empty():
		return
	var atlas: AnimateAtlas = atlases[atlas_index]
	if not is_instance_valid(atlas):
		return
	if atlas.wants_redraw():
		frame = frame
		queue_redraw()
	
	if not playing:
		return

	var fps: float = atlas.get_framerate()
	frame_timer += delta * speed_scale
	if frame_timer >= 1.0 / fps:
		frame += floori(frame_timer * fps)
		frame_timer = wrapf(frame_timer, 0.0, 1.0 / fps)


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		queue_redraw()


func _draw() -> void:
	if atlases.is_empty():
		return
	if atlas_index > atlases.size() - 1:
		atlas_index = 0

	var atlas: AnimateAtlas = atlases[atlas_index]
	if not is_instance_valid(atlas):
		return

	match atlas.format:
		"sparrow":
			_draw_sparrow(atlas as SparrowAtlas)
		"adobe":
			_draw_adobe(atlas as AdobeAtlas)
		_:
			pass


func get_animation_length() -> int:
	if atlases.is_empty():
		return 0
	if atlas_index > atlases.size() - 1:
		atlas_index = 0

	var atlas: AnimateAtlas = atlases[atlas_index]
	if not is_instance_valid(atlas):
		return 0

	match atlas.format:
		"sparrow":
			return (atlas as SparrowAtlas).get_count_filtered(symbol)
		"adobe":
			return (atlas as AdobeAtlas).get_length_of(StringName(symbol))
		_:
			pass

	return 0


func _draw_sparrow(atlas: SparrowAtlas) -> void:
	if not is_instance_valid(atlas.texture):
		return
	if get_animation_length() == 0:
		return

	var sparrow_frame: SparrowFrame = atlas.get_frame_filtered(frame, symbol)
	var draw_offset: Vector2 = offset
	if centered:
		if sparrow_frame.offset.size != Vector2i.ZERO:
			draw_offset -= sparrow_frame.offset.size / 2.0
		else:
			draw_offset -= sparrow_frame.region.size / 2.0

	RenderingServer.canvas_item_clear(get_canvas_item())
	atlas.draw_on(get_canvas_item(), 
		AnimateDrawInfo.new(
			symbol,
			frame,
			draw_offset,
			get_transform()
		)
	)


func _draw_adobe(atlas: AdobeAtlas) -> void:
	RenderingServer.canvas_item_clear(get_canvas_item())
	RenderingServer.canvas_item_set_transform(get_canvas_item(), get_transform())
	atlas.draw_on(get_canvas_item(),
		AnimateDrawInfo.new(
			symbol,
			frame,
			offset,
			get_transform()
		)
	)
