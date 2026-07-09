class_name TextureAtlasDrawState
extends RefCounted


var materials: Dictionary[StringName, Material] = {
	&"default": null,
	&"blend_add": null,
	&"blend_subtract": null,
}

var backbuffer_transform := Transform2D.IDENTITY
var local_transform := Transform2D.IDENTITY

var blend_mode := TextureAtlas.BlendMode.NORMAL
var masking_mode := false
