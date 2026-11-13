extends Node3D
## O andar da Tabajara Seguros, montado por código, com HUD, diálogos e NPCs.
## Dias "pc": a jogadora vai até a mesa e aperte E no computador (sinal sentou_no_pc).
## Dias "3d": uma missão (res://missoes/missao_NN.gd) roda aqui e chama finalizar().

signal sentou_no_pc
signal concluida(resultado: Dictionary)

const Estilo := preload("res://scripts/estilo.gd")
const Catalogo := preload("res://scripts/catalogo.gd")
const Jogador := preload("res://scripts/jogador.gd")

const MESA_PC := Vector3(3.6, 0, 1.6)

var dia := 1
var jogador: CharacterBody3D
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
	_montar_npcs()
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


func _process(_delta: float) -> void:
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
	_objetivo.text = texto


func extra(texto: String) -> void:
	_extra.text = texto
	_extra.visible = texto != ""


## Mostra uma fala. `opcoes` é uma lista de textos; `ao_escolher(indice)` é chamado
## com o índice escolhido (ou -1 quando não há opções e a fala acaba).
func dialogo(quem: String, texto: String, opcoes: Array = [], ao_escolher := Callable()) -> void:
	_dlg_fila.append([quem, texto, opcoes, ao_escolher])
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


func material(cor: Color, emissao := 0.0, transparente := false) -> StandardMaterial3D:
	var chave := "%s|%s|%s" % [cor.to_html(), emissao, transparente]
	if _materiais.has(chave):
		return _materiais[chave]
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.8
	if emissao > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = emissao
	if transparente:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materiais[chave] = m
	return m


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


func texto3d(pos: Vector3, texto: String, tamanho := 48, cor: Color = Color.WHITE, pai: Node = null) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font_size = tamanho
	l.modulate = cor
	l.outline_size = 8
	l.double_sided = false
	l.position = pos
	(pai if pai else self).add_child(l)
	return l


## Pessoa simples (corpo, cabeça, nome flutuante), sólida e interativa.
func pessoa(nome: String, pos: Vector3, cor: Color, olhando := 0.0) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.position = pos
	corpo.rotation.y = olhando
	var forma := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.32
	cs.height = 1.75
	forma.shape = cs
	forma.position.y = 0.875
	corpo.add_child(forma)
	var tronco := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.1
	tronco.mesh = cap
	tronco.position.y = 0.95
	tronco.material_override = material(cor)
	corpo.add_child(tronco)
	var pernas := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.36, 0.5, 0.22)
	pernas.mesh = pm
	pernas.position.y = 0.25
	pernas.material_override = material(Color("2b3040"))
	corpo.add_child(pernas)
	var cabeca := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.17
	esf.height = 0.34
	cabeca.mesh = esf
	cabeca.position.y = 1.66
	cabeca.material_override = material(Color("d9a77f"))
	corpo.add_child(cabeca)
	var olhos := MeshInstance3D.new()
	var om := BoxMesh.new()
	om.size = Vector3(0.2, 0.04, 0.02)
	olhos.mesh = om
	olhos.position = Vector3(0, 1.69, -0.16)
	olhos.material_override = material(Color("15151a"))
	corpo.add_child(olhos)
	var nome3d := texto3d(Vector3(0, 2.05, 0), nome, 36, cor.lightened(0.3), corpo)
	nome3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(corpo)
	npcs[nome] = corpo
	if FALAS.has(nome):
		interativo(corpo, "Falar com " + nome, func(): dialogo(nome, FALAS[nome].pick_random()))
	return corpo


# ================================================================ construção

func _montar_ambiente() -> void:
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a1f2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9d3e6")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35
	amb.environment = env
	add_child(amb)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-60, 30, 0)
	sol.light_energy = 0.45
	sol.light_color = Color("fff3e0")
	add_child(sol)
	for p in [Vector3(-10, 2.8, 2), Vector3(0, 2.8, 2), Vector3(10, 2.8, 2), Vector3(-12, 2.8, -7),
			Vector3(-5, 2.8, -8), Vector3(3, 2.8, -7.5), Vector3(12.5, 2.8, -7), Vector3(0, 2.8, 7.5)]:
		var luz := OmniLight3D.new()
		luz.position = p
		luz.omni_range = 9.0
		luz.light_energy = 0.9
		luz.light_color = Color("fff6ea")
		add_child(luz)


func _parede(x1: float, z1: float, x2: float, z2: float, cor := Color("d8d4cc"), alt := 3.0) -> void:
	var meio := Vector3((x1 + x2) / 2.0, 0, (z1 + z2) / 2.0)
	var tam := Vector3(maxf(absf(x2 - x1), 0.15), alt, maxf(absf(z2 - z1), 0.15))
	caixa(meio, tam, cor)


func _montar_andar() -> void:
	var piso_cor := Color("3b4456")
	caixa(Vector3(0, -0.1, 0), Vector3(34, 0.1, 22), piso_cor)
	caixa(Vector3(0, 3.0, 0), Vector3(34, 0.1, 22), Color("e8e6e1"), false)
	# Painéis de luz no teto
	for x in [-10, -4, 2, 8, 13]:
		for z in [-7, -1, 4]:
			caixa(Vector3(x, 2.94, z), Vector3(1.4, 0.04, 0.6), Color("fff8ec"), false, 1.2)
	# Paredes externas
	_parede(-17, -11, 17, -11)
	_parede(-17, 11, 17, 11)
	_parede(-17, -11, -17, 11)
	_parede(17, -11, 17, 11)
	# Recepção (sul): divisória em z=5 com passagem central e porta corta-fogo no leste
	_parede(-17, 5, -1.3, 5, Color("c9c4ba"))
	_parede(1.3, 5, 14.2, 5, Color("c9c4ba"))
	_parede(15.8, 5, 17, 5, Color("c9c4ba"))
	caixa(Vector3(-1.2, 0, 5), Vector3(0.2, 1.0, 0.6), Color("707a8c"))   # catraca esquerda
	caixa(Vector3(1.2, 0, 5), Vector3(0.2, 1.0, 0.6), Color("707a8c"))    # catraca direita
	texto3d(Vector3(0, 2.6, 4.9), "TABAJARA SEGUROS S.A.", 64, Estilo.DESTAQUE).rotation.y = PI
	texto3d(Vector3(0, 2.25, 4.9), "Segurança é prioridade (desde 2009, rev. nunca)", 28, Color("444"), null).rotation.y = PI
	texto3d(Vector3(0, 2.6, 5.1), "TABAJARA SEGUROS S.A.", 64, Estilo.DESTAQUE)
	texto3d(Vector3(15.0, 2.3, 5.1), "SAÍDA DE EMERGÊNCIA", 26, Color("2fbf5a"))
	# Balcão da recepção
	caixa(Vector3(-4.5, 0, 7.4), Vector3(3.2, 1.1, 0.8), Color("6b4f3a"))
	caixa(Vector3(-4.5, 1.1, 7.4), Vector3(3.3, 0.05, 0.9), Color("e9e2d5"), false)
	texto3d(Vector3(-4.5, 1.5, 6.95), "RECEPÇÃO", 30, Color("333"), null).rotation.y = 0
	# Sofá de espera
	caixa(Vector3(5.5, 0, 9.8), Vector3(3.0, 0.45, 0.8), Color("8a3b5c"))
	caixa(Vector3(5.5, 0.45, 10.15), Vector3(3.0, 0.5, 0.15), Color("8a3b5c"))
	_planta(Vector3(8, 0, 9.8))
	_planta(Vector3(-8, 0, 9.8))

	# Sala do Valdecir (vidro) no noroeste
	var vidro := Color(0.6, 0.8, 0.95, 0.25)
	_parede(-17, -4, -11.5, -4, vidro)
	_parede(-9.8, -4, -9, -4, vidro)
	_parede(-9, -11, -9, -4, vidro)
	caixa(Vector3(-13, 0, -8), Vector3(2.4, 0.76, 1.1), Color("5a3d2b"))
	_monitor(Vector3(-13, 0.76, -8.2), 0.0, Color("2a5bd7"))
	texto3d(Vector3(-13, 2.5, -4.1), "GERÊNCIA DE SEGURANÇA", 30, Color("223"))
	texto3d(Vector3(-13, 2.2, -4.1), "(e de Facilities, e do Refeitório)", 20, Color("445"))

	# Copa
	_parede(-9, -6, -2.4, -6, Color("e3d9c6"))
	_parede(-2.4, -11, -2.4, -7.6, Color("e3d9c6"))
	caixa(Vector3(-5.5, 0, -10.3), Vector3(5, 0.9, 0.7), Color("b8b2a7"))
	caixa(Vector3(-7.6, 0.9, -10.3), Vector3(0.45, 0.55, 0.4), Color("222"), true)  # cafeteira
	caixa(Vector3(-3.2, 0, -10.2), Vector3(0.8, 1.9, 0.7), Color("dfe3e8"))         # geladeira
	caixa(Vector3(-5.5, 0, -8.3), Vector3(1.6, 0.74, 1.0), Color("c7a271"))
	texto3d(Vector3(-5.5, 2.4, -6.1), "COPA", 36, Color("553"))
	var quadro := caixa(Vector3(-8.9, 1.0, -8.5), Vector3(0.05, 1.0, 1.6), Color("f4f4f2"), false)
	var wifi := texto3d(Vector3(0.04, 0.6, 0), "Wi-Fi: Tabajara-Corp\nsenha: Tabajara@2009\nNÃO CONTAR PRA NINGUÉM", 16, Color("1b3b8a"), quadro)
	wifi.rotation.y = PI / 2

	# Sala de reunião
	_parede(-0.5, -5, 3.0, -5, vidro)
	_parede(4.6, -5, 8.0, -5, vidro)
	_parede(8.0, -11, 8.0, -5, Color("d8d4cc"))
	_parede(-0.5, -11, -0.5, -5, Color("d8d4cc"))
	caixa(Vector3(3.8, 0, -8), Vector3(4.0, 0.75, 1.6), Color("4b3a2c"))
	caixa(Vector3(3.8, 1.0, -10.85), Vector3(2.4, 1.3, 0.08), Color("101010"))          # TV
	texto3d(Vector3(3.8, 2.6, -5.1), "SALA DE REUNIÃO 'SINERGIA'", 28, Color("223"))

	# Datacenter (nordeste)
	_parede(9.0, -4, 11.4, -4, Color("8d96a5"))
	_parede(13.2, -4, 17, -4, Color("8d96a5"))
	_parede(9.0, -11, 9.0, -4, Color("8d96a5"))
	for i in range(4):
		var rack := caixa(Vector3(11 + i * 1.3, 0, -9.6), Vector3(0.8, 2.1, 1.0), Color("1c1f26"))
		for j in range(6):
			caixa(Vector3(-0.25 + (j % 3) * 0.25, 0.4 + j * 0.27, -0.51), Vector3(0.05, 0.05, 0.02),
				[Color("3cff7a"), Color("ff4fa3"), Color("38d9e8")][j % 3], false, 3.0, rack)
	texto3d(Vector3(12.3, 2.55, -3.9), "DATACENTER  ·  ACESSO RESTRITO", 28, Color("b00020"))
	var porta_dc := caixa(Vector3(12.3, 0, -4), Vector3(1.8, 2.3, 0.12), Color("5a6170"))
	porta_dc.name = "PortaDatacenter"
	caixa(Vector3(13.4, 1.2, -3.8), Vector3(0.12, 0.18, 0.05), Color("ff3030"), false, 2.0)   # leitor de crachá

	# Mesas do open space
	var cores_cadeira := [Color("30364a"), Color("3a3048"), Color("2e3e3b")]
	var k := 0
	for x in [-12.5, -9.0, -5.5, 6.5, 10.0, 13.5]:
		for z in [-1.0, 1.6]:
			_mesa(Vector3(x, 0, z), cores_cadeira[k % 3], k)
			k += 1
	# A mesa da estagiária
	_mesa(MESA_PC, Color("3a3048"), 99, true)
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
	texto3d(MESA_PC + Vector3(0, 1.75, -0.3), "ESTAGIÁRIA\n(PROVISÓRIO)", 22, Estilo.DESTAQUE).billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Impressora
	caixa(Vector3(15.6, 0, 2.5), Vector3(0.9, 1.0, 0.7), Color("e5e5e0"))
	caixa(Vector3(15.6, 1.0, 2.5), Vector3(0.7, 0.12, 0.5), Color("bdbdb5"))
	texto3d(Vector3(15.6, 1.5, 2.5), "Impressora\n'Godzilla'", 18, Color("333")).billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_planta(Vector3(-16, 0, 4.2))
	_planta(Vector3(16, 0, -3.2))


func _mesa(pos: Vector3, cor_cadeira: Color, semente: int, minha := false) -> void:
	caixa(pos, Vector3(1.5, 0.74, 0.8), Color("cfc7b8"))
	caixa(pos + Vector3(0, 0, 0.75), Vector3(0.5, 0.48, 0.5), cor_cadeira)
	caixa(pos + Vector3(0, 0.48, 0.98), Vector3(0.5, 0.6, 0.08), cor_cadeira, false)
	_monitor(pos + Vector3(0, 0.74, -0.2), 0.0, Estilo.DESTAQUE if minha else [Color("2a5bd7"), Color("1f8a70"), Color("3d3d6b")][semente % 3])
	if not minha and semente % 4 == 1:
		caixa(pos + Vector3(0.24, 1.0, -0.17), Vector3(0.08, 0.08, 0.01), Color("ffe95a"), false)   # post-it
	if not minha and semente % 3 == 2:
		caixa(pos + Vector3(-0.5, 0.74, 0.1), Vector3(0.08, 0.14, 0.08), Color("2fd3a0"), false)    # lata de energético


func _monitor(pos: Vector3, rot: float, cor_tela: Color) -> void:
	var m := Node3D.new()
	m.position = pos
	m.rotation.y = rot
	add_child(m)
	caixa(Vector3(0, 0, 0), Vector3(0.2, 0.05, 0.15), Color("222"), false, 0.0, m)
	caixa(Vector3(0, 0.05, 0), Vector3(0.05, 0.2, 0.05), Color("222"), false, 0.0, m)
	caixa(Vector3(0, 0.22, 0), Vector3(0.62, 0.38, 0.04), Color("111"), false, 0.0, m)
	caixa(Vector3(0, 0.24, 0.022), Vector3(0.56, 0.32, 0.01), cor_tela, false, 1.6, m)


func _planta(pos: Vector3) -> void:
	caixa(pos, Vector3(0.45, 0.5, 0.45), Color("8a5a3c"))
	var folhas := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.45
	esf.height = 0.9
	folhas.mesh = esf
	folhas.position = pos + Vector3(0, 0.9, 0)
	folhas.material_override = material(Color("3f8f4a"))
	add_child(folhas)


func _montar_npcs() -> void:
	pessoa("Valdecir", Vector3(-13, 0, -9.1), Estilo.cor_de("Valdecir"), 0)
	pessoa("Jurema", Vector3(-5.5, 0, 2.35), Estilo.cor_de("Jurema"), 0)
	pessoa("Kauã", Vector3(10.0, 0, -0.25), Estilo.cor_de("Kauã"), 0)
	pessoa("Dona Cida", Vector3(-6.5, 0, -9.3), Estilo.cor_de("Dona Cida"), PI)
	pessoa("Seu Josias", Vector3(-4.5, 0, 8.4), Color("4a5f8a"), PI)


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
