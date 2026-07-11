class_name TextureAtlasDrawState
extends RefCounted


var item_parent: RID
var item_pool: Array[RID]
var item_pool_index: int = 0

var materials: Dictionary[StringName, Material] = {}

var backbuffer_transform := Transform2D.IDENTITY
var local_transform := Transform2D.IDENTITY

var blend_mode := TextureAtlas.BlendMode.NORMAL
var masking_mode := false


func get_material(blend: TextureAtlas.BlendMode) -> RID:
	match blend:
		TextureAtlas.BlendMode.SUBTRACT:
			if materials.has(&"blend_subtract") and is_instance_valid(materials[&"blend_subtract"]):
				return materials[&"blend_subtract"].get_rid()
			else:
				return _get_other_blends_material()
		TextureAtlas.BlendMode.ADD:
			if materials.has(&"blend_add") and is_instance_valid(materials[&"blend_add"]):
				return materials[&"blend_add"].get_rid()
			else:
				return _get_other_blends_material()
		TextureAtlas.BlendMode.NORMAL:
			return materials[&"default"].get_rid()
		_:
			return _get_other_blends_material()


func _get_other_blends_material() -> RID:
	if materials.has(&"other_blends") and is_instance_valid(materials[&"other_blends"]):
		return materials[&"other_blends"].get_rid()
	else:
		return materials[&"default"].get_rid()


func get_current_item() -> RID:
	if item_pool.is_empty():
		return RID()
	else:
		return item_pool[item_pool_index]


func get_next_item() -> RID:
	item_pool_index += 1

	var rid: RID
	if item_pool_index >= item_pool.size():
		item_pool_index = item_pool.size()

		rid = RenderingServer.canvas_item_create()
		item_pool.push_back(rid)
	else:
		rid = item_pool[item_pool_index]

	return rid
