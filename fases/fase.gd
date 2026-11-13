extends Control
## Base de toda fase jogada na tela do computador (TabajaraOS).
##
## Como escrever uma fase (fases/dia_NN.gd):
##   extends "res://fases/fase.gd"
##   func _init() -> void:
##       dia = N
##       titulo = "Título curto"
##       chamado = "Texto do chamado em BBCode: o que fazer, regras, dicas."
##   func montar() -> void:            # cria a interface dentro de `corpo`
##   func avaliar() -> Dictionary:     # {"nota": 0..100, "comentario": "...", "cagada": "" }
##   func solucao_teste() -> void:     # preenche a resposta certa (usado pelos testes)
##
## O botão "Entregar" chama avaliar() e encerra. A fase também pode encerrar
## sozinha chamando finalizar(nota, comentario, cagada).

signal concluida(resultado: Dictionary)

const Estilo := preload("res://scripts/estilo.gd")

var dia := 0
var titulo := ""
var chamado := ""
var texto_entregar := "Entregar"

var corpo: VBoxContainer
var _chat_lista: VBoxContainer
var _chat_scroll: ScrollContainer
var _aviso: Label
var _botao_entregar: Button
var _relogio: Label
var _minutos := 9 * 60 + 2
var _acumulado := 0.0
var encerrada := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = Estilo.tema()
	_montar_moldura()
	montar()


func _process(delta: float) -> void:
	# O relógio do escritório anda 1 minuto a cada 2 segundos.
	_acumulado += delta
	if _acumulado >= 2.0:
		_acumulado -= 2.0
		_minutos += 1
		if _relogio:
			_relogio.text = "%02d:%02d" % [int(_minutos / 60) % 24, _minutos % 60]


# ---------------------------------------------------------------- para sobrescrever

func montar() -> void:
	pass


func avaliar() -> Dictionary:
	return {"nota": 0, "comentario": "Fase sem avaliação."}


func solucao_teste() -> void:
	pass


# ---------------------------------------------------------------- moldura

func _montar_moldura() -> void:
	var fundo := ColorRect.new()
	fundo.color = Estilo.FUNDO
	fundo.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fundo)

	var raiz := VBoxContainer.new()
	raiz.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	raiz.add_theme_constant_override("separation", 0)
	add_child(raiz)

	# Barra de cima
	var barra := PanelContainer.new()
	barra.add_theme_stylebox_override("panel", Estilo.caixa(Color("0a0d13"), Color("0a0d13"), 0, 10))
	raiz.add_child(barra)
	var hb := HBoxContainer.new()
	barra.add_child(hb)
	var icone := TextureRect.new()
	icone.texture = load("res://arte/icone.svg")
	icone.custom_minimum_size = Vector2(24, 24)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(icone)
	var logo := Label.new()
	logo.text = "TabajaraOS 3.11 for Workgroups"
	logo.add_theme_color_override("font_color", Estilo.DESTAQUE)
	logo.add_theme_font_override("font", Estilo.mono())
	hb.add_child(logo)
	var tit := Label.new()
	tit.text = "   Dia %d de 30  ·  %s" % [dia, titulo]
	tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tit.add_theme_font_override("font", Estilo.titulo(700))
	tit.add_theme_font_size_override("font_size", 17)
	hb.add_child(tit)
	var cracha := Label.new()
	cracha.text = "CRACHÁ: PROVISÓRIO   "
	cracha.add_theme_color_override("font_color", Estilo.ALERTA)
	cracha.add_theme_font_size_override("font_size", 12)
	hb.add_child(cracha)
	_relogio = Label.new()
	_relogio.text = "09:02"
	_relogio.add_theme_font_override("font", Estilo.mono())
	hb.add_child(_relogio)

	# Meio: área de trabalho + chat
	var meio := HBoxContainer.new()
	meio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meio.add_theme_constant_override("separation", 0)
	raiz.add_child(meio)

	var margem := MarginContainer.new()
	margem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 14)
	meio.add_child(margem)
	var esquerda := VBoxContainer.new()
	esquerda.add_theme_constant_override("separation", 10)
	margem.add_child(esquerda)

	if chamado != "":
		var painel := PanelContainer.new()
		painel.add_theme_stylebox_override("panel", Estilo.caixa(Estilo.PAINEL, Estilo.DESTAQUE.darkened(0.4), 6, 12))
		esquerda.add_child(painel)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.text = "[color=#ff4fa3][b]CHAMADO #%d[/b][/color]  %s" % [4000 + dia * 37, Jogo.txt(chamado)]
		painel.add_child(rt)

	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	esquerda.add_child(rolagem)
	corpo = VBoxContainer.new()
	corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 8)
	rolagem.add_child(corpo)

	# Chat lateral (TabajaraChat)
	var lateral := PanelContainer.new()
	lateral.custom_minimum_size = Vector2(320, 0)
	lateral.add_theme_stylebox_override("panel", Estilo.caixa(Color("121722"), Estilo.BORDA, 0, 10))
	meio.add_child(lateral)
	var lv := VBoxContainer.new()
	lateral.add_child(lv)
	var ct := Label.new()
	ct.text = "TabajaraChat  ·  #seguranca"
	ct.add_theme_color_override("font_color", Estilo.TEXTO_FRACO)
	ct.add_theme_font_size_override("font_size", 13)
	lv.add_child(ct)
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(_chat_scroll)
	_chat_lista = VBoxContainer.new()
	_chat_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_lista.add_theme_constant_override("separation", 8)
	_chat_scroll.add_child(_chat_lista)

	# Barra de baixo
	var rodape := PanelContainer.new()
	rodape.add_theme_stylebox_override("panel", Estilo.caixa(Color("0a0d13"), Color("0a0d13"), 0, 10))
	raiz.add_child(rodape)
	var hr := HBoxContainer.new()
	rodape.add_child(hr)
	_aviso = Label.new()
	_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso.add_theme_color_override("font_color", Estilo.TEXTO_FRACO)
	hr.add_child(_aviso)
	_botao_entregar = Button.new()
	_botao_entregar.text = texto_entregar
	_botao_entregar.custom_minimum_size = Vector2(160, 36)
	_botao_entregar.pressed.connect(_entregar)
	hr.add_child(_botao_entregar)


func _entregar() -> void:
	if encerrada:
		return
	var r := avaliar()
	finalizar(int(r.get("nota", 0)), str(r.get("comentario", "")), str(r.get("cagada", "")))


# ---------------------------------------------------------------- utilidades para as fases

## Encerra a fase. `cagada` não vazia conta como cagada grave para o final.
func finalizar(nota: int, comentario: String, cagada := "") -> void:
	if encerrada:
		return
	encerrada = true
	concluida.emit({"dia": dia, "nota": clampi(nota, 0, 100), "comentario": Jogo.txt(comentario), "cagada": Jogo.txt(cagada)})


## Esconde ou mostra o botão de entregar (para fases que encerram sozinhas).
func mostrar_entregar(sim: bool) -> void:
	_botao_entregar.visible = sim


func aviso(texto: String, cor: Color = Estilo.TEXTO_FRACO) -> void:
	_aviso.text = Jogo.txt(texto)
	_aviso.add_theme_color_override("font_color", cor)


## Mensagem no TabajaraChat. Personagens: Valdecir, Jurema, Kauã, CEO, RH, Sistema, Você...
func chat(quem: String, msg: String) -> void:
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 1)
	var nome := Label.new()
	nome.text = quem
	nome.add_theme_color_override("font_color", Estilo.cor_de(quem))
	nome.add_theme_font_size_override("font_size", 13)
	caixa.add_child(nome)
	var t := Label.new()
	t.text = Jogo.txt(msg)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(280, 0)
	t.add_theme_font_size_override("font_size", 14)
	caixa.add_child(t)
	_chat_lista.add_child(caixa)
	await get_tree().process_frame
	if is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


func rotulo(texto: String, tamanho := 15, cor: Color = Estilo.TEXTO, pai: Control = null) -> Label:
	var l := Label.new()
	l.text = Jogo.txt(texto)
	# Dentro de linhas e grades, quebra automática deixa o rótulo com largura zero
	# (vira uma coluna de letras); ali o texto fica numa linha só.
	if pai is HBoxContainer or pai is GridContainer:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	(pai if pai else corpo).add_child(l)
	return l


func texto_rico(bbcode: String, pai: Control = null) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.text = Jogo.txt(bbcode)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(pai if pai else corpo).add_child(rt)
	return rt


## Texto monoespaçado só leitura (logs, código, hex...).
func bloco_mono(texto: String, altura := 0, pai: Control = null) -> TextEdit:
	var te := editor(texto, altura, pai)
	te.editable = false
	return te


func editor(texto := "", altura := 220, pai: Control = null) -> TextEdit:
	var te := TextEdit.new()
	te.text = texto
	te.custom_minimum_size = Vector2(0, altura if altura > 0 else 160)
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	te.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	(pai if pai else corpo).add_child(te)
	return te


func campo(dica := "", pai: Control = null) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = dica
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(pai if pai else corpo).add_child(le)
	return le


func botao(texto: String, acao: Callable, pai: Control = null) -> Button:
	var b := Button.new()
	b.text = Jogo.txt(texto)
	b.pressed.connect(acao)
	(pai if pai else corpo).add_child(b)
	return b


func linha(pai: Control = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	(pai if pai else corpo).add_child(h)
	return h


func painel(pai: Control = null, cor: Color = Estilo.PAINEL) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Estilo.caixa(cor, Estilo.BORDA, 6, 12))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(pai if pai else corpo).add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v


func opcoes(itens: Array, pai: Control = null) -> OptionButton:
	var ob := OptionButton.new()
	for i in itens:
		ob.add_item(Jogo.txt(str(i)))
	(pai if pai else corpo).add_child(ob)
	return ob


func caixa_marcar(texto: String, pai: Control = null) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = Jogo.txt(texto)
	(pai if pai else corpo).add_child(cb)
	return cb


## Converte acertos em nota inteira 0..100.
static func proporcao(acertos: float, total: float) -> int:
	if total <= 0:
		return 0
	return clampi(int(round(100.0 * acertos / total)), 0, 100)
