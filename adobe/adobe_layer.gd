@tool
extends Resource
class_name AdobeLayer


@export_storage var name: StringName = &""
@export_storage var frames: Array[AdobeLayerFrame] = []
@export_storage var clipping: bool = false
@export_storage var clipped_by: String = ""
