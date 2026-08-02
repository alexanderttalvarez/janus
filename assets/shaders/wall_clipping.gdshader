shader_type spatial;
render_mode cull_disabled, unshaded;

// ── Wall Clipping Shader ──────────────────────────────────────────────
// Applied to WallMesh in floor.tscn.
//
// Global shader parameters (set by CameraManager and GameManager):
//   camera_direction (vec2) — current camera view direction in XZ plane
//   wall_mode (int)         — 0=Cutaway, 1=Partial, 2=Full
//
// Clipping logic:
//   Cutaway: Walls facing the camera (front) are nearly invisible (5%).
//            Walls facing away (back) are fully visible (100%).
//   Partial: All walls are nearly invisible (5%).
//   Full:    All walls are fully visible (100%).
//
// Wall face normal is derived from vertex position.
// A wall that faces +X has its visible face normal pointing -X.

// ── Uniforms ───────────────────────────────────────────────────────────

uniform vec3 wall_color : source_color = vec3(0.85, 0.82, 0.78);

// ── Globals ────────────────────────────────────────────────────────────

global uniform vec2 camera_direction = vec2(1.0, 0.0);
global uniform int wall_mode = 0;

// ── Vertex ─────────────────────────────────────────────────────────────

varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = mat3(MODEL_MATRIX) * NORMAL;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// ── Fragment ───────────────────────────────────────────────────────────

void fragment() {
	// Determine if this wall face is facing the camera.
	// Project world normal onto XZ plane (ignore Y since walls are vertical).
	vec2 normal_xz = normalize(world_normal.xz);
	float facing = dot(normal_xz, normalize(camera_direction));

	// facing < 0 means the wall face normal points roughly opposite to camera
	// direction, i.e., the camera is looking at the BACK of this face.
	// facing > 0 means the camera is looking at the FRONT.
	bool is_front_face = facing > 0.0;

	float alpha = 1.0;

	if (wall_mode == 0) {
		// Cutaway: front walls nearly invisible, back walls visible.
		alpha = is_front_face ? 0.05 : 1.0;
	} else if (wall_mode == 1) {
		// Partial: all walls nearly invisible.
		alpha = 0.05;
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
