shader_type sky;

// Assign a NoiseTexture3D resource in the inspector.
uniform sampler3D noise_tex : filter_linear, repeat_enable;
uniform float speed = 0.05;
uniform float scale = 1.0;
uniform vec3 color_a : source_color = vec3(0.05, 0.08, 0.2);
uniform vec3 color_b : source_color = vec3(0.9, 0.6, 0.8);

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void sky() {
    vec3 uvw = vec3(SKY_COORDS * scale, TIME * speed);
    float n = texture(noise_tex, uvw).r;
    COLOR = mix(color_a, color_b, n);
    
    vec3 in_rgb = COLOR;
    vec3 in_hsv = rgb2hsv(in_rgb);
    vec3 out_hsv = in_hsv;
    out_hsv.x += (n - 0.5);
    COLOR = hsv2rgb(out_hsv);
}