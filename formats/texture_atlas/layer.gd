@tool
class_name TextureAtlasLayer
extends Resource


@export var name: StringName = &""
@export var frames: Array[TextureAtlasFrame] = []
@export var frame_range: Array = []
@export var start_index: int = 0
@export var duration: int = 0
@export var clipping: bool = false
@export var clipped_by: String = ""


static func parse(layer: Dictionary, optimized: bool) -> TextureAtlasLayer:
	var parsed := TextureAtlasLayer.new()
	parsed.name = layer.get("LN" if optimized else "Layer_name")

	if layer.has("Clpb" if optimized else "Clipped_by"):
		parsed.clipped_by = layer.get("Clpb" if optimized else "Clipped_by")
	elif layer.has("LT" if optimized else "Layer_type"):
		if optimized:
			parsed.clipping = layer["LT"] == "Clp"
		else:
			parsed.clipping = layer["Layer_type"] == "Clipper"

	var layer_duration: int = 0
	if layer.has("FR" if optimized else "Frames"):
		var frames: Array = layer.get("FR" if optimized else "Frames", [])
		for frame: Dictionary in frames:
			parsed.frames.push_back(
				TextureAtlasFrame.parse(frame, optimized)
			)

	if not parsed.frames.is_empty():
		parsed.start_index = parsed.frames[0].starting_index

		var last := parsed.frames[parsed.frames.size() - 1]
		parsed.duration = last.starting_index + last.duration

		parsed.frame_range = range(parsed.start_index, parsed.start_index + parsed.duration)

	return parsed
