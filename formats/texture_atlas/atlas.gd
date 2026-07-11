@tool
class_name TextureAtlas
extends AnimateSymbolLibrary


enum BlendMode {
	ADD = 0,
	ALPHA = 1,
	DARKEN = 2,
	DIFFERENCE = 3,
	ERASE = 4,
	HARD_LIGHT = 5,
	INVERT = 6,
	LAYER = 7,
	LIGHTEN = 8,
	MULTIPLY = 9,
	NORMAL = 10,
	OVERLAY = 11,
	SCREEN = 12,
	SHADER = 13,
	SUBTRACT = 14,
}

enum SymbolType {
	GRAPHIC = 0,
	MOVIE_CLIP
	# TODO: BUTTONs
}

enum SymbolLoopMode {
	LOOP = 0,
	PLAY_ONCE,
	SINGLE_FRAME,
	REVERSE_PLAY_ONCE, # TODO: Implement
	REVERSE_LOOP # TODO: Implement
}

const MATERIAL_LIST: Array[StringName] = [
	&"default",
	&"blend_add",
	&"blend_sub",
	&"other_blends",
]

## Path to any file in the animation path (like Animation.json, spritemap1.json, etc),
## or the folder that contains those files.
@export_dir var folder: String = "":
	set(v):
		folder = v

		if not folder.get_extension().is_empty():
			folder = folder.get_base_dir()
		elif folder.ends_with("/"):
			folder = folder.left(-1)

		parse()
		path_changed.emit()

# TODO: fix the impl for this
## For movie clips to play more like in a SWF, set to true.
@export var movie_clips_play: bool = false:
	set(v):
		movie_clips_play = v
		redraw_requested.emit()

## Clips the edges outside of each part of the spritemap (to help prevent edge bleeding, may not always be desired)
@export var clip_texture_uvs: bool = false:
	set(v):
		clip_texture_uvs = v
		redraw_requested.emit()

## Uses a simpler form of rendering the atlas that takes less time but doesn't support
## more "advanced" features like Blend Modes, Masking, etc.[br][br]
## Use if you need better performance (usually with a lot of TAs at once)
## and don't need those more complex features.
@export_enum("Full", "Performance") var render_mode: String = "Full":
	set(v):
		render_mode = v
		redraw_requested.emit()
		notify_property_list_changed()

## Override internal default materials used by [TextureAtlas]
var override_enable := false

var override_default: Material = null
var override_blend_add: Material = null
var override_blend_subtract: Material = null
var override_other_blends: Material = null

var spritemap: Dictionary[StringName, AtlasTexture] = {}
var symbols: Dictionary[StringName, TextureAtlasSymbol] = {}
var framerate: float = 24.0
var stage_symbol: StringName = &""
var stage_transform: Transform2D = Transform2D.IDENTITY

var _internal_materials: Dictionary[StringName, Material]


static func parse_matrix(matrix: Variant) -> Transform2D:
	if matrix is Dictionary:
		return Transform2D(
			Vector2(matrix["m00"], matrix["m01"]),
			Vector2(matrix["m10"], matrix["m11"]),
			Vector2(matrix["m30"], matrix["m31"]),
		)
	elif matrix is Array:
		if matrix.size() == 6:
			return Transform2D(
				Vector2(matrix[0], matrix[1]),
				Vector2(matrix[2], matrix[3]),
				Vector2(matrix[4], matrix[5]),
			)
		else:
			return Transform2D(
				Vector2(matrix[0], matrix[1]),
				Vector2(matrix[4], matrix[5]),
				Vector2(matrix[12], matrix[13]),
			)
	else:
		return Transform2D.IDENTITY


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	if Engine.is_editor_hint() and render_mode == "Full":
		properties.push_back({
			"name": &"Rendering Options",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP,
		})

		properties.push_back({
			"name": &"Override Materials",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_SUBGROUP,
			"hint_string": "override_",
		})

		properties.push_back({
			"name": &"override_enable",
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_GROUP_ENABLE,
			"usage": PROPERTY_USAGE_DEFAULT,
		})

		for name: StringName in MATERIAL_LIST:
			properties.push_back({
				"name": &"override_%s" % name,
				"type": TYPE_OBJECT,
				"usage": PROPERTY_USAGE_DEFAULT,
			})

	return properties


func parse() -> void:
	redraw_requested.emit()

	var cache_path := "%s/animation_cache.res" % [folder]
	if ResourceLoader.exists(cache_path):
		var cached: TextureAtlasCache = load(cache_path)
		if is_instance_valid(cached):
			cached.apply_to_atlas(self)
			return

	symbols.clear()
	spritemap.clear()

	var animation_json := "%s/Animation.json" % [folder]
	if not ResourceLoader.exists(animation_json):
		printerr("Atlas path (%s) is missing Animation.json!" % [folder])
		return

	TextureAtlasSpritemap.load_spritemaps(folder, spritemap)
	load_animation()

	#for symbol: TextureAtlasSymbol in symbols.values():
		#for layer: TextureAtlasLayer in symbol.layers:
			#for frame: TextureAtlasFrame in layer.frames:
				#for element: TextureAtlasDrawable in frame.elements:
					#if element is TextureAtlasSymbolInstance:
						#element.symbol = symbols[element.key]


func cache() -> void:
	TextureAtlasCache.save_from_atlas(self)


func draw_2d(target: AnimateSymbol2D) -> void:
	var symbol: StringName = target.symbol
	var use_stage: bool = not symbols.has(target.symbol)
	if use_stage and not stage_symbol.is_empty():
		symbol = stage_symbol

	if not symbols.has(symbol):
		return

	var transform := Transform2D(0.0, target.offset)
	if target.centered:
		var rect: Rect2 = get_symbol_rect(symbol)
		transform = transform.translated(
			-rect.position - (rect.size / 2.0),
		)

	if use_stage:
		transform *= stage_transform

	var target_item := target.get_canvas_item()
	match render_mode:
		"Performance":
			target._clear_canvas_item(true)
			_internal_materials.clear()
			draw_2d_simple(
				symbols[symbol],
				target.frame,
				transform,
				target_item,
			)
		"Full":
			if _internal_materials.is_empty():
				_internal_materials = {
					&"default": load("res://addons/gdanimate/formats/texture_atlas/shaders/sprite_material.tres"),
					&"blend_add": load("res://addons/gdanimate/formats/texture_atlas/shaders/additive_material.tres"),
					&"blend_subtract": load("res://addons/gdanimate/formats/texture_atlas/shaders/subtract_material.tres"),
				}

			var state := TextureAtlasDrawState.new()
			state.item_pool = target._canvas_item_pool
			state.item_parent = target_item
			state.materials[&"default"] = target.material

			if not is_instance_valid(state.materials[&"default"]):
				state.materials[&"default"] = _internal_materials[&"default"]

			if override_enable:
				if override_default:
					state.materials[&"default"] = override_default
				if override_blend_add:
					state.materials[&"blend_add"] = override_blend_add
				if override_blend_subtract:
					state.materials[&"blend_subtract"] = override_blend_subtract
				if override_other_blends:
					state.materials[&"other_blends"] = override_other_blends

			target._clear_canvas_item(false)
			target._reset_canvas_item_pool()

			var root_item: RID = state.get_next_item()
			RenderingServer.canvas_item_set_parent(
				root_item,
				target_item,
			)

			RenderingServer.canvas_item_set_transform(root_item, transform)

			draw_2d_full(
				symbols[symbol],
				target.frame,
				state,
				root_item,
			)


func draw_2d_simple(
	symbol: TextureAtlasSymbol,
	frame: int,
	transform: Transform2D,
	target: RID,
) -> void:
	for i: int in symbol.layers_draw_order:
		var layer := symbol.layers[i]
		if not frame in layer.frame_range:
			continue

		for layer_frame: TextureAtlasFrame in layer.frames:
			if frame > layer_frame.starting_index + layer_frame.duration - 1:
				continue
			if frame < layer_frame.starting_index:
				break

			for element: TextureAtlasDrawable in layer_frame.elements:
				if element is TextureAtlasSprite:
					var texture := spritemap[element.key]
					texture.filter_clip = clip_texture_uvs
					element.draw(target, {
						&"texture": texture,
						&"transform": transform,
					})
				elif element is TextureAtlasSymbolInstance:
					draw_2d_simple(symbols[element.key],
						element.get_frame_after(
							frame - layer_frame.starting_index,
							symbols[element.key].length,
							movie_clips_play,
						),
						transform * element.transform,
						target,
					)


func draw_2d_full(
	symbol: TextureAtlasSymbol,
	frame: int,
	state: TextureAtlasDrawState,
	target: RID,
) -> void:
	var start_transform := state.local_transform
	var start_blend := state.blend_mode

	for i: int in symbol.layers_draw_order:
		var layer := symbol.layers[i]
		if not frame in layer.frame_range:
			continue

		for layer_frame: TextureAtlasFrame in layer.frames:
			if frame > layer_frame.starting_index + layer_frame.duration - 1:
				continue
			if frame < layer_frame.starting_index:
				break

			for element: TextureAtlasDrawable in layer_frame.elements:
				var current_item := state.get_current_item()
				if start_blend != state.blend_mode:
					current_item = state.get_next_item()
					state.blend_mode = start_blend

				RenderingServer.canvas_item_set_material(
					current_item,
					state.get_material(start_blend)
				)

				RenderingServer.canvas_item_set_instance_shader_parameter(
					current_item,
					&"blend_mode",
					int(start_blend),
				)

				var used_matrix := TextureAtlasColorMatrix.new()
				RenderingServer.canvas_item_set_instance_shader_parameter(current_item, &"color_multipliers_0", used_matrix.color_multipliers[0])
				RenderingServer.canvas_item_set_instance_shader_parameter(current_item, &"color_multipliers_1", used_matrix.color_multipliers[1])
				RenderingServer.canvas_item_set_instance_shader_parameter(current_item, &"color_multipliers_2", used_matrix.color_multipliers[2])
				RenderingServer.canvas_item_set_instance_shader_parameter(current_item, &"color_multipliers_3", used_matrix.color_multipliers[3])
				RenderingServer.canvas_item_set_instance_shader_parameter(current_item, &"color_offsets", used_matrix.color_offsets)

				if current_item != target:
					RenderingServer.canvas_item_set_parent(current_item, target)

				state.local_transform = start_transform

				if element is TextureAtlasSprite:
					var texture := spritemap[element.key]
					texture.filter_clip = clip_texture_uvs
					element.draw(current_item, {
						&"texture": texture,
						&"transform": state.local_transform,
					})
				elif element is TextureAtlasSymbolInstance:
					state.local_transform *= element.transform

					if (
						start_blend == BlendMode.NORMAL and
						state.blend_mode != element.blend_mode
					):
						state.get_next_item()
						state.blend_mode = element.blend_mode

					draw_2d_full(symbols[element.key],
						element.get_frame_after(
							frame - layer_frame.starting_index,
							symbols[element.key].length,
							movie_clips_play,
						),
						state,
						target,
					)


func get_framerate() -> float:
	return framerate


func get_filename() -> StringName:
	return StringName(folder.get_file())


func get_symbol_list() -> PackedStringArray:
	return symbols.keys()


func get_symbol_length(key: StringName) -> int:
	if not symbols.has(key):
		key = stage_symbol
	if symbols.has(key):
		return symbols[key].length

	return 0


func get_symbol_rect(key: StringName) -> Rect2:
	if not symbols.has(key):
		return Rect2()

	#return symbols[key].bounding_box
	return Rect2()


func has_symbol(symbol: StringName) -> bool:
	return symbols.has(symbol)


"""
func draw_symbol(
	target: TextureAtlasSymbol,
	parent: RID,
	t: Transform2D,
	frame: int,
	is_clipper: bool,
	items: Array[RID],
	blend_mode: TextureAtlas.BlendMode = TextureAtlas.BlendMode.NORMAL,
	material: Material = null,
	color_matrix: TextureAtlasColorMatrix = null,
) -> void:
	if frame > target.length - 1:
		frame = target.length - 1

	var to_push: Array[RID] = []
	var clip_pushes: Dictionary[StringName, Array] = {}
	var rids: Dictionary[StringName, RID] = {}
	for layer: TextureAtlasLayer in target.layers:
		var layer_rid: RID
		var layer_parent: RID = parent
		if not is_clipper:
			layer_rid = create_canvas_item(items)
			RenderingServer.canvas_item_set_use_parent_material(layer_rid, true)
			rids.set(layer.name, layer_rid)

			if layer.clipping:
				RenderingServer.canvas_item_set_canvas_group_mode(layer_rid, RenderingServer.CANVAS_GROUP_MODE_CLIP_ONLY)
				RenderingServer.canvas_item_set_use_parent_material(layer_rid, false)
			elif not layer.clipped_by.is_empty():
				if not clip_pushes.has(layer.clipped_by):
					clip_pushes.set(layer.clipped_by, [])

				clip_pushes[layer.clipped_by].push_front(layer_rid)
				layer_parent = rids.get(layer.clipped_by, parent)
		else:
			layer_rid = parent

		var rendered: bool = false
		for layer_frame: TextureAtlasFrame in layer.frames:
			if frame > layer_frame.starting_index + layer_frame.duration - 1:
				continue
			if frame < layer_frame.starting_index:
				continue

			var difference: int = frame - layer_frame.starting_index
			rendered = true
			for element: TextureAtlasDrawable in layer_frame.elements:
				if element is TextureAtlasSymbolInstance:
					var symbol_frame: int = element.first_frame
					if element.type == TextureAtlas.SymbolType.GRAPHIC:
						match element.loop_mode:
							TextureAtlas.SymbolLoopMode.LOOP:
								symbol_frame = wrapi(symbol_frame + difference, 0, symbols[element.key].length)
							TextureAtlas.SymbolLoopMode.ONE_SHOT:
								symbol_frame = clampi(symbol_frame + difference, 0, symbols[element.key].length - 1)
							TextureAtlas.SymbolLoopMode.FREEZE_FRAME:
								symbol_frame = symbol_frame
					elif element.type == TextureAtlas.SymbolType.MOVIE_CLIP:
						if not movie_clips_play:
							symbol_frame = element.first_frame
						else:
							symbol_frame = wrapi(symbol_frame + difference, 0, symbols[element.key].length)

					var next_matrix: TextureAtlasColorMatrix = color_matrix
					if next_matrix == null:
						next_matrix = element.color_matrix
					elif element.color_matrix != null:
						next_matrix = next_matrix.concat(element.color_matrix)
					draw_symbol(
						symbols[element.key],
						layer_rid,
						t * element.transform,
						symbol_frame,
						is_clipper or layer.clipping,
						items,
						(
							element.blend_mode
							if blend_mode == TextureAtlas.BlendMode.NORMAL
							else blend_mode
						),
						material,
						next_matrix
					)
				elif element is TextureAtlasSprite:
					draw_atlas_sprite(
						element as TextureAtlasSprite,
						layer_rid,
						t,
					)

		if (not is_clipper) and layer_parent == parent:
			if rendered:
				if is_instance_valid(material):
					var use_material: bool = blend_mode != TextureAtlas.BlendMode.NORMAL
					if not use_material:
						use_material = color_matrix != null

					var used_matrix: TextureAtlasColorMatrix = color_matrix
					if used_matrix == null:
						used_matrix = TextureAtlasColorMatrix.new()

					if use_material:
						var ignored_blends: Array[TextureAtlas.BlendMode] = [
							TextureAtlas.BlendMode.NORMAL,
							TextureAtlas.BlendMode.ALPHA,
							TextureAtlas.BlendMode.ERASE,
						]

						if not ignored_blends.has(blend_mode):
							# TODO: Optimize the rect here, please it's crapping my perf
							RenderingServer.canvas_item_set_copy_to_backbuffer(layer_rid, true, Rect2())

						RenderingServer.canvas_item_set_use_parent_material(layer_rid, false)
						RenderingServer.canvas_item_set_material(layer_rid, material.get_rid())
						RenderingServer.canvas_item_set_instance_shader_parameter(layer_rid, &"blend_mode", int(blend_mode))
						RenderingServer.canvas_item_set_instance_shader_parameter(layer_rid, &"color_multipliers_0", used_matrix.color_multipliers[0])
						RenderingServer.canvas_item_set_instance_shader_parameter(layer_rid, &"color_multipliers_1", used_matrix.color_multipliers[1])
						RenderingServer.canvas_item_set_instance_shader_parameter(layer_rid, &"color_multipliers_2", used_matrix.color_multipliers[2])
						RenderingServer.canvas_item_set_instance_shader_parameter(layer_rid, &"color_multipliers_3", used_matrix.color_multipliers[3])
						RenderingServer.canvas_item_set_instance_shader_parameter(layer_rid, &"color_offsets", used_matrix.color_offsets)

				to_push.push_front(layer_rid)

	var i: int = items.size() - 1
	for item: RID in to_push:
		RenderingServer.canvas_item_set_parent(item, parent)
		RenderingServer.canvas_item_set_draw_index(item, i)
		i += 1

	for key: StringName in clip_pushes.keys():
		var array: Array = clip_pushes[key]
		var clip_parent: RID = rids[key]

		i = items.size() - 1
		for item: RID in array:
			RenderingServer.canvas_item_set_parent(item, clip_parent)
			RenderingServer.canvas_item_set_draw_index(item, i)
			i += 1


func draw_atlas_sprite(sprite: TextureAtlasSprite, parent: RID, t: Transform2D) -> void:
	var transform: Transform2D = t * sprite.transform
	if sprite.rotated:
		transform *= Transform2D(
			-PI / 2.0, #deg_to_rad(-90.0),
			Vector2(
				0.0,
				sprite.region.size.x,
			),
		)

	RenderingServer.canvas_item_add_set_transform(parent, transform)
	RenderingServer.canvas_item_add_texture_rect_region(
		parent,
		Rect2(
			Vector2.ZERO,
			Vector2(sprite.region.size),
		),
		sprite.texture.get_rid(),
		Rect2(sprite.region),
		Color.WHITE,
		false,
		clip_texture_uvs,
	)
"""


func load_animation() -> void:
	var raw_json: String = FileAccess.get_file_as_string("%s/Animation.json" % [folder])
	var json: Variant = JSON.parse_string(raw_json)
	if json == null:
		printerr("Failed to parse %s/Animation.json as JSON!" % folder)
		return

	if json is not Dictionary:
		printerr("Animation JSON must be a Dictionary!")
		return

	json = json as Dictionary

	var optimized: bool = json.has("AN")
	if ResourceLoader.exists("%s/metadata.json" % folder):
		var meta_raw_json: String = FileAccess.get_file_as_string("%s/metadata.json" % [folder])
		var meta_json: Variant = JSON.parse_string(meta_raw_json)
		if meta_json == null:
			printerr("Failed to parse %s/metadata.json as JSON!" % folder)
			return

		if meta_json is not Dictionary:
			print("Metadata JSON must be a Dictionary!")
			return

		meta_json = meta_json as Dictionary
		framerate = meta_json.get("framerate", meta_json.get("FRT", 24.0))
	else:
		var meta: Dictionary = json.get("MD" if optimized else "metadata", {})
		framerate = meta.get("FRT" if optimized else "framerate", 24.0)

	if json.has("SD" if optimized else "SYMBOL_DICTIONARY"):
		var symbol_dict: Dictionary = json.get("SD" if optimized else "SYMBOL_DICTIONARY", {})
		var symbol_array: Array = symbol_dict.get("S" if optimized else "Symbols", [])
		SymbolDictionary.parse_array(symbol_array, optimized, symbols)
	elif DirAccess.dir_exists_absolute("%s/LIBRARY" % folder):
		var dir: DirAccess = DirAccess.open("%s/LIBRARY" % folder)
		if dir == null:
			printerr("Failed to open %s/LIBRARY directory! Error: " % [
				folder,
				DirAccess.get_open_error(),
			])

			return

		SymbolDictionary.load_symbols_directory(
			optimized,
			dir,
			"",
			symbols,
		)

	var main_animation: Dictionary = json.get("AN" if optimized else "ANIMATION", {})
	SymbolDictionary.parse_symbol(main_animation, optimized, symbols)

	stage_symbol = main_animation.get("SN" if optimized else "SYMBOL_name")
	stage_transform = Transform2D.IDENTITY

	if main_animation.has("STI" if optimized else "StageInstance"):
		var stage: Dictionary = main_animation.get("STI" if optimized else "StageInstance", {})
		var instance: Dictionary = stage.get("SI" if optimized else "SYMBOL_Instance", {})

		if instance.has("MX" if optimized else "Matrix"):
			stage_transform = parse_matrix(instance.get("MX" if optimized else "Matrix"))
		elif instance.has("M3D" if optimized else "Matrix3D"):
			stage_transform = parse_matrix(instance.get("M3D" if optimized else "Matrix3D"))
