extends "res://fases/fase.gd"
## Dia 17: priorizando CVEs. Montar o vetor CVSS 3.1 de cada achado (nota calculada
## com a fórmula oficial) e ordenar a correção por risco real, não por nota.

const METRICAS := [
	["AV", "Vetor de ataque", [["N", "Rede"], ["A", "Adjacente"], ["L", "Local"], ["P", "Físico"]]],
	["AC", "Complexidade", [["L", "Baixa"], ["H", "Alta"]]],
	["PR", "Privilégio exigido", [["N", "Nenhum"], ["L", "Baixo"], ["H", "Alto"]]],
	["UI", "Interação do usuário", [["N", "Nenhuma"], ["R", "Requerida"]]],
	["S", "Escopo", [["U", "Inalterado"], ["C", "Alterado"]]],
	["C", "Confidencialidade", [["H", "Alta"], ["L", "Baixa"], ["N", "Nenhuma"]]],
	["I", "Integridade", [["H", "Alta"], ["L", "Baixa"], ["N", "Nenhuma"]]],
	["A", "Disponibilidade", [["H", "Alta"], ["L", "Baixa"], ["N", "Nenhuma"]]],
]

## Achados (CVEs fictícias, vetores reais). "certo" é o vetor de referência.
const ACHADOS := [
	{"curto": "VPN", "titulo": "CVE-2026-31415 (fictícia) · Portal VPN SSL (vpn.tabajara.com.br), firmware 7.0.11",
	 "texto": "Estouro de buffer no tratamento de um cabeçalho HTTP do portal web da VPN. Um atacante [b]sem autenticação[/b], pela internet, envia uma única requisição forjada e executa código como root no equipamento. Nenhum usuário precisa fazer nada. O comprometimento fica no próprio equipamento.",
	 "kev": true, "epss": 0.94, "exposicao": "internet",
	 "certo": {"AV": "N", "AC": "L", "PR": "N", "UI": "N", "S": "U", "C": "H", "I": "H", "A": "H"}},
	{"curto": "XSS", "titulo": "CVE-2026-27182 (fictícia) · Portal do Corretor (interno), campo \"observações\"",
	 "texto": "O campo de observações do sinistro não sanitiza HTML. Qualquer corretor [b]logado[/b] grava um script que roda no navegador de quem abrir o sinistro (o analista precisa abrir a página). O script lê e altera parte do que aparece na tela da vítima, mas não derruba nada. O portal só é acessível pela rede interna roteada e pela VPN.",
	 "kev": false, "epss": 0.004, "exposicao": "rede interna",
	 "certo": {"AV": "N", "AC": "L", "PR": "L", "UI": "R", "S": "C", "C": "L", "I": "L", "A": "N"}},
	{"curto": "Spooler", "titulo": "CVE-2026-16180 (fictícia) · Driver de impressão das 2.300 estações Windows",
	 "texto": "Um usuário [b]já logado na máquina[/b], sem privilégio administrativo, faz o serviço de spooler carregar uma DLL e vira SYSTEM. Sem clique de ninguém. Exploit público; grupos de ransomware usam logo depois do acesso inicial para escalar.",
	 "kev": true, "epss": 0.61, "exposicao": "estações",
	 "certo": {"AV": "L", "AC": "L", "PR": "L", "UI": "N", "S": "U", "C": "H", "I": "H", "A": "H"}},
	{"curto": "Impressora", "titulo": "CVE-2026-08821 (fictícia) · Multifuncional do 3º andar",
	 "texto": "O serviço de descoberta da impressora responde, [b]só para quem está no mesmo segmento de rede[/b] (broadcast, não roteável), com o catálogo de e-mails da empresa. Sem autenticação e sem interação. Só leitura: não altera nada e não trava a impressora.",
	 "kev": false, "epss": 0.01, "exposicao": "segmento local",
	 "certo": {"AV": "A", "AC": "L", "PR": "N", "UI": "N", "S": "U", "C": "L", "I": "N", "A": "N"}},
	{"curto": "Cotação", "titulo": "CVE-2026-22604 (fictícia) · Servidor de cotação on-line (cotacao.tabajara.com.br)",
	 "texto": "Exposto na internet. Um pacote TLS malformado, enviado [b]sem autenticação[/b], trava o processo até alguém reiniciar na mão. Não vaza nem altera dados. Sem exploração conhecida até agora.",
	 "kev": false, "epss": 0.03, "exposicao": "internet",
	 "certo": {"AV": "N", "AC": "L", "PR": "N", "UI": "N", "S": "U", "C": "N", "I": "N", "A": "H"}},
]

const ORDEM_CERTA := [0, 2, 4, 1, 3]

var _abas: TabContainer
var _seletores: Array = []    # por achado: {metrica: OptionButton}
var _saidas: Array = []
var _ordem: Array = [3, 1, 4, 2, 0]
var _lista_ordem: VBoxContainer


func _init() -> void:
	dia = 17
	titulo = "Priorizando CVEs"
	chamado = ("Para cada achado, monte o vetor [b]CVSS 3.1[/b] (métricas base) lendo a descrição com cuidado: a nota é calculada com a fórmula oficial do FIRST. "
		+ "Depois, na aba [b]Prioridade[/b], ordene a correção pelo risco real: nota, exploração ativa (CISA KEV, EPSS) e exposição. "
		+ "Nota: 70% pelas métricas certas, 30% pela ordem.")


func montar() -> void:
	_abas = TabContainer.new()
	_abas.custom_minimum_size = Vector2(0, 400)
	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_child(_abas)
	for i in ACHADOS.size():
		_montar_achado(_aba(ACHADOS[i]["curto"]), i)
	var v := _aba("Prioridade")
	rotulo("Ordem de correção (1 = primeiro). Use os botões para subir e descer.", 15, Estilo.TEXTO, v)
	_lista_ordem = VBoxContainer.new()
	_lista_ordem.add_theme_constant_override("separation", 6)
	v.add_child(_lista_ordem)
	texto_rico("[color=#8b95a8]CVSS mede gravidade técnica, não risco. KEV = já exploradas no mundo real. EPSS = probabilidade de exploração nos próximos 30 dias.[/color]", v)
	_mostrar_ordem()
	chat("Valdecir", "O fornecedor do scanner classificou as 4.312 como 9,8. Então corrige tudo hoje, em ordem alfabética.")
	chat("Jurema", "O fornecedor chuta 9,8 até para a impressora. Monta o vetor de cada um. Rede interna roteada é AV:N, viu? Adjacente é só o mesmo segmento.")


func _aba(nome: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_abas.add_child(sc)
	_abas.set_tab_title(_abas.get_tab_count() - 1, nome)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	return v


func _montar_achado(v: VBoxContainer, i: int) -> void:
	var a: Dictionary = ACHADOS[i]
	texto_rico("[b]%s[/b]\n%s\n[color=#8b95a8]Exposição: %s  ·  CISA KEV: %s  ·  EPSS: %s[/color]" % [
		a["titulo"], a["texto"], a["exposicao"], "sim" if a["kev"] else "não", ("%.3f" % a["epss"]).replace(".", ",")], v)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	var sel := {}
	for m in METRICAS:
		var l := rotulo("%s (%s)" % [m[1], m[0]], 14, Estilo.TEXTO, g)
		l.custom_minimum_size = Vector2(190, 0)
		var itens := ["?"]
		for o in m[2]:
			itens.append("%s: %s" % [o[0], o[1]])
		var ob := opcoes(itens, g)
		ob.custom_minimum_size = Vector2(240, 0)
		ob.item_selected.connect(func(_x): _atualizar(i))
		sel[m[0]] = ob
	_seletores.append(sel)
	var s := texto_rico("", v)
	_saidas.append(s)
	_atualizar(i)


# ---------------------------------------------------------------- CVSS 3.1 (especificação do FIRST)

static func roundup(x: float) -> float:
	var n := int(round(x * 100000.0))
	if n % 10000 == 0:
		return n / 100000.0
	return (floori(n / 10000.0) + 1) / 10.0


## Nota base CVSS 3.1. Devolve -1 se faltar métrica.
static func nota_base(v: Dictionary) -> float:
	for m in METRICAS:
		if not v.has(m[0]) or v[m[0]] == "":
			return -1.0
	var mudou: bool = v["S"] == "C"
	var av: float = {"N": 0.85, "A": 0.62, "L": 0.55, "P": 0.2}[v["AV"]]
	var ac: float = {"L": 0.77, "H": 0.44}[v["AC"]]
	var pr: float = {"N": 0.85, "L": 0.68 if mudou else 0.62, "H": 0.5 if mudou else 0.27}[v["PR"]]
	var ui: float = {"N": 0.85, "R": 0.62}[v["UI"]]
	var cia := {"H": 0.56, "L": 0.22, "N": 0.0}
	var iss: float = 1.0 - (1.0 - cia[v["C"]]) * (1.0 - cia[v["I"]]) * (1.0 - cia[v["A"]])
	var impacto: float
	if mudou:
		impacto = 7.52 * (iss - 0.029) - 3.25 * pow(iss - 0.02, 15.0)
	else:
		impacto = 6.42 * iss
	var explorabilidade := 8.22 * av * ac * pr * ui
	if impacto <= 0.0:
		return 0.0
	if mudou:
		return roundup(minf(1.08 * (impacto + explorabilidade), 10.0))
	return roundup(minf(impacto + explorabilidade, 10.0))


static func severidade(n: float) -> String:
	if n < 0.0:
		return "incompleto"
	if n == 0.0:
		return "Nenhuma"
	if n < 4.0:
		return "Baixa"
	if n < 7.0:
		return "Média"
	if n < 9.0:
		return "Alta"
	return "Crítica"


static func vetor_texto(v: Dictionary) -> String:
	var p: Array = ["CVSS:3.1"]
	for m in METRICAS:
		p.append("%s:%s" % [m[0], v.get(m[0], "") if v.get(m[0], "") != "" else "?"])
	return "/".join(p)


func _vetor(i: int) -> Dictionary:
	var v := {}
	for m in METRICAS:
		var ob: OptionButton = _seletores[i][m[0]]
		v[m[0]] = "" if ob.selected <= 0 else m[2][ob.selected - 1][0]
	return v


func _atualizar(i: int) -> void:
	var v := _vetor(i)
	var n := nota_base(v)
	var nt := "?" if n < 0.0 else ("%.1f" % n).replace(".", ",")
	_saidas[i].text = "[code]%s[/code]\nNota base: [b]%s[/b] (%s)     [color=#8b95a8]Nota do fornecedor: 9,8 Crítica (como sempre)[/color]" % [vetor_texto(v), nt, severidade(n)]
	if is_instance_valid(_lista_ordem):
		_mostrar_ordem()


# ---------------------------------------------------------------- prioridade

func _mostrar_ordem() -> void:
	for c in _lista_ordem.get_children():
		c.queue_free()
	for pos in _ordem.size():
		var idx: int = _ordem[pos]
		var a: Dictionary = ACHADOS[idx]
		var h := linha(_lista_ordem)
		var sobe := botao("Subir", _mover.bind(pos, -1), h)
		sobe.disabled = pos == 0
		var desce := botao("Descer", _mover.bind(pos, 1), h)
		desce.disabled = pos == _ordem.size() - 1
		var n := nota_base(_vetor(idx)) if idx < _seletores.size() else -1.0
		var l := rotulo("%d. %s  [sua nota %s · KEV %s · EPSS %s · %s]" % [pos + 1, a["curto"], "?" if n < 0 else ("%.1f" % n).replace(".", ","),
			"sim" if a["kev"] else "não", ("%.3f" % a["epss"]).replace(".", ","), a["exposicao"]], 15, Estilo.TEXTO, h)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _mover(pos: int, d: int) -> void:
	var alvo := pos + d
	if alvo < 0 or alvo >= _ordem.size():
		return
	var t = _ordem[pos]
	_ordem[pos] = _ordem[alvo]
	_ordem[alvo] = t
	_mostrar_ordem()


## Pares na mesma ordem relativa da referência (de 10).
static func concordancia(ordem: Array) -> int:
	var c := 0
	for a in ORDEM_CERTA.size():
		for b in range(a + 1, ORDEM_CERTA.size()):
			if ordem.find(ORDEM_CERTA[a]) < ordem.find(ORDEM_CERTA[b]):
				c += 1
	return c


# ---------------------------------------------------------------- avaliação

func avaliar() -> Dictionary:
	var certas := 0
	var total := 0
	var erros: Array = []
	for i in ACHADOS.size():
		var v := _vetor(i)
		var ref: Dictionary = ACHADOS[i]["certo"]
		var errou: Array = []
		for m in METRICAS:
			total += 1
			if v[m[0]] == ref[m[0]]:
				certas += 1
			else:
				errou.append(m[0])
		if not errou.is_empty():
			erros.append("%s (%s; o certo é %s = %s)" % [ACHADOS[i]["curto"], ", ".join(errou), vetor_texto(ref).trim_prefix("CVSS:3.1/"), ("%.1f" % nota_base(ref)).replace(".", ",")])
	var conc := concordancia(_ordem)
	var nota := int(round(70.0 * certas / total + 30.0 * conc / 10.0))
	var com := "%d de %d métricas certas; ordem com %d de 10 pares na posição relativa certa." % [certas, total, conc]
	if not erros.is_empty():
		com += " Errou: " + "; ".join(erros) + "."
	if conc < 10:
		com += " Ordem certa: VPN (crítica, internet, KEV), Spooler (KEV, escala para SYSTEM), Cotação (internet, mas só DoS), XSS (interno, precisa de login e clique), Impressora."
	else:
		com += " Priorização certa: CVSS é gravidade; KEV, EPSS e exposição dizem o que vai ser explorado primeiro."
	return {"nota": clampi(nota, 0, 100), "comentario": com, "cagada": ""}


func solucao_teste() -> void:
	for i in ACHADOS.size():
		var ref: Dictionary = ACHADOS[i]["certo"]
		for m in METRICAS:
			for k in m[2].size():
				if m[2][k][0] == ref[m[0]]:
					_seletores[i][m[0]].selected = k + 1
		_atualizar(i)
	_ordem = ORDEM_CERTA.duplicate()
	_mostrar_ordem()
