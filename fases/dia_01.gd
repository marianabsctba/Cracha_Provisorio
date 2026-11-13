extends "res://fases/fase.gd"
## Dia 1: a política de senhas absurda do Valdecir, e o que o NIST diz de verdade.

const PLANETAS := ["mercurio", "venus", "terra", "marte", "jupiter", "saturno", "urano", "netuno"]
const PROIBIDAS := ["tabajara", "senha", "123", "2026", "estagio", "qwerty"]
const VAZADAS := ["Password1!", "Senha@12345678", "Tabajara@2026", "Marte@Venus2024!", "Brasil@1234567"]

var _senha: LineEdit
var _regras: VBoxContainer
var _pergunta: VBoxContainer
var _resposta: OptionButton
var _politica_ok := false
var _tentativas := 0


func _init() -> void:
	dia = 1
	titulo = "Política de senhas"
	chamado = ("Crie sua senha de rede. Ela precisa passar em [b]todas[/b] as regras da Política de Senhas "
		+ "POL-SEG-0001 (rev. 2009). Depois responda à pergunta da Jurema sobre o que a norma "
		+ "[b]NIST SP 800-63B[/b] recomenda de verdade.")


func montar() -> void:
	rotulo("Nova senha para o usuário estagio.prov:", 15, Estilo.TEXTO_FRACO)
	_senha = campo("digite aqui (as regras se atualizam a cada tecla)")
	_senha.secret = false
	_senha.text_changed.connect(func(_t): _atualizar())
	_regras = painel()
	var b := botao("Cadastrar senha", _cadastrar)
	b.custom_minimum_size = Vector2(200, 34)
	_pergunta = painel(null, Color("1b1626"))
	_pergunta.visible = false
	rotulo("Jurema: agora me diz. O que o NIST SP 800-63B recomenda para senhas memorizadas?", 15, Estilo.cor_de("Jurema"), _pergunta)
	_resposta = opcoes([
		"(escolha)",
		"Trocar a cada 30 dias e exigir maiúscula, número e símbolo",
		"Comprimento mínimo, aceitar frases longas e bloquear senhas já vazadas",
		"Proibir copiar e colar e exigir pergunta secreta",
		"Somar os dígitos para dar 25, como manda a POL-SEG-0001",
	], _pergunta)
	_atualizar()
	chat("Valdecir", "A POL-SEG-0001 é minha obra-prima. 9 regras. Nenhum hacker passa.")
	chat("Jurema", "Nenhum funcionário passa também. Metade da empresa anota a senha no monitor.")
	if Jogo.genero == "n":
		chat("Jurema", "Ah, e o sistema do RH travou no campo de gênero do seu cadastro. Consertei em cinco minutos. O sistema que se adapte, não você.")
		chat("Valdecir", "Eu aprovei a mudança! Não sei o que mudou, mas aprovei rapidinho.")
	aviso("Dica: as regras são chatas, mas todas são possíveis ao mesmo tempo.")


func regras(s: String) -> Array:
	var baixa := s.to_lower()
	var soma := 0
	for c in s:
		if c >= "0" and c <= "9":
			soma += int(c)
	var tem_planeta := false
	for p in PLANETAS:
		if baixa.contains(p):
			tem_planeta = true
	var proibida := ""
	for p in PROIBIDAS:
		if baixa.contains(p):
			proibida = p
	var repete := false
	for i in range(2, s.length()):
		if s[i] == s[i - 1] and s[i] == s[i - 2]:
			repete = true
	return [
		["Ter pelo menos 14 caracteres (%d)" % s.length(), s.length() >= 14],
		["Ter letra maiúscula", RegEx.create_from_string("[A-Z]").search(s) != null],
		["Ter letra minúscula", RegEx.create_from_string("[a-z]").search(s) != null],
		["Ter número", RegEx.create_from_string("[0-9]").search(s) != null],
		["Ter símbolo (!@#$%&*?)", RegEx.create_from_string("[!@#$%&*?]").search(s) != null],
		["Os números somados devem dar 25 (soma atual: %d)" % soma, soma == 25],
		["Conter o nome de um planeta, sem acento (o Valdecir gosta de astronomia)", tem_planeta],
		["Não conter palavras proibidas%s" % ("" if proibida == "" else " (achei: %s)" % proibida), proibida == ""],
		["Não repetir o mesmo caractere 3 vezes seguidas", not repete],
		["Entropia estimada de pelo menos 60 bits (%.0f bits)" % entropia(s), entropia(s) >= 60.0],
	]


## Estimativa ingênua: comprimento x log2(tamanho do alfabeto usado).
static func entropia(s: String) -> float:
	if s.is_empty():
		return 0.0
	var alfabeto := 0
	if RegEx.create_from_string("[a-z]").search(s): alfabeto += 26
	if RegEx.create_from_string("[A-Z]").search(s): alfabeto += 26
	if RegEx.create_from_string("[0-9]").search(s): alfabeto += 10
	if RegEx.create_from_string("[^a-zA-Z0-9]").search(s): alfabeto += 33
	return s.length() * (log(alfabeto) / log(2.0))


func _atualizar() -> void:
	for c in _regras.get_children():
		c.queue_free()
	var todas := true
	for r in regras(_senha.text):
		var ok: bool = r[1]
		todas = todas and ok
		rotulo(("[OK]  " if ok else "[  ]  ") + r[0], 14, Estilo.OK if ok else Estilo.ERRO, _regras)
	_politica_ok = todas


func _cadastrar() -> void:
	_tentativas += 1
	if not _politica_ok:
		aviso("A senha não atende à política. O sistema emitiu um bipe de 1995.", Estilo.ERRO)
		return
	if _senha.text in VAZADAS:
		aviso("Senha aprovada pela política... e encontrada numa lista de senhas vazadas. Tenta outra.", Estilo.ALERTA)
		chat("Jurema", "Essa aí está no Have I Been Pwned. Viu? Política complexa não impede senha ruim.")
		return
	_senha.editable = false
	_pergunta.visible = true
	aviso("Senha cadastrada. Agora responda à Jurema e clique em Entregar.", Estilo.OK)
	chat("Sistema", "Senha alterada com sucesso. Ela expira em 30 dias.")
	chat("Jurema", "30 dias. Em dezembro você vai estar na senha Marte@Venus2024!13. Todo mundo acaba assim.")


func avaliar() -> Dictionary:
	if not _politica_ok or _senha.editable:
		return {"nota": 10, "comentario": "Você não conseguiu nem criar a senha. Ficou o dia todo com o crachá de visitante."}
	var nota := 60
	var comentario := "Senha criada."
	if _resposta.selected == 2:
		nota += 40
		comentario += " E você sabe que o NIST manda priorizar comprimento e bloquear senhas vazadas, não regras de composição nem troca periódica."
	else:
		comentario += " Mas errou o NIST: a 800-63B desaconselha troca periódica sem motivo e regras de composição, e manda checar contra senhas vazadas."
	if _tentativas > 3:
		nota -= 5
	return {"nota": nota, "comentario": comentario}


func solucao_teste() -> void:
	_senha.text = "Netuno!Azul#Gato997Xz"
	_atualizar()
	_cadastrar()
	_resposta.selected = 2
