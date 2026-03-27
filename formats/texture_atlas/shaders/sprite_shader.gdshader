shader_type canvas_item;

#include "blend_modes/additive.gdshaderinc"
#include "blend_modes/darken.gdshaderinc"
#include "blend_modes/difference.gdshaderinc"
#include "blend_modes/overlay.gdshaderinc"
#include "blend_modes/lighten.gdshaderinc"
#include "blend_modes/multiply.gdshaderinc"
#include "blend_modes/invert.gdshaderinc"
#include "blend_modes/screen.gdshaderinc"
#include "blend_modes/subtract.gdshaderinc"

const int BLEND_ALPHA = 1;
const int BLEND_ERASE = 4;
const int BLEND_NORMAL = 10;
//const int BLEND_LAYER = 7;
//const int BLEND_SHADER = 13;

// no mat4 in shader instance uniforms
instance uniform vec4 color_multipliers_0 = vec4(1.0, 0.0, 0.0, 0.0);
instance uniform vec4 color_multipliers_1 = vec4(0.0, 1.0, 0.0, 0.0);
instance uniform vec4 color_multipliers_2 = vec4(0.0, 0.0, 1.0, 0.0);
instance uniform vec4 color_multipliers_3 = vec4(0.0, 0.0, 0.0, 1.0);
instance uniform vec4 color_offsets = vec4(0.0);

instance uniform int blend_mode : hint_enum(
	"Additive",
	"Alpha",
	"Darken",
	"Difference",
	"Erase",
	"Hard Light",
	"Invert",
	"Layer", // Something something Flash / OpenFL I guess
	"Lighten",
	"Multiply",
	"Normal",
	"Overlay",
	"Screen",
	"Flash Shader", // Maybe if these are exported someone could make a translator? Idk
	"Subtract"
) = 10;

// most from https://godotshaders.com/snippet/blending-modes/
#define blend(MODE, CALCULATION) if (blend_mode == MODE) {\
	COLOR.rgb = CALCULATION;\
}

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

void fragment() {
	// from what i can tell ALPHA and ERASE just do nothing in animate?
	// if someone can figure out the real formula or use case if there is
	// one then feel free to contribute i guess
	if (blend_mode == BLEND_ALPHA || blend_mode == BLEND_ERASE) {
		discard;
	}

	mat4 color_multipliers = mat4(
		color_multipliers_0,
		color_multipliers_1,
		color_multipliers_2,
		color_multipliers_3
	);
	COLOR = color_offsets + (COLOR * color_multipliers);

	if (blend_mode != BLEND_NORMAL) {
		vec3 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
		blend(BLEND_ADD, blend_additive(COLOR.rgb, screen_color))
		blend(BLEND_DARKEN, blend_darken(COLOR.rgb, screen_color))
		blend(BLEND_DIFFERENCE, blend_difference(COLOR.rgb, screen_color))
		blend(BLEND_HARD_LIGHT, blend_overlay(COLOR.rgb, screen_color))
		blend(BLEND_INVERT, blend_invert(screen_color))
		blend(BLEND_LIGHTEN, blend_lighten(COLOR.rgb, screen_color))
		blend(BLEND_MULTIPLY, blend_multiply(COLOR.rgb, screen_color))
		blend(BLEND_OVERLAY, blend_overlay(screen_color, COLOR.rgb))
		blend(BLEND_SCREEN, blend_screen(COLOR.rgb, screen_color))
		blend(BLEND_SUBTRACT, blend_subtract(screen_color, COLOR.rgb))
	}
}