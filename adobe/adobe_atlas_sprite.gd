@tool
extends AdobeDrawable
class_name AdobeAtlasSprite


@export_storage var region: Rect2i
@export_storage var rotated: bool
@export_storage var texture: Texture2D
@export_storage var transform: Transform2D


func calculate_bounding_box() -> void:
	var t: Transform2D = transform
	if rotated:
		t *= Transform2D(
			-PI / 2.0, #deg_to_rad(-90.0),
			Vector2(0.0, region.size.x)
		)

	bounding_box = t * Rect2(Vector2.ZERO, Vector2(region.size))
