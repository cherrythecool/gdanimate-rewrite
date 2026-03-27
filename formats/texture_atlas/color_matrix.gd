class_name TextureAtlasColorMatrix
extends Resource


@export_storage var color_multipliers: Array[Vector4]
@export_storage var color_offsets: Vector4 = Vector4.ZERO


func _init() -> void:
	color_multipliers = [
		Vector4(1.0, 0.0, 0.0, 0.0),
		Vector4(0.0, 1.0, 0.0, 0.0),
		Vector4(0.0, 0.0, 1.0, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0),
	]


func concat(another: TextureAtlasColorMatrix) -> TextureAtlasColorMatrix:
	var matrix: TextureAtlasColorMatrix = TextureAtlasColorMatrix.new()
	matrix.color_multipliers = color_multipliers.duplicate()
	matrix.color_offsets = color_offsets

	for i: int in color_multipliers.size():
		matrix.color_multipliers[i] *= another.color_multipliers[i]
	matrix.color_offsets += another.color_offsets
	return matrix


static func parse(optimized: bool, data: Dictionary) -> TextureAtlasColorMatrix:
	var matrix := TextureAtlasColorMatrix.new()
	var mode: Variant = data.get("M" if optimized else "mode")
	if mode == null or mode is not String:
		return matrix

	var rm: Variant = data.get("RM" if optimized else "RedMultiplier")
	var ro: Variant = data.get("RO" if optimized else "redOffset")

	var gm: Variant = data.get("GM" if optimized else "greenMultiplier")
	var go: Variant = data.get("GO" if optimized else "greenOffset")

	var bm: Variant = data.get("BM" if optimized else "blueMultiplier")
	var bo: Variant = data.get("BO" if optimized else "blueOffset")

	var am: Variant = data.get("AM" if optimized else "alphaMultiplier")
	var ao: Variant = data.get("AO" if optimized else "AlphaOffset")

	match mode:
		"AD", "Advanced":
			matrix.color_multipliers[0] *= float(rm)
			matrix.color_multipliers[1] *= float(gm)
			matrix.color_multipliers[2] *= float(bm)
			matrix.color_multipliers[3] *= float(am)
			matrix.color_offsets = Vector4(
				float(ro),
				float(go),
				float(bo),
				float(ao),
			) / 255.0
		"CA", "Alpha":
			matrix.color_multipliers[3] *= float(am)
		"CBRT", "Brightness":
			var brt: Variant = data.get("BRT" if optimized else "brightness")
			var brightness := float(brt)

			var color_mult: float = 1.0 - absf(brightness)
			matrix.color_multipliers[0] *= float(color_mult)
			matrix.color_multipliers[1] *= float(color_mult)
			matrix.color_multipliers[2] *= float(color_mult)

			var color_offset: float = maxf(brightness, 0.0)
			matrix.color_offsets += Vector4(
				color_offset, color_offset, color_offset, 0.0,
			)
		"T", "Tint":
			var tc: Variant = data.get("TC" if optimized else "tintColor")
			var tm: Variant = data.get("TM" if optimized else "tintMultiplier")

			var tint := Color.from_string(String(tc), Color.WHITE)
			var tint_multiplier := float(tm)
			var mult: float = 1.0 - tint_multiplier
			matrix.color_multipliers[0] *= mult
			matrix.color_multipliers[1] *= mult
			matrix.color_multipliers[2] *= mult
			matrix.color_offsets = Vector4(
				tint.r * tint_multiplier,
				tint.g * tint_multiplier,
				tint.b * tint_multiplier,
				0.0,
			)

	return matrix
