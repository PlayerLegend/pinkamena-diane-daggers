shader_type spatial;
render_mode depth_draw_opaque;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_map : hint_normal, repeat_enable;

uniform float refraction_strength : hint_range(0.0, 0.2) = 0.03;
uniform float blur : hint_range(0.0, 6.0) = 0.0;   // frosted glass
uniform vec4 tint : source_color = vec4(0.9, 0.95, 1.0, 1.0);
//uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float geo_refraction_strength : hint_range(-0.2, 0.2) = 0.05;
//uniform vec3 albedo : source_color;

void fragment() {
    // Decode the normal map to -1..1 and use xy as a 2D screen offset
    vec3 n = texture(normal_map, UV).rgb * 2.0 - 1.0;
    vec2 offset = n.xy * refraction_strength;

    vec2 geo_offset = NORMAL.xy * geo_refraction_strength;

    // Sample the already-rendered scene at the shifted coordinates
    vec3 refracted = textureLod(screen_texture, SCREEN_UV  + geo_offset + offset, blur).rgb;

    // Output the refracted color as emission so scene lighting doesn't darken it
    //ALBEDO = vec3(0.0);
    
    ALBEDO = tint.rgb;
    EMISSION = refracted * tint.rgb;

    // Keep the surface glossy so lights and reflections still glint on it
    //ROUGHNESS = roughness;
    //SPECULAR = 0.8;
    //NORMAL_MAP = texture(normal_map, UV).rgb;
}