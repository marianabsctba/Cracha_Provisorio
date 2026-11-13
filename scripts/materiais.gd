extends RefCounted
## Materiais do jogo. Tudo usa dois shaders próprios e enxutos (opaco e vidro), com
## iluminação feita à mão. No navegador, cada variação do material padrão do Godot
## custava cerca de 2 s de compilação no primeiro quadro; estes custam 0,2 s.

const OPACO := preload("res://shaders/simples.gdshader")
const VIDRO := preload("res://shaders/vidro.gdshader")

static var _cache := {}


## Material de cor sólida (alfa < 1 vira vidro). `emissao` acende a superfície.
static func cor(c: Color, emissao := 0.0) -> ShaderMaterial:
	var k := "%s|%s" % [c.to_html(), emissao]
	if _cache.has(k):
		return _cache[k]
	var m := ShaderMaterial.new()
	m.shader = VIDRO if c.a < 1.0 else OPACO
	m.set_shader_parameter("cor", c)
	m.set_shader_parameter("emissao", emissao)
	_cache[k] = m
	return m


## Material com textura (repetida `repeticao` vezes no UV).
static func textura(tex: Texture2D, repeticao := Vector2.ONE, c := Color.WHITE, emissao := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = OPACO
	m.set_shader_parameter("cor", c)
	m.set_shader_parameter("textura", tex)
	m.set_shader_parameter("repeticao", repeticao)
	m.set_shader_parameter("emissao", emissao)
	return m


## Converte um material importado (glb/obj) para o nosso, mantendo cor e textura.
static func de(original: Material, cor_nova = null) -> ShaderMaterial:
	var c := Color.WHITE
	var tex: Texture2D = null
	if original is BaseMaterial3D:
		c = (original as BaseMaterial3D).albedo_color
		tex = (original as BaseMaterial3D).albedo_texture
	if cor_nova != null:
		c = cor_nova
	if tex == null:
		return cor(c)
	var k := "tex|%s|%s" % [tex.get_rid(), c.to_html()]
	if not _cache.has(k):
		_cache[k] = textura(tex, Vector2.ONE, c)
	return _cache[k]


## Troca todos os materiais de um modelo pelos nossos. `cores`: nome do material -> Color.
static func aplicar(no: Node, cores := {}) -> void:
	var lista: Array = no.find_children("*", "MeshInstance3D", true, false)
	if no is MeshInstance3D:
		lista.append(no)
	for m in lista:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			var nome := mat.resource_name if mat else ""
			mi.set_surface_override_material(i, de(mat, Color(cores[nome]) if cores.has(nome) else null))
