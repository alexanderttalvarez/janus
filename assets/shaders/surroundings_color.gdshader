shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.8;


void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = surface_roughness;
}
