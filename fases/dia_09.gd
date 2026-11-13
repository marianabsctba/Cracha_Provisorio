extends "res://fases/fase.gd"
## Dia 9: senhas do portal do corretor em MD5 sem sal. Ver o estrago, provar com um
## dicionário (MD5 de verdade) e escolher parâmetros de argon2id dentro do orçamento.

const USUARIOS := [
	["corretor.ana", "tabajara123"], ["corretor.beto", "tabajara123"], ["corretor.caio", "Corretor2026"],
	["corretor.dani", "123456"], ["corretor.edu", "tabajara123"], ["corretor.fabi", "senha"],
	["corretor.gil", "123456"], ["corretor.hugo", "Primavera2026"], ["corretor.ines", "corretor"],
	["corretor.joao", "Corretor2026"], ["corretor.kika", "x9$Lq!m2Vv8#tR"], ["corretor.leo", "123456"],
	["corretor.mari", "futebol"], ["admin.portal", "Seguro2025!"], ["corretor.nina", "tabajara123"],
]
const MEMORIA_LIVRE_MIB := 4096
const LOGINS_SIMULTANEOS := 120
# Configurações mínimas recomendadas pela OWASP para argon2id (m em MiB, t), p = 1
const OWASP := [[46, 1], [19, 2], [12, 3], [9, 4], [7, 5]]

var _tabela: TextEdit
var _grupos: SpinBox
var _wordlist: TextEdit
var _r_cap: CheckBox
var _r_123: CheckBox
var _r_ano: CheckBox
var _r_exc: CheckBox
var _saida_quebra: TextEdit
var _senha_admin: LineEdit
var _m: SpinBox
var _t: SpinBox
var _p: SpinBox
var _custo: Label
var _estrategia: OptionButton
var _agrupado := false


func _init() -> void:
	dia = 9
	titulo = "Migração de senhas"
	chamado = ("O portal do corretor guarda senha em [b]MD5 sem sal[/b]. 1) Conte quantos grupos de hashes repetidos existem "
		+ "(senha igual dá hash igual). 2) Use o quebrador com dicionário para descobrir a senha do [b]admin.portal[/b]. "
		+ "3) Escolha parâmetros de [b]argon2id[/b] que cumpram o mínimo da OWASP sem estourar a memória do servidor "
		+ "(%d MiB livres, pico de %d logins simultâneos). 4) Escolha a estratégia de migração." % [MEMORIA_LIVRE_MIB, LOGINS_SIMULTANEOS])


func montar() -> void:
	var t1 := painel()
	rotulo("1. Tabela portal.usuarios (coluna senha_md5)", 14, Estilo.CIANO, t1)
	_tabela = bloco_mono("", 170, t1)
	var l1 := linha(t1)
	botao("Ordenar por hash", func():
		_agrupado = true
		_desenhar_tabela(), l1)
	rotulo("Grupos de hashes repetidos:", 14, Estilo.TEXTO, l1)
	_grupos = SpinBox.new()
	_grupos.max_value = 15
	l1.add_child(_grupos)
	_desenhar_tabela()

	var t2 := painel()
	rotulo("2. Quebrador de dicionário (MD5 calculado de verdade)", 14, Estilo.CIANO, t2)
	var l2 := linha(t2)
	_wordlist = editor("123456\nsenha\ntabajara\nfutebol\ncorretor\nprimavera\nbrasil\nqwerty\nadmin\nseguro", 150, l2)
	var regras := VBoxContainer.new()
	l2.add_child(regras)
	rotulo("Regras de mutação:", 14, Estilo.TEXTO_FRACO, regras)
	_r_cap = caixa_marcar("Primeira letra maiúscula", regras)
	_r_123 = caixa_marcar("Sufixo 123", regras)
	_r_ano = caixa_marcar("Sufixo de ano (2024 a 2026)", regras)
	_r_exc = caixa_marcar("Sufixo !", regras)
	botao("Rodar ataque", _quebrar, regras)
	_saida_quebra = bloco_mono("(nenhum ataque rodado)", 110, t2)
	var l3 := linha(t2)
	rotulo("Senha do admin.portal:", 14, Estilo.TEXTO, l3)
	_senha_admin = campo("descoberta pelo ataque", l3)

	var t3 := painel()
	rotulo("3. Parâmetros do argon2id", 14, Estilo.CIANO, t3)
	var l4 := linha(t3)
	_m = _spin(l4, "memória m (MiB)", 1, 512, 64)
	_t = _spin(l4, "iterações t", 1, 10, 1)
	_p = _spin(l4, "paralelismo p", 1, 8, 1)
	_custo = rotulo("", 14, Estilo.TEXTO, t3)
	for s in [_m, _t, _p]:
		s.value_changed.connect(func(_v): _calcular())
	_calcular()

	var t4 := painel()
	rotulo("4. Estratégia de migração", 14, Estilo.CIANO, t4)
	_estrategia = opcoes(["(escolha)",
		"Descriptografar os MD5 e recriptografar com argon2id",
		"Esperar cada corretor fazer login e só então gerar o argon2id",
		"Agora: argon2id(md5) para todos; no próximo login, trocar por argon2id(senha) e apagar a camada MD5",
		"Trocar por SHA-256 com sal, que é mais rápido"], t4)
	chat("Jurema", "MD5 sem sal: duas pessoas com a mesma senha têm o mesmo hash. Ordena a tabela e olha.")
	chat("Kauã", "Mas MD5 é criptografia de 128 bits! É muito bit!")
	chat("Jurema", "Uma GPU de jogo faz dezenas de bilhões de MD5 por segundo. Os teus 128 bits viram pó em segundos se a senha for 'tabajara123'.")


func _spin(pai: Control, nome: String, mn: int, mx: int, v: int) -> SpinBox:
	var c := VBoxContainer.new()
	pai.add_child(c)
	rotulo(nome, 13, Estilo.TEXTO_FRACO, c)
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.value = v
	c.add_child(s)
	return s


func _desenhar_tabela() -> void:
	var linhas := []
	for u in USUARIOS:
		linhas.append([str(u[0]), str(u[1]).md5_text()])
	if _agrupado:
		linhas.sort_custom(func(a, b): return a[1] < b[1])
	var t := "%-16s %s\n" % ["usuario", "senha_md5"]
	for l in linhas:
		t += "%-16s %s\n" % [l[0], l[1]]
	_tabela.text = t


static func grupos_repetidos() -> int:
	var cont := {}
	for u in USUARIOS:
		var h: String = str(u[1]).md5_text()
		cont[h] = int(cont.get(h, 0)) + 1
	var n := 0
	for h in cont:
		if cont[h] >= 2:
			n += 1
	return n


func candidatos() -> Array:
	var saida := []
	for w in _wordlist.text.split("\n", false):
		w = w.strip_edges()
		if w.is_empty():
			continue
		var bases := [w]
		if _r_cap.button_pressed:
			bases.append(w.substr(0, 1).to_upper() + w.substr(1))
		var variantes := []
		for b in bases:
			variantes.append(b)
			if _r_123.button_pressed:
				variantes.append(b + "123")
			if _r_ano.button_pressed:
				for ano in ["2024", "2025", "2026"]:
					variantes.append(b + ano)
		if _r_exc.button_pressed:
			for v in variantes.duplicate():
				variantes.append(v + "!")
		saida.append_array(variantes)
	return saida


func _quebrar() -> void:
	var alvo := {}
	for u in USUARIOS:
		var h: String = str(u[1]).md5_text()
		if not alvo.has(h):
			alvo[h] = []
		alvo[h].append(u[0])
	var cands := candidatos()
	var achados := []
	var contas := 0
	for c in cands:
		var h: String = str(c).md5_text()
		if alvo.has(h):
			achados.append("%s  %s  ->  %s" % [h, c, ", ".join(alvo[h])])
			contas += alvo[h].size()
			alvo.erase(h)
	var t := "%d candidatos testados, %d contas quebradas de %d\n" % [cands.size(), contas, USUARIOS.size()]
	t += "\n".join(achados)
	_saida_quebra.text = t
	if contas >= 10:
		chat("Jurema", "%d de %d contas em menos de um segundo, no navegador. Imagina numa GPU." % [contas, USUARIOS.size()])


func _calcular() -> void:
	var m := int(_m.value)
	var t := int(_t.value)
	var pico := m * LOGINS_SIMULTANEOS
	var ms := 0.9 * m * t / maxf(_p.value, 1.0) * (1.0 + 0.15 * (_p.value - 1.0))
	var ok_owasp := owasp_ok(m, t)
	_custo.text = "Pico de memória: %d MiB de %d livres (%s)   ·   Tempo estimado por login: %.0f ms   ·   Mínimo OWASP: %s" % [
		pico, MEMORIA_LIVRE_MIB, "cabe" if pico <= MEMORIA_LIVRE_MIB else "ESTOURA", ms, "cumpre" if ok_owasp else "NÃO cumpre"]
	_custo.add_theme_color_override("font_color", Estilo.OK if ok_owasp and pico <= MEMORIA_LIVRE_MIB else Estilo.ALERTA)


static func owasp_ok(m: int, t: int) -> bool:
	for c in OWASP:
		if m >= c[0] and t >= c[1]:
			return true
	return false


func avaliar() -> Dictionary:
	var nota := 0
	var partes := []
	if int(_grupos.value) == grupos_repetidos():
		nota += 20
		partes.append("Contou os %d grupos de hashes iguais: sem sal, senha igual entrega hash igual." % grupos_repetidos())
	else:
		partes.append("Eram %d grupos de hashes repetidos (ordene por hash e conte)." % grupos_repetidos())
	if _senha_admin.text == "Seguro2025!":
		nota += 30
		partes.append("Quebrou o admin.portal com dicionário e regras: 'Seguro2025!' passa em qualquer política e cai em milissegundos.")
	else:
		partes.append("A senha do admin era Seguro2025! (palavra + ano + !, o padrão mais comum do Brasil corporativo).")
	var m := int(_m.value)
	if owasp_ok(m, int(_t.value)) and m * LOGINS_SIMULTANEOS <= MEMORIA_LIVRE_MIB:
		nota += 30
		partes.append("Parâmetros do argon2id cumprem a OWASP e cabem na memória (m x logins simultâneos).")
	else:
		partes.append("O argon2id precisa cumprir o mínimo da OWASP (ex.: m=19 MiB, t=2, p=1) e caber na memória no pico de logins.")
	if _estrategia.selected == 3:
		nota += 20
		partes.append("Migração certa: envelopar todo mundo agora, sem esperar os inativos.")
	else:
		partes.append("A migração certa é envelopar argon2id(md5) já para todos e trocar no próximo login. MD5 não se descriptografa, e SHA-256 é rápido demais para senha.")
	return {"nota": nota, "comentario": " ".join(partes)}


func solucao_teste() -> void:
	_agrupado = true
	_desenhar_tabela()
	_grupos.value = grupos_repetidos()
	_r_cap.button_pressed = true
	_r_ano.button_pressed = true
	_r_exc.button_pressed = true
	_quebrar()
	_senha_admin.text = "Seguro2025!"
	_m.value = 19
	_t.value = 2
	_p.value = 1
	_estrategia.selected = 3
