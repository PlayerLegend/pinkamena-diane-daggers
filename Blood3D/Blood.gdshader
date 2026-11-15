shader_type spatial;

instance uniform float start_time = 0.0;

global uniform float shader_time;
uniform sampler2D albedo_tex : source_color, repeat_enable;
uniform sampler2D noise_tex : repeat_enable;

void fragment() {
	float t = max(shader_time - start_time, 0.0);

	vec2 uv = UV;
	uv.y += t / (t + 0.1);
    vec4 tex = texture(albedo_tex, uv);
	ALBEDO = tex.rgb;

	float threshold = texture(noise_tex, UV).r * UV.y * tex.a;
	if (threshold < t) {
		discard;
	}
}