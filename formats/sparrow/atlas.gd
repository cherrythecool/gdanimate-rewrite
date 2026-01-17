@tool
extends AnimateSymbolLibrary
class_name SparrowAtlas


@export_file_path("*.xml") var source_path: String = "":
	set(v):
		source_path = v
		parse()

@export var texture: Texture2D = null:
	set(v):
		texture = v
		redraw_requested.emit()
@export var override_texture: bool = false

@export var framerate: float = 24.0
@export_tool_button("Export", "SpriteFrames") var export_spriteframes: Callable = export

@export_storage var frames: Array[SparrowFrame] = []
@export_storage var symbols: PackedStringArray = []

# Caches the relationship between symbols -> frames
# so that there is less time needed to filter the
# frames array every frame
var internal_frames_cache: Dictionary[String, Array] = {}

# Yes I really got to this point of optimization. I'm not kidding.
# (And it really does help performance a LITTLE).
var internal_bounding_cache: Dictionary[String, Rect2] = {}

var internal_image: Image = null

# Helps save both on time and on the size of exported SpriteFrames
var internal_rotated_cache: Dictionary[Rect2, AtlasTexture] = {}


func parse() -> void:
	super()

	frames.clear()
	symbols.clear()
	internal_frames_cache.clear()
	internal_bounding_cache.clear()

	var basename: String = source_path.get_basename()
	var cache_path: String = "%s.res" % [basename]
	if ResourceLoader.exists(cache_path):
		var cached: SparrowAtlas = load(cache_path)
		framerate = cached.framerate
		frames = cached.frames
		texture = cached.texture
		symbols = cached.symbols
		symbols_changed.emit()
		return

	if not FileAccess.file_exists(source_path):
		printerr("Failed to find sparrow at path \"%s\"!" % [source_path])
		symbols_changed.emit()
		return

	var xml: XMLParser = XMLParser.new()
	var err: Error = OK
	err = xml.open(source_path)
	if err != OK:
		printerr("Failed to open XML, error code: %s!" % [err])
		symbols_changed.emit()
		return

	while xml.read() != ERR_FILE_EOF:
		if xml.get_node_type() != XMLParser.NODE_ELEMENT:
			continue

		var node_name: String = xml.get_node_name().to_lower()
		match node_name:
			"textureatlas":
				if override_texture:
					continue
				var path: String = "%s/%s" % [
					source_path.get_base_dir(),
					xml.get_named_attribute_value_safe("imagePath"),
				]

				if not ResourceLoader.exists(path):
					path = "%s.png" % [source_path.get_basename()]
				if ResourceLoader.exists(path):
					texture = load(ResourceUID.path_to_uid(path))
			"subtexture":
				var frame: SparrowFrame = SparrowFrame.new()
				frame.name = xml.get_named_attribute_value_safe("name")
				frame.region = Rect2(
					Vector2(
						float(xml.get_named_attribute_value_safe("x")),
						float(xml.get_named_attribute_value_safe("y"))
					),
					Vector2(
						float(xml.get_named_attribute_value_safe("width")),
						float(xml.get_named_attribute_value_safe("height"))
					)
				)

				if xml.has_attribute("frameX"):
					frame.offset = Rect2(
						Vector2(
							float(xml.get_named_attribute_value_safe("frameX")),
							float(xml.get_named_attribute_value_safe("frameY"))
						),
						Vector2(
							float(xml.get_named_attribute_value_safe("frameWidth")),
							float(xml.get_named_attribute_value_safe("frameHeight"))
						)
					)
				else:
					frame.offset = Rect2(Vector2.ZERO, frame.region.size)

				frame.rotated = xml.get_named_attribute_value_safe("rotated") == "true"
				frames.push_back(frame)

	frames.sort_custom(SparrowFrame.sort_by_name)
	for frame: SparrowFrame in frames:
		if frame.name.length() < 4:
			continue
		var numbers: String = frame.name.right(4)
		var cutout: String = frame.name.left(-4)
		if (not symbols.has(cutout)) and numbers.is_valid_int():
			symbols.push_back(cutout)

	symbols_changed.emit()


func cache() -> void:
	super()

	var basename: String = source_path.get_basename()
	take_over_path("%s.res" % [basename])
	ResourceSaver.save(self, "%s.res" % [basename], ResourceSaver.FLAG_COMPRESS + ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)


func get_framerate() -> float:
	return framerate


func get_filename() -> String:
	return source_path.get_file()


func get_symbol_list() -> PackedStringArray:
	return symbols


func get_symbol_length(key: StringName) -> int:
	if not internal_frames_cache.has(key):
		internal_frames_cache[key] = get_filtered_frames(key)
	return maxi(internal_frames_cache[key].size() - 1, 0)


func draw_2d(target: AnimateSymbol2D) -> void:
	super(target)

	var sparrow_frame: SparrowFrame = get_filtered_frame(target.symbol, target.frame)
	if not is_instance_valid(sparrow_frame):
		push_warning("Cannot draw invalid sparrow atlas frame!")
		return

	var canvas_item: RID = target.get_canvas_item()
	var offset: Vector2 = -sparrow_frame.offset.position
	offset += target.offset
	if target.centered:
		offset -= get_bounding_box(target.symbol).size / 2.0

	if sparrow_frame.rotated:
		RenderingServer.canvas_item_add_set_transform(canvas_item,
			Transform2D(
				-PI / 2.0,
				Vector2(
					offset.x,
					sparrow_frame.region.size.x + offset.y
				),
			)
		)
	else:
		RenderingServer.canvas_item_add_set_transform(canvas_item,
			Transform2D(0.0, offset)
		)

	RenderingServer.canvas_item_add_texture_rect_region(canvas_item,
		Rect2(Vector2.ZERO, sparrow_frame.region.size),
		texture, sparrow_frame.region,
	)


func get_bounding_box(symbol: String) -> Rect2:
	if not internal_bounding_cache.has(symbol):
		var filtered: Array[SparrowFrame] = get_filtered_frames(symbol)
		var bounding: Rect2 = Rect2()
		for frame: SparrowFrame in filtered:
			if frame.rotated:
				bounding = bounding.merge(Rect2(
					Vector2.ZERO,
					Vector2(frame.region.size.y, frame.region.size.x)
				))
			else:
				bounding = bounding.merge(Rect2(Vector2.ZERO, frame.region.size))
		internal_bounding_cache[symbol] = bounding
	return internal_bounding_cache[symbol]


func export() -> void:
	if frames.is_empty() or (not is_instance_valid(texture)):
		printerr("Cannot export blank or invalid Sparrow atlas!")
		return

	var sprite_frames: SpriteFrames = SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	if not symbols.is_empty():
		for symbol: String in symbols:
			add_symbol_to_frames(sprite_frames, symbol)
	sprite_frames.add_animation(&" ")
	sprite_frames.set_animation_speed(&" ", framerate)
	sprite_frames.set_animation_loop(&" ", false)
	for frame: SparrowFrame in frames:
		add_frame_to_frames(sprite_frames, " ", frame)

	var basename: String = source_path.get_basename()
	sprite_frames.take_over_path("%s_frames.res" % [basename])
	ResourceSaver.save(sprite_frames, "%s_frames.res" % [basename], ResourceSaver.FLAG_COMPRESS + ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	internal_image = null
	internal_rotated_cache.clear()


func add_symbol_to_frames(sprite_frames: SpriteFrames, symbol: String) -> void:
	sprite_frames.add_animation(symbol)
	sprite_frames.set_animation_speed(symbol, framerate)
	sprite_frames.set_animation_loop(symbol, false)

	var filtered: Array = get_filtered_frames(symbol)
	for frame: SparrowFrame in filtered:
		add_frame_to_frames(sprite_frames, symbol, frame)


func add_frame_to_frames(sprite_frames: SpriteFrames, symbol: String, frame: SparrowFrame) -> void:
	var atlas_texture: AtlasTexture = AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.filter_clip = true
	atlas_texture.region = frame.region
	atlas_texture.margin = Rect2(
		-frame.offset.position,
		frame.offset.size - frame.region.size
	)

	if frame.rotated:
		if not internal_rotated_cache.has(frame.region):
			if not is_instance_valid(internal_image):
				internal_image = texture.get_image()
			var rotated: Image = internal_image.get_region(frame.region)
			rotated.rotate_90(COUNTERCLOCKWISE)

			atlas_texture.atlas = ImageTexture.create_from_image(rotated)
			atlas_texture.region = Rect2(
				Vector2.ZERO,
				Vector2(frame.region.size.y, frame.region.size.x),
			)
			atlas_texture.margin.size = frame.offset.size - Vector2(frame.region.size.y, frame.region.size.x)
			internal_rotated_cache[frame.region] = atlas_texture
		else:
			atlas_texture = internal_rotated_cache[frame.region].duplicate()
			# Just in case this comes up someday somehow
			atlas_texture.margin.position = -frame.offset.position

	sprite_frames.add_frame(symbol, atlas_texture)


func get_filtered_frame(prefix: String, frame: int) -> SparrowFrame:
	if frames.is_empty():
		return null
	if not internal_frames_cache.has(prefix):
		internal_frames_cache[prefix] = get_filtered_frames(prefix)

	var filtered: Array = internal_frames_cache[prefix]
	if filtered.is_empty():
		return null
	else:
		return filtered[mini(frame, maxi(filtered.size() - 1, 0))]


func get_filtered_frames(filter: String) -> Array[SparrowFrame]:
	return frames.filter(func(frame: SparrowFrame) -> bool:
		if filter.strip_edges().is_empty():
			return true
		if not symbols.has(filter):
			return frame.name.begins_with(filter)
		else:
			return (
				frame.name.substr(0, frame.name.length() - 4) == filter and
				frame.name.right(4).is_valid_int()
			)
	)
