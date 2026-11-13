extends "res://fases/fase.gd"
## Dia 25: Diffie-Hellman no guardanapo com o técnico da resseguradora.

const P_FALSO := 221        # 13 x 17, a pegadinha
const P := 2027             # primo
const G := 2                # 2 gera todo o grupo multiplicativo mod 2027
const SEGREDO_PARCEIRO := 1311

var _fase := 0              # 0: primeira ligação; 1: p bom aceito
var _recusou_falso := false
var _aceitou_falso := false
var _transcricao: RichTextLabel
var _verif_num: LineEdit
var _verif_saida: Label
var _b: LineEdit
var _passos: TextEdit
var _campo_B: LineEdit
var _campo_K: LineEdit
var _resultado: Label
var _pergunta: OptionButton
var _area_calc: VBoxContainer
var _ditou_ok := false
var _chave_ok := false


func _init() -> void:
	dia = 25
	titulo = "VPN com o parceiro"
	chamado = ("O técnico da resseguradora vai ditar [b]p[/b], [b]g[/b] e o valor público [b]A[/b] dele. "
		+ "Antes de aceitar, confira se p é primo (verificador abaixo). Depois escolha seu segredo [b]b[/b] "
		+ "(entre 2 e p-2), calcule [b]B = g^b mod p[/b] e [b]K = A^b mod p[/b] na calculadora de guardanapo, "
		+ "dite B de volta e confirme K. No fim, responda à pergunta da Jurema.")


static func pot_mod(base: int, exp: int, m: int) -> int:
	var r := 1
	var b := base % m
	var e := exp
	while e > 0:
		if e & 1:
			r = (r * b) % m
		b = (b * b) % m
		e >>= 1
	return r


static func fatorar(n: int) -> Array:
	var f := []
	var x := n
	var d := 2
	while d * d <= x:
		while x % d == 0:
			f.append(d)
			x /= d
		d += 1
	if x > 1:
		f.append(x)
	return f


## Passos do square and multiply, lendo o expoente em binário da esquerda para a direita.
static func passos_sm(base: int, exp: int, m: int) -> String:
	var bits := ""
	var e := exp
	while e > 0:
		bits = str(e & 1) + bits
		e >>= 1
	var s := "%d^%d mod %d   expoente em binário: %s\n" % [base, exp, m, bits]
	var r := 1
	for i in bits.length():
		var antes := r
		r = (r * r) % m
		var linha_txt := "bit %d = %s:  quadrado %d^2 mod %d = %d" % [i, bits[i], antes, m, r]
		if bits[i] == "1":
			var q := r
			r = (r * base) % m
			linha_txt += ";  multiplica %d x %d mod %d = %d" % [q, base, m, r]
		s += linha_txt + "\n"
	s += "resultado = %d" % r
	return s


func _a_parceiro() -> int:
	return pot_mod(G, SEGREDO_PARCEIRO, P)


func montar() -> void:
	var tp := painel(null, Color("141a24"))
	rotulo("Transcrição da ligação (ramal 4412, chiado de fundo)", 13, Estilo.TEXTO_FRACO, tp)
	_transcricao = texto_rico("", tp)
	_transcricao.text = ("[color=#38d9e8]Técnico:[/color] Bom dia! Vamos de Diffie-Hellman clássico. "
		+ "Anota aí: [b]p = %d[/b], [b]g = %d[/b]. Meu valor público eu passo depois que você confirmar o p." % [P_FALSO, G])
	var lp := linha(tp)
	botao("Aceitar esse p", _aceitar_falso, lp)
	botao("Recusar: p não é primo", _recusar_falso, lp)

	var vp := painel()
	rotulo("Verificador de primalidade (divisão por tentativa)", 13, Estilo.TEXTO_FRACO, vp)
	var lv := linha(vp)
	_verif_num = campo("número para testar", lv)
	botao("Testar", _testar, lv)
	_verif_saida = rotulo("", 14, Estilo.TEXTO, vp)

	_area_calc = painel()
	_area_calc.get_parent().visible = false
	rotulo("Calculadora de guardanapo (exponenciação rápida mod p)", 13, Estilo.TEXTO_FRACO, _area_calc)
	var lb := linha(_area_calc)
	rotulo("Seu segredo b:", 14, Estilo.TEXTO, lb)
	_b = campo("2 a p-2", lb)
	botao("Calcular B = g^b mod p", _calc_B, lb)
	botao("Calcular K = A^b mod p", _calc_K, lb)
	_passos = bloco_mono("", 170, _area_calc)
	_passos.add_theme_font_override("font", Estilo.mono())
	_passos.add_theme_font_size_override("font_size", 12)
	var ld := linha(_area_calc)
	rotulo("B para ditar:", 14, Estilo.TEXTO, ld)
	_campo_B = campo("B", ld)
	rotulo("K:", 14, Estilo.TEXTO, ld)
	_campo_K = campo("K", ld)
	botao("Ditar e conferir", _ditar, ld)
	_resultado = rotulo("", 14, Estilo.TEXTO, _area_calc)
	rotulo("Jurema: um estagiário de outra empresa ouviu a ligação inteira (p, g, A e B). Por que ele não tem a chave?", 14, Estilo.cor_de("Jurema"), _area_calc)
	_pergunta = opcoes([
		"(escolha)",
		"Porque achar b a partir de B = g^b mod p é o problema do logaritmo discreto, inviável em grupos grandes (2048+ bits ou X25519). Mas sem autenticação um homem no meio troca os valores.",
		"Porque o telefone é criptografado de fábrica, então ninguém ouve nada.",
		"Porque K é só a soma de A e B, e ele não sabe somar números de 4 dígitos.",
		"Porque o DH já autentica as partes, então nem um homem no meio funciona.",
	], _area_calc)
	_pergunta.fit_to_longest_item = false
	_pergunta.custom_minimum_size = Vector2(0, 32)
	_pergunta.clip_text = true

	chat("Valdecir", "Diffie quem? Só faz a VPN subir. A diretoria quer ver o painel verde.")
	chat("Jurema", "Antes de qualquer conta, confere o p. Técnico de telefone dita cada coisa...")
	aviso("Use o verificador antes de aceitar qualquer número ditado.")


func _testar() -> void:
	var t := _verif_num.text.strip_edges()
	if not t.is_valid_int() or int(t) < 2:
		_verif_saida.text = "Digite um inteiro maior que 1."
		return
	var n := int(t)
	if n > 1000000000:
		_verif_saida.text = "Grande demais para o guardanapo. Na vida real se usa Miller-Rabin."
		return
	var f := fatorar(n)
	if f.size() == 1:
		_verif_saida.text = "%d é primo." % n
		_verif_saida.add_theme_color_override("font_color", Estilo.OK)
	else:
		_verif_saida.text = "%d NÃO é primo: %s" % [n, " x ".join(f.map(func(x): return str(x)))]
		_verif_saida.add_theme_color_override("font_color", Estilo.ERRO)


func _aceitar_falso() -> void:
	if _fase != 0:
		return
	_aceitou_falso = true
	chat("Jurema", "Aceitou 221? É 13 x 17. Com módulo composto o logaritmo discreto quebra pelo Teorema Chinês do Resto. Vou fingir que não vi.")
	_segunda_ligacao()


func _recusar_falso() -> void:
	if _fase != 0:
		return
	_recusou_falso = true
	chat("Você", "221 não é primo, é 13 x 17. Manda outro.")
	chat("Jurema", "Isso. Módulo composto quebra em pedacinhos pequenos e o logaritmo discreto vira brincadeira.")
	_segunda_ligacao()


func _segunda_ligacao() -> void:
	_fase = 1
	_transcricao.text += ("\n[color=#38d9e8]Técnico:[/color] Ops, era o ramal da cantina. Agora sim: "
		+ "[b]p = %d[/b], [b]g = %d[/b], meu [b]A = %d[/b]. Seu segredo fica com você, só me dita o B." % [P, G, _a_parceiro()])
	_area_calc.get_parent().visible = true
	aviso("Confira o novo p no verificador e escolha b.", Estilo.CIANO)


func _ler_b() -> int:
	var t := _b.text.strip_edges()
	if not t.is_valid_int():
		_resultado.text = "b precisa ser um inteiro."
		return -1
	var b := int(t)
	if b <= 1 or b >= P - 1:
		_resultado.text = ("b = 1 daria B = g (você entrega o segredo de bandeja) e b = p-1 daria B = 1 "
			+ "(Fermat: g^(p-1) = 1 mod p). Escolha entre 2 e %d." % (P - 2))
		_resultado.add_theme_color_override("font_color", Estilo.ERRO)
		return -1
	return b


func _calc_B() -> void:
	var b := _ler_b()
	if b < 0:
		return
	_passos.text = passos_sm(G, b, P)


func _calc_K() -> void:
	var b := _ler_b()
	if b < 0:
		return
	_passos.text = passos_sm(_a_parceiro(), b, P)


func _ditar() -> void:
	var b := _ler_b()
	if b < 0:
		return
	var B := pot_mod(G, b, P)
	var K := pot_mod(_a_parceiro(), b, P)
	_ditou_ok = _campo_B.text.strip_edges() == str(B)
	var k_digitado := _campo_K.text.strip_edges()
	# O parceiro calcula do lado dele: B^a mod p.
	var k_parceiro := pot_mod(int(_campo_B.text) if _campo_B.text.is_valid_int() else 0, SEGREDO_PARCEIRO, P)
	_chave_ok = _ditou_ok and k_digitado == str(K) and k_parceiro == K
	if _chave_ok:
		_resultado.text = "[OK] O técnico calculou B^a mod p = %d. Bateu com o seu K. Túnel no ar." % k_parceiro
		_resultado.add_theme_color_override("font_color", Estilo.OK)
		chat("Sistema", "IKE SA estabelecida com resseguradora-gw. Painel verde.")
		chat("Valdecir", "Verde! Vou tirar print pra diretoria.")
	elif not _ditou_ok:
		_resultado.text = "O técnico calculou com o seu B e a chave dele não bate com nada. Confira B = g^b mod p."
		_resultado.add_theme_color_override("font_color", Estilo.ERRO)
	else:
		_resultado.text = "B certo, mas o seu K não confere com o do técnico (%s). Refaça A^b mod p." % ("ele chegou em outro valor" if k_digitado != "" else "você não digitou K")
		_resultado.add_theme_color_override("font_color", Estilo.ALERTA)


func avaliar() -> Dictionary:
	var nota := 0
	var c := []
	if _recusou_falso:
		nota += 20
		c.append("Recusou o p = 221 (13 x 17)")
	elif _aceitou_falso:
		c.append("Aceitou p composto (221 = 13 x 17), o que tornaria o logaritmo discreto fácil")
	else:
		c.append("Nem passou da primeira ligação")
	if _ditou_ok:
		nota += 25
		c.append("B correto")
	if _chave_ok:
		nota += 30
		c.append("K bateu dos dois lados")
	if _pergunta.selected == 1:
		nota += 25
		c.append("entendeu logaritmo discreto, tamanho de grupo e o risco de homem no meio sem autenticação")
	elif _pergunta.selected > 1:
		c.append("errou a pergunta: a segurança vem do logaritmo discreto, e DH puro não autentica ninguém")
	return {"nota": nota, "comentario": ". ".join(c) + ". Na vida real: grupos de 2048+ bits ou X25519, sempre com autenticação (certificado ou PSK).", "cagada": ""}


func solucao_teste() -> void:
	_recusar_falso()
	_b.text = "777"
	_campo_B.text = str(pot_mod(G, 777, P))
	_campo_K.text = str(pot_mod(_a_parceiro(), 777, P))
	_calc_K()
	_ditar()
	_pergunta.selected = 1
