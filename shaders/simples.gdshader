shader_type spatial;
// Iluminação feita à mão (ambiente + uma luz direcional fixa + emissão), sem o
// pipeline de luzes do Godot. Compila em uma fração do tempo no WebGL.
render_mode unshaded, cull_back;

uniform vec4 cor : source_color = vec4(1.0);
uniform sampler2D textura : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec2 repeticao = vec2(1.0);
uniform float emissao = 0.0;

const vec3 LUZ = vec3(0.35, 0.82, 0.45);

varying vec3 normal_mundo;

void vertex() {
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	UV = UV * repeticao;
}

void fragment() {
	vec3 base = cor.rgb * texture(textura, UV).rgb;
	float difusa = max(dot(normalize(normal_mundo), normalize(LUZ)), 0.0);
	float ceu = 0.5 + 0.5 * normal_mundo.y;
	vec3 luz = vec3(0.50, 0.52, 0.56) + vec3(0.22) * ceu + vec3(0.42, 0.40, 0.36) * difusa;
	ALBEDO = base * luz + base * emissao;
}
