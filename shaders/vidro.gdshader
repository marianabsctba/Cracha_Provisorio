shader_type spatial;
// Vidro e superfícies translúcidas, com a mesma iluminação simples do simples.gdshader.
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 cor : source_color = vec4(1.0);
uniform float emissao = 0.0;

void fragment() {
	ALBEDO = cor.rgb * (0.95 + emissao);
	ALPHA = cor.a;
}
