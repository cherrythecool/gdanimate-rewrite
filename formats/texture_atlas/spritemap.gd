class_name TextureAtlasSpritemap
extends Object


static func parse_spritemap(
	json_data: Dictionary,
	output_dict: Dictionary[StringName, TextureAtlasSprite],
	source_texture: Texture,
) -> void:
	if not json_data.has("ATLAS"):
		printerr("Malformed spritemap JSON has no ATLAS!")
		return

	var data: Dictionary = json_data.get("ATLAS", {})
	var sprites: Array = data.get("SPRITES", [])
	for sprite: Dictionary in sprites:
		var sprite_data: Dictionary = sprite.get("SPRITE", {})
		var atlas_sprite: TextureAtlasSprite = TextureAtlasSprite.new()
		atlas_sprite.texture = source_texture
		atlas_sprite.region = Rect2(
			Vector2(
				float(sprite_data.get("x", 0.0)),
				float(sprite_data.get("y", 0.0)),
			),
			Vector2(
				float(sprite_data.get("w", 0.0)),
				float(sprite_data.get("h", 0.0)),
			),
		)
		atlas_sprite.rotated = sprite_data.get("rotated", false)

		var name: String = sprite_data.get("name", "")
		output_dict[StringName(name)] = atlas_sprite
