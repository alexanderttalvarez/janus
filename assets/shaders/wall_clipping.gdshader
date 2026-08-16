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
// Door lintels are a special wall material variant. They remain visible in
// Full mode, but are hidden in Cutaway and Partial so exterior door openings
// remain visually open instead of showing a horizontal bar.

uniform vec3 wall_color : source_color = vec3(0.85, 0.82, 0.78);

// ── Globals ────────────────────────────────────────────────────────────

global uniform vec2 camera_direction;
global uniform int wall_mode;

// Cap-plate variant: walls and caps are BoxMesh instances positioned in
// world space, so their cutaway classification always comes from the outward
// direction baked into the material (the wall's outward normal, the corner
// cube's diagonal, or the cap's parent box's outward direction).
uniform bool is_cap = false;
uniform bool is_door_lintel = false;
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

	if (is_door_lintel && wall_mode != 2) {
		// The upper door bar is intentionally omitted in Cutaway and Partial.
		keep_fragment = false;
	} else if (is_cap) {
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
