shader_type canvas_item;

// Screen-filling sky: three-stop vertical gradient, quantized into bands for
// a pixel-art look (no smooth 24-bit gradient). Fixed to the screen — the
// parallax layers in backdrop.gd provide the depth.
uniform vec4 top_color : source_color = vec4(0.23, 0.42, 0.84, 1.0);
uniform vec4 mid_color : source_color = vec4(0.45, 0.68, 0.95, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.84, 0.93, 0.98, 1.0);
uniform float mid_pos : hint_range(0.05, 0.95) = 0.55;
uniform float bands = 18.0;

void fragment() {
	float t = floor(UV.y * bands) / bands;
	vec3 c = t < mid_pos
		? mix(top_color.rgb, mid_color.rgb, t / mid_pos)
		: mix(mid_color.rgb, horizon_color.rgb, (t - mid_pos) / (1.0 - mid_pos));
	COLOR = vec4(c, 1.0);
}
