shader_type canvas_item;
render_mode blend_add;

// Thanks GDShader for no mat4 in shader instance uniforms!
instance uniform vec4 color_multipliers_0 = vec4(1.0, 0.0, 0.0, 0.0);
instance uniform vec4 color_multipliers_1 = vec4(0.0, 1.0, 0.0, 0.0);
instance uniform vec4 color_multipliers_2 = vec4(0.0, 0.0, 1.0, 0.0);
instance uniform vec4 color_multipliers_3 = vec4(0.0, 0.0, 0.0, 1.0);
instance uniform vec4 color_offsets = vec4(0.0);

instance uniform int blend_mode : hint_enum(
	"ADD",
	"ALPHA", // Not implemented, just per Flash n' stuff
	"DARKEN",
	"DIFFERENCE",
	"ERASE", // Not implemented, just per Flash n' stuff
	"HARD LIGHT",
	"INVERT",
	"LAYER", // Not implemented, just per Flash n' stuff
	"LIGHTEN",
	"MULTIPLY",
	"NORMAL",
	"OVERLAY",
	"SCREEN",
	"SHADER", // Not implemented, just per Flash n' stuff
	"SUBTRACT"
) = 0;

void fragment() {
	mat4 color_multipliers = mat4(
		color_multipliers_0,
		color_multipliers_1,
		color_multipliers_2,
		color_multipliers_3
	);

	COLOR = color_offsets + (COLOR * color_multipliers);
}
