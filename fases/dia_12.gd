extends "res://fases/fase.gd"
## Dia 12: regex de DLP. Casar CPF e não casar telefone, CNPJ, protocolo e CPF com dígito errado.
## A regex roda de verdade (PCRE2) sobre o corpus; precisão, revocação e F1 calculados ao vivo.

const Dia8 := preload("res://fases/dia_08.gd")

var _corpus: Array = []      # [texto, [cpfs esperados (só dígitos)]]
var _regex: LineEdit
var _validar: CheckBox
var _resultado: RichTextLabel
var _placar: Label
var _f1 := 0.0


func _init() -> void:
	dia = 12
	titulo = "Regex de DLP"
	chamado = ("Escreva uma expressão regular que pegue os [b]CPFs[/b] das mensagens abaixo (com ou sem pontuação) e [b]não[/b] pegue "
		+ "telefone, CNPJ, protocolo nem número de apólice. Telefone celular também tem 11 dígitos, então pense em "
		+ "fronteiras e no [b]dígito verificador[/b]. A nota é o F1 (equilíbrio entre precisão e revocação).")


static func digitos(s: String) -> String:
	var r := ""
	for c in s:
		if c >= "0" and c <= "9":
			r += c
	return r


## Algoritmo real do dígito verificador do CPF.
static func cpf_ok(s: String) -> bool:
	var d := digitos(s)
	if d.length() != 11:
		return false
	var iguais := true
	for c in d:
		if c != d[0]:
			iguais = false
	if iguais:
		return false
	for k in [9, 10]:
		var soma := 0
		for i in k:
			soma += int(d[i]) * (k + 1 - i)
		var r := (soma * 10) % 11
		if r == 10:
			r = 0
		if r != int(d[k]):
			return false
	return true


func montar() -> void:
	var c1 := Dia8.cpf_valido("318445207")
	var c2 := Dia8.cpf_valido("907113564")
	var c3 := Dia8.cpf_valido("246800135")
	var c4 := Dia8.cpf_valido("650212978")
	var c5 := Dia8.cpf_valido("111222333")
	var c6 := Dia8.cpf_valido("803571496")
	var c4_errado := c4.substr(0, c4.length() - 1) + str((int(c4[c4.length() - 1]) + 3) % 10)
	_corpus = [
		["Segue o CPF do segurado para o sinistro: %s" % c1, [c1]],
		["CPF sem pontuação: %s, favor conferir" % digitos(c2), [c2]],
		["Me liga no (41) 99876-5432 que eu explico", []],
		["Celular do CEO: 41998765432 (não bloquear de novo)", []],
		["CNPJ da oficina credenciada: 12.345.678/0001-95", []],
		["Protocolo de atendimento 2026111300457 aberto", []],
		["Apólice nº 0048213-77 renovada", []],
		["Dependentes: %s e %s" % [c3, c5], [c3, c5]],
		["CPF digitado errado pelo corretor: %s" % c4_errado, []],
		["Placa ABC1D23, chassi 9BWZZZ377VT004251", []],
		["cpf=%s&acao=consultar" % digitos(c4), [c4]],
		["Telefone fixo 4133224455, ramal 2210", []],
		["Data do sinistro 13/11/2026 às 14:32", []],
		["Valor: R$ 12.345.678,90 (sim, era um Fusca de ouro)", []],
		["O Kauã testou com 000.000.000-00 e 111.111.111-11", []],
		["Titular %s, beneficiário em análise" % c6, [c6]],
		["Código de barras 23793.38128 60082.477218 35000.063305 1 90150000012345", []],
	]
	var p := painel()
	rotulo("Regex (PCRE2, como no motor do DLP)", 14, Estilo.CIANO, p)
	_regex = campo("ex.: \\d{3}...", p)
	_regex.text_changed.connect(func(_t): _rodar())
	_validar = caixa_marcar("Validar o dígito verificador dos casamentos (algoritmo do CPF)", p)
	_validar.toggled.connect(func(_b): _rodar())
	_placar = rotulo("", 15, Estilo.TEXTO, p)
	_resultado = texto_rico("")
	_rodar()
	chat("Jurema", "O DLP atual usa \\d{11}. Bloqueou o telefone do CEO, o protocolo do call center e metade dos boletos.")
	chat("CEO", "Por que meu WhatsApp corporativo diz 'MENSAGEM BLOQUEADA: DADO PESSOAL'? Eu só mandei meu celular para o meu personal.")
	chat("Jurema", "Dica: (?<!\\d) e (?!\\d) impedem casar pedaço de número maior. E regex nenhuma sabe se o dígito verificador bate, isso é com o validador.")


## Devolve [vp, fp, fn, marcações por linha]
func medir(padrao: String, validar: bool) -> Array:
	var vp := 0
	var fp := 0
	var fn := 0
	var linhas := []
	var rx := RegEx.new()
	if padrao.is_empty() or rx.compile(padrao) != OK:
		for item in _corpus:
			fn += item[1].size()
			linhas.append([item[0], [], item[1].map(func(x): return digitos(x))])
		return [0, 0, fn, linhas, padrao.is_empty() == false]
	for item in _corpus:
		var esperados: Array = item[1].map(func(x): return digitos(x))
		var achados := []
		for m in rx.search_all(item[0]):
			var s := m.get_string()
			if s.is_empty():
				continue
			if validar and not cpf_ok(s):
				continue
			achados.append(s)
		var restantes := esperados.duplicate()
		for a in achados:
			var d := digitos(a)
			if d in restantes:
				vp += 1
				restantes.erase(d)
			else:
				fp += 1
		fn += restantes.size()
		linhas.append([item[0], achados, restantes])
	return [vp, fp, fn, linhas, false]


func _rodar() -> void:
	var r := medir(_regex.text, _validar.button_pressed)
	var vp: int = r[0]
	var fp: int = r[1]
	var fn: int = r[2]
	var precisao := float(vp) / maxf(vp + fp, 1)
	var revocacao := float(vp) / maxf(vp + fn, 1)
	_f1 = 0.0 if vp == 0 else 2.0 * precisao * revocacao / (precisao + revocacao)
	if r[4]:
		_placar.text = "Regex inválida (erro de sintaxe)."
		_placar.add_theme_color_override("font_color", Estilo.ERRO)
	else:
		_placar.text = "VP %d   FP %d   FN %d   ·   precisão %.0f%%   revocação %.0f%%   F1 %.2f" % [vp, fp, fn, precisao * 100, revocacao * 100, _f1]
		_placar.add_theme_color_override("font_color", Estilo.OK if _f1 >= 0.99 else (Estilo.ALERTA if _f1 > 0.5 else Estilo.TEXTO))
	var bb := ""
	for l in r[3]:
		var texto: String = l[0]
		var marca := "[color=#8b95a8]     [/color]"
		var achados: Array = l[1]
		var faltou: Array = l[2]
		var falsos := 0
		for a in achados:
			if not cpf_ok(a) or not digitos(a) in _esperados_da_linha(texto):
				falsos += 1
		if falsos > 0:
			marca = "[color=#ff5d5d]FP   [/color]"
		elif not faltou.is_empty():
			marca = "[color=#ffc94d]FN   [/color]"
		elif not achados.is_empty():
			marca = "[color=#5ee38a]VP   [/color]"
		for a in achados:
			texto = texto.replace(a, "[bgcolor=#5a2a48]" + a + "[/bgcolor]")
		bb += "[code]" + marca + "[/code]" + texto + "\n"
	_resultado.text = bb


func _esperados_da_linha(texto: String) -> Array:
	for item in _corpus:
		if item[0] == texto:
			return item[1].map(func(x): return digitos(x))
	return []


func avaliar() -> Dictionary:
	var r := medir(_regex.text, _validar.button_pressed)
	var vp: int = r[0]
	var fp: int = r[1]
	var fn: int = r[2]
	var precisao := float(vp) / maxf(vp + fp, 1)
	var revocacao := float(vp) / maxf(vp + fn, 1)
	var f1 := 0.0 if vp == 0 else 2.0 * precisao * revocacao / (precisao + revocacao)
	var nota := int(round(f1 * 100))
	var partes := ["F1 %.2f (precisão %.0f%%, revocação %.0f%%)." % [f1, precisao * 100, revocacao * 100]]
	if fp > 0:
		partes.append("Ainda tem %d falso(s) positivo(s): é assim que o telefone do CEO vai preso." % fp)
	if fn > 0:
		partes.append("Deixou passar %d CPF(s): é assim que a planilha vaza." % fn)
	if not _validar.button_pressed:
		partes.append("Sem o dígito verificador, um celular de 11 dígitos é indistinguível de CPF. Regex acha candidato, validação decide.")
	else:
		partes.append("Regex para achar candidato, validador para confirmar: é assim que DLP decente funciona.")
	return {"nota": nota, "comentario": " ".join(partes)}


func solucao_teste() -> void:
	_regex.text = "(?<![\\d.])\\d{3}\\.?\\d{3}\\.?\\d{3}-?\\d{2}(?![\\d.\\-/])"
	_validar.button_pressed = true
	_rodar()
