shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform sampler2D decal_texture : source_color, filter_nearest, hint_default_transparent;
uniform float decal_size;

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 duv = world_pos.xz / decal_size + 0.5;
	ALBEDO = texture(albedo_texture, UV).rgb;
	if (duv.x >= 0.0 && duv.x <= 1.0 && duv.y >= 0.0 && duv.y <= 1.0) {
		vec4 d = texture(decal_texture, duv);
		ALBEDO = mix(ALBEDO, d.rgb, d.a);
	}
    
}