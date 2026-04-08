shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 albedo_color : source_color = vec4(0.5, 0.7, 0.3, 1.0);

// World-space sun direction (warm light from upper-front-left)
const vec3 SUN_DIR   = vec3(-0.5, 1.8, -0.3);
const vec3 SUN_COLOR = vec3(1.08, 1.00, 0.82);
const vec3 AMB_COLOR = vec3(0.52, 0.58, 0.78);

void fragment() {
	// Reconstruct flat (per-face) normal from view-space position derivatives.
	// dFdx/dFdy give the screen-space tangents of the current triangle face,
	// so their cross product is the uninterpolated face normal — giving the
	// hard-edged low-poly look without needing flat-shading vertex attributes.
	vec3 flat_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));

	// Transform sun direction into view space so dot products are consistent.
	vec3 sun_vs = normalize(mat3(VIEW_MATRIX) * normalize(SUN_DIR));

	float ndotl = dot(flat_normal, sun_vs);

	// 3-band cel shading: top/lit face, angled sides, back/shadow faces.
	float band;
	if (ndotl > 0.35) {
		band = 1.00;
	} else if (ndotl > -0.10) {
		band = 0.68;
	} else {
		band = 0.40;
	}

	// Smoothly blend ambient (cool) → sun (warm) tint, then apply band scale.
	float t = clamp(ndotl * 0.5 + 0.5, 0.0, 1.0);
	vec3 lighting = mix(AMB_COLOR, SUN_COLOR, t) * band;

	ALBEDO = albedo_color.rgb * lighting;
}
