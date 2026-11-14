shader_type canvas_item;
render_mode blend_disabled;

uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    if (c.a < alpha_cutoff) {
        discard;
    }
    COLOR = vec4(c.rgb, 1.0);
}