extends Node3D
## O andar da Tabajara Seguros, montado por código, com HUD, diálogos e NPCs.
## Dias "pc": a jogadora vai até a mesa e aperte E no computador (sinal sentou_no_pc).
## Dias "3d": uma missão (res://missoes/missao_NN.gd) roda aqui e chama finalizar().

signal sentou_no_pc
signal concluida(resultado: Dictionary)

const Estilo := preload("res://scripts/estilo.gd")
const Catalogo := preload("res://scripts/catalogo.gd")
const Jogador := preload("res://scripts/jogador.gd")
const Gente := preload("res://scripts/gente3d.gd")
const Materiais := preload("res://scripts/materiais.gd")

const MESA_PC := Vector3(3.6, 0, 1.6)

var dia := 1
var vitrine := false        # true: só o cenário, com câmera passeando (fundo do menu)
var jogador: CharacterBody3D
var _cam_vitrine: Camera3D
var _t_vitrine := 0.0
var missao: Node
var npcs := {}             # nome -> Node3D

var _hud: CanvasLayer
var _objetivo: Label
var _dica: Label
var _extra: Label
var _mira: Label
var _dlg: PanelContainer
var _dlg_nome: Label
var _dlg_texto: Label
var _dlg_opcoes: HBoxContainer
var _dlg_fila: Array = []
var _dlg_callback: Callable
var _materiais := {}
var _encerrado := false

const FALAS := {
	"Leidiane": ["Eu só pluguei o pendrive para ver de quem era. Para devolver! Sou uma pessoa honesta.",
		"Minha senha é o nome do meu gato mais o ano. Mas o gato morreu, então agora é mais segura."],
	"Contadora": ["Você é da segurança? Então me explica por que o Excel pede senha de macro.",
		"Eu guardo as senhas numa planilha chamada senhas.xlsx. Com senha. A senha está na outra aba."],
	"Analista de Marketing": ["Tive uma ideia: um QR code no elevador que leva para um formulário pedindo CPF. Engajamento!",
		"Pode tirar o MFA do Instagram da empresa? A agência mora em outro fuso."],
	"Valdecir": ["Sabia que eu fui o primeiro a instalar antivírus nesta empresa? Em 1998. Ainda é o mesmo.",
		"Se alguém perguntar, a política de segurança está sendo revisada. Desde 2014.",
		"Firewall é igual a muro: quanto mais alto, mais seguro. Eu pedi um de 3 metros."],
	"Jurema": ["22 anos aqui. Já vi três 'transformações digitais'. Todas deram em planilha.",
		"Regra número um: nunca acredite no Kauã quando ele diz 'é rapidinho'.",
		"Documenta tudo. O que não está documentado não aconteceu, e o que aconteceu vai ser culpa sua."],
	"Kauã": ["Eu não uso senha forte, eu uso senha longa: kaua123kaua123kaua123.",
		"Funciona na minha máquina. Se quiser, eu levo a minha máquina para produção.",
		"Já ouviu falar de segurança por obscuridade? Meu código ninguém entende. Nem eu."],
	"Dona Cida": ["Meu filho, o café da copa é melhor que o da diretoria. O da diretoria é cápsula.",
		"A senha do Wi-Fi está no quadro da copa. Todo mundo sabe. Até o moço da pizza.",
		"Eu limpo as mesas às sete. Vejo cada post-it que vocês nem imaginam."],
	"Seu Josias": ["Crachá provisório, hein? Eu também comecei assim. Em 1987.",
		"Aqui só entra com crachá. Ou com caixa de pizza. Pizza eu respeito.",
		"A câmera 3 está desligada desde a Copa de 2014. Mas não conta para ninguém."],
}


func _ready() -> void:
	_montar_ambiente()
	_montar_andar()
	_decorar()
	_montar_npcs()
	if vitrine:
		_cam_vitrine = Camera3D.new()
		_cam_vitrine.fov = 60
		add_child(_cam_vitrine)
		return
	_montar_hud()
	jogador = Jogador.new()
	jogador.position = Vector3(0, 0.1, 8.6)
	add_child(jogador)
	var info: Dictionary = Catalogo.dia(dia)
	if info["tipo"] == "pc":
		objetivo("Vá até a sua mesa (monitor rosa) e aperte E no computador.")
	if ResourceLoader.exists("res://missoes/missao_%02d.gd" % dia):
		missao = load("res://missoes/missao_%02d.gd" % dia).new()
		missao.set("escritorio", self)
		add_child(missao)
	var quem: String = info["quem"]
	dialogo(quem, "Dia %d. %s" % [dia, info["briefing"]])


func _process(delta: float) -> void:
	if vitrine:
		# Passeio lento de câmera pelo andar
		_t_vitrine += delta * 0.045
		var a := _t_vitrine
		_cam_vitrine.position = Vector3(sin(a) * 6.5 + 1.5, 1.75 + sin(a * 2.3) * 0.15, 1.2 + cos(a) * 3.0)
		_cam_vitrine.look_at(Vector3(sin(a + 0.9) * 7.0, 1.1, -4.0 + cos(a * 0.7) * 2.0))
		return
	if _dlg.visible:
		_mira.visible = false
		return
	_mira.visible = true
	var alvo: Node = jogador.alvo()
	if alvo:
		_dica.text = "[E] " + str(alvo.get_meta("nome", "Interagir"))
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_dica.text = "Clique na tela para olhar com o mouse.  WASD anda, Shift corre, E interage."
	else:
		_dica.text = ""


func _unhandled_input(evento: InputEvent) -> void:
	if vitrine:
		return
	if not (evento is InputEventKey and evento.pressed and not evento.echo):
		return
	if _dlg.visible:
		if (evento.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]) and _dlg_opcoes.get_child_count() <= 1:
			_avancar_dialogo()
			get_viewport().set_input_as_handled()
		return
	if evento.keycode == KEY_E:
		var alvo: Node = jogador.alvo()
		if alvo:
			var f: Callable = alvo.get_meta("interagir")
			f.call()
			get_viewport().set_input_as_handled()
	elif evento.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ================================================================ API para missões

func objetivo(texto: String) -> void:
	_objetivo.text = Jogo.txt(texto)


func extra(texto: String) -> void:
	_extra.text = Jogo.txt(texto)
	_extra.visible = texto != ""


## Mostra uma fala. `opcoes` é uma lista de textos; `ao_escolher(indice)` é chamado
## com o índice escolhido (ou -1 quando não há opções e a fala acaba).
func dialogo(quem: String, texto: String, opcoes: Array = [], ao_escolher := Callable()) -> void:
	_dlg_fila.append([quem, Jogo.txt(texto), opcoes.map(func(o): return Jogo.txt(str(o))), ao_escolher])
	if not _dlg.visible:
		_mostrar_proxima()


func dialogo_aberto() -> bool:
	return _dlg.visible


## Painel 2D por cima do escritório (trava a jogadora e solta o mouse).
func abrir_painel(c: Control) -> void:
	c.theme = Estilo.tema()
	_hud.add_child(c)
	jogador.travado = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func fechar_painel(c: Control) -> void:
	c.queue_free()
	jogador.travado = false


func finalizar(resultado: Dictionary) -> void:
	if _encerrado:
		return
	_encerrado = true
	resultado["dia"] = dia
	concluida.emit(resultado)


## Torna um nó interativo pela mira: aperte E para chamar `acao`.
func interativo(no: Node, nome: String, acao: Callable) -> void:
	no.set_meta("interagir", acao)
	no.set_meta("nome", nome)


func material(cor: Color, emissao := 0.0, _transparente := false) -> Material:
	return Materiais.cor(cor, emissao)


## Caixa sólida (com colisão se `solido`). `pos` é o centro da base.
func caixa(pos: Vector3, tam: Vector3, cor: Color, solido := true, emissao := 0.0, pai: Node = null) -> Node3D:
	var malha := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	malha.mesh = bm
	malha.material_override = material(cor, emissao, cor.a < 1.0)
	malha.position = Vector3(0, tam.y / 2.0, 0)
	var raiz: Node3D
	if solido:
		raiz = StaticBody3D.new()
		var forma := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = tam
		forma.shape = bs
		forma.position = malha.position
		raiz.add_child(forma)
	else:
		raiz = Node3D.new()
	raiz.add_child(malha)
	raiz.position = pos
	(pai if pai else self).add_child(raiz)
	return raiz


func texto3d(pos: Vector3, texto: String, tamanho := 48, cor: Color = Color.WHITE, pai: Node = null, fonte: Font = null) -> Label3D:
	var l := Label3D.new()
	l.font = fonte if fonte else Estilo.texto(700)
	l.text = Jogo.txt(texto)
	l.font_size = tamanho
	l.modulate = cor
	l.outline_size = 8
	l.double_sided = false
	l.position = pos
	(pai if pai else self).add_child(l)
	return l


## Pessoa (modelo humano animado), sólida e interativa. `olhando` é o ângulo em y
## (0 = de frente para -Z) ou use olhar_para() depois.
func pessoa(nome: String, pos: Vector3, _cor: Color = Color.WHITE, olhando := 0.0) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.position = pos
	corpo.rotation.y = olhando
	var forma := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.3
	cs.height = 1.75
	forma.shape = cs
	forma.position.y = 0.875
	corpo.add_child(forma)
	var modelo := Gente.criar(nome)
	corpo.add_child(modelo)
	corpo.set_meta("modelo", modelo)
	var cor_nome: Color = Estilo.cor_de(nome) if Estilo.PERSONAGENS.has(nome) else Color("c9d3e6")
	var rotulo := texto3d(Vector3(0, 2.08, 0), nome, 30, cor_nome, corpo, Estilo.texto(700))
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.double_sided = true
	add_child(corpo)
	npcs[nome] = corpo
	var falas: Array = FALAS.get(nome, [])
	if not falas.is_empty():
		interativo(corpo, "Falar com " + nome, func():
			Gente.acenar(modelo, "Wave" if randf() < 0.5 else "Interact")
			dialogo(nome, falas.pick_random()))
	return corpo


## Gira a pessoa (ou qualquer nó) para olhar um ponto no chão.
func olhar_para(no: Node3D, alvo: Vector3) -> void:
	var d := alvo - no.position
	no.rotation.y = atan2(-d.x, -d.z)


## Toca uma animação no modelo de uma pessoa ("Idle", "Walk", "Wave"...).
func animar(no: Node, nome: String) -> void:
	if no and no.has_meta("modelo"):
		Gente.tocar(no.get_meta("modelo"), nome)


# ================================================================ construção

func _montar_ambiente() -> void:
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a1f2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e4e7ee")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Brilho só fora do navegador: no WebGL cada efeito a mais é shader a compilar
	env.glow_enabled = not OS.has_feature("web")
	env.glow_intensity = 0.35
	amb.environment = env
	add_child(amb)


func _parede(x1: float, z1: float, x2: float, z2: float, cor := Color("d8d4cc"), alt := 3.0) -> void:
	var meio := Vector3((x1 + x2) / 2.0, 0, (z1 + z2) / 2.0)
	var tam := Vector3(maxf(absf(x2 - x1), 0.15), alt, maxf(absf(z2 - z1), 0.15))
	caixa(meio, tam, cor)
	if cor.a >= 1.0:
		# barrado escuro e faixa rosa da identidade visual
		var baixo := Vector3(tam.x + (0.04 if tam.x < 0.2 else 0.0), 0.9, tam.z + (0.04 if tam.z < 0.2 else 0.0))
		caixa(meio, baixo, cor.darkened(0.35), false)
		caixa(meio + Vector3(0, 0.9, 0), Vector3(baixo.x + 0.002, 0.06, baixo.z + 0.002), Color("c23c7e"), false)


const MOVEIS := "res://modelos/moveis/"
var _recursos := {}


## Coloca um modelo (.obj da pasta de móveis pelo nome, ou caminho completo de .glb).
## `tam`: altura alvo (float, escala uniforme) ou tamanho alvo (Vector3, escala por eixo).
## A base do modelo fica em `pos`, centrada. `cores`: nome do material -> Color.
func modelo(caminho: String, pos: Vector3, tam = 1.0, rot := 0.0, cores := {}, solido := true, pai: Node = null) -> Node3D:
	if not caminho.contains("/"):
		caminho = MOVEIS + caminho + ".obj"
	var res = _recursos.get(caminho)
	if res == null:
		res = load(caminho)
		_recursos[caminho] = res
	var vis: Node3D
	if res is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = res
		vis = mi
	else:
		vis = (res as PackedScene).instantiate()
	var ab := _aabb_local(vis)
	var escala: Vector3
	if tam is Vector3:
		escala = Vector3(tam.x / maxf(ab.size.x, 0.001), tam.y / maxf(ab.size.y, 0.001), tam.z / maxf(ab.size.z, 0.001))
	else:
		var e := float(tam) / maxf(ab.size.y, 0.001)
		escala = Vector3(e, e, e)
	var raiz: Node3D = StaticBody3D.new() if solido else Node3D.new()
	raiz.position = pos
	raiz.rotation.y = rot
	vis.scale = escala
	vis.position = -Vector3(ab.get_center().x * escala.x, ab.position.y * escala.y, ab.get_center().z * escala.z)
	raiz.add_child(vis)
	if solido:
		var forma := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = ab.size * escala
		forma.shape = bs
		forma.position.y = bs.size.y / 2.0
		raiz.add_child(forma)
	Materiais.aplicar(vis, cores)
	(pai if pai else self).add_child(raiz)
	return raiz


func _aabb_local(no: Node3D) -> AABB:
	var total := AABB()
	var primeiro := true
	var lista: Array = no.find_children("*", "MeshInstance3D", true, false)
	if no is MeshInstance3D:
		lista.append(no)
	for m in lista:
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n and n != no:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var a: AABB = t * (m as MeshInstance3D).get_aabb()
		total = a if primeiro else total.merge(a)
		primeiro = false
	return total


func _montar_andar() -> void:
	_piso()
	_teto()
	# Paredes externas
	_parede(-17, -11, 17, -11)
	_parede(-17, 11, 17, 11)
	_parede(-17, -11, -17, 11)
	_parede(17, -11, 17, 11)
	# Recepção (sul): divisória em z=5 com passagem central e porta corta-fogo no leste
	_parede(-17, 5, -1.3, 5, Color("c9c4ba"))
	_parede(1.3, 5, 14.2, 5, Color("c9c4ba"))
	_parede(15.8, 5, 17, 5, Color("c9c4ba"))
	_catracas()
	_recepcao()

	# Sala do Valdecir (vidro) no noroeste
	var vidro := Color(0.62, 0.8, 0.95, 0.22)
	_parede(-17, -4, -11.5, -4, vidro)
	_parede(-9.8, -4, -9, -4, vidro)
	_parede(-9, -11, -9, -4, vidro)
	_caixilhos_vidro()
	modelo("desk", Vector3(-13, 0, -8), Vector3(2.0, 0.76, 1.0), PI, {"wood": Color("5a3d2b")})
	_monitor(Vector3(-13.35, 0.76, -8.2), PI, Color("2a5bd7"))
	modelo("chairDesk", Vector3(-13, 0, -8.85), 1.15, PI, {"carpet": Color("2b2b33"), "metal": Color("3a3f4a")}, false)
	modelo("bookcaseClosedDoors", Vector3(-16.45, 0, -7.4), 1.9, -PI / 2, {"wood": Color("5a3d2b")})
	modelo("books", Vector3(-16.4, 1.9, -7.4), 0.22, -PI / 2, {}, false)
	modelo("coatRackStanding", Vector3(-10.0, 0, -5.0), 1.7, 0.0, {}, false)
	modelo("loungeChair", Vector3(-11.2, 0, -6.2), 0.85, -2.4, {"carpet": Color("7a2b4a")})
	modelo("res://modelos/plantas/planta_morta.glb", Vector3(-12.3, 0.76, -8.25), 0.5, 0.0, {}, false)
	modelo("trashcan", Vector3(-14.2, 0, -8.6), 0.4, 0.0, {}, false)
	_placa_parede(Vector3(-13.6, 1.75, -4.0), 0.0, "GERÊNCIA DE SEGURANÇA DA INFORMAÇÃO", "Valdecir Antunes · Gerente\n(e de Facilities, e do Refeitório)", Estilo.ALERTA, false)
	var diploma := caixa(Vector3(-13.0, 1.5, -10.9), Vector3(0.7, 0.5, 0.03), Color("6b4a2a"), false)
	caixa(Vector3(0, 0.04, 0.02), Vector3(0.62, 0.42, 0.01), Color("f3ecd8"), false, 0.0, diploma)
	texto3d(Vector3(0, 0.3, 0.03), "CERTIFICADO\nCurso Básico de Antivírus\n(1998, 4 horas)", 9, Color("3a2a10"), diploma, Estilo.titulo(700))

	# Copa
	_parede(-9, -6, -2.4, -6, Color("e3d9c6"))
	_parede(-2.4, -11, -2.4, -7.6, Color("e3d9c6"))
	for i in 5:
		if i == 3:
			continue
		modelo("kitchenCabinet", Vector3(-8.1 + i * 0.86, 0, -10.48), Vector3(0.86, 0.9, 0.62), PI, {"wood": Color("e9e4da"), "metal": Color("9aa3ad")})
	modelo("kitchenSink", Vector3(-5.52, 0, -10.48), Vector3(0.86, 0.98, 0.62), PI, {"wood": Color("e9e4da")}, false)
	for i in 3:
		modelo("kitchenCabinetUpper", Vector3(-7.7 + i * 1.2, 1.55, -10.75), Vector3(1.1, 0.7, 0.35), PI, {"wood": Color("e9e4da")}, false)
	modelo("kitchenCoffeeMachine", Vector3(-7.6, 0.9, -10.35), 0.4, PI, {}, false)
	modelo("kitchenMicrowave", Vector3(-4.6, 0.9, -10.45), 0.32, PI, {}, false)
	modelo("kitchenFridge", Vector3(-3.15, 0, -10.4), Vector3(0.8, 1.9, 0.7), PI)
	modelo("table", Vector3(-5.5, 0, -8.3), Vector3(1.7, 0.74, 1.0), 0.0, {"wood": Color("c7a271")})
	for d in [Vector3(-5.9, 0, -7.55), Vector3(-5.1, 0, -7.55)]:
		modelo("stoolBar", d, 0.65, 0.0, {}, false)
	modelo("trashcan", Vector3(-2.9, 0, -9.0), 0.45, 0.0, {}, false)
	_placa_parede(Vector3(-2.4, 1.6, -8.4), PI / 2, "COPA", "Lave sua caneca.\n(Kauã, isso é com você.)", Color("7fc4ff"))
	var quadro := caixa(Vector3(-8.9, 1.0, -8.5), Vector3(0.05, 1.0, 1.6), Color("f4f4f2"), false)
	caixa(Vector3(0, -0.05, 0), Vector3(0.07, 1.1, 1.7), Color("9aa3ad"), false, 0.0, quadro)
	var wifi := texto3d(Vector3(0.04, 0.6, 0), "Wi-Fi: Tabajara-Corp\nsenha: Tabajara@2009\nNÃO CONTAR PRA NINGUÉM", 16, Color("1b3b8a"), quadro, Estilo.titulo(600))
	wifi.rotation.y = PI / 2
	var bolo := texto3d(Vector3(-8.85, 1.6, -7.2), "Bolo de fubá\nsexta 15h\nass: Dona Cida", 12, Color("8a1c4a"), null, Estilo.titulo(700))
	bolo.rotation.y = PI / 2

	# Sala de reunião
	_parede(-0.5, -5, 3.0, -5, vidro)
	_parede(4.6, -5, 8.0, -5, vidro)
	_parede(8.0, -11, 8.0, -5, Color("d8d4cc"))
	_parede(-0.5, -11, -0.5, -5, Color("d8d4cc"))
	modelo("table", Vector3(3.8, 0, -8), Vector3(4.0, 0.75, 1.6), 0.0, {"wood": Color("4b3a2c")})
	for i in 4:
		for lado in [-1, 1]:
			modelo("chairDesk", Vector3(2.4 + i * 0.95, 0, -8 + lado * 1.15), 1.05, 0.0 if lado > 0 else PI, {"carpet": Color("2e3242"), "metal": Color("3a3f4a")}, false)
	_tv(Vector3(3.8, 1.0, -10.85))
	modelo("res://modelos/plantas/espada_sao_jorge.glb", Vector3(0.0, 0, -10.4), 1.1, 0.0, {}, false)
	_placa_parede(Vector3(5.9, 1.6, -5.0), 0.0, "SALA SINERGIA", "Reservas pelo Outlook\n(que ninguém usa)", Estilo.CIANO, false)

	# Datacenter (nordeste)
	_parede(9.0, -4, 11.4, -4, Color("8d96a5"))
	_parede(13.2, -4, 17, -4, Color("8d96a5"))
	_parede(9.0, -11, 9.0, -4, Color("8d96a5"))
	_datacenter()

	# Open space: duas fileiras de mesas de cada lado do corredor
	var k := 0
	for x in [-12.5, -9.0, -5.5, 6.5, 10.0, 13.5]:
		for z in [-1.0, 1.6]:
			_mesa(Vector3(x, 0, z), k)
			k += 1
	# A mesa de quem joga
	_mesa(MESA_PC, 99, true)
	var pc := StaticBody3D.new()
	pc.position = MESA_PC + Vector3(0, 0.76, -0.25)
	var forma := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 0.7, 0.4)
	forma.shape = bs
	forma.position.y = 0.35
	pc.add_child(forma)
	add_child(pc)
	interativo(pc, "Sentar e usar o computador", _usar_pc)
	var etiqueta := texto3d(MESA_PC + Vector3(0, 1.62, -0.3), "{ESTAGIÁRIA|ESTAGIÁRIO|ESTAGIÁRIE} (PROVISÓRIO)", 20, Estilo.DESTAQUE, null, Estilo.titulo(800))
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.double_sided = true
	_impressora(Vector3(15.6, 0, 2.5))
	_vaso_chao(Vector3(-16, 0, 4.2), "costela_adao_b", 0.9)
	_vaso_chao(Vector3(16, 0, -3.2), "espada_sao_jorge", 1.15)
	_vaso_chao(Vector3(-0.9, 0, -3.6), "costela_adao_b", 0.8)
	_vaso_chao(Vector3(8.6, 0, 4.4), "espada_sao_jorge", 1.0)
	for x in [-14.3, -3.8, 4.6, 15.2]:
		modelo("trashcan", Vector3(x, 0, 0.3), 0.42, 0.0, {}, false)


func _teto() -> void:
	# Forro em placas de 60 cm com perfis, e luminárias embutidas
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var borda := x < 2 or y < 2
			img.set_pixel(x, y, Color("b9bcc2") if borda else Color("eceae6").lightened(randf() * 0.02))
	img.generate_mipmaps()
	var m := Materiais.textura(ImageTexture.create_from_image(img), Vector2(34.0 / 0.6, 22.0 / 0.6), Color.WHITE, 0.15)
	superficie(Vector3(0, 2.99, 0), Vector2(34, 22), m, true)
	for x in [-10, -4, 2, 8, 13]:
		for z in [-7, -1, 4]:
			caixa(Vector3(x, 2.96, z), Vector3(1.2, 0.04, 0.6), Color("8f949c"), false)
			caixa(Vector3(x, 2.955, z), Vector3(1.1, 0.02, 0.5), Color("fffaf0"), false, 1.0)


## Plano texturizado (UV de 0 a 1 no plano todo), virado para cima ou para baixo (teto).
func superficie(centro: Vector3, tam: Vector2, mat: Material, teto := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = tam
	mi.mesh = pm
	mi.material_override = mat
	mi.position = centro
	if teto:
		mi.rotation.x = PI
	add_child(mi)
	return mi


func _caixilhos_vidro() -> void:
	# Perfis metálicos nas paredes de vidro
	for x in [-17.0, -15.5, -14.0, -12.5, -11.5, -9.8, -9.0]:
		caixa(Vector3(x, 0, -4), Vector3(0.06, 3.0, 0.08), Color("4a505c"), false)
	for z in [-11.0, -9.5, -8.0, -6.5, -5.0, -4.0]:
		caixa(Vector3(-9, 0, z), Vector3(0.08, 3.0, 0.06), Color("4a505c"), false)
	for x in [-0.5, 1.0, 3.0, 4.6, 6.2, 8.0]:
		caixa(Vector3(x, 0, -5), Vector3(0.06, 3.0, 0.08), Color("4a505c"), false)
	# Faixas jateadas (para ninguém dar de cara no vidro)
	caixa(Vector3(-14.25, 1.2, -4), Vector3(5.5, 0.12, 0.17), Color(1, 1, 1, 0.55), false)
	caixa(Vector3(-9, 1.2, -7.5), Vector3(0.17, 0.12, 7.0), Color(1, 1, 1, 0.55), false)
	caixa(Vector3(1.25, 1.2, -5), Vector3(3.5, 0.12, 0.17), Color(1, 1, 1, 0.55), false)
	caixa(Vector3(6.3, 1.2, -5), Vector3(3.4, 0.12, 0.17), Color(1, 1, 1, 0.55), false)


func _catracas() -> void:
	for x in [-1.2, 1.2]:
		var c := caixa(Vector3(x, 0, 5), Vector3(0.28, 1.0, 0.9), Color("2a2f3a"))
		caixa(Vector3(0, 1.0, 0), Vector3(0.3, 0.04, 0.92), Color("c9ced8"), false, 0.0, c)
		caixa(Vector3(0, 0.82, 0.46), Vector3(0.18, 0.12, 0.01), Color("3cff7a"), false, 2.5, c)
		caixa(Vector3(0, 0.82, -0.46), Vector3(0.18, 0.12, 0.01), Color("3cff7a"), false, 2.5, c)
	var aviso := texto3d(Vector3(0, 1.25, 5.5), "APROXIME O CRACHÁ  ·  UMA PESSOA POR VEZ", 14, Color("c9d3e6"), null, Estilo.texto(700))
	aviso.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# Painel da marca acima da passagem, de frente para quem chega
	var painel := Node3D.new()
	painel.position = Vector3(0, 0, 5.09)
	add_child(painel)
	caixa(Vector3(0, 1.95, 0), Vector3(9.0, 1.0, 0.04), Color("141924"), false, 0.0, painel)
	caixa(Vector3(0, 1.93, 0.025), Vector3(9.0, 0.03, 0.01), Estilo.DESTAQUE, false, 2.5, painel)
	caixa(Vector3(0, 2.93, 0.025), Vector3(9.0, 0.03, 0.01), Estilo.DESTAQUE, false, 2.5, painel)
	_marca(Vector3(-3.55, 2.45, 0.03), 0.62, painel)
	texto3d(Vector3(0.45, 2.55, 0.03), "TABAJARA SEGUROS S.A.", 74, Color("f4f1ea"), painel, Estilo.titulo(800))
	texto3d(Vector3(0.45, 2.2, 0.03), "Segurança é prioridade desde 2009 (revisada nunca)", 26, Color("ff86c0"), painel, Estilo.texto(600))
	# Do lado de dentro: placar de dias sem incidente
	var placar := Node3D.new()
	placar.position = Vector3(-4.5, 0, 4.9)
	placar.rotation.y = PI
	add_child(placar)
	caixa(Vector3(0, 1.45, 0), Vector3(1.9, 1.0, 0.04), Color("f4f1ea"), false, 0.0, placar)
	caixa(Vector3(0, 1.85, 0.025), Vector3(1.9, 0.2, 0.01), Color("b00020"), false, 0.0, placar)
	texto3d(Vector3(0, 1.85, 0.035), "SEGURANÇA DA INFORMAÇÃO", 16, Color.WHITE, placar, Estilo.titulo(800))
	texto3d(Vector3(0, 1.62, 0.035), "ESTE ANDAR ESTÁ HÁ", 14, Color("222"), placar, Estilo.titulo(700))
	caixa(Vector3(0, 1.22, 0.025), Vector3(0.5, 0.36, 0.01), Color("111"), false, 0.0, placar)
	texto3d(Vector3(0, 1.4, 0.035), "0", 72, Color("ff3b3b"), placar, Estilo.mono())
	texto3d(Vector3(0.62, 1.4, 0.035), "DIAS\nSEM\nINCIDENTES", 11, Color("222"), placar, Estilo.titulo(700))
	texto3d(Vector3(0, 1.06, 0.035), "recorde: 2 dias (Carnaval de 2019)", 10, Color("555"), placar, Estilo.texto(600))
	# Placa de saída de emergência acesa
	var saida := caixa(Vector3(15.0, 2.45, 5.1), Vector3(1.0, 0.32, 0.04), Color("1fa34a"), false, 1.4)
	texto3d(Vector3(0, 0.16, 0.025), "SAÍDA  >>", 26, Color.WHITE, saida, Estilo.titulo(800))
	var saida2 := caixa(Vector3(15.0, 2.45, 4.9), Vector3(1.0, 0.32, 0.04), Color("1fa34a"), false, 1.4)
	var t2 := texto3d(Vector3(0, 0.16, -0.025), "SAÍDA  >>", 26, Color.WHITE, saida2, Estilo.titulo(800))
	t2.rotation.y = PI
	# Placa de corredor pendurada no teto
	var pend := Node3D.new()
	pend.position = Vector3(0, 0, 0.3)
	add_child(pend)
	for lado in [-0.85, 0.85]:
		caixa(Vector3(lado, 2.62, 0), Vector3(0.02, 0.38, 0.02), Color("6b7280"), false, 0.0, pend)
	caixa(Vector3(0, 2.18, 0), Vector3(2.6, 0.44, 0.05), Color("171d29"), false, 0.0, pend)
	caixa(Vector3(0, 2.15, 0), Vector3(2.6, 0.03, 0.06), Estilo.DESTAQUE, false, 2.0, pend)
	for face in [1.0, -1.0]:
		var t := texto3d(Vector3(0, 2.4, 0.03 * face), "<  Gerência · Copa      Reunião  ^      Datacenter  >", 17, Color("e6e9f0"), pend, Estilo.texto(700))
		if face < 0:
			t.rotation.y = PI
			t.text = "<  Datacenter      Reunião  ^      Copa · Gerência  >"


func _marca(pos: Vector3, tam: float, pai: Node) -> void:
	# Escudo da Tabajara: losango rosa com um T
	var m := Node3D.new()
	m.position = pos
	pai.add_child(m)
	var losango := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(tam * 0.7, tam * 0.7, 0.02)
	losango.mesh = bm
	losango.material_override = material(Estilo.DESTAQUE, 1.2)
	losango.rotation.z = PI / 4
	m.add_child(losango)
	var borda := MeshInstance3D.new()
	var bm2 := BoxMesh.new()
	bm2.size = Vector3(tam * 0.56, tam * 0.56, 0.02)
	borda.mesh = bm2
	borda.material_override = material(Color("141924"))
	borda.rotation.z = PI / 4
	borda.position.z = 0.006
	m.add_child(borda)
	var t := texto3d(Vector3(0, 0, 0.02), "T", int(110 * tam), Estilo.DESTAQUE, m, Estilo.titulo(800))
	t.outline_size = 0


func _recepcao() -> void:
	# Balcão
	caixa(Vector3(-4.5, 0, 7.4), Vector3(3.2, 1.1, 0.8), Color("f1ede6"))
	caixa(Vector3(-4.5, 0.05, 7.805), Vector3(3.2, 0.06, 0.01), Estilo.DESTAQUE, false, 2.2)
	caixa(Vector3(-4.5, 1.1, 7.4), Vector3(3.36, 0.06, 0.94), Color("7a5236"))
	texto3d(Vector3(-4.5, 0.6, 7.81), "RECEPÇÃO", 34, Color("2a2f3a"), null, Estilo.titulo(800))
	_monitor(Vector3(-3.6, 1.16, 7.6), PI, Color("1f8a70"))
	modelo("chairDesk", Vector3(-4.5, 0, 6.3), 1.1, PI, {"carpet": Color("1f2d4a")}, false)
	modelo("res://modelos/plantas/vaso_a.glb", Vector3(-5.8, 1.13, 7.25), 0.28, 0.0, {}, false)
	# Sala de espera
	modelo("rugRectangle", Vector3(5.6, 0.005, 8.6), Vector3(4.2, 0.01, 2.6), 0.0, {"carpet": Color("3d2f4a")}, false)
	modelo("loungeSofa", Vector3(5.6, 0, 9.85), Vector3(2.6, 0.85, 0.9), PI, {"carpet": Color("8a3b5c"), "wood": Color("3a2a1e")})
	modelo("loungeChair", Vector3(3.6, 0, 8.4), 0.85, -PI / 2, {"carpet": Color("8a3b5c"), "wood": Color("3a2a1e")})
	modelo("tableCoffee", Vector3(5.6, 0, 8.55), Vector3(1.3, 0.42, 0.75), 0.0, {"wood": Color("3a2a1e")})
	var revista := texto3d(Vector3(5.6, 0.44, 8.55), "Revista Seguro Hoje\nEdição 2011", 9, Color("333"), null, Estilo.titulo(700))
	revista.rotation.x = -PI / 2
	_vaso_chao(Vector3(8, 0, 9.9), "espada_sao_jorge", 1.2)
	_vaso_chao(Vector3(-8, 0, 9.9), "costela_adao_b", 0.95)
	modelo("res://modelos/plantas/jiboia_grande.glb", Vector3(-16.6, 1.6, 9.5), 0.55, 0.0, {}, false)
	modelo("lampRoundFloor", Vector3(7.6, 0, 8.4), 1.6, 0.0, {}, false)
	_quadro_parede(Vector3(0, 1.6, 10.92), PI, "Missão: proteger o que é seu.\nVisão: um dia ler a política.", Color("f4f1ea"))


func _quadro_parede(pos: Vector3, rot: float, texto: String, cor: Color) -> void:
	var q := Node3D.new()
	q.position = pos
	q.rotation.y = rot
	add_child(q)
	caixa(Vector3(0, 0, 0), Vector3(2.2, 0.8, 0.03), Color("1b1f29"), false, 0.0, q)
	caixa(Vector3(0, 0.05, 0.02), Vector3(2.1, 0.7, 0.01), cor, false, 0.0, q)
	texto3d(Vector3(0, 0.4, 0.03), texto, 20, Color("1b1f29"), q, Estilo.titulo(700))


func _placa_parede(pos: Vector3, rot: float, titulo: String, sub: String, cor: Color, dois_lados := true) -> void:
	# Placa de acrílico escuro com filete colorido (dos dois lados da parede, se for alvenaria)
	for face in ([1.0, -1.0] if dois_lados else [1.0]):
		var p := Node3D.new()
		p.position = pos
		p.rotation.y = rot + (0.0 if face > 0 else PI)
		add_child(p)
		var desloc := 0.09
		caixa(Vector3(0, 0, desloc), Vector3(1.25, 0.46, 0.02), Color("171d29"), false, 0.0, p)
		caixa(Vector3(-0.6, 0, desloc + 0.012), Vector3(0.04, 0.46, 0.01), cor, false, 1.8, p)
		var t := texto3d(Vector3(0.03, 0.34, desloc + 0.015), titulo, 15, Color("f4f1ea"), p, Estilo.titulo(800))
		t.outline_size = 0
		var s := texto3d(Vector3(0.03, 0.17, desloc + 0.015), sub, 10, Color("aab3c5"), p, Estilo.texto(600))
		s.outline_size = 0


func _datacenter() -> void:
	# Piso elevado, racks com LEDs, bandeja de cabos e ar-condicionado
	caixa(Vector3(13.0, 0.0, -7.5), Vector3(7.9, 0.02, 6.9), Color("9aa2ae"), false)
	for i in range(4):
		var rack := caixa(Vector3(11 + i * 1.3, 0, -9.6), Vector3(0.8, 2.1, 1.0), Color("1c1f26"))
		caixa(Vector3(0, 0.1, 0.505), Vector3(0.7, 1.9, 0.01), Color("2a2f3a"), false, 0.0, rack)
		for j in range(12):
			caixa(Vector3(-0.28 + (j % 4) * 0.18, 0.35 + int(j / 4) * 0.55 + (j % 2) * 0.12, 0.52), Vector3(0.04, 0.025, 0.01),
				[Color("3cff7a"), Color("38d9e8"), Color("3cff7a"), Color("ff4fa3")][j % 4], false, 4.0, rack)
		texto3d(Vector3(0, 1.95, 0.52), "RACK %02d" % (i + 1), 14, Color("c9d3e6"), rack, Estilo.mono())
	caixa(Vector3(12.95, 2.35, -9.6), Vector3(5.0, 0.06, 0.4), Color("6b7280"), false)
	for i in 6:
		caixa(Vector3(10.7 + i * 0.9, 2.2, -9.6), Vector3(0.05, 0.24, 0.05), [Color("2a5bd7"), Color("e0a020"), Color("c23c7e")][i % 3], false)
	var ar := caixa(Vector3(16.6, 1.8, -7.0), Vector3(0.4, 0.5, 1.4), Color("e9ecef"), false)
	texto3d(Vector3(-0.21, 0.25, 0), "GERALDO", 14, Color("333"), ar, Estilo.titulo(800)).rotation.y = -PI / 2
	modelo("cardboardBoxClosed", Vector3(9.8, 0, -5.0), 0.45, 0.3, {}, false)
	modelo("cardboardBoxOpen", Vector3(10.4, 0, -5.3), 0.45, -0.2, {}, false)
	var porta_dc := caixa(Vector3(12.3, 0, -4), Vector3(1.8, 2.3, 0.12), Color("5a6170"))
	porta_dc.name = "PortaDatacenter"
	caixa(Vector3(0.6, 1.0, 0.07), Vector3(0.05, 0.35, 0.04), Color("c9ced8"), false, 0.0, porta_dc)
	caixa(Vector3(0, 1.75, 0.065), Vector3(0.5, 0.36, 0.01), Color("9fc4e8"), false, 0.3, porta_dc)
	caixa(Vector3(13.4, 1.2, -3.8), Vector3(0.12, 0.18, 0.05), Color("ff3030"), false, 2.0)
	_placa_parede(Vector3(14.6, 1.6, -4.0), 0.0, "DATACENTER", "Acesso restrito. Proibido entrar\ncom café, comida ou Kauã.", Color("ff3b3b"))
	var faixa := caixa(Vector3(12.3, 2.45, -3.93), Vector3(1.9, 0.16, 0.02), Color("ffcc00"), false)
	texto3d(Vector3(0, 0.08, 0.012), "ÁREA RESTRITA  ·  ÁREA RESTRITA", 12, Color("111"), faixa, Estilo.titulo(800)).outline_size = 0


func _tv(pos: Vector3) -> void:
	caixa(pos, Vector3(2.4, 1.36, 0.06), Color("0d0d10"), false)
	caixa(pos + Vector3(0, 0.05, 0.035), Vector3(2.28, 1.26, 0.01), Color("141a2a"), false, 0.6)
	var slide := texto3d(pos + Vector3(0, 1.1, 0.045), "PLANEJAMENTO ESTRATÉGICO Q3", 24, Color("ff86c0"), null, Estilo.titulo(800))
	slide.outline_size = 0
	var itens := texto3d(pos + Vector3(-0.2, 0.7, 0.045), "1. Sinergia\n2. Sinergizar a sinergia\n3. Segurança (se sobrar orçamento)", 16, Color("e6e9f0"), null, Estilo.texto(600))
	itens.outline_size = 0
	# A área clicável da TV (usada nas missões) fica no mesmo lugar
	var colisao := caixa(pos, Vector3(2.4, 1.36, 0.06), Color(0, 0, 0, 0))
	colisao.visible = false


func _impressora(pos: Vector3) -> void:
	caixa(pos, Vector3(0.9, 0.62, 0.7), Color("3a3f4a"))                       # gabinete
	caixa(pos + Vector3(0, 0.62, 0), Vector3(0.9, 0.38, 0.7), Color("e6e6e1"))  # corpo
	caixa(pos + Vector3(0, 1.0, 0), Vector3(0.7, 0.12, 0.5), Color("cfcfc8"))   # bandeja
	caixa(pos + Vector3(-0.3, 0.86, -0.36), Vector3(0.24, 0.1, 0.02), Color("38d9e8"), false, 1.5)
	caixa(pos + Vector3(0.05, 1.12, 0.05), Vector3(0.21, 0.01, 0.3), Color.WHITE, false)
	var nome := texto3d(pos + Vector3(0, 1.55, 0), "Impressora 'Godzilla'", 16, Color("e6e9f0"), null, Estilo.titulo(800))
	nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nome.double_sided = true
	var bilhete := texto3d(pos + Vector3(0, 0.45, -0.36), "Atolou? Reze.", 10, Color("ffe95a"), null, Estilo.titulo(700))
	bilhete.rotation.y = PI


func _vaso_chao(pos: Vector3, planta: String, altura: float) -> void:
	# Vaso de cerâmica com a base em `pos` (topo do vaso em 0,5 m) e a planta por cima
	caixa(pos, Vector3(0.46, 0.5, 0.46), Color("d9cbb4"))
	caixa(pos + Vector3(0, 0.5, 0), Vector3(0.5, 0.04, 0.5), Color("c4b59b"), false)
	modelo("res://modelos/plantas/%s.glb" % planta, pos + Vector3(0, 0.42, 0), altura, randf() * TAU, {}, false)


func _piso() -> void:
	# Carpete em placas, gerado por código (sem arquivo de textura).
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in 128:
		for x in 128:
			var placa := (int(x / 64) + int(y / 64)) % 2
			var base := Color("3a4458") if placa == 0 else Color("343d50")
			var listra := (x if placa == 0 else y) % 4 == 0
			var c := base.darkened(0.08) if listra else base
			c = c.lightened(rng.randf_range(-0.03, 0.04))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var m := Materiais.textura(tex, Vector2(17, 11))
	var piso := caixa(Vector3(0, -0.1, 0), Vector3(34, 0.1, 22), Color.WHITE)
	(piso.get_child(1) as MeshInstance3D).visible = false
	superficie(Vector3(0, 0.0, 0), Vector2(34, 22), m)
	# Porcelanato na recepção e na copa
	var img2 := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			img2.set_pixel(x, y, Color("8f8a82") if x < 1 or y < 1 else Color("d8d2c6").darkened(rng.randf_range(0.0, 0.04)))
	img2.generate_mipmaps()
	var porcelanato := ImageTexture.create_from_image(img2)
	superficie(Vector3(0, 0.004, 8.0), Vector2(34, 6), Materiais.textura(porcelanato, Vector2(34.0 / 0.8, 6.0 / 0.8)))
	var p3 := Materiais.textura(porcelanato, Vector2(6.6 / 0.8, 5.0 / 0.8))
	superficie(Vector3(-5.7, 0.004, -8.5), Vector2(6.6, 5.0), p3)


func _ceu() -> ImageTexture:
	# Vista da janela: céu de Curitiba (nublado, claro) e prédios ao longe
	var w := 256
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in h:
		var c := Color("cfe0f0").lerp(Color("9fbfdf"), float(y) / h)
		for x in w:
			img.set_pixel(x, y, c)
	var x0 := 0
	while x0 < w:
		var larg := rng.randi_range(14, 34)
		var alt := rng.randi_range(30, 100)
		var cor := Color("7d8ea3").lerp(Color("5b6b80"), rng.randf())
		for y in range(h - alt, h):
			for x in range(x0, mini(x0 + larg, w)):
				var janela := (x - x0) % 5 >= 2 and (y - (h - alt)) % 6 >= 3 and x - x0 > 2 and x < x0 + larg - 2
				img.set_pixel(x, y, cor.lightened(0.18) if janela else cor)
		x0 += larg + rng.randi_range(0, 6)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _decorar() -> void:
	# Janelas com vista da cidade
	var vista := Materiais.textura(_ceu(), Vector2.ONE, Color.WHITE, 0.45)
	var janelas := []
	for x in [-14.0, 1.0, 5.0, 11.0, 14.5]:
		janelas.append([Vector3(x, 0.9, -10.93), Vector3(2.4, 1.6, 0.02), true])
	for z in [-7.5, 0.5, 8.0]:
		janelas.append([Vector3(-16.93, 0.9, z), Vector3(0.02, 1.6, 2.4), false])
	for z in [0.5, 8.0]:
		janelas.append([Vector3(16.93, 0.9, z), Vector3(0.02, 1.6, 2.4), false])
	for j in janelas:
		var v := caixa(j[0], j[1], Color.WHITE, false)
		(v.get_child(0) as MeshInstance3D).material_override = vista
		var moldura := Color("3a3f4a")
		var horizontal: bool = j[2]
		var larg := 2.5
		var e := Vector3(larg, 0.06, 0.06) if horizontal else Vector3(0.06, 0.06, larg)
		caixa(j[0] + Vector3(0, -0.03, 0), e, moldura, false)
		caixa(j[0] + Vector3(0, 1.6, 0), e, moldura, false)
		var meio := Vector3(0.05, 1.6, 0.07) if horizontal else Vector3(0.07, 1.6, 0.05)
		caixa(j[0], meio, moldura, false)
		caixa(j[0] + Vector3(0, -0.06, 0) + (Vector3(0, 0, 0.12) if horizontal else Vector3(0.12, 0, 0)) * (1 if j[0].z < 0 or j[0].x < 0 else -1),
			Vector3(larg, 0.04, 0.22) if horizontal else Vector3(0.22, 0.04, larg), Color("e8e4dc"), false)
	# Cartazes
	_cartaz(Vector3(-16.9, 1.5, -2.6), PI / 2, "TROQUE SUA SENHA\nA CADA 30 DIAS!", "Política POL-SEG-0001", Color("ffc94d"))
	_cartaz(Vector3(16.9, 1.5, -1.5), -PI / 2, "VOCÊ É O FIREWALL\nHUMANO", "(o outro firewall está em\n'permitir tudo')", Color("ff4fa3"))
	_cartaz(Vector3(-0.4, 1.5, -6.5), PI / 2, "CLICOU NO LINK?\nAVISE A TI", "Ramal 2210. Atendemos\nde 10h às 10h15.", Color("38d9e8"))
	_cartaz(Vector3(7.9, 1.5, -8.0), -PI / 2, "MESA LIMPA,\nTELA BLOQUEADA", "Windows + L. Não é difícil.", Color("5ee38a"))
	_cartaz(Vector3(-16.9, 1.5, 2.8), PI / 2, "NÃO ALIMENTE\nO ESTAGIÁRIO", "Ele precisa aprender\na caçar sozinho.", Color("ff86c0"))
	# Relógio de parede e bebedouro
	var relogio := caixa(Vector3(-13.0, 2.25, 4.88), Vector3(0.5, 0.5, 0.04), Color("f4f4f2"), false)
	relogio.rotation.y = PI
	caixa(Vector3(0, -0.02, -0.01), Vector3(0.54, 0.54, 0.03), Color("2a2f3a"), false, 0.0, relogio)
	texto3d(Vector3(0, 0.25, -0.03), "09:00", 22, Color("222"), relogio, Estilo.mono()).rotation.y = PI
	caixa(Vector3(-1.5, 0, -4.4), Vector3(0.4, 1.1, 0.4), Color("dfe7ef"))
	caixa(Vector3(-1.5, 1.1, -4.4), Vector3(0.3, 0.42, 0.3), Color("7fb8f0"), false, 0.3)
	# Quadro branco do Kauã
	var quadro := caixa(Vector3(16.9, 1.0, 0.9), Vector3(0.04, 1.1, 1.8), Color("fafafa"), false)
	caixa(Vector3(0.01, -0.05, 0), Vector3(0.05, 1.2, 1.9), Color("9aa3ad"), false, 0.0, quadro)
	var t := texto3d(Vector3(-0.03, 0.55, 0), "SPRINT 47\n- cotação em contêiner\n- tirar senha do código (urgente?)\n- aprender o que é JWT", 14, Color("1b5e20"), quadro, Estilo.titulo(700))
	t.rotation.y = -PI / 2
	# Plantas pequenas nas mesas e jiboias penduradas
	for p in [Vector3(-12.0, 0.76, -1.3), Vector3(-5.0, 0.76, 1.3), Vector3(7.0, 0.76, 1.3), Vector3(14.0, 0.76, -1.3)]:
		modelo("res://modelos/plantas/%s.glb" % ["vaso_a", "vaso_b", "vaso_c"][int(abs(p.x)) % 3], p, 0.3, 0.0, {}, false)
	for p in [Vector3(-8.0, 2.35, 4.6), Vector3(8.0, 2.35, 4.6)]:
		caixa(p + Vector3(0, 0.25, 0), Vector3(0.02, 0.4, 0.02), Color("6b7280"), false)
		modelo("res://modelos/plantas/jiboia_media.glb", p - Vector3(0, 0.25, 0), 0.6, 0.0, {}, false)


func _cartaz(pos: Vector3, rot: float, titulo: String, sub: String, cor: Color) -> void:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = rot
	add_child(c)
	caixa(Vector3(0, -0.03, -0.005), Vector3(1.16, 1.06, 0.02), Color("d8d4cc"), false, 0.0, c)
	caixa(Vector3(0, 0, 0), Vector3(1.1, 1.0, 0.02), Color("15171c"), false, 0.0, c)
	caixa(Vector3(0, 0.88, 0.012), Vector3(1.0, 0.06, 0.01), cor, false, 1.0, c)
	texto3d(Vector3(0, 0.6, 0.02), titulo, 24, cor, c, Estilo.titulo(800))
	texto3d(Vector3(0, 0.25, 0.02), sub, 13, Color("c8cdd8"), c, Estilo.texto(600))


const PLAQUINHAS := {
	0: "Contabilidade\n\"o Excel é meu pastor\"", 3: "Financeiro\nnão empresto calculadora", 5: "Jurema · 22 anos de casa",
	6: "Marketing\n#sinergia", 8: "Kauã · Dev\n(Full Stack Overflow)", 11: "Atendimento\nramal 2210",
}


func _mesa(pos: Vector3, semente: int, minha := false) -> void:
	var cores_cadeira := [Color("30364a"), Color("3a3048"), Color("2e3e3b")]
	modelo("desk", pos, Vector3(1.5, 0.76, 0.8), PI, {"wood": Color("e6e1d6"), "metal": Color("6b7280")})
	modelo("chairDesk", pos + Vector3(0, 0, 0.72), 1.1, 0.0, {"carpet": cores_cadeira[semente % 3], "metal": Color("3a3f4a")}, false)
	_monitor(pos + Vector3(0, 0.76, -0.2), 0.0, Estilo.DESTAQUE if minha else [Color("2a5bd7"), Color("1f8a70"), Color("3d3d6b")][semente % 3])
	modelo("computerKeyboard", pos + Vector3(0, 0.76, 0.12), Vector3(0.42, 0.03, 0.15), PI, {}, false)
	modelo("computerMouse", pos + Vector3(0.32, 0.76, 0.14), Vector3(0.06, 0.03, 0.1), PI, {}, false)
	if minha:
		caixa(pos + Vector3(-0.55, 0.76, 0.05), Vector3(0.09, 0.11, 0.09), Color("ff4fa3"), false)   # caneca nova
		return
	if semente % 4 == 1:
		caixa(pos + Vector3(0.24, 1.0, -0.12), Vector3(0.08, 0.08, 0.01), Color("ffe95a"), false)   # post-it
	if semente % 3 == 2:
		caixa(pos + Vector3(-0.5, 0.76, 0.1), Vector3(0.07, 0.14, 0.07), Color("2fd3a0"), false)    # lata de energético
	if semente % 5 == 3:
		modelo("laptop", pos + Vector3(-0.42, 0.76, 0.0), 0.2, PI + 0.3, {}, false)
	if semente % 3 == 0:
		caixa(pos + Vector3(0.55, 0.76, -0.1), Vector3(0.22, 0.05, 0.3), Color("f4f1ea"), false)  # pilha de papel
	if PLAQUINHAS.has(semente):
		var p := texto3d(pos + Vector3(-0.35, 0.8, 0.38), PLAQUINHAS[semente], 9, Color("2a2f3a"), null, Estilo.titulo(700))
		p.outline_size = 0
		caixa(pos + Vector3(-0.35, 0.76, 0.37), Vector3(0.32, 0.09, 0.02), Color("f4f1ea"), false)


func _monitor(pos: Vector3, rot: float, cor_tela: Color) -> void:
	var m := Node3D.new()
	m.position = pos
	m.rotation.y = rot
	add_child(m)
	modelo("computerScreen", Vector3.ZERO, Vector3(0.6, 0.45, 0.16), PI, {}, false, m)
	caixa(Vector3(0, 0.17, 0.035), Vector3(0.54, 0.27, 0.01), cor_tela, false, 1.4, m)
	# "Janelas" desenhadas na tela
	caixa(Vector3(-0.12, 0.27, 0.041), Vector3(0.24, 0.05, 0.002), cor_tela.lightened(0.45), false, 1.8, m)
	caixa(Vector3(0.08, 0.2, 0.041), Vector3(0.3, 0.02, 0.002), cor_tela.darkened(0.4), false, 0.4, m)
	caixa(Vector3(0.05, 0.24, 0.041), Vector3(0.24, 0.02, 0.002), cor_tela.darkened(0.4), false, 0.4, m)


func _montar_npcs() -> void:
	olhar_para(pessoa("Valdecir", Vector3(-14.35, 0, -8.7)), Vector3(-12, 0, -4))
	olhar_para(pessoa("Jurema", Vector3(-4.35, 0, 1.95)), Vector3(-1, 0, 1.0))
	olhar_para(pessoa("Kauã", Vector3(11.05, 0, -0.35)), Vector3(10, 0, -1.2))
	olhar_para(pessoa("Dona Cida", Vector3(-6.5, 0, -9.3)), Vector3(-6.0, 0, -5))
	olhar_para(pessoa("Seu Josias", Vector3(-4.5, 0, 6.65)), Vector3(-3, 0, 11))
	# Colegas de fundo
	if dia != 14:
		olhar_para(pessoa("Leidiane", Vector3(-8.0, 0, -0.35)), Vector3(-9.0, 0, -1.2))
		olhar_para(pessoa("Contadora", Vector3(-11.4, 0, 2.3)), Vector3(-12.5, 0, 1.6))
		olhar_para(pessoa("Analista de Marketing", Vector3(7.6, 0, 0.6)), Vector3(4.0, 0, 1.0))


func _usar_pc() -> void:
	if Catalogo.dia(dia)["tipo"] != "pc":
		if missao and missao.has_method("usar_pc"):
			missao.usar_pc()
		else:
			dialogo("Sistema", "Hoje o trabalho é no andar, não no computador.")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sentou_no_pc.emit()


# ================================================================ HUD e diálogo

func _montar_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = Estilo.tema()
	_hud.add_child(raiz)

	_mira = Label.new()
	_mira.text = "+"
	_mira.add_theme_font_size_override("font_size", 22)
	_mira.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_mira.position -= Vector2(6, 14)
	raiz.add_child(_mira)

	var topo := PanelContainer.new()
	topo.add_theme_stylebox_override("panel", Estilo.caixa(Color(0.06, 0.07, 0.1, 0.82), Estilo.DESTAQUE.darkened(0.3), 6, 12))
	topo.position = Vector2(16, 14)
	raiz.add_child(topo)
	var tv := VBoxContainer.new()
	topo.add_child(tv)
	var cab := Label.new()
	cab.text = "Dia %d de 30  ·  %s" % [dia, Catalogo.dia(dia)["titulo"]]
	cab.add_theme_color_override("font_color", Estilo.DESTAQUE)
	tv.add_child(cab)
	_objetivo = Label.new()
	_objetivo.custom_minimum_size = Vector2(420, 0)
	_objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(_objetivo)

	_extra = Label.new()
	_extra.add_theme_font_override("font", Estilo.mono())
	_extra.add_theme_font_size_override("font_size", 14)
	_extra.add_theme_stylebox_override("normal", Estilo.caixa(Color(0.04, 0.05, 0.08, 0.85), Estilo.CIANO.darkened(0.3), 6, 12))
	_extra.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_extra.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_extra.position += Vector2(-16, 14)
	_extra.visible = false
	raiz.add_child(_extra)

	_dica = Label.new()
	_dica.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dica.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.position.y -= 60
	_dica.add_theme_color_override("font_outline_color", Color.BLACK)
	_dica.add_theme_constant_override("outline_size", 6)
	raiz.add_child(_dica)

	_dlg = PanelContainer.new()
	_dlg.add_theme_stylebox_override("panel", Estilo.caixa(Color(0.06, 0.07, 0.1, 0.94), Estilo.DESTAQUE, 8, 18))
	_dlg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dlg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dlg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dlg.custom_minimum_size = Vector2(820, 0)
	_dlg.position.y -= 24
	_dlg.visible = false
	raiz.add_child(_dlg)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	_dlg.add_child(dv)
	_dlg_nome = Label.new()
	_dlg_nome.add_theme_font_size_override("font_size", 18)
	dv.add_child(_dlg_nome)
	_dlg_texto = Label.new()
	_dlg_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_texto.custom_minimum_size = Vector2(780, 0)
	_dlg_texto.add_theme_font_size_override("font_size", 17)
	dv.add_child(_dlg_texto)
	_dlg_opcoes = HBoxContainer.new()
	_dlg_opcoes.add_theme_constant_override("separation", 10)
	_dlg_opcoes.alignment = BoxContainer.ALIGNMENT_END
	dv.add_child(_dlg_opcoes)


func _mostrar_proxima() -> void:
	if _dlg_fila.is_empty():
		_dlg.visible = false
		jogador.travado = false
		return
	var item: Array = _dlg_fila.pop_front()
	var quem: String = item[0]
	_dlg_nome.text = quem
	_dlg_nome.add_theme_color_override("font_color", Estilo.cor_de(quem) if quem != "Seu Josias" else Color("8fa8e0"))
	_dlg_texto.text = item[1]
	_dlg_callback = item[3]
	for c in _dlg_opcoes.get_children():
		c.queue_free()
	var opcoes: Array = item[2]
	if opcoes.is_empty():
		var b := Button.new()
		b.text = "Continuar  [E]"
		b.pressed.connect(_avancar_dialogo)
		_dlg_opcoes.add_child(b)
	else:
		for i in opcoes.size():
			var b := Button.new()
			b.text = str(opcoes[i])
			b.pressed.connect(_escolher.bind(i))
			_dlg_opcoes.add_child(b)
	_dlg.visible = true
	jogador.travado = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _avancar_dialogo() -> void:
	_escolher(-1)


func _escolher(i: int) -> void:
	var cb := _dlg_callback
	_dlg_callback = Callable()
	_mostrar_proxima()
	if cb.is_valid():
		cb.call(i)
	if not _dlg.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not _encerrado else Input.MOUSE_MODE_VISIBLE
