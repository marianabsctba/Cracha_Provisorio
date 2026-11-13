extends Node
## Dia 29: auditoria ISO/IEC 27001:2022. Coletar evidências pelo andar, lidar com as
## não conformidades (sem esconder nada) e ligar cada evidência ao controle do Anexo A.

const Estilo := preload("res://scripts/estilo.gd")

var escritorio: Node3D

# nome, posição, cor, controle certo (índice em CONTROLES), descrição
const EVIDENCIAS := [
	["Planilha de inventário de ativos (versão do dia 2)", Vector3(-12.6, 0.77, -7.7), Color("2e7d32"), 0, "Com os 5 aparelhos novos etiquetados. Tem uma mancha de café, mas é evidência."],
	["Pasta de termos de confidencialidade assinados", Vector3(-4.0, 1.12, 7.3), Color("1565c0"), 1, "Todos assinados. O do Kauã tem um desenho de foguete no lugar da rubrica."],
	["Certificados do treinamento de conscientização", Vector3(-5.2, 0.76, 1.4), Color("6a1b9a"), 2, "92% de conclusão. Os 8% restantes são a diretoria."],
	["Livro de registro de visitantes", Vector3(-5.2, 1.12, 7.5), Color("8d6e63"), 3, "Data, nome, documento, quem recebeu e hora de saída. O motoboy da pizza tem 214 entradas."],
	["Relatório do teste de restauração de backup", Vector3(12.6, 0.76, -6.5), Color("00838f"), 4, "Restauração testada no simulado do dia 16, com RPO e RTO medidos."],
	["Cartaz da política de mesa limpa e tela limpa", Vector3(-4.0, 1.3, -6.12), Color("f9a825"), 5, "Colado na copa, do lado do quadro com a senha do Wi-Fi. Ironia não é não conformidade. Ainda."],
	["Relatório de manutenção do nobreak e do ar do datacenter", Vector3(14.4, 0.76, -6.5), Color("455a64"), 6, "Baterias trocadas em março. O ar-condicionado tem nome: Geraldo."],
	["Relatório da revisão de acessos (dia 3)", Vector3(9.6, 0.75, 1.5), Color("ad1457"), 7, "Ex-funcionário desabilitado, transferências corrigidas, exceções registradas."],
]

const CONTROLES := [
	"A.5.9  Inventário de informações e outros ativos associados",
	"A.6.6  Acordos de confidencialidade ou de não divulgação",
	"A.6.3  Conscientização, educação e treinamento em segurança da informação",
	"A.7.2  Entrada física",
	"A.8.13 Backup das informações",
	"A.7.7  Mesa limpa e tela limpa",
	"A.7.11 Utilidades de apoio",
	"A.5.18 Direitos de acesso",
	"A.8.24 Uso de criptografia",
	"A.5.23 Segurança da informação para uso de serviços em nuvem",
]

var _coletadas := {}
var _cafeteira := ""     # "", "registrou", "escondeu"
var _postit := ""        # "", "registrou", "ignorou"
var _seletores := []
var _painel: Control


func _ready() -> void:
	# A datacenter fica aberta hoje (o auditor vai entrar)
	var porta: Node = escritorio.get_node_or_null("PortaDatacenter")
	if porta:
		porta.queue_free()
	escritorio.caixa(Vector3(13.5, 0, -6.5), Vector3(2.8, 0.75, 0.7), Color("6d7480"))
	for i in EVIDENCIAS.size():
		var e: Array = EVIDENCIAS[i]
		var tam := Vector3(0.32, 0.05, 0.24) if i != 5 else Vector3(0.4, 0.5, 0.05)
		var no: Node3D = escritorio.caixa(e[1], tam, e[2])
		escritorio.interativo(no, "Coletar: " + e[0], _coletar.bind(i, no))
	# Não conformidades
	var cafe: Node3D = escritorio.caixa(Vector3(-7.6, 1.45, -10.3), Vector3(0.5, 0.06, 0.45), Color("ff4fa3"), false, 1.5)
	cafe.name = "AvisoCafe"
	var alvo_cafe: Node3D = escritorio.caixa(Vector3(-7.6, 0.9, -10.0), Vector3(0.6, 0.6, 0.3), Color(0, 0, 0, 0.0))
	escritorio.interativo(alvo_cafe, "Examinar a cafeteira inteligente", _examinar_cafeteira)
	var postit: Node3D = escritorio.caixa(Vector3(-9.12, 1.02, -1.15), Vector3(0.1, 0.1, 0.012), Color("ffe95a"), true)
	escritorio.interativo(postit, "Ler o post-it no monitor", _examinar_postit)
	escritorio.objetivo("O auditor chega às 14h. Colete as 8 evidências pelo andar (E), resolva as não conformidades que encontrar e, no seu computador, ligue cada evidência a um controle do Anexo A.")
	_hud()


func _hud() -> void:
	var t := "EVIDÊNCIAS (%d de %d)\n" % [_coletadas.size(), EVIDENCIAS.size()]
	for i in EVIDENCIAS.size():
		t += ("[x] " if _coletadas.has(i) else "[ ] ") + str(EVIDENCIAS[i][0]).left(46) + "\n"
	t += "\nCafeteira: %s\nPost-it: %s" % [_cafeteira if _cafeteira != "" else "não vista", _postit if _postit != "" else "não visto"]
	escritorio.extra(t)


func _coletar(i: int, no: Node3D) -> void:
	_coletadas[i] = true
	escritorio.dialogo("Você", "%s.\n%s" % [EVIDENCIAS[i][0], EVIDENCIAS[i][4]])
	no.queue_free()
	_hud()


func _examinar_cafeteira() -> void:
	escritorio.dialogo("Dona Cida", "Essa é a cafeteira com Wi-Fi que o Valdecir comprou. Ela tem uma tal de porta 23 aberta. O moço do TI disse que é Telnet. Eu achei que era o número do café.")
	escritorio.dialogo("Valdecir", "Esconde ela no armário até o auditor ir embora. Ninguém precisa saber.", [
		"Registrar como não conformidade, isolar na rede de IoT e abrir plano de ação com prazo",
		"Esconder no armário, como o Valdecir mandou",
	], func(e: int):
		if e == 0:
			_cafeteira = "registrou"
			escritorio.dialogo("Jurema", "Isso. Auditor não reprova quem acha o próprio problema. Reprova quem esconde.")
		else:
			_cafeteira = "escondeu"
			escritorio.dialogo("Sistema", "A cafeteira foi para o armário. Ainda ligada na tomada. Ainda no Wi-Fi.")
		_hud())


func _examinar_postit() -> void:
	escritorio.dialogo("Você", "Post-it colado no monitor do Financeiro: \"VPN: fin.tabajara / Primavera@2026\".", [
		"Registrar a não conformidade de mesa limpa, avisar o dono e pedir troca da senha",
		"Deixar quieto, o auditor não vai olhar ali",
	], func(e: int):
		_postit = "registrou" if e == 0 else "ignorou"
		_hud())


func usar_pc() -> void:
	if _painel:
		return
	_painel = PanelContainer.new()
	_painel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_painel.custom_minimum_size = Vector2(980, 560)
	_painel.position -= Vector2(490, 280)
	_painel.add_theme_stylebox_override("panel", Estilo.caixa(Estilo.FUNDO, Estilo.DESTAQUE, 8, 18))
	escritorio.abrir_painel(_painel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_painel.add_child(v)
	var tit := Label.new()
	tit.text = "Matriz de evidências  ·  ISO/IEC 27001:2022, Anexo A"
	tit.add_theme_color_override("font_color", Estilo.DESTAQUE)
	tit.add_theme_font_size_override("font_size", 20)
	v.add_child(tit)
	_seletores.clear()
	for i in EVIDENCIAS.size():
		var h := HBoxContainer.new()
		v.add_child(h)
		var l := Label.new()
		l.text = str(EVIDENCIAS[i][0]) if _coletadas.has(i) else "(não coletada) " + str(EVIDENCIAS[i][0])
		l.custom_minimum_size = Vector2(430, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Estilo.TEXTO if _coletadas.has(i) else Estilo.TEXTO_FRACO)
		h.add_child(l)
		var ob := OptionButton.new()
		ob.add_item("(escolha o controle)")
		for c in CONTROLES:
			ob.add_item(c)
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.disabled = not _coletadas.has(i)
		ob.clip_text = true
		h.add_child(ob)
		_seletores.append(ob)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(botoes)
	var voltar := Button.new()
	voltar.text = "Voltar ao andar"
	voltar.pressed.connect(func():
		escritorio.fechar_painel(_painel)
		_painel = null)
	botoes.add_child(voltar)
	var entregar := Button.new()
	entregar.text = "Entregar ao auditor"
	entregar.pressed.connect(func():
		var r := _avaliar()
		escritorio.fechar_painel(_painel)
		escritorio.finalizar(r))
	botoes.add_child(entregar)


func _avaliar() -> Dictionary:
	var certos := 0
	for i in EVIDENCIAS.size():
		if _coletadas.has(i) and i < _seletores.size() and _seletores[i].selected - 1 == EVIDENCIAS[i][3]:
			certos += 1
	var nota := int(round(70.0 * certos / EVIDENCIAS.size()))
	var partes := ["%d de %d evidências ligadas ao controle certo." % [certos, EVIDENCIAS.size()]]
	if _cafeteira == "registrou":
		nota += 15
		partes.append("A cafeteira com Telnet virou não conformidade com plano de ação: auditor gosta de ver que o processo pega os próprios furos.")
	if _postit == "registrou":
		nota += 15
		partes.append("O post-it com senha foi tratado (A.7.7 na prática).")
	elif _postit == "ignorou":
		partes.append("O post-it com a senha da VPN ficou lá. O auditor achou. Sempre acham.")
	var cagada := ""
	if _cafeteira == "escondeu":
		nota = mini(nota, 30)
		cagada = "Escondeu a cafeteira com Telnet no armário. O auditor abriu o armário para pegar um copo. Esconder evidência numa auditoria de certificação é o fim da certificação."
	return {"nota": clampi(nota, 0, 100), "comentario": " ".join(partes), "cagada": cagada}
