shader_type spatial;

uniform float min_rotation : hint_range(-180.0, 180.0) = -15.0;
uniform float max_rotation : hint_range(-180.0, 180.0) = -50.0;
uniform float period : hint_range(0.05, 1.0) = 0.25;
uniform vec2 pivot_yz = vec2(0.2, -0.15);
uniform sampler2D albedo_texture : source_color;

global uniform float boid_time;

// Precomputed per-frame (uniform expressions — Godot hoists these once)
float get_angle() {
    float t = sin(TIME * (6.28318530718 / period));
    return radians(mix(min_rotation, max_rotation, t * 0.5 + 0.5));
}

void vertex() {
    if (COLOR.r > 0.5) {
        float a = get_angle();       // hoisted per-frame by compiler
        float s = sin(a);
        float c = cos(a);

        // Translate to pivot
        vec3 p = VERTEX - vec3(0.0, pivot_yz.y, pivot_yz.x);

        // X-axis rotation, inlined (no mat3 construction)
        vec3 r = vec3(
            p.x,
            p.y * c - p.z * s,
            p.y * s + p.z * c
        );

        VERTEX = r + vec3(0.0, pivot_yz.y, pivot_yz.x);
        NORMAL = vec3(NORMAL.x, NORMAL.y * c - NORMAL.z * s, NORMAL.y * s + NORMAL.z * c);
    }
}

void fragment() {
    float flash_end = INSTANCE_CUSTOM.x;
    float active = step(boid_time, flash_end) * step(0.001, flash_end);

    ALBEDO = texture(albedo_texture, UV).rgb;
}