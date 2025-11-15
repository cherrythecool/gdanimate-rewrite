@tool
extends AnimateAtlas
class_name AdobeAtlas


## Path to any file in the animation path (like Animation.json, spritemap1.json, etc),
## or the folder that contains those files.
@export_dir var folder_path: String = "":
	set(v):
		folder_path = v
		parse()

# TODO: Implement
## For more like SWF behavior, set to true.
@export var movie_clips_play: bool = false

@export_storage var spritemap: Dictionary[StringName, AdobeAtlasSprite] = {}
@export_storage var symbols: Dictionary[StringName, AdobeSymbol] = {}
@export_storage var framerate: float = 24.0
@export_storage var stage_symbol: StringName = &""
@export_storage var stage_transform: Transform2D = Transform2D.IDENTITY


func parse() -> void:
	super()
	format = "adobe"

	var base_dir: String = folder_path.get_base_dir()
	var cache_path: String = "%s/Animation.res" % [base_dir]
	if ResourceLoader.exists(cache_path):
		var cached: AdobeAtlas = load(cache_path)
		if is_instance_valid(cached):
			spritemap = cached.spritemap
			symbols = cached.symbols
			framerate = cached.framerate
			stage_symbol = cached.stage_symbol
			stage_transform = cached.stage_transform
			return
	
	spritemap.clear()
	symbols.clear()
	
	var animation_json: String = "%s/Animation.json" % [base_dir]
	if not ResourceLoader.exists(animation_json):
		printerr("Atlas path (%s) is missing Animation.json!" % [base_dir])
		return
	
	_load_spritemaps()
	_load_animation()


func cache() -> void:
	super()

	var basename: String = folder_path.get_base_dir()
	ResourceSaver.save(self, "%s/Animation.res" % [basename], ResourceSaver.FLAG_COMPRESS)


func draw_on(canvas_item: RID, draw_info: AnimateDrawInfo) -> void:
	super(canvas_item, draw_info)
	
	if stage_symbol.is_empty():
		return
	
	var use_stage: bool = not symbols.has(draw_info.symbol)
	var key: StringName = stage_symbol if use_stage else draw_info.symbol
	var transform: Transform2D = Transform2D.IDENTITY
	transform = transform.translated(draw_info.offset)
	if use_stage and stage_transform != Transform2D.IDENTITY:
		transform *= stage_transform
	
	var stage_item: RID = RenderingServer.canvas_item_create()
	draw_info.items.push_back(stage_item)
	RenderingServer.canvas_item_set_transform(stage_item, transform)
	RenderingServer.canvas_item_set_parent(stage_item, canvas_item)
	RenderingServer.canvas_item_set_draw_behind_parent(stage_item, true)
	RenderingServer.canvas_item_set_use_parent_material(stage_item, true)
	
	_draw_symbol(symbols[key],
		stage_item,
		Transform2D.IDENTITY,
		draw_info.frame,
		false,
		draw_info.items
	)


func get_framerate() -> float:
	return framerate


func get_filename() -> String:
	return folder_path.get_base_dir().get_file()


func get_symbols() -> String:
	var string: String = ""
	for symbol_name: StringName in symbols.keys():
		string += "%s," % [symbol_name.json_escape()]
	if not string.is_empty():
		string.remove_char(string.length() - 1)
	
	return ("" if string.is_empty() else " ,") + string


func get_length_of(symbol: StringName) -> int:
	if not symbols.has(symbol):
		symbol = stage_symbol
	
	if symbols.has(symbol):
		return symbols[symbol].length
	
	return 0


static func get_layer_path(layers: Array[String], id: int) -> String:
	var value: String = ""
	for layer: String in layers:
		value += layer
	value += " {%d}" % [id]
	return value


func _draw_symbol(target: AdobeSymbol, parent: RID,
				t: Transform2D, frame: int,
				is_clipper: bool, items: Array[RID]) -> void:
	if frame > target.length - 1:
		frame = target.length - 1
	
	var to_push: Array[RID] = []
	var clip_pushes: Dictionary[StringName, Array] = {}
	var rids: Dictionary[StringName, RID] = {}
	for layer: AdobeLayer in target.layers:
		var layer_rid: RID
		var layer_parent: RID = parent
		if not is_clipper:
			layer_rid = RenderingServer.canvas_item_create()
			RenderingServer.canvas_item_set_use_parent_material(layer_rid, true)
			rids.set(layer.name, layer_rid)
			
			if layer.clipping:
				RenderingServer.canvas_item_set_canvas_group_mode(layer_rid, RenderingServer.CANVAS_GROUP_MODE_CLIP_ONLY)
			elif not layer.clipped_by.is_empty():
				if not clip_pushes.has(layer.clipped_by):
					clip_pushes.set(layer.clipped_by, [])
				
				clip_pushes[layer.clipped_by].push_front(layer_rid)
				layer_parent = rids.get(layer.clipped_by, parent)
		else:
			layer_rid = parent
		
		var rendered: bool = false
		for layer_frame: AdobeLayerFrame in layer.frames:
			if frame > layer_frame.starting_index + layer_frame.duration - 1:
				continue
			if frame < layer_frame.starting_index:
				continue
			
			rendered = true
			for element: AdobeDrawable in layer_frame.elements:
				if element is AdobeSymbolInstance:
					_draw_symbol(
						symbols[element.key],
						layer_rid,
						t * element.transform,
						element.first_frame,
						is_clipper or layer.clipping,
						items
					)
				elif element is AdobeAtlasSprite:
					_draw_atlas_sprite(
						element as AdobeAtlasSprite,
						layer_rid,
						t
					)
		
		if rendered and (not is_clipper) and layer_parent == parent:
			to_push.push_front(layer_rid)
	
	var i: int = items.size() - 1
	for item: RID in to_push:
		items.push_back(item)
		RenderingServer.canvas_item_set_parent(item, parent)
		RenderingServer.canvas_item_set_draw_index(item, i)
		i += 1
	
	for key: StringName in clip_pushes.keys():
		var array: Array = clip_pushes[key]
		var clip_parent: RID = rids[key]
		
		i = items.size() - 1
		for item: RID in array:
			items.push_back(item)
			RenderingServer.canvas_item_set_parent(item, clip_parent)
			RenderingServer.canvas_item_set_draw_index(item, i)
			i += 1


func _draw_atlas_sprite(sprite: AdobeAtlasSprite, parent: RID, t: Transform2D) -> void:
	var transform: Transform2D = t * sprite.transform
	if sprite.rotated:
		transform *= Transform2D(
			-PI / 2.0, #deg_to_rad(-90.0),
			Vector2(0.0, sprite.region.size.x)
		)
	
	RenderingServer.canvas_item_add_set_transform(parent, transform)
	RenderingServer.canvas_item_add_texture_rect_region(
		parent,
		Rect2(Vector2.ZERO, Vector2(sprite.region.size)),
		sprite.texture.get_rid(),
		Rect2(sprite.region),
	)


func _load_spritemaps() -> void:
	var files: PackedStringArray = ResourceLoader.list_directory(folder_path.get_base_dir())
	for file: String in files:
		if not file.begins_with("spritemap"):
			continue
		if not file.get_extension() == "json":
			continue
		
		_load_spritemap(file)


func _load_spritemap(spritemap_name: String) -> void:
	var base_dir: String = folder_path.get_base_dir()
	var raw_json: String = FileAccess.get_file_as_string("%s/%s" % [base_dir, spritemap_name])
	var json: Variant = JSON.parse_string(raw_json)
	if json == null:
		printerr("Failed to parse %s/%s as JSON!" % [base_dir, spritemap_name])
		return

	var texture: Texture2D = load("%s/%s.png" % [base_dir, spritemap_name.get_basename()])
	if not is_instance_valid(texture):
		printerr("Failed to load %s/%s.png as Texture2D!" % [base_dir, spritemap_name.get_basename()])
		return
	
	var data: Dictionary = json as Dictionary
	if not data.has("ATLAS"):
		printerr("Malformed spritemap json has no ATLAS property!")
		return
	data = data.get("ATLAS")
	
	var image: Image = null
	var sprites: Array = data.get("SPRITES", [])
	for sprite: Dictionary in sprites:
		var sprite_data: Dictionary = sprite.get("SPRITE", {})
		var atlas_sprite: AdobeAtlasSprite = AdobeAtlasSprite.new()
		atlas_sprite.region = Rect2i(
			Vector2i(
				int(sprite_data.get("x", 0.0)),
				int(sprite_data.get("y", 0.0))
			),
			Vector2i(
				int(sprite_data.get("w", 0.0)),
				int(sprite_data.get("h", 0.0))
			)
		)
		atlas_sprite.rotated = sprite_data.get("rotated", false)
		atlas_sprite.texture = texture
		
		spritemap.set(StringName(sprite_data.get("name", "")), atlas_sprite)


func _load_animation() -> void:
	var base_dir: String = folder_path.get_base_dir()
	var raw_json: String = FileAccess.get_file_as_string("%s/Animation.json" % [base_dir])
	var json: Variant = JSON.parse_string(raw_json)
	if json == null:
		printerr("Failed to parse %s/Animation.json as JSON!" % [base_dir])
		return
	
	var data: Dictionary = json as Dictionary
	var optimized: bool = data.has("AN")
	
	var meta: Dictionary = _get_pair(optimized, data, "metadata", "MD")
	framerate = _get_pair(optimized, meta, "framerate", "FRT")
	
	var symbol_dict: Dictionary = _get_pair(optimized, data, "SYMBOL_DICTIONARY", "SD")
	var symbol_array: Array = _get_pair(optimized, symbol_dict, "Symbols", "S")
	_load_symbols(optimized, symbol_array)
	
	var anim: Dictionary = _get_pair(optimized, data, "ANIMATION", "AN")
	stage_symbol = _get_pair(optimized, anim, "SYMBOL_name", "SN")
	_load_symbol(optimized, anim)
	
	if _has_pair(optimized, anim, "StageInstance", "STI"):
		var stage: Dictionary = _get_pair(optimized, anim, "StageInstance", "STI")
		var instance: Dictionary = _get_pair(optimized, stage, "SYMBOL_Instance", "SI")
		stage_transform = _parse_matrix(_get_pair(optimized, instance, "Matrix3D", "M3D"))
	else:
		stage_transform = Transform2D.IDENTITY


func _load_symbols(optimized: bool, symbol_array: Array) -> void:
	for symbol: Dictionary in symbol_array:
		_load_symbol(optimized, symbol)


func _load_symbol(optimized: bool, symbol: Dictionary) -> void:
	var key: String = _get_pair(optimized, symbol, "SYMBOL_name", "SN")
	var gd_symbol: AdobeSymbol = AdobeSymbol.new()
	
	var timeline: Dictionary = _get_pair(optimized, symbol, "TIMELINE", "TL")
	var layers: Array = _get_pair(optimized, timeline, "LAYERS", "L")
	for layer: Dictionary in layers:
		var gd_layer: AdobeLayer = AdobeLayer.new()
		gd_layer.name = _get_pair(optimized, layer, "Layer_name", "LN")
		if _has_pair(optimized, layer, "Layer_type", "LT"):
			if optimized:
				gd_layer.clipping = layer["LT"] == "Clp"
			else:
				gd_layer.clipping = layer["Layer_type"] == "Clipper"
		if _has_pair(optimized, layer, "Clipped_by", "Clpb"):
			gd_layer.clipped_by = _get_pair(optimized, layer, "Clipped_by", "Clpb")
		
		var duration: int = 0
		var frames: Array = _get_pair(optimized, layer, "Frames", "FR")
		for frame: Dictionary in frames:
			gd_layer.frames.push_back(_load_frame(optimized, frame))
			duration += gd_layer.frames[gd_layer.frames.size() - 1].duration
		
		if gd_symbol.length < duration:
			gd_symbol.length = duration
		
		gd_symbol.layers.push_back(gd_layer)
	
	symbols[StringName(key)] = gd_symbol


func _load_frame(optimized: bool, frame: Dictionary) -> AdobeLayerFrame:
	var gd_frame: AdobeLayerFrame = AdobeLayerFrame.new()
	gd_frame.starting_index = _get_pair(optimized, frame, "index", "I")
	gd_frame.duration = _get_pair(optimized, frame, "duration", "DU")
	
	var elements: Array = _get_pair(optimized, frame, "elements", "E")
	for element: Dictionary in elements:
		if element.has("SYMBOL_Instance") or element.has("SI"):
			gd_frame.elements.push_back(_load_symbol_instance(optimized, element))
		else:
			gd_frame.elements.push_back(_load_atlas_sprite(optimized, element))
	
	return gd_frame


func _load_symbol_instance(optimized: bool, element: Dictionary) -> AdobeSymbolInstance:
	var symbol_instance: AdobeSymbolInstance = AdobeSymbolInstance.new()
	element = _get_pair(optimized, element, "SYMBOL_Instance", "SI")

	var key: String = _get_pair(optimized, element, "SYMBOL_name", "SN")
	symbol_instance.key = StringName(key)
	if _has_pair(optimized, element, "firstFrame", "FF"):
		symbol_instance.first_frame = _get_pair(optimized, element, "firstFrame", "FF")
	else:
		symbol_instance.first_frame = 0
	
	symbol_instance.transform = _parse_matrix(_get_pair(optimized, element, "Matrix3D", "M3D"))
	
	if _has_pair(optimized, element, "loop", "LP"):
		var loop_mode: String = _get_pair(optimized, element, "loop", "LP")
		if optimized:
			match loop_mode:
				"PO":
					symbol_instance.loop_mode = AdobeSymbolInstance.AdobeSymbolLoopMode.ONE_SHOT
				"SF":
					symbol_instance.loop_mode = AdobeSymbolInstance.AdobeSymbolLoopMode.FREEZE_FRAME
				"LP":
					symbol_instance.loop_mode = AdobeSymbolInstance.AdobeSymbolLoopMode.LOOP
				_:
					symbol_instance.loop_mode = AdobeSymbolInstance.AdobeSymbolLoopMode.LOOP
		else:
			match loop_mode:
				"playonce":
					symbol_instance.loop_mode = AdobeSymbolInstance.AdobeSymbolLoopMode.ONE_SHOT
				"singleframe":
					symbol_instance.loop_mode = AdobeSymbolInstance.AdobeSymbolLoopMode.FREEZE_FRAME
				"loop":
					symbol_instance.loop_mode = AdobeSymbolInstance.AdobeSymbolLoopMode.LOOP
				_:
					symbol_instance.loop_mode = AdobeSymbolInstance.AdobeSymbolLoopMode.LOOP
	else:
		symbol_instance.loop_mode = AdobeSymbolInstance.AdobeSymbolLoopMode.LOOP
	
	var type: String = _get_pair(optimized, element, "symbolType", "ST")
	if optimized:
		symbol_instance.type = (
			AdobeSymbolInstance.AdobeSymbolType.MOVIE_CLIP
			if type == "MC" else
			AdobeSymbolInstance.AdobeSymbolType.GRAPHIC
		)
	else:
		symbol_instance.type = (
			AdobeSymbolInstance.AdobeSymbolType.MOVIE_CLIP
			if type == "movieclip" else
			AdobeSymbolInstance.AdobeSymbolType.GRAPHIC
		)
	
	return symbol_instance


func _load_atlas_sprite(optimized: bool, element: Dictionary) -> AdobeAtlasSprite:
	element = _get_pair(optimized, element, "ATLAS_SPRITE_instance", "ASI")
	
	var key_raw: String = _get_pair(optimized, element, "name", "N")
	var key: StringName = StringName(key_raw)
	if not spritemap.has(key):
		return AdobeAtlasSprite.new()
	
	var sprite: AdobeAtlasSprite = spritemap[key].duplicate()
	sprite.transform = _parse_matrix(_get_pair(optimized, element, "Matrix3D", "M3D"))
	return sprite


func _parse_matrix(matrix: Variant) -> Transform2D:
	if matrix == null:
		return Transform2D.IDENTITY
	
	if matrix is Dictionary:
		return Transform2D(
			Vector2(matrix["m00"], matrix["m01"]),
			Vector2(matrix["m10"], matrix["m11"]),
			Vector2(matrix["m30"], matrix["m31"])
		)
	
	return Transform2D(
		Vector2(matrix[0], matrix[1]),
		Vector2(matrix[4], matrix[5]),
		Vector2(matrix[12], matrix[13])
	)


func _has_pair(optimized: bool, dict: Dictionary, unoptim: String, optim: String) -> bool:
	return dict.has(optim if optimized else unoptim)


func _get_pair(optimized: bool, dict: Dictionary, unoptim: String, optim: String) -> Variant:
	return dict.get(optim if optimized else unoptim)
