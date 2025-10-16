extends RefCounted
class_name AnimateDrawInfo


@export var symbol: String = ""
@export var frame: int = 0
@export var offset: Vector2 = Vector2.ZERO
@export var transform: Transform2D = Transform2D.IDENTITY


func _init(_symbol: String, _frame: int, 
		_offset: Vector2, _transform: Transform2D) -> void:
	symbol = _symbol
	frame = _frame
	offset = _offset
	transform = _transform
