class_name TextureAtlasFilter
extends Resource


enum AdobeFilterType {
	BLUR = 0,
	ADJUST_COLOR
}

@export_storage var type: AdobeFilterType = AdobeFilterType.BLUR
@export_storage var data: Dictionary = {}
