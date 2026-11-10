shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec4 light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 dark_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler3D noise_texture_3d : repeat_enable, filter_linear;
uniform float noise_scale = 1.0;
uniform vec3 noise_offset = vec3(0.0);

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 sample_pos = world_pos * noise_scale + noise_offset;

    float noise_value = texture(noise_texture_3d, sample_pos).r;

    ALBEDO = mix(dark_color.rgb, light_color.rgb, noise_value);
    ALPHA = 1.0;
}