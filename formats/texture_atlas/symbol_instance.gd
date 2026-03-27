@tool
class_name TextureAtlasSymbolInstance
extends TextureAtlasDrawable


@export_storage var key: StringName
@export_storage var type: TextureAtlas.SymbolType
@export_storage var loop_mode: TextureAtlas.SymbolLoopMode
@export_storage var transform: Transform2D
@export_storage var first_frame: int
@export_storage var filters: Array[TextureAtlasFilter] = []
@export_storage var blend_mode: TextureAtlas.BlendMode = TextureAtlas.BlendMode.NORMAL
@export_storage var color_matrix: TextureAtlasColorMatrix = null
@export_storage var symbol: TextureAtlasSymbol = null


func calculate_bounding_box() -> void:
	bounding_box = transform * symbol.bounding_box
