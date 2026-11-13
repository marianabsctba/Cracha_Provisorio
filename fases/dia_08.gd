extends "res://fases/fase.gd"
## Dia 8: a "criptografia" do Kauã. Receita de decodificação encadeada, estilo CyberChef.

const OPERACOES := ["From Base64", "To Base64", "From Hex", "To Hex", "XOR (chave)", "ROT13", "Reverse", "URL Decode"]
const CHAVE_XOR := "Bolacha"

var _cpfs: Array = []
var _amostras: Array = []
var _escolha: OptionButton
var _entrada: TextEdit
var _receita: ItemList
var _passos: Array = []
var _chave: LineEdit
var _saida: TextEdit
var _saida_hex: TextEdit
var _respostas: Array = []
var _pergunta: OptionButton


func _init() -> void:
	dia = 8
	titulo = "Criptografia de base64"
	chamado = ("O sistema de sinistros guarda o CPF \"criptografado\". Monte uma [b]receita[/b] de operações para "
		+ "recuperar o CPF de cada uma das 3 amostras e digite os três CPFs. Depois diga o que o Kauã devia ter usado. "
		+ "As operações são aplicadas de cima para baixo, como numa receita de bolo (de fubá, se a Dona Cida fizer).")


static func cpf_valido(base9: String) -> String:
	var d := []
	for c in base9:
		d.append(int(c))
	for _k in 2:
		var soma := 0
		var peso := d.size() + 1
		for x in d:
			soma += x * peso
			peso -= 1
		var resto := (soma * 10) % 11
		d.append(0 if resto == 10 else resto)
	var s := ""
	for x in d:
		s += str(x)
	return "%s.%s.%s-%s" % [s.substr(0, 3), s.substr(3, 3), s.substr(6, 3), s.substr(9, 2)]


static func xor_bytes(dados: PackedByteArray, chave: String) -> PackedByteArray:
	var k := chave.to_utf8_buffer()
	var r := dados.duplicate()
	if k.is_empty():
		return r
	for i in r.size():
		r[i] = r[i] ^ k[i % k.size()]
	return r


func montar() -> void:
	_cpfs = [cpf_valido("318445207"), cpf_valido("907113564"), cpf_valido("246800135")]
	var a1 := Marshalls.utf8_to_base64(_cpfs[0])
	var a2 := Marshalls.utf8_to_base64(_cpfs[1]).to_utf8_buffer().hex_encode()
	var a3 := Marshalls.raw_to_base64(xor_bytes(_cpfs[2].to_utf8_buffer(), CHAVE_XOR))
	_amostras = [a1, a2, a3]

	var topo := linha()
	rotulo("Amostra:", 15, Estilo.TEXTO_FRACO, topo)
	_escolha = opcoes(["Sinistro 1047 (segurado: Odair)", "Sinistro 1048 (segurada: Leidiane)", "Sinistro 1049 (segurado: Kléber)"], topo)
	_escolha.item_selected.connect(func(_i): _processar())
	_entrada = bloco_mono("", 54)

	var meio := linha()
	var esq := painel(meio)
	rotulo("Operações", 14, Estilo.CIANO, esq)
	var grade := GridContainer.new()
	grade.columns = 2
	esq.add_child(grade)
	for op in OPERACOES:
		botao("+ " + op, _adicionar.bind(op), grade)
	_chave = campo("chave do XOR", esq)
	_chave.text_changed.connect(func(_t): _processar())
	var dir := painel(meio)
	rotulo("Receita (de cima para baixo)", 14, Estilo.CIANO, dir)
	_receita = ItemList.new()
	_receita.custom_minimum_size = Vector2(0, 120)
	dir.add_child(_receita)
	var lb := linha(dir)
	botao("Subir", _mover.bind(-1), lb)
	botao("Descer", _mover.bind(1), lb)
	botao("Remover", _remover, lb)
	botao("Limpar", func():
		_passos.clear()
		_processar(), lb)

	rotulo("Saída (texto)", 14, Estilo.TEXTO_FRACO)
	_saida = bloco_mono("", 50)
	rotulo("Saída (hex)", 14, Estilo.TEXTO_FRACO)
	_saida_hex = bloco_mono("", 50)

	var resp := painel()
	rotulo("CPFs recuperados", 14, Estilo.CIANO, resp)
	var lr := linha(resp)
	for i in 3:
		_respostas.append(campo("CPF do sinistro %d" % (1047 + i), lr))
	rotulo("O que o Kauã devia ter usado para guardar o CPF?", 14, Estilo.CIANO, resp)
	_pergunta = opcoes(["(escolha)",
		"Base64 duas vezes, para ficar duas vezes mais seguro",
		"Cifra autenticada (AES-256-GCM) com a chave num KMS/cofre, fora do banco e do código",
		"MD5 do CPF, porque ninguém consegue reverter hash",
		"XOR com uma chave maior, tipo o nome completo do cachorro"], resp)
	_processar()
	chat("Kauã", "Base64 é criptografia sim. Olha só, ninguém consegue ler: " + str(_amostras[0]))
	chat("Jurema", "Kauã, base64 é codificação. É reversível sem chave nenhuma. É tipo escrever em letra de médico.")
	chat("Kauã", "A terceira amostra eu fiz mais forte: XOR com o nome do meu cachorro, o Bolacha. Ninguém vai adivinhar.")
	chat("Jurema", "Ele acabou de falar a chave no canal da empresa. Anota aí.")


func _adicionar(op: String) -> void:
	_passos.append(op)
	_processar()


func _mover(delta: int) -> void:
	var sel := _receita.get_selected_items()
	if sel.is_empty():
		return
	var i: int = sel[0]
	var j := i + delta
	if j < 0 or j >= _passos.size():
		return
	var tmp = _passos[i]
	_passos[i] = _passos[j]
	_passos[j] = tmp
	_processar()
	_receita.select(j)


func _remover() -> void:
	var sel := _receita.get_selected_items()
	if sel.is_empty():
		return
	_passos.remove_at(sel[0])
	_processar()


## Aplica uma operação. Devolve [bytes, erro].
func aplicar(op: String, dados: PackedByteArray, chave: String) -> Array:
	var texto := dados.get_string_from_utf8()
	match op:
		"From Base64":
			var limpo := texto.strip_edges()
			if limpo.is_empty() or limpo.length() % 4 != 0 or RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$").search(limpo) == null:
				return [dados, "From Base64: entrada não é base64 válido"]
			return [Marshalls.base64_to_raw(limpo), ""]
		"To Base64":
			return [Marshalls.raw_to_base64(dados).to_utf8_buffer(), ""]
		"From Hex":
			var h := texto.strip_edges().replace(" ", "")
			if h.is_empty() or h.length() % 2 != 0 or RegEx.create_from_string("^[0-9a-fA-F]+$").search(h) == null:
				return [dados, "From Hex: entrada não é hexadecimal válido"]
			return [h.hex_decode(), ""]
		"To Hex":
			return [dados.hex_encode().to_utf8_buffer(), ""]
		"XOR (chave)":
			if chave.is_empty():
				return [dados, "XOR: falta a chave"]
			return [xor_bytes(dados, chave), ""]
		"ROT13":
			var r := PackedByteArray()
			for b in dados:
				if b >= 65 and b <= 90:
					b = (b - 65 + 13) % 26 + 65
				elif b >= 97 and b <= 122:
					b = (b - 97 + 13) % 26 + 97
				r.append(b)
			return [r, ""]
		"Reverse":
			var r := dados.duplicate()
			r.reverse()
			return [r, ""]
		"URL Decode":
			return [texto.uri_decode().to_utf8_buffer(), ""]
	return [dados, ""]


func _processar() -> void:
	var i := _escolha.selected
	_entrada.text = _amostras[i]
	var dados: PackedByteArray = str(_amostras[i]).to_utf8_buffer()
	var erro := ""
	for op in _passos:
		var r := aplicar(op, dados, _chave.text)
		dados = r[0]
		if r[1] != "":
			erro = r[1]
			break
	_receita.clear()
	for p in _passos:
		_receita.add_item(p + ("  [" + _chave.text + "]" if p == "XOR (chave)" else ""))
	var legivel := ""
	for b in dados:
		legivel += char(b) if b >= 32 and b < 127 else "."
	_saida.text = legivel
	_saida_hex.text = dados.hex_encode()
	if erro != "":
		aviso(erro, Estilo.ERRO)
	elif RegEx.create_from_string("^\\d{3}\\.\\d{3}\\.\\d{3}-\\d{2}$").search(legivel):
		aviso("Isso parece um CPF. A \"criptografia\" caiu.", Estilo.OK)
	else:
		aviso("Saída com %d bytes." % dados.size())


static func so_digitos(s: String) -> String:
	var r := ""
	for c in s:
		if c >= "0" and c <= "9":
			r += c
	return r


func avaliar() -> Dictionary:
	var certos := 0
	for i in 3:
		if so_digitos(_respostas[i].text) == so_digitos(_cpfs[i]) and so_digitos(_cpfs[i]) != "":
			certos += 1
	var nota := certos * 25
	var partes := ["Você recuperou %d de 3 CPFs." % certos]
	if _pergunta.selected == 2:
		nota += 25
		partes.append("E acertou: dado que precisa voltar ao original pede cifra autenticada com chave gerenciada fora do sistema. Base64 é codificação, XOR com chave curta cai em segundos.")
	else:
		partes.append("A resposta era AES-256-GCM com chave num KMS. MD5 de CPF cai por força bruta (só 10^9 combinações) e base64 não tem chave nenhuma.")
	return {"nota": nota, "comentario": " ".join(partes)}


func solucao_teste() -> void:
	_respostas[0].text = _cpfs[0]
	_respostas[1].text = _cpfs[1]
	_respostas[2].text = _cpfs[2]
	_pergunta.selected = 2
	_escolha.selected = 2
	_chave.text = CHAVE_XOR
	_passos = ["From Base64", "XOR (chave)"]
	_processar()
