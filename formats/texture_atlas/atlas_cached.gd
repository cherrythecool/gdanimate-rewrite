class_name TextureAtlasCache
extends Resource


@export_storage var spritemap: Dictionary[StringName, TextureAtlasSprite] = {}
@export_storage var symbols: Dictionary[StringName, TextureAtlasSymbol] = {}
@export_storage var framerate: float = 24.0
@export_storage var stage_symbol: StringName = &""
@export_storage var stage_transform: Transform2D = Transform2D.IDENTITY


static func save_from_atlas(atlas: TextureAtlas) -> void:
	var cached := TextureAtlasCache.new()
	cached.spritemap = atlas.spritemap
	cached.symbols = atlas.symbols
	cached.framerate = atlas.framerate
	cached.stage_symbol = atlas.stage_symbol
	cached.stage_transform = atlas.stage_transform
	cached.take_over_path(
		"%s/animation_cache.res" % [atlas.folder_path],
	)

	ResourceSaver.save(
		cached,
		"%s/animation_cache.res" % [atlas.folder_path],
		(
			ResourceSaver.FLAG_COMPRESS +
			ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
		),
	)


func apply_to_atlas(atlas: TextureAtlas) -> void:
	atlas.spritemap = spritemap
	atlas.symbols = symbols
	atlas.framerate = framerate
	atlas.stage_symbol = stage_symbol
	atlas.stage_transform = stage_transform
