@tool
extends AnimateSymbolLibrary
class_name SparrowAtlas


@export_file_path("*.xml") var source_path: String:
	set(v):
		source_path = v
		parse()
		path_changed.emit()

@export var texture: Texture2D:
	set(v):
		texture = v
		redraw_requested.emit()

@export var override_texture := false

@export_range(0.0, 100.0, 0.01, "or_greater") var framerate: float = 24.0
@export_tool_button("Export", "SpriteFrames") var export_spriteframes := export

@export_storage var frames: Array[SparrowFrame]
@export_storage var symbols: PackedStringArray

# Caches the relationship between symbols -> frames
# so that there is less time needed to filter the
# frames array every frame
var _internal_frames_cache: Dictionary[StringName, Array]

# Yes I really got to this point of optimization. I'm not kidding.
# (And it really does help performance a LITTLE).
var _internal_bounding_cache: Dictionary[StringName, Rect2]

var _internal_image: Image

# Helps save both on time and on the size of exported SpriteFrames
var _internal_rotated_cache: Dictionary[Rect2, AtlasTexture]


func parse() -> void:
	has_symbols_with_commas = false
	frames.clear()
	symbols.clear()
	_internal_frames_cache.clear()
	_internal_bounding_cache.clear()

	var basename: String = source_path.get_basename()
	var cache_path: String = "%s.res" % [basename]
	if ResourceLoader.exists(cache_path):
		var cached: SparrowAtlas = load(cache_path)
		framerate = cached.framerate
		frames = cached.frames
		texture = cached.texture
		symbols = cached.symbols
		check_symbols_have_commas(symbols)
		symbols_changed.emit()
		return

	if not FileAccess.file_exists(source_path):
		printerr("Failed to find sparrow at path \"%s\"!" % [source_path])
		symbols_changed.emit()
		return

	var xml: XMLParser = XMLParser.new()
	var open_error: Error = xml.open(source_path)
	if open_error != OK:
		printerr("Failed to open XML, error code: %s!" % [open_error])
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

	check_symbols_have_commas(symbols)
	symbols_changed.emit()


func cache() -> void:
	var basename: String = source_path.get_basename()
	take_over_path("%s.res" % [basename])
	ResourceSaver.save(self, "%s.res" % [basename], ResourceSaver.FLAG_COMPRESS + ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)


func draw_2d(target: AnimateSymbol2D) -> void:
	var sparrow_frame: SparrowFrame = _get_filtered_frame(target.symbol, target.frame)
	if not is_instance_valid(sparrow_frame):
		return

	var canvas_item: RID = target.get_canvas_item()
	var offset: Vector2 = -sparrow_frame.offset.position
	offset += target.offset

	if target.centered:
		offset -= get_symbol_rect(target.symbol).size / 2.0

	if sparrow_frame.rotated:
		RenderingServer.canvas_item_add_set_transform(
			canvas_item,
			Transform2D(
				-PI / 2.0,
				Vector2(
					offset.x,
					sparrow_frame.region.size.x + offset.y
				),
			),
		)
	else:
		RenderingServer.canvas_item_add_set_transform(
			canvas_item,
			Transform2D(0.0, offset),
		)

	RenderingServer.canvas_item_add_texture_rect_region(
		canvas_item,
		Rect2(Vector2.ZERO, sparrow_frame.region.size),
		texture,
		sparrow_frame.region,
	)


func get_framerate() -> float:
	return framerate


func get_filename() -> StringName:
	return StringName(source_path.get_file())


func get_symbol_list() -> PackedStringArray:
	return symbols


func get_symbol_length(key: StringName) -> int:
	if not _internal_frames_cache.has(key):
		_internal_frames_cache[key] = _get_filtered_frames(key)

	return maxi(_internal_frames_cache[key].size() - 1, 0)


func has_symbol(symbol: StringName) -> bool:
	return symbols.has(String(symbol))


func get_symbol_rect(symbol: StringName) -> Rect2:
	if not _internal_bounding_cache.has(symbol):
		var filtered: Array[SparrowFrame] = _get_filtered_frames(symbol)
		var bounding: Rect2 = Rect2()
		for frame: SparrowFrame in filtered:
			if frame.rotated:
				bounding = bounding.merge(Rect2(
					Vector2.ZERO,
					Vector2(frame.region.size.y, frame.region.size.x)
				))
			else:
				bounding = bounding.merge(Rect2(Vector2.ZERO, frame.region.size))

		_internal_bounding_cache[symbol] = bounding

	return _internal_bounding_cache[symbol]


func export() -> void:
	if frames.is_empty() or (not is_instance_valid(texture)):
		printerr("Cannot export blank or invalid Sparrow atlas!")
		return

	var sprite_frames: SpriteFrames = SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	if not symbols.is_empty():
		for symbol: String in symbols:
			_add_symbol_to_frames(sprite_frames, symbol)

	# Equivalent to blank (which means all) on the AnimateSymbol
	sprite_frames.add_animation(&" ")
	sprite_frames.set_animation_speed(&" ", framerate)
	sprite_frames.set_animation_loop(&" ", false)
	for frame: SparrowFrame in frames:
		_add_frame_to_frames(sprite_frames, " ", frame)

	var basename: String = source_path.get_basename()
	sprite_frames.take_over_path("%s_frames.res" % [basename])
	ResourceSaver.save(
		sprite_frames,
		"%s_frames.res" % [basename],
		ResourceSaver.FLAG_COMPRESS + \
		ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	)
	_internal_image = null
	_internal_rotated_cache.clear()


func _add_symbol_to_frames(sprite_frames: SpriteFrames, symbol: String) -> void:
	sprite_frames.add_animation(symbol)
	sprite_frames.set_animation_speed(symbol, framerate)
	sprite_frames.set_animation_loop(symbol, false)

	var filtered: Array = _get_filtered_frames(symbol)
	var max_frame_size: Vector2
	for frame: SparrowFrame in filtered:
		if frame.offset.size.x > max_frame_size.x:
			max_frame_size.x = frame.offset.size.x
		if frame.offset.size.y > max_frame_size.y:
			max_frame_size.y = frame.offset.size.y

	for frame: SparrowFrame in filtered:
		# hopefully, this should fix some really weird edge cases
		# with improper frame width and frame heights!!! :3
		if frame.offset.size.x < max_frame_size.x:
			frame.offset.size.x = max_frame_size.x
		if frame.offset.size.y < max_frame_size.y:
			frame.offset.size.y = max_frame_size.y

		_add_frame_to_frames(sprite_frames, symbol, frame)


func _add_frame_to_frames(sprite_frames: SpriteFrames, symbol: String, frame: SparrowFrame) -> void:
	var atlas_texture: AtlasTexture = AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.filter_clip = true
	atlas_texture.region = frame.region
	atlas_texture.margin = Rect2(
		-frame.offset.position,
		frame.offset.size - frame.region.size
	)

	if frame.rotated:
		if not _internal_rotated_cache.has(frame.region):
			# I really wish there was a better way of doing this
			# but as far as I know there isn't one. (Part of the reason
			# sparrow even exists as an option is so I could optimize
			# this out lol)
			if not is_instance_valid(_internal_image):
				_internal_image = texture.get_image()

			var rotated: Image = _internal_image.get_region(frame.region)
			rotated.rotate_90(COUNTERCLOCKWISE)

			atlas_texture.atlas = ImageTexture.create_from_image(rotated)
			atlas_texture.region = Rect2(
				Vector2.ZERO,
				Vector2(frame.region.size.y, frame.region.size.x),
			)
			atlas_texture.margin.size = frame.offset.size - Vector2(frame.region.size.y, frame.region.size.x)
			_internal_rotated_cache[frame.region] = atlas_texture
		else:
			atlas_texture = _internal_rotated_cache[frame.region].duplicate()

			# Just in case the frame offset somehow
			# changes even though the frame is the same
			atlas_texture.margin.position = -frame.offset.position

	sprite_frames.add_frame(symbol, atlas_texture)


func _get_filtered_frame(prefix: String, frame: int) -> SparrowFrame:
	if frames.is_empty():
		return null
	if not _internal_frames_cache.has(prefix):
		_internal_frames_cache[prefix] = _get_filtered_frames(prefix)

	var filtered: Array = _internal_frames_cache[prefix]
	if filtered.is_empty():
		return null
	else:
		return filtered[mini(frame, maxi(filtered.size() - 1, 0))]


func _get_filtered_frames(filter: String) -> Array[SparrowFrame]:
	if filter.strip_edges().is_empty():
		return frames.duplicate()

	return frames.filter(func(frame: SparrowFrame) -> bool:
		# Fallback (prefixing)
		if not symbols.has(filter):
			return frame.name.begins_with(filter)

		return (
			frame.name.left(frame.name.length() - 4) == filter and
			frame.name.right(4).is_valid_int()
		)
	)
