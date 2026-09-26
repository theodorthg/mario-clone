shader_type canvas_item;

// Screen-filling sky: three-stop vertical gradient, quantized into bands for
// a pixel-art look (no smooth 24-bit gradient), optional twinkling stars and
// a crescent moon for night courses. Fixed to the screen — the parallax
// layers in backdrop.gd provide the depth.
uniform vec4 top_color : source_color = vec4(0.23, 0.42, 0.84, 1.0);
uniform vec4 mid_color : source_color = vec4(0.45, 0.68, 0.95, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.84, 0.93, 0.98, 1.0);
uniform float mid_pos : hint_range(0.05, 0.95) = 0.55;
uniform float bands = 18.0;
uniform float stars = 0.0;
uniform float moon = 0.0;
uniform vec2 moon_uv = vec2(0.78, 0.2);
uniform float sun = 0.0;
uniform vec2 sun_uv = vec2(0.8, 0.2);
uniform vec2 design_size = vec2(480.0, 270.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float t = floor(UV.y * bands) / bands;
	vec3 c = t < mid_pos
		? mix(top_color.rgb, mid_color.rgb, t / mid_pos)
		: mix(mid_color.rgb, horizon_color.rgb, (t - mid_pos) / (1.0 - mid_pos));
	if (stars > 0.0) {
		vec2 cell = floor(UV * design_size);
		float h = hash(cell);
		if (h > 0.993 && UV.y < 0.75) {
			float tw = 0.55 + 0.45 * sin(TIME * (1.5 + h * 3.0) + h * 40.0);
			c = mix(c, vec3(1.0, 0.97, 0.85), tw * stars * (1.0 - UV.y));
		}
	}
	if (moon > 0.0) {
		vec2 px = floor(UV * design_size);
		vec2 m = floor(moon_uv * design_size);
		float r = 11.0;
		float d1 = length(px - m);
		float d2 = length(px - m - vec2(5.0, -3.0));
		if (d1 < r && d2 > r - 1.0) {
			c = vec3(1.0, 0.95, 0.72);
		} else if (d1 < r + 5.0) {
			c = mix(c, vec3(0.45, 0.5, 0.75), 0.15);
		}
	}
	if (sun > 0.0) {
		vec2 px = floor(UV * design_size);
		float d = length(px - floor(sun_uv * design_size));
		if (d < 13.0) {
			c = d < 11.0 ? vec3(1.0, 0.98, 0.84) : vec3(1.0, 0.9, 0.55);
		} else if (d < 30.0) {
			// stepped halo rings (pixel-art glow, no smooth gradient)
			float ring = floor((30.0 - d) / 6.0) / 3.0;
			c = mix(c, vec3(1.0, 0.95, 0.75), ring * 0.35 * sun);
		}
	}
	COLOR = vec4(c, 1.0);
}
