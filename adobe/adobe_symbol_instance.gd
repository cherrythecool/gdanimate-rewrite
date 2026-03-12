@tool
extends AdobeDrawable
class_name AdobeSymbolInstance


enum AdobeSymbolType {
	GRAPHIC = 0,
	MOVIE_CLIP
	# TODO: Buttons
}

enum AdobeSymbolLoopMode {
	LOOP = 0,
	ONE_SHOT,
	FREEZE_FRAME,
	REVERSE_ONE_SHOT, # TODO: Implement
	REVERSE_LOOP # TODO: Implement
}

enum AdobeBlendMode {
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


@export_storage var key: StringName
@export_storage var type: AdobeSymbolType
@export_storage var loop_mode: AdobeSymbolLoopMode = AdobeSymbolLoopMode.LOOP
@export_storage var transform: Transform2D
@export_storage var first_frame: int
@export_storage var filters: Array[AdobeFilter] = []
@export_storage var blend_mode: AdobeBlendMode = AdobeBlendMode.NORMAL
@export_storage var color_matrix: AdobeColorMatrix = null


func calculate_bounding_box() -> void:
	pass
