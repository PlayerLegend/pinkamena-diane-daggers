shader_type spatial;

uniform sampler2D vat_positions : filter_nearest, repeat_disable;
uniform sampler2D vat_normals : filter_nearest, repeat_disable;

instance uniform float time = 0.0;
 
void vertex() {
	ivec2 size = textureSize(vat_positions, 0);
	int frame = min(int(fract(time) * float(size.y)), size.y - 1);
	ivec2 px = ivec2(int(UV2.x * float(size.x)), frame);
	VERTEX = texelFetch(vat_positions, px, 0).xyz;
	NORMAL = texelFetch(vat_normals, px, 0).xyz;
}

void fragment() {
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
