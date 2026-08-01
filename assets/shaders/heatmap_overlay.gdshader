shader_type canvas_item;
render_mode blend_premul_alpha;

// ── Heatmap Overlay Shader ─────────────────────────────────────────────
// Rendered on a full-screen ColorRect via SubViewport overlaid on the
// 3D game view. Maps a data texture to a color gradient.
//
// Data texture format:
//   R channel = normalized value (0.0 = min, 1.0 = max)
//
// Color gradient: cool (blue/cyan) → neutral (green/yellow) → hot (red).
//
// Usage:
//   1. Create a SubViewport with this shader on a full-rect ColorRect.
//   2. Write tile data values into a ViewportTexture or pass as uniform.
//   3. Overlay the SubViewportContainer on the game view.

// ── Uniforms ───────────────────────────────────────────────────────────

uniform sampler2D data_texture : filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.6;

// ── Fragment ───────────────────────────────────────────────────────────

void fragment() {
	// Sample the data texture.
	vec4 data = texture(data_texture, UV);
	float value = data.r;

	// Map value (0.0-1.0) through a gradient:
	// 0.0 → blue (cool, low density)
	// 0.25 → cyan
	// 0.5 → green/yellow
	// 0.75 → orange
	// 1.0 → red (hot, high density)
	vec3 cool_low  = vec3(0.0, 0.4, 0.9);   // blue
	vec3 cool_high = vec3(0.0, 0.8, 0.8);   // cyan
	vec3 mid_low   = vec3(0.2, 0.9, 0.3);   // green
	vec3 mid_high  = vec3(0.9, 0.9, 0.1);   // yellow
	vec3 hot_low   = vec3(1.0, 0.5, 0.0);   // orange
	vec3 hot_high  = vec3(0.9, 0.1, 0.0);   // red

	vec3 color;
	if (value < 0.25) {
		float t = value / 0.25;
		color = mix(cool_low, cool_high, t);
	} else if (value < 0.5) {
		float t = (value - 0.25) / 0.25;
		color = mix(cool_high, mid_low, t);
	} else if (value < 0.75) {
		float t = (value - 0.5) / 0.25;
		color = mix(mid_low, hot_low, t);
	} else {
		float t = (value - 0.75) / 0.25;
		color = mix(hot_low, hot_high, t);
	}

	// Apply intensity (desaturates toward grey at low intensity).
	color = mix(vec3(0.5), color, intensity);

	// If data texture has meaningful data (value > 0), render colored.
	// Otherwise, render transparent.
	float alpha = value > 0.001 ? opacity * intensity : 0.0;
	COLOR = vec4(color, alpha);
}
