extends "res://fases/fase.gd"
## Dia 28: o pendrive "SALÁRIOS 2027" é um teclado disfarçado (HID). O inject.bin guarda pares
## (código de tecla HID, modificador). A jogadora decodifica com a tabela e responde ao incidente.

const SHIFT := 0x02
const GUI := 0x08
const URL := "http://203.0.113.66/vpn"

# Roteiro digitado pelo dispositivo (formato de alto nível; vira bytes em _codificar)
const ROTEIRO := [
	["DELAY", 250], ["DELAY", 250], ["DELAY", 250],
	["COMBO", GUI, 0x15],                      # Win + r
	["DELAY", 200],
	["STRING", "notepad"], ["ENTER"],
	["DELAY", 250], ["DELAY", 250],
	["STRING", "Salarios 2027: confidencial. Aguarde..."], ["ENTER"],
	["DELAY", 250],
	["COMBO", GUI, 0x15],
	["DELAY", 200],
	["STRING", "msedge " + URL], ["ENTER"],
]

const DISTRATOR_PLUGAR := 5
const ACOES := [
	["Tirar a máquina do financeiro da rede e preservar o pendrive como evidência", true],
	["Trocar a senha da VPN que a colega digitou na página falsa e revisar os acessos dela", true],
	["Bloquear 203.0.113.66 no proxy e no firewall e procurar outros acessos a ele", true],
	["Política para bloquear dispositivos HID novos e campanha sobre pendrive achado", true],
	["Formatar o pendrive e devolver para os achados e perdidos", false],
	["Plugar o pendrive na máquina do Valdecir para confirmar o que ele faz", false],
]

var _bytes := PackedByteArray()
var _hex: TextEdit
var _decod: TextEdit
var _atalho: OptionButton
var _url: LineEdit
var _tipo: OptionButton
var _acoes: Array = []


func _init() -> void:
	dia = 28
	titulo = "Pendrive do estacionamento"
	chamado = ("O pendrive \"SALÁRIOS 2027\" não é um pendrive: o computador o reconheceu como [b]teclado[/b]. O conteúdo dele "
		+ "(inject.bin) é uma sequência de pares de bytes: [b]código de tecla HID[/b] + [b]modificador[/b]. O par 00 NN é uma pausa de NN ms. "
		+ "O decodificador da equipe só entende letras minúsculas; o resto você lê pela tabela. Descubra o que ele digitou e responda.")


static func _tecla(c: String) -> Array:
	var o := c.unicode_at(0)
	if c >= "a" and c <= "z":
		return [0x04 + o - 97, 0]
	if c >= "A" and c <= "Z":
		return [0x04 + o - 65, SHIFT]
	if c >= "1" and c <= "9":
		return [0x1E + o - 49, 0]
	match c:
		"0": return [0x27, 0]
		" ": return [0x2C, 0]
		".": return [0x37, 0]
		"/": return [0x38, 0]
		":": return [0x33, SHIFT]
		"-": return [0x2D, 0]
	return [0x2C, 0]


static func codificar() -> PackedByteArray:
	var b := PackedByteArray()
	for passo in ROTEIRO:
		match passo[0]:
			"DELAY":
				b.append(0x00); b.append(passo[1])
			"COMBO":
				b.append(passo[2]); b.append(passo[1])
			"ENTER":
				b.append(0x28); b.append(0x00)
			"STRING":
				for c in str(passo[1]):
					var t := _tecla(c)
					b.append(t[0]); b.append(t[1])
	return b


func montar() -> void:
	_bytes = codificar()
	var l := linha()
	var esq := painel(l)
	rotulo("inject.bin  (%d bytes)" % _bytes.size(), 14, Estilo.CIANO, esq)
	var t := ""
	for i in range(0, _bytes.size(), 12):
		var parte := _bytes.slice(i, mini(i + 12, _bytes.size()))
		var h := ""
		for j in range(0, parte.size(), 2):
			h += "%02X %02X  " % [parte[j], parte[j + 1] if j + 1 < parte.size() else 0]
		t += "%04X  %s\n" % [i, h]
	_hex = bloco_mono(t, 260, esq)
	var dir := painel(l)
	rotulo("Tabela HID (teclado US)", 14, Estilo.CIANO, dir)
	bloco_mono("Modificador: 00 nenhum  02 Shift  08 Win (GUI)\n"
		+ "04-1D  a até z (04=a, 05=b ... 15=r ... 1D=z)\n"
		+ "1E-26  1 até 9      27  0\n"
		+ "28  Enter     2C  Espaço    2D  -\n"
		+ "33  ;  (com Shift: :)\n"
		+ "37  .     38  /\n"
		+ "00 NN  pausa de NN ms (NN em hexa)\n"
		+ "Letra com 02 = maiúscula", 260, dir)
	var bd := linha()
	botao("Rodar o decodificador da equipe", _decodificar, bd)
	_decod = bloco_mono("(clique para decodificar; o que ele não conhece aparece como [XX/MM])", 110)
	_decod.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	var r := painel()
	rotulo("Respostas", 14, Estilo.CIANO, r)
	var g := GridContainer.new()
	g.columns = 2
	r.add_child(g)
	rotulo("Qual combinação abre a janela Executar?", 14, Estilo.TEXTO, g)
	_atalho = opcoes(["(escolha)", "Ctrl + Alt + Del", "Win + R", "Alt + F4", "Shift + R"], g)
	rotulo("Endereço aberto no navegador:", 14, Estilo.TEXTO, g)
	_url = campo("como foi digitado", g)
	rotulo("O que é esse dispositivo?", 14, Estilo.TEXTO, g)
	_tipo = opcoes(["(escolha)", "Pendrive com vírus em arquivo .exe",
		"Teclado (HID) que digita sozinho: o antivírus não vê arquivo nenhum",
		"Placa de rede USB", "Só um pendrive com um bloco de notas"], g)
	_tipo.fit_to_longest_item = false
	_tipo.clip_text = true
	_tipo.custom_minimum_size = Vector2(380, 0)
	rotulo("Resposta ao incidente (marque o que fazer):", 14, Estilo.TEXTO, r)
	for a in ACOES:
		_acoes.append(caixa_marcar(a[0], r))
	chat("Dona Cida", "Eu não pluguei, viu? Eu só achei. Quem plugou foi a Leidiane do financeiro.")
	chat("RH", "A Leidiane disse que abriu um bloco de notas sozinho, depois uma página da VPN pedindo senha. Ela digitou. Duas vezes, porque achou que errou.")
	chat("Jurema", "Pendrive que vira teclado. Ele digita mais rápido que o Kauã e com menos erro de digitação.")


func _decodificar() -> void:
	var t := ""
	for i in range(0, _bytes.size(), 2):
		var k := _bytes[i]
		var m := _bytes[i + 1]
		if k == 0x00:
			t += "<%dms>" % m
		elif m == 0 and k >= 0x04 and k <= 0x1D:
			t += char(97 + k - 0x04)
		else:
			t += "[%02X/%02X]" % [k, m]
	_decod.text = t
	aviso("O decodificador parou de entender em %d pares. A tabela ao lado resolve." % t.count("["))


func avaliar() -> Dictionary:
	var nota := 0
	var partes := []
	if _atalho.selected == 2:
		nota += 15
		partes.append("15 08 é r com Win: Win + R, a janela Executar.")
	else:
		partes.append("O par 15 08 é r com modificador Win: Win + R.")
	if _url.text.strip_edges().to_lower() == URL:
		nota += 30
		partes.append("Endereço certo: a página falsa de VPN em 203.0.113.66.")
	else:
		partes.append("O endereço era %s (dígitos 1E a 27, ponto 37, barra 38, dois-pontos é 33 com Shift)." % URL)
	if _tipo.selected == 2:
		nota += 15
		partes.append("É um HID: para o sistema é um teclado de confiança, então nada de arquivo para o antivírus examinar.")
	var certas := 0
	var erradas := 0
	for i in ACOES.size():
		if _acoes[i].button_pressed:
			if ACOES[i][1]:
				certas += 1
			else:
				erradas += 1
	nota += maxi(0, certas * 10 - erradas * 10)
	partes.append("Resposta ao incidente: %d de 4 ações certas%s." % [certas, ", e %d ação ruim" % erradas if erradas else ""])
	var cagada := ""
	if _acoes[DISTRATOR_PLUGAR].button_pressed:
		nota = mini(nota, 35)
		cagada = "Mandou plugar o pendrive malicioso na máquina do gerente \"para confirmar\". Confirmou."
	return {"nota": clampi(nota, 0, 100), "comentario": " ".join(partes), "cagada": cagada}


func solucao_teste() -> void:
	_decodificar()
	_atalho.selected = 2
	_url.text = URL
	_tipo.selected = 2
	for i in 4:
		_acoes[i].button_pressed = true
