shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// ── Wall Clipping Shader ──────────────────────────────────────────────
// Applied to wall boxes, corner cubes, and their cap plates (BoxMesh
// instances positioned in world space via their node transform).
//
// Global shader parameters (set by CameraManager and GameManager):
//   camera_direction (vec2) — direction from the scene toward the camera
//   wall_mode (int)         — 0=Cutaway, 1=Partial, 2=Full
//
// Clipping logic:
//   The BOX is classified by its outward direction (baked into the material
//   as `outward`), NOT by the per-face normal. This way all faces of a box
//   share one classification — a wall facing the camera disappears entirely
//   (no inner face showing through), and a wall facing away stays solid.
//
//   A fragment counts as front-facing when
//   dot(outward, camera_direction) > front_threshold:
//     - Straight walls bake their axis normal and use threshold 0.0.
//     - Corner cubes bake the corner diagonal and use threshold 0.5, so
//       only the corner facing the camera (dot ≈ 1) opens; side corners sit
//       perpendicular to the camera (dot ≈ 0) and always stay solid.
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

// Cap-plate variant: walls and caps are BoxMesh instances positioned in
// world space, so their cutaway classification always comes from the outward
// direction baked into the material (the wall's outward normal, the corner
// cube's diagonal, or the cap's parent box's outward direction).
uniform bool is_cap = false;
uniform vec2 outward = vec2(0.0, 0.0);

// Minimum dot(outward, camera_direction) for the box to count as
// front-facing. 0.0 for straight walls, 0.5 for corner cubes.
uniform float front_threshold = 0.0;

// Fraction of the wall's bottom kept visible in Cutaway/Partial — a strip
// so the player can tell a wall is there without seeing over it.
const float KEEP_FRACTION = 0.10;
// BoxMesh half-height in world units — matches WallManager.WALL_HEIGHT (3.0).
// (Only walls and corner cubes use it; caps ignore it via the is_cap branch.)
const float HALF_HEIGHT = 1.5;
const float WALL_HEIGHT = 3.0;

varying vec3 world_pos;
varying float wall_bottom;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wall_bottom = (MODEL_MATRIX * vec4(0.0, -HALF_HEIGHT, 0.0, 1.0)).y;
}

void fragment() {
	// The box's outward direction: baked into the material per wall/cap.
	vec2 outward_xz = normalize(outward);
	float facing = dot(outward_xz, normalize(camera_direction));

	// facing > threshold means the box's outward side points toward the
	// camera (the camera is outside, looking at this box's front).
	bool is_front_face = facing > front_threshold;

	// Whether this fragment lies in the visible bottom strip of the wall.
	float rel_y = (world_pos.y - wall_bottom) / WALL_HEIGHT;
	bool in_keep_strip = rel_y < KEEP_FRACTION;

	bool keep_fragment = true;

	if (is_cap) {
		// Cap plate: the "top" of a cut wall. Visible only where the wall
		// is actually cut (front walls in Cutaway, all walls in Partial).
		if (wall_mode == 0) {
			keep_fragment = is_front_face;
		} else if (wall_mode == 1) {
			keep_fragment = true;
		} else {
			keep_fragment = false;
		}
	} else if (wall_mode == 0) {
		// Cutaway: front walls keep only the bottom strip, back walls full.
		keep_fragment = !is_front_face || in_keep_strip;
	} else if (wall_mode == 1) {
		// Partial: all walls keep only the bottom strip.
		keep_fragment = in_keep_strip;
	} else {
		// Full: all walls fully visible.
		keep_fragment = true;
	}

	// Walls are opaque geometry. Clipped fragments are discarded instead of
	// writing ALPHA, which keeps walls in the depth-buffered opaque pass and
	// prevents object-level transparent sorting at perpendicular junctions.
	if (!keep_fragment) {
		discard;
	}

	ALBEDO = wall_color;
}
