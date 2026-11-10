shader_type spatial;
render_mode cull_back; 

uniform float displacement_distance : hint_range(-2.0, 2.0) = 0.2;
uniform float noise_scale = 10.0;
uniform sampler3D noise_texture : filter_linear, repeat_enable;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;

void vertex() {
    if (COLOR.r > 0.5) {
        vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        float noise_val = texture(noise_texture, world_pos / noise_scale).r;
        VERTEX += NORMAL * noise_val * displacement_distance;
    }
    
}

void fragment() {
    vec4 tex_color = texture(albedo_texture, UV);
    ALBEDO = tex_color.rgb;
    //ALBEDO = COLOR.xyz;
}