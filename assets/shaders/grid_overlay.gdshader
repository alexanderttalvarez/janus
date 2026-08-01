shader_type spatial;
render_mode unshaded;

// Grid overlay shader — draws 25×25 grid lines on a PlaneMesh.
// Applied to GridOverlay MeshInstance3D in floor.tscn.

uniform float grid_size : hint_range(1.0, 100.0, 1.0) = 25.0;
uniform float line_thickness : hint_range(0.001, 0.05, 0.001) = 0.02;
uniform vec3 line_color : source_color = vec3(0.6, 0.6, 0.6);
uniform vec3 fill_color : source_color = vec3(0.3, 0.3, 0.3);

void fragment() {
	vec2 grid = fract(UV * grid_size);
	float line = smoothstep(0.0, line_thickness, min(grid.x, grid.y));
	ALBEDO = mix(fill_color, line_color, line);
}
