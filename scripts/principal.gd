extends Node
## Fluxo do jogo: menu, escritório do dia, fase no computador, resultado e desfecho.
## Atalhos de desenvolvimento (argumentos depois de --):
##   --dia=N [--solucao] [--captura=arquivo.png]   abre a fase N direto
##   --escritorio=N [--captura=arquivo.png]       abre o escritório do dia N
##   --final=promovida|estagiaria|demitida        mostra um desfecho

const Catalogo := preload("res://scripts/catalogo.gd")
const Estilo := preload("res://scripts/estilo.gd")
const Escritorio := preload("res://scripts/escritorio.gd")

var _camada: CanvasLayer
var _atual: Node
var _dia_jogando := 0


func _ready() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 5
	add_child(_camada)
	var args := {}
	for a in OS.get_cmdline_user_args():
		var p := a.trim_prefix("--").split("=", true, 1)
		args[p[0]] = p[1] if p.size() > 1 else "1"
	if args.has("dia"):
		var fase := _abrir_fase(int(args["dia"]))
		if args.has("solucao"):
			await get_tree().process_frame
			fase.solucao_teste()
	elif args.has("escritorio"):
		_iniciar_dia(int(args["escritorio"]))
		if args.has("olhar"):
			var v: PackedStringArray = str(args["olhar"]).split(",")
			_atual.jogador.position = Vector3(float(v[0]), 0.1, float(v[1]))
			_atual.jogador.rotation.y = float(v[2]) if v.size() > 2 else 0.0
	elif args.has("final"):
		_mostrar_final(args["final"])
	else:
		_menu()
	if args.has("captura"):
		await get_tree().create_timer(float(args.get("espera", "1.2"))).timeout
		get_viewport().get_texture().get_image().save_png(args["captura"])
		get_tree().quit()


func _limpar() -> void:
	if is_instance_valid(_atual):
		_atual.queue_free()
	_atual = null
	for c in _camada.get_children():
		c.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _tela() -> Control:
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.theme = Estilo.tema()
	var fundo := ColorRect.new()
	fundo.color = Estilo.FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)
	# Brilho rosa suave no alto, como na tela de carregamento
	var brilho := TextureRect.new()
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.3)
	g.fill_to = Vector2(1.0, 0.9)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.31, 0.64, 0.16))
	grad.set_color(1, Color(1.0, 0.31, 0.64, 0.0))
	g.gradient = grad
	brilho.texture = g
	brilho.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brilho.stretch_mode = TextureRect.STRETCH_SCALE
	brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(brilho)
	_camada.add_child(raiz)
	return raiz


func _centro(raiz: Control, largura := 760) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(largura, 0)
	v.add_theme_constant_override("separation", 12)
	cc.add_child(v)
	return v


func _label(pai: Control, texto: String, tam := 16, cor: Color = Estilo.TEXTO, centro := false, fonte: Font = null) -> Label:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	if fonte:
		l.add_theme_font_override("font", fonte)
	if centro:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pai.add_child(l)
	return l


func _botao(pai: Control, texto: String, acao: Callable, primario := false) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_override("font", Estilo.texto(700))
	b.add_theme_font_size_override("font_size", 16)
	if primario:
		b.add_theme_stylebox_override("normal", Estilo.caixa(Estilo.DESTAQUE, Estilo.DESTAQUE, 10, 18))
		b.add_theme_stylebox_override("hover", Estilo.caixa(Color("ff6db3"), Color("ffd0e6"), 10, 18))
		b.add_theme_stylebox_override("pressed", Estilo.caixa(Color("d93d8a"), Estilo.DESTAQUE, 10, 18))
		b.add_theme_color_override("font_color", Color("1a0d14"))
		b.add_theme_color_override("font_hover_color", Color("1a0d14"))
		b.add_theme_color_override("font_pressed_color", Color("1a0d14"))
	else:
		b.add_theme_stylebox_override("normal", Estilo.caixa(Color(0.09, 0.11, 0.16, 0.85), Estilo.BORDA, 10, 18))
		b.add_theme_stylebox_override("hover", Estilo.caixa(Color(0.13, 0.16, 0.23, 0.95), Estilo.DESTAQUE, 10, 18))
	b.pressed.connect(acao)
	pai.add_child(b)
	return b


# ================================================================ menu

func _menu() -> void:
	_limpar()
	# Fundo: o andar da Tabajara com a câmera passeando
	var fundo3d: Node3D = Escritorio.new()
	fundo3d.vitrine = true
	add_child(fundo3d)
	_atual = fundo3d
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.theme = Estilo.tema()
	_camada.add_child(raiz)
	var veu := TextureRect.new()
	var g := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.42, 0.75, 1.0])
	grad.colors = PackedColorArray([Color(0.059, 0.075, 0.106, 0.97), Color(0.059, 0.075, 0.106, 0.9), Color(0.059, 0.075, 0.106, 0.35), Color(0.059, 0.075, 0.106, 0.1)])
	g.gradient = grad
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(1, 0)
	veu.texture = g
	veu.stretch_mode = TextureRect.STRETCH_SCALE
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(veu)

	var coluna := MarginContainer.new()
	coluna.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	coluna.custom_minimum_size = Vector2(600, 0)
	for lado in ["left", "right", "top", "bottom"]:
		coluna.add_theme_constant_override("margin_" + lado, {"left": 72, "right": 24, "top": 40, "bottom": 32}[lado])
	raiz.add_child(coluna)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	coluna.add_child(v)

	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 18)
	v.add_child(topo)
	var logo := TextureRect.new()
	logo.texture = load("res://arte/icone.svg")
	logo.custom_minimum_size = Vector2(118, 118)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.pivot_offset = Vector2(59, 0)
	topo.add_child(logo)
	var tw := create_tween().set_loops()
	tw.tween_property(logo, "rotation", 0.07, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "rotation", -0.07, 1.6).set_trans(Tween.TRANS_SINE)
	var nome := VBoxContainer.new()
	nome.add_theme_constant_override("separation", -22)
	nome.alignment = BoxContainer.ALIGNMENT_CENTER
	topo.add_child(nome)
	_label(nome, "Crachá", 76, Color("f4f1ea"), false, Estilo.titulo(800)).autowrap_mode = TextServer.AUTOWRAP_OFF
	_label(nome, "Provisório", 76, Estilo.DESTAQUE, false, Estilo.titulo(800)).autowrap_mode = TextServer.AUTOWRAP_OFF

	_label(v, "30 dias de estágio em segurança da informação.\nNenhum deles no SOC.", 20, Estilo.TEXTO, false, Estilo.texto(600))
	_label(v, "Tabajara Seguros S.A.  ·  Departamento de Segurança da Informação (1 pessoa e meia)", 13, Estilo.TEXTO_FRACO)
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 12)
	v.add_child(sep)
	var botoes := VBoxContainer.new()
	botoes.custom_minimum_size = Vector2(440, 0)
	botoes.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	botoes.add_theme_constant_override("separation", 10)
	v.add_child(botoes)
	if Jogo.tem_progresso() and not Jogo.terminou():
		_botao(botoes, "Continuar no dia %d  ·  %s" % [Jogo.dia_atual, Catalogo.dia(Jogo.dia_atual)["titulo"]], func(): _iniciar_dia(Jogo.dia_atual), true)
	if Jogo.terminou():
		_botao(botoes, "Ver meu desfecho", func(): _mostrar_final(Jogo.desfecho()), true)
	_botao(botoes, "Novo estágio" if Jogo.tem_progresso() else "Começar o estágio", func():
		Jogo.novo_jogo()
		_iniciar_dia(1), not Jogo.tem_progresso())
	if not Jogo.notas.is_empty():
		var linha := HBoxContainer.new()
		botoes.add_child(linha)
		var ob := OptionButton.new()
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.fit_to_longest_item = false
		ob.clip_text = true
		var dias := Jogo.notas.keys()
		dias.sort()
		for d in dias:
			ob.add_item("Dia %d: %s (nota %d)" % [d, Catalogo.dia(d)["titulo"], Jogo.notas[d]], d)
		linha.add_child(ob)
		_botao(linha, "Refazer", func(): _iniciar_dia(ob.get_selected_id()))
		var prog := _label(v, "Progresso: %d de 30 dias  ·  média %.0f" % [Jogo.notas.size(), Jogo.media() * 30.0 / maxf(Jogo.notas.size(), 1)], 13, Estilo.TEXTO_FRACO)
		prog.autowrap_mode = TextServer.AUTOWRAP_OFF
	var sep2 := Control.new()
	sep2.custom_minimum_size = Vector2(0, 8)
	v.add_child(sep2)
	_label(v, "Clique para olhar com o mouse  ·  WASD anda  ·  Shift corre  ·  E interage  ·  Esc solta o mouse", 13, Estilo.TEXTO_FRACO)
	_label(v, "Tudo aqui é fictício: empresa, pessoas, IPs e chaves. As técnicas são de verdade; use só em ambiente autorizado.", 12, Color("6b7486"))


# ================================================================ dia

func _iniciar_dia(n: int) -> void:
	_limpar()
	_dia_jogando = n
	var e: Node3D = Escritorio.new()
	e.dia = n
	e.sentou_no_pc.connect(_no_pc)
	e.concluida.connect(_resultado)
	add_child(e)
	_atual = e


func _no_pc() -> void:
	var fase := _abrir_fase(_dia_jogando)
	if is_instance_valid(_atual):
		_atual.process_mode = Node.PROCESS_MODE_DISABLED
		_atual.visible = false
		for c in _atual.get_children():
			if c is CanvasLayer:
				c.visible = false
	fase.concluida.connect(_resultado)


func _abrir_fase(n: int) -> Control:
	for c in _camada.get_children():
		c.queue_free()
	var fase: Control = load("res://fases/dia_%02d.gd" % n).new()
	_camada.add_child(fase)
	return fase


func _resultado(r: Dictionary) -> void:
	var n := int(r.get("dia", _dia_jogando))
	Jogo.registrar(n, r)
	_limpar()
	var raiz := _tela()
	var v := _centro(raiz, 780)
	_label(v, "FIM DO DIA %d  ·  %s" % [n, Catalogo.dia(n)["titulo"]], 16, Estilo.TEXTO_FRACO, true)
	var nota := int(r.get("nota", 0))
	var cor := Estilo.OK if nota >= 75 else (Estilo.ALERTA if nota >= 45 else Estilo.ERRO)
	_label(v, "%d" % nota, 96, cor, true, Estilo.titulo(800))
	_label(v, str(r.get("comentario", "")), 17, Estilo.TEXTO, true)
	var cagada := str(r.get("cagada", ""))
	if cagada != "":
		_label(v, "CAGADA GRAVE REGISTRADA NO SEU PRONTUÁRIO:\n" + cagada, 17, Estilo.ERRO, true)
		_label(v, "(%d de 2 permitidas antes do RH te chamar para um café)" % Jogo.cagadas.size(), 13, Estilo.TEXTO_FRACO, true)
	var frase: String
	if nota >= 90:
		frase = ["Jurema: nada mal. Não conta para ninguém que eu disse isso.", "Valdecir: excelente! Vou apresentar como ideia minha.", "Kauã: caramba, até eu entendi."].pick_random()
	elif nota >= 60:
		frase = ["Jurema: passável. O atacante também acha.", "Valdecir: bom, bom. O que é que você fez mesmo?", "Dona Cida: amanhã tem bolo de fubá, filha."].pick_random()
	else:
		frase = ["Jurema: amanhã a gente finge que hoje não aconteceu.", "Valdecir: vou registrar como 'aprendizado'.", "Kauã: relaxa, eu derrubo produção toda semana."].pick_random()
	_label(v, frase, 15, Estilo.CIANO, true)
	_label(v, "Média do estágio até agora: %.0f  ·  Dias concluídos: %d de 30" % [Jogo.media() * 30.0 / maxf(Jogo.notas.size(), 1), Jogo.notas.size()], 13, Estilo.TEXTO_FRACO, true)
	if Jogo.terminou():
		_botao(v, "Sexta-feira, 18h: o RH quer falar com você", func(): _mostrar_final(Jogo.desfecho()))
	else:
		_botao(v, "Ir para casa e voltar amanhã (dia %d)" % Jogo.dia_atual, func(): _iniciar_dia(Jogo.dia_atual))
	_botao(v, "Menu", _menu)


# ================================================================ desfechos

func _mostrar_final(tipo: String) -> void:
	_limpar()
	var raiz := _tela()
	var rol := ScrollContainer.new()
	rol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	raiz.add_child(rol)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rol.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(820, 0)
	v.add_theme_constant_override("separation", 12)
	cc.add_child(v)
	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 30)
	v.add_child(espaco)
	match tipo:
		"promovida":
			_label(v, "PROMOVIDA", 72, Estilo.OK, true, Estilo.titulo(800))
			_label(v, "Analista de Segurança da Informação Júnior", 22, Estilo.TEXTO, true)
			_label(v, "O RH te chamou na sala. Você já estava preparando o discurso de despedida quando o Valdecir entrou com um bolo escrito \"PARABÉNS EFETIVADA\" (com a fonte Comic Sans, porque segundo ele \"transmite confiança\").\n\nO crachá novo não diz mais PROVISÓRIO. Diz ANALISTA. A foto ficou horrível, mas é sua.\n\nA Jurema deixou um post-it na sua mesa: \"Agora o problema é seu. Bem-vinda.\" Foi a coisa mais carinhosa que ela escreveu em 22 anos.\n\nO Kauã pediu para você aprovar um PR. Você recusou. Ele chorou. Vocês são amigos agora.", 17, Estilo.TEXTO)
		"demitida":
			_label(v, "MANDADA EMBORA", 72, Estilo.ERRO, true, Estilo.titulo(800))
			_label(v, "Contrato de estágio encerrado \"por reestruturação\"", 20, Estilo.TEXTO_FRACO, true)
			_label(v, "O Seu Josias recebeu ordem de recolher seu crachá. Ele pegou uma tesoura e cortou o PROVISÓRIO ao meio, devagar, olhando nos seus olhos. Depois te deu um abraço e um pão de queijo.\n\nO Valdecir disse que a decisão \"veio de cima\". A decisão veio dele. Ele estava em cima de uma cadeira trocando uma lâmpada quando decidiu.\n\nNo LinkadoIn você escreveu: \"Encerrando um ciclo de muito aprendizado. Gratidão.\" O post teve 3 curtidas: sua mãe, a Dona Cida e um recrutador oferecendo vaga no SOC.", 17, Estilo.TEXTO)
		_:
			_label(v, "ESTAGIÁRIA POR MAIS 15 ANOS", 56, Estilo.ALERTA, true, Estilo.titulo(800))
			_label(v, "Nem demitida, nem promovida. Renovada. De novo. E de novo.", 20, Estilo.TEXTO_FRACO, true)
			_label(v, "2027: o contrato é renovado \"por mais seis meses, para avaliar melhor\".\n2029: você ganha uma cadeira com rodinhas. Três rodinhas.\n2031: você treina o novo estagiário. Ele é efetivado antes de você.\n2033: a política de senhas faz 24 anos. Você ainda não conseguiu mudar a regra dos dígitos que somam 25.\n2035: você vira a pessoa que sabe onde fica tudo. Inclusive o Raspberry Pi do estagiário de 2026.\n2037: o Valdecir se aposenta. O cargo dele vai para o Kauã.\n2039: a Jurema se aposenta e te deixa a caneca dela. É a maior honraria da empresa.\n2041: o crachá ainda diz PROVISÓRIO. O plástico já está amarelo. Você é a funcionária mais antiga do andar. Oficialmente, você não existe no organograma.", 17, Estilo.TEXTO)
	if not Jogo.notas.is_empty():
		_label(v, "\nBoletim do estágio  ·  média %.0f" % Jogo.media(), 18, Estilo.DESTAQUE)
		var boletim := ""
		for d in range(1, 31):
			if Jogo.notas.has(d):
				boletim += "Dia %02d  %-32s %3d%s\n" % [d, Catalogo.dia(d)["titulo"], Jogo.notas[d], "   CAGADA" if Jogo.cagadas.has(d) else ""]
		var bl := _label(v, boletim, 14, Estilo.TEXTO)
		bl.add_theme_font_override("font", Estilo.mono())
		for d in Jogo.cagadas:
			_label(v, "Dia %d: %s" % [d, Jogo.cagadas[d]], 14, Estilo.ERRO)
	_label(v, "\nRegras do RH: média 75 ou mais e nenhuma cagada grave, promoção. Média abaixo de 45 ou duas cagadas, rua. O resto, renovação eterna.", 13, Estilo.TEXTO_FRACO, true)
	_botao(v, "Começar um novo estágio", func():
		Jogo.novo_jogo()
		_iniciar_dia(1))
	_botao(v, "Menu", _menu)
