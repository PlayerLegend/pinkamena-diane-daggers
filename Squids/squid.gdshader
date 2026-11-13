shader_type spatial;
//render_mode unshaded;

uniform float amplitude : hint_range(0.0, 180.0) = 15;        // peak rotation in degrees
uniform float scale_amplitude : hint_range(0.0, 1.0) = 0.07;  // peak radial scale change (0.2 = ±20%)
uniform float time_period : hint_range(0.1, 10.0) = 3;       // seconds per full cycle
uniform float height_period : hint_range(0.1, 20.0) = 1.0;   // world units (model-space Y) per full wave
uniform float phase_offset : hint_range(-3.14159, 3.14159) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0);

uniform sampler2D albedo_texture : source_color;

void vertex() {
    // Vertex color red channel acts as the wobble weight (0 = none, 1 = full)
    float weight = clamp(COLOR.r, 0.0, 1.0);

    // Shared phase for both twist and radial scale
    float phase = TIME * (TAU / time_period) - VERTEX.y * (TAU / height_period) + phase_offset;
    float wave = sin(phase) * weight;

    // Twist angle
    float a = radians(amplitude) * wave;
    float s = sin(a);
    float c = cos(a);

    // Radial scale (toward/away from the Y axis), kept positive
    float k = max(1.0 + scale_amplitude * wave, 0.001);

    // Scale X/Z about the Y axis, then rotate about Y
    vec3 v = vec3(VERTEX.x * k, VERTEX.y, VERTEX.z * k);
    VERTEX = vec3(
        v.x * c + v.z * s,
        v.y,
        -v.x * s + v.z * c
    );

    // Normals use the inverse-transpose of the scale (1/k on X/Z), then rotate
    vec3 n = vec3(NORMAL.x / k, NORMAL.y, NORMAL.z / k);
    NORMAL = normalize(vec3(
        n.x * c + n.z * s,
        n.y,
        -n.x * s + n.z * c
    ));
}

void fragment() {
    ALBEDO = (texture(albedo_texture, UV) * tint_color).rgb;
}