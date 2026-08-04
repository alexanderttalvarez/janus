shader_type spatial;
render_mode unshaded, cull_disabled;

// ── Zone Overlay Shader ────────────────────────────────────────────────
// Applied to zone overlay meshes (one MeshInstance3D per floor).
// Maps a zone ID texture to zone-type colors for visual identification.
//
// Zone ID texture format:
//   R channel = zone type ID (integer encoded as normalized float).
//
// Zone type colors:
//   0 = No zone (transparent)
//   1 = Retail (warm orange)
//   2 = Food & Beverage (red)
//   3 = Entertainment (purple)
//   4 = Services (blue)
//   5 = Anchor (gold)
//
// Usage:
//   Apply to a MeshInstance3D with a ShaderMaterial.
//   Set zone_id_texture uniform to an ImageTexture built from tile data.

// ── Uniforms ───────────────────────────────────────────────────────────

uniform sampler2D zone_id_texture : filter_nearest;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.4;

// ── Vertex ─────────────────────────────────────────────────────────────

varying vec2 world_uv;

void vertex() {
	// Pass world-space XZ as UV for texture lookup.
	// Assumes mesh vertices are placed at tile grid positions.
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_uv = world_pos.xz / 2.0;  // Divide by TILE_SIZE for grid coords.
}

// ── Fragment ───────────────────────────────────────────────────────────

void fragment() {
	// Sample zone ID from texture.
	float zone_id_float = texture(zone_id_texture, world_uv).r;
	int zone_id = int(zone_id_float * 255.0 + 0.5);

	// Zone type colors.
	vec3 color;
	float alpha = 0.0;

	if (zone_id == 0) {
		// No zone — transparent.
		alpha = 0.0;
		color = vec3(0.0);
	} else if (zone_id == 1) {
		// Retail (purple).
		color = vec3(0.5, 0.2, 0.8);
		alpha = opacity;
	} else if (zone_id == 2) {
		// Food & Beverage (green).
		color = vec3(0.2, 0.7, 0.3);
		alpha = opacity;
	} else if (zone_id == 3) {
		// Entertainment (orange).
		color = vec3(0.9, 0.5, 0.1);
		alpha = opacity;
	} else if (zone_id == 4) {
		// Services (blue).
		color = vec3(0.2, 0.4, 0.9);
		alpha = opacity;
	} else if (zone_id == 5) {
		// Anchor (red).
		color = vec3(0.9, 0.2, 0.2);
		alpha = opacity;
	} else {
		// Unknown zone type — grey with low alpha.
		color = vec3(0.5);
		alpha = opacity * 0.3;
	}

	ALBEDO = color;
	ALPHA = alpha;

	if (alpha < 0.01) {
		discard;
	}
}
