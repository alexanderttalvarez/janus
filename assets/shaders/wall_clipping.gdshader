shader_type spatial;
render_mode cull_back;

// ── Wall Clipping Shader ──────────────────────────────────────────────
// Applied to wall prisms and their cap plates (both are ArrayMesh prisms
// built in world space with an identity transform).
//
// Global shader parameters (set by CameraManager and GameManager):
//   camera_direction (vec2) — direction from the scene toward the camera
//   wall_mode (int)         — 0=Cutaway, 1=Partial, 2=Full
//
// Clipping logic:
//   The WALL is classified by its outward direction (baked into the
//   material as `corner_outward` — the wall's outward normal), NOT by the
//   per-face normal. This way all faces of a wall prism share one
//   classification — a wall facing the camera disappears entirely (no inner
//   face showing through), and a wall facing away stays fully solid.
//
//   Cutaway: Front walls (facing the camera) keep only a bottom strip
//            (KEEP_FRACTION of the wall height) so the player can tell a
//            wall is there without seeing over it; back walls are visible.
//            A thin cap plate (is_cap) is rendered on top of the strip as
//            the cut wall's "top", so the cut never shows a hollow interior.
//   Partial: Every wall keeps only the bottom strip (+ its cap).
//   Full:    All walls are fully visible.
//
// Walls are LIT (no unshaded): the DirectionalLight3D differentiates
// sun-facing walls from shadowed ones (interior walls, far sides).
//
// NOTE: global uniforms cannot declare default values in Godot 4 — the
// values are supplied via RenderingServer.global_shader_parameter_set().

// ── Uniforms ──────────────────────────────────────────────────────────

uniform vec3 wall_color : source_color = vec3(0.85, 0.82, 0.78);

// ── Globals ────────────────────────────────────────────────────────────

global uniform vec2 camera_direction;
global uniform int wall_mode;

// Cap-plate variant: walls and caps are built in world space (identity
// transform), so their cutaway classification always comes from the outward
// direction baked into the material (the wall's outward normal, or the cap's
// parent wall's outward normal).
uniform bool is_cap = false;
uniform vec2 corner_outward = vec2(0.0, 0.0);

// Fraction of the wall's bottom kept visible in Cutaway/Partial — a strip
// so the player can tell a wall is there without seeing over it.
const float KEEP_FRACTION = 0.10;
// BoxMesh half-height / height in world units — matches
// WallManager.WALL_HEIGHT (3.0).
const float HALF_HEIGHT = 1.5;
const float WALL_HEIGHT = 3.0;

varying vec3 world_pos;
varying float wall_bottom;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wall_bottom = (MODEL_MATRIX * vec4(0.0, -HALF_HEIGHT, 0.0, 1.0)).y;
}

void fragment() {
	// The wall's outward direction: baked into the material per wall/cap.
	vec2 outward_xz = normalize(corner_outward);
	float facing = dot(outward_xz, normalize(camera_direction));

	// facing > 0 means the wall's outward side points toward the camera
	// (the camera is outside, looking at this wall's front).
	bool is_front_face = facing > 0.0;

	// Whether this fragment lies in the visible bottom strip of the wall.
	float rel_y = (world_pos.y - wall_bottom) / WALL_HEIGHT;
	bool in_keep_strip = rel_y < KEEP_FRACTION;

	float alpha = 1.0;

	if (is_cap) {
		// Cap plate: the "top" of a cut wall. Visible only where the wall
		// is actually cut (front walls in Cutaway, all walls in Partial).
		if (wall_mode == 0) {
			alpha = is_front_face ? 1.0 : 0.0;
		} else if (wall_mode == 1) {
			alpha = 1.0;
		} else {
			alpha = 0.0;
		}
	} else if (wall_mode == 0) {
		// Cutaway: front walls keep only the bottom strip, back walls full.
		alpha = (is_front_face && !in_keep_strip) ? 0.05 : 1.0;
	} else if (wall_mode == 1) {
		// Partial: all walls keep only the bottom strip.
		alpha = in_keep_strip ? 1.0 : 0.05;
	} else {
		// Full: all walls fully visible.
		alpha = 1.0;
	}

	ALBEDO = wall_color;
	ALPHA = alpha;

	// For very low alpha, discard to avoid depth write (cleaner cutaway).
	if (alpha < 0.1) {
		discard;
	}
}
