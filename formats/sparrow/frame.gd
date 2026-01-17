extends Resource
class_name SparrowFrame


@export var name: StringName = &""
@export var region: Rect2 = Rect2()
@export var offset: Rect2 = Rect2()
@export var rotated: bool = false


static func sort_by_name(a: SparrowFrame, b: SparrowFrame) -> bool:
	return String(a.name) < String(b.name)
