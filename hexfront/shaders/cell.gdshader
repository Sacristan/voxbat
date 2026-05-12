shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 albedo_color : source_color = vec4(0.5, 0.7, 0.3, 1.0);
// alpha = 0 means unowned; alpha > 0 blends owner color into the cell
// No source_color hint — passed as raw linear values to avoid gamma double-conversion
uniform vec4 owner_color = vec4(0.0, 0.0, 0.0, 0.0);

// World-space sun direction (warm light from upper-front-left)
const vec3 SUN_DIR = vec3(-0.5, 1.8, -0.3);

void fragment() {
	vec3 flat_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	vec3 sun_vs = normalize(mat3(VIEW_MATRIX) * normalize(SUN_DIR));
	float ndotl = dot(flat_normal, sun_vs);

	// Boost saturation (Ni No Kuni style — vivid, painterly)
	float luma = dot(albedo_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 saturated = mix(vec3(luma), albedo_color.rgb, 1.6);

	// Hard toon bands with warm highlight and cool shadow tint
	vec3 color;
	if (ndotl > 0.3) {
		color = saturated * vec3(1.30, 1.22, 1.05);
	} else if (ndotl > -0.2) {
		color = saturated * vec3(0.82, 0.80, 0.88);
	} else {
		color = saturated * vec3(0.42, 0.40, 0.55);
	}

	// Owner tint applied after shading, uniform across all faces
	color = mix(color, owner_color.rgb, owner_color.a * 0.275);

	ALBEDO = clamp(color, 0.0, 1.0);
}
