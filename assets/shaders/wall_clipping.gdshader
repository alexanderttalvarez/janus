shader_type spatial;
render_mode cull_back;

// ── Wall Clipping Shader ──────────────────────────────────────────────
// Applied to wall meshes (BoxMesh, local +Z = outward face).
//
// Global shader parameters (set by CameraManager and GameManager):
//   camera_direction (vec2) — direction from the scene toward the camera
//   wall_mode (int)         — 0=Cutaway, 1=Partial, 2=Full
//
// Clipping logic:
//   The WALL is classified by its outward direction (the mesh's local +Z,
//   derived from MODEL_MATRIX), NOT by the per-face normal. This way all
//   faces of a wall box share one classification — a wall facing the camera
//   disappears entirely (no inner face showing through), and a wall facing
//   away stays fully solid.
//
//   Cutaway: Walls whose outward direction points toward the camera are
//            nearly invisible (discarded); walls facing away are visible.
//   Partial: All walls are nearly invisible.
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

// ── Fragment ───────────────────────────────────────────────────────────

// Corner-cube variants: cubes are axis-aligned (their faces match the walls),
// so their cutaway classification comes from the corner's outward direction
// baked into the material instead of the mesh's local +Z, and uses a 0.5
// threshold so the side corners (perpendicular to the camera, facing ~0)
// stay solid — only the corner whose two walls face the camera (facing ~1)
// opens.
uniform bool is_corner = false;
uniform vec2 corner_outward = vec2(0.0, 0.0);

void fragment() {
	// The wall's outward direction: mesh local +Z in world space for walls,
	// or the baked corner diagonal for corner cubes.
	vec2 outward_xz = is_corner
		? normalize(corner_outward)
		: normalize((mat3(MODEL_MATRIX) * vec3(0.0, 0.0, 1.0)).xz);
	float facing = dot(outward_xz, normalize(camera_direction));

	// facing > 0 means the wall's outward side points toward the camera
	// (the camera is outside, looking at this wall's front).
	bool is_front_face = facing > (is_corner ? 0.5 : 0.0);

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
