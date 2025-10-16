@tool
extends AdobeDrawable
class_name AdobeSymbolInstance


@export_storage var key: StringName
@export_storage var type: AdobeSymbolType
@export_storage var loop_mode: AdobeSymbolLoopMode
@export_storage var transform: Transform2D
@export_storage var first_frame: int


func draw_on(parent: RID, frame: int, previous_transform: Transform2D, symbols: Dictionary[StringName, AdobeSymbol], stack: Array[String], id: int) -> void:
	super(parent, frame, previous_transform, symbols, stack, id)
	if not symbols.has(key):
		printerr("Missing symbol %s to draw!" % [key])
		return
	
	frame = first_frame
	
	var symbol: AdobeSymbol = symbols.get(key)
	var length: int = symbol.length
	if frame > length - 1:
		frame = length - 1
	
	var trans: Transform2D = previous_transform * transform
	for layer: AdobeLayer in symbol.layers:
		for layer_frame: AdobeLayerFrame in layer.frames:
			if frame < layer_frame.starting_index:
				continue
			if frame > layer_frame.starting_index + layer_frame.duration - 1:
				continue
			
			var layer_stack: Array[String] = stack.duplicate()
			layer_stack.push_back(layer.name)
			for element: AdobeDrawable in layer_frame.elements:
				if element is AdobeSymbolInstance:
					id += 1
				
				element.draw_on(parent, frame, trans, symbols, layer_stack, id)


enum AdobeSymbolType {
	GRAPHIC = 0,
	MOVIE_CLIP
}

enum AdobeSymbolLoopMode {
	LOOP = 0,
	ONE_SHOT,
	FREEZE_FRAME,
	REVERSE_ONE_SHOT,
	REVERSE_LOOP
}
