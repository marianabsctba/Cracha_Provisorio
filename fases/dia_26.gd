extends "res://fases/fase.gd"
## Dia 26: duelo de argumentos com o CEO pelo MFA.

const CARTA_TENTACAO := "Tudo bem, desligo o MFA do senhor só durante o golfe."

## Cada turno: argumento do CEO e cartas [texto, efeito na teimosia, efeito na credibilidade, reação].
const TURNOS := [
	{"ceo": "O celular fica no carro durante o golfe. Não vou voltar ao estacionamento por causa de um código.",
	 "cartas": [
		["Uma chave de segurança FIDO2 cabe no chaveiro do carrinho de golfe. Encosta e pronto, sem celular.", -25, 0, "Chaveiro... isso eu levo pra todo canto."],
		["O senhor vai ser preso se não usar MFA.", 0, -20, "Preso? Por quem? Pelo Valdecir?"],
		["É a política e pronto.", 5, -10, "A política que eu assino?"],
	]},
	{"ceo": "Ninguém vai querer hackear logo eu.",
	 "cartas": [
		["CEO é alvo preferido: whaling e fraude do CEO (BEC). Um e-mail seu pedindo transferência vale mais que mil senhas de estagiário.", -20, 5, "Hum. O financeiro paga mesmo qualquer coisa que eu peço."],
		["Hacker só ataca empresa grande dos Estados Unidos.", 0, -20, "Então estamos seguros, ótimo."],
		["Com MFA o senhor fica 100% imune a qualquer ataque.", -5, -15, "100%? Até eu sei que isso não existe."],
	]},
	{"ceo": "A gente tem antivírus. Pago caro nele.",
	 "cartas": [
		["Antivírus protege o notebook. Sua conta de e-mail está na nuvem: quem tem a senha entra de qualquer lugar do mundo sem passar pelo seu antivírus.", -20, 5, "Então o antivírus não vê quem entra no meu e-mail?"],
		["Antivírus e firewall são a mesma coisa, então já está tudo coberto.", 5, -15, "O Valdecir fala isso também. Desconfio."],
		["O antivírus é inútil, pode cancelar.", 0, -10, "Ótimo, economizo e continuo sem MFA."],
	]},
	{"ceo": "Li que o MFA do concorrente foi burlado com fadiga de push. Então não serve pra nada.",
	 "cartas": [
		["Fadiga de push se resolve com number matching, ou melhor ainda, com FIDO2: não tem notificação para aprovar sem querer e é resistente a phishing.", -20, 5, "Então o problema era o tipo de MFA, não o MFA."],
		["Isso é notícia falsa, MFA nunca foi burlado.", 0, -20, "Saiu no jornal econômico, menina."],
		["Por isso vamos mandar 3 notificações em vez de uma.", 10, -10, "Mais notificações? No meio da tacada?"],
	]},
	{"ceo": "Meu sobrinho é de TI e disse que senha forte basta.",
	 "cartas": [
		["Senha forte não adianta quando vaza: credential stuffing testa senhas de vazamentos em massa. Sua senha pode estar numa lista e o senhor nem sabe.", -20, 5, "Aquele site de vinho que eu usava vazou ano passado..."],
		["Seu sobrinho não entende nada.", 0, -15, "Ele é formado! Num curso de 6 meses, mas é."],
		["Senha forte é proibida pela LGPD.", 5, -20, "Isso nem faz sentido."],
	]},
	{"ceo": "A TI do meu clube de golfe nem usa isso.",
	 "cartas": [
		["O clube não guarda dados de 300 mil segurados nem responde à SUSEP e à ANPD. A gente guarda. E o MFA vira só um toque na chave.", -15, 5, "Tá bom, tá bom. Me arruma essa chave."],
		["O clube vai ser hackeado amanhã, eu garanto.", 0, -15, "Garante como?"],
		["Se o clube não usa, então tudo bem.", 10, -10, "Viu? Até você concorda."],
	]},
]

var _teimosia := 100
var _credibilidade := 100
var _turno := 0
var _cedeu := false
var _barra_t: ProgressBar
var _barra_c: ProgressBar
var _fala_ceo: RichTextLabel
var _cartas: VBoxContainer
var _historico: VBoxContainer
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	dia = 26
	titulo = "O CEO e o MFA"
	chamado = ("Duelo na sala do CEO. A cada turno ele solta um argumento e você joga uma carta de resposta. "
		+ "Fatos corretos reduzem a [b]teimosia[/b] dele; exagero, mentira técnica ou \"é a política\" custam "
		+ "[b]credibilidade[/b]. Objetivo: ele aceitar MFA resistente a phishing. Não desligue o MFA de ninguém.")


func montar() -> void:
	_rng.seed = 26
	var barras := painel()
	var l1 := linha(barras)
	rotulo("Teimosia do CEO", 14, Estilo.cor_de("CEO"), l1).custom_minimum_size = Vector2(170, 0)
	_barra_t = _barra(l1, Estilo.ERRO)
	var l2 := linha(barras)
	rotulo("Sua credibilidade", 14, Estilo.DESTAQUE, l2).custom_minimum_size = Vector2(170, 0)
	_barra_c = _barra(l2, Estilo.OK)
	var pc := painel(null, Color("231820"))
	_fala_ceo = texto_rico("", pc)
	_cartas = VBoxContainer.new()
	_cartas.add_theme_constant_override("separation", 6)
	corpo.add_child(_cartas)
	_historico = painel(null, Color("141a24"))
	rotulo("Ata da reunião", 13, Estilo.TEXTO_FRACO, _historico)
	_atualizar_barras()
	_mostrar_turno()
	chat("Valdecir", "Estou no dentista. Literalmente. Com anestesia. Não me liguem.")
	chat("Jurema", "Fato, não susto. CEO sente cheiro de FUD de longe. E não vai ceder no golfe, hein.")


func _barra(pai: Control, cor: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = 100
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 20)
	var f := StyleBoxFlat.new()
	f.bg_color = cor
	b.add_theme_stylebox_override("fill", f)
	pai.add_child(b)
	return b


func _atualizar_barras() -> void:
	_barra_t.value = _teimosia
	_barra_c.value = _credibilidade


func _mostrar_turno() -> void:
	for c in _cartas.get_children():
		c.queue_free()
	if _turno >= TURNOS.size() or _teimosia <= 0:
		_encerrar_vitoria()
		return
	if _credibilidade <= 0:
		_fala_ceo.text = "[color=#ff5d5d][b]CEO:[/b][/color] Chega. Volta quando tiver argumento. Pode ir."
		aviso("Sem credibilidade. A reunião acabou. Entregue para ver a nota.", Estilo.ERRO)
		return
	var t: Dictionary = TURNOS[_turno]
	_fala_ceo.text = "[color=#ff5d5d][b]CEO (turno %d de %d):[/b][/color] %s" % [_turno + 1, TURNOS.size(), t["ceo"]]
	var ordem := range(t["cartas"].size())
	# Embaralha de forma determinística para a carta boa não ser sempre a primeira.
	for i in range(ordem.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = ordem[i]
		ordem[i] = ordem[j]
		ordem[j] = tmp
	for i in ordem:
		var carta: Array = t["cartas"][i]
		var b := botao(carta[0], _jogar.bind(i), _cartas)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var tent := botao(CARTA_TENTACAO, _ceder, _cartas)
	tent.add_theme_color_override("font_color", Estilo.ALERTA)
	tent.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _jogar(i: int) -> void:
	if encerrada or _cedeu or _teimosia <= 0 or _credibilidade <= 0 or _turno >= TURNOS.size():
		return
	var carta: Array = TURNOS[_turno]["cartas"][i]
	_teimosia = clampi(_teimosia + carta[1], 0, 100)
	_credibilidade = clampi(_credibilidade + carta[2], 0, 100)
	var boa: bool = carta[1] <= -15
	rotulo("Você: " + carta[0], 13, Estilo.OK if boa else Estilo.ERRO, _historico)
	rotulo("CEO: " + carta[3], 13, Estilo.TEXTO_FRACO, _historico)
	chat("CEO", carta[3])
	if boa:
		if _turno % 2 == 0:
			chat("Jurema", "Boa. Fato verificável, sem drama.")
	else:
		chat("Jurema", "Isso foi FUD ou mentira técnica. Ele percebeu.")
	_turno += 1
	_atualizar_barras()
	_mostrar_turno()


func _ceder() -> void:
	if encerrada:
		return
	_cedeu = true
	for c in _cartas.get_children():
		c.queue_free()
	_fala_ceo.text = "[color=#ff5d5d][b]CEO:[/b][/color] Ótimo! Sabia que você era sensata."
	chat("Valdecir", "(do dentista) VOCÊ FEZ O QUÊ?")
	chat("Jurema", "A conta mais visada da empresa sem MFA justo no fim de semana. Parabéns.")
	var r := avaliar()
	finalizar(r["nota"], r["comentario"], r["cagada"])


func _encerrar_vitoria() -> void:
	if _teimosia <= 0:
		_fala_ceo.text = "[color=#ff5d5d][b]CEO:[/b][/color] Tá. Me arruma essa chave FIDO2. Uma reserva também, vou perder a primeira no lago do buraco 7."
		chat("Sistema", "Chamado aberto: 2 chaves FIDO2 para o CEO (titular + reserva no cofre).")
		chat("Jurema", "Convenceu o CEO sem mentir. Isso é mais raro que eclipse.")
	else:
		_fala_ceo.text = "[color=#ff5d5d][b]CEO:[/b][/color] Vou pensar. Marca outra reunião com a minha secretária."
	aviso("Reunião encerrada. Clique em Entregar.", Estilo.CIANO)


func avaliar() -> Dictionary:
	if _cedeu:
		return {"nota": 0, "comentario": "Você desligou o MFA da conta mais visada da empresa. CEO é alvo de whaling e BEC; a resposta era chave FIDO2 no chaveiro.",
			"cagada": "Desligou o MFA do CEO para ele jogar golfe. O primeiro login suspeito veio de outro continente antes do buraco 3."}
	var convencido := 100 - _teimosia
	var nota := int(round(convencido * 0.7 + _credibilidade * 0.3))
	if _turno == 0:
		nota = 0
	var com := "Teimosia restante %d, credibilidade %d." % [_teimosia, _credibilidade]
	if _teimosia <= 0:
		com += " O CEO aceitou FIDO2: resistente a phishing, sem celular e imune à fadiga de push."
	else:
		com += " Argumentos que funcionam: CEO é alvo de BEC/whaling, senha vaza (credential stuffing), antivírus não protege conta na nuvem, number matching ou FIDO2 contra fadiga de push."
	if _credibilidade < 100:
		com += " FUD e mentira técnica custam credibilidade: segurança se vende com fato."
	return {"nota": nota, "comentario": com, "cagada": ""}


func solucao_teste() -> void:
	while _turno < TURNOS.size() and _teimosia > 0 and not encerrada:
		_jogar(0)
