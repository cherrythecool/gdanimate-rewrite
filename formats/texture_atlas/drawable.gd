@tool
@abstract
class_name TextureAtlasDrawable
extends Resource


var bounding_box := Rect2():
	get:
		if bounding_box == Rect2():
			calculate_bounding_box()

		return bounding_box


func calculate_bounding_box() -> void:
	bounding_box = Rect2()
