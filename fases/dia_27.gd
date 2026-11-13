extends "res://fases/fase.gd"
## Dia 27: segmentar o /16 plano em VLANs com CIDR do tamanho certo, e a matriz de permissões.

const BLOCO := "10.20.0.0/16"

## [nome, hosts necessários, CIDR de referência para o teste]
const VLANS := [
	["VLAN 10 Financeiro", 120, "10.20.7.0/25"],
	["VLAN 20 Atendimento", 400, "10.20.4.0/23"],
	["VLAN 30 TI", 50, "10.20.7.128/26"],
	["VLAN 40 Diretoria", 12, "10.20.8.32/28"],
	["VLAN 50 Câmeras CFTV", 200, "10.20.6.0/24"],
	["VLAN 60 IoT/cafeteiras", 25, "10.20.8.0/27"],
	["VLAN 70 Wi-Fi visitante", 900, "10.20.0.0/22"],
	["VLAN 80 Servidores", 60, "10.20.7.192/26"],
]

## [regra, deve permitir?]
const REGRAS := [
	["Visitante -> Internet (HTTP/HTTPS)", true],
	["Visitante -> Servidores", false],
	["Visitante -> Financeiro", false],
	["Câmeras -> gravação (RTSP 554, em Servidores)", true],
	["Câmeras -> Internet", false],
	["IoT/cafeteiras -> Financeiro", false],
	["IoT/cafeteiras -> Servidores (folha)", false],
	["Financeiro -> Servidores (ERP, folha)", true],
	["Atendimento -> Servidores (sistema de cotação)", true],
	["Atendimento -> Financeiro", false],
	["TI -> todas as VLANs (gerência via jump server)", true],
	["Diretoria -> Servidores (e-mail, arquivos)", true],
]

var _campos: Array[LineEdit] = []
var _saidas: Array[Label] = []
var _marcas: Array[CheckBox] = []
var _resumo: Label


func _init() -> void:
	dia = 27
	titulo = "Segmentação de rede"
	chamado = (("Bloco disponível: [b]%s[/b]. Para cada VLAN digite um CIDR (ex.: 10.20.4.0/23). Regras: endereço de rede "
		+ "alinhado à máscara, dentro do /16, sem sobreposição, hosts utilizáveis (2^(32-n) - 2) suficientes e sem "
		+ "desperdício maior que 4 vezes o necessário. Depois marque na matriz o que deve ser [b]permitido[/b] (o resto é negado por padrão).") % BLOCO)


static func ip_int(s: String) -> int:
	var p := s.split(".")
	if p.size() != 4:
		return -1
	var v := 0
	for o in p:
		if not o.is_valid_int() or int(o) < 0 or int(o) > 255 or (o.length() > 1 and o.begins_with("0")):
			return -1
		v = (v << 8) | int(o)
	return v


static func int_ip(v: int) -> String:
	return "%d.%d.%d.%d" % [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255]


## Retorna {"ok": bool, "erro": "", "rede": int, "prefixo": int, "bcast": int, "hosts": int}
static func analisar(cidr: String) -> Dictionary:
	var r := {"ok": false, "erro": "", "rede": 0, "prefixo": 0, "bcast": 0, "hosts": 0}
	var t := cidr.strip_edges()
	if t == "":
		r["erro"] = "vazio"
		return r
	var partes := t.split("/")
	if partes.size() != 2 or not partes[1].is_valid_int():
		r["erro"] = "formato inválido (use a.b.c.d/n)"
		return r
	var ip := ip_int(partes[0])
	var n := int(partes[1])
	if ip < 0 or n < 1 or n > 30:
		r["erro"] = "endereço ou prefixo inválido (use /1 a /30)"
		return r
	var tam := 1 << (32 - n)
	var mascara := (0xFFFFFFFF << (32 - n)) & 0xFFFFFFFF
	if ip & mascara != ip:
		r["erro"] = "não alinhado: a rede de um /%d com esse IP seria %s" % [n, int_ip(ip & mascara)]
		return r
	var base := ip_int("10.20.0.0")
	if ip < base or ip + tam - 1 > base + 65535:
		r["erro"] = "fora do bloco %s" % BLOCO
		return r
	r["ok"] = true
	r["rede"] = ip
	r["prefixo"] = n
	r["bcast"] = ip + tam - 1
	r["hosts"] = tam - 2
	return r


func montar() -> void:
	var p := painel()
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 6)
	p.add_child(grade)
	for v in VLANS:
		var nome := rotulo("%s (%d hosts)" % [v[0], v[1]], 14, Estilo.TEXTO, grade)
		nome.custom_minimum_size = Vector2(230, 0)
		nome.autowrap_mode = TextServer.AUTOWRAP_OFF
		var c := campo("10.20.x.x/n", grade)
		c.custom_minimum_size = Vector2(140, 0)
		c.size_flags_horizontal = Control.SIZE_FILL
		c.add_theme_font_override("font", Estilo.mono())
		c.text_changed.connect(func(_t): _atualizar())
		_campos.append(c)
		var s := rotulo("", 12, Estilo.TEXTO_FRACO, grade)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.add_theme_font_override("font", Estilo.mono())
		_saidas.append(s)
	_resumo = rotulo("", 14, Estilo.TEXTO_FRACO, p)

	var m := painel(null, Color("141a24"))
	rotulo("Matriz de permissões entre VLANs (marque só o que deve ser PERMITIDO; padrão: negar tudo)", 14, Estilo.CIANO, m)
	var g2 := GridContainer.new()
	g2.columns = 2
	g2.add_theme_constant_override("h_separation", 20)
	m.add_child(g2)
	for r in REGRAS:
		var cb := caixa_marcar(r[0], g2)
		cb.add_theme_font_size_override("font_size", 13)
		_marcas.append(cb)
	_atualizar()
	chat("Jurema", "Hoje a cafeteira pinga no servidor da folha. Literalmente. Eu testei.")
	chat("Valdecir", "Faz tudo /24 que é mais bonito. Número redondo.")
	chat("Jurema", "Visitante com 900 aparelhos num /24, Valdecir? 254 hosts. Faz a conta.")


func _atualizar() -> void:
	var dados := []
	for i in VLANS.size():
		dados.append(analisar(_campos[i].text))
	var validas := 0
	for i in VLANS.size():
		var d: Dictionary = dados[i]
		var s := _saidas[i]
		if not d["ok"]:
			s.text = "" if d["erro"] == "vazio" else d["erro"]
			s.add_theme_color_override("font_color", Estilo.ERRO)
			continue
		var conflito := ""
		for j in VLANS.size():
			if j != i and dados[j]["ok"] and d["rede"] <= dados[j]["bcast"] and dados[j]["rede"] <= d["bcast"]:
				conflito = VLANS[j][0].split(" ")[1] + " " + VLANS[j][0].split(" ")[2]
		var info := "%s a %s, bc %s, %d hosts" % [int_ip(d["rede"] + 1), int_ip(d["bcast"] - 1), int_ip(d["bcast"]), d["hosts"]]
		var cor := Estilo.OK
		if conflito != "":
			info = "sobrepõe %s. " % conflito + info
			cor = Estilo.ERRO
		elif d["hosts"] < VLANS[i][1]:
			info = "faltam hosts. " + info
			cor = Estilo.ERRO
		elif d["hosts"] > VLANS[i][1] * 4:
			info = "desperdício. " + info
			cor = Estilo.ALERTA
		else:
			validas += 1
		s.text = info
		s.add_theme_color_override("font_color", cor)
	_resumo.text = "%d de %d VLANs corretas." % [validas, VLANS.size()]


func avaliar() -> Dictionary:
	var dados := []
	for i in VLANS.size():
		dados.append(analisar(_campos[i].text))
	var pontos := 0.0
	var erros := []
	for i in VLANS.size():
		var d: Dictionary = dados[i]
		var nome: String = VLANS[i][0]
		if not d["ok"]:
			if d["erro"] != "vazio":
				erros.append("%s: %s" % [nome, d["erro"]])
			continue
		var sobrepoe := false
		for j in VLANS.size():
			if j != i and dados[j]["ok"] and d["rede"] <= dados[j]["bcast"] and dados[j]["rede"] <= d["bcast"]:
				sobrepoe = true
		if sobrepoe:
			erros.append("%s sobrepõe outra VLAN" % nome)
		elif d["hosts"] < VLANS[i][1]:
			erros.append("%s: /%d dá %d hosts, precisa de %d" % [nome, d["prefixo"], d["hosts"], VLANS[i][1]])
		elif d["hosts"] > VLANS[i][1] * 4:
			pontos += 0.5
			erros.append("%s: /%d desperdiça endereços" % [nome, d["prefixo"]])
		else:
			pontos += 1.0
	var certas := 0
	var tocou := false
	for i in REGRAS.size():
		if _marcas[i].button_pressed:
			tocou = true
		if _marcas[i].button_pressed == REGRAS[i][1]:
			certas += 1
	var nota_rede := 70.0 * pontos / VLANS.size()
	var nota_matriz := (30.0 * certas / REGRAS.size()) if tocou else 0.0
	var com := "Sub-redes: %.1f de %d. Matriz: %d de %d regras certas." % [pontos, VLANS.size(), certas, REGRAS.size()]
	if not erros.is_empty():
		com += " Problemas: " + "; ".join(erros.slice(0, 3)) + "."
	com += " Lembre: aloque do maior para o menor para manter o alinhamento, e visitante/IoT/câmeras nunca falam com a rede interna."
	return {"nota": int(round(nota_rede + nota_matriz)), "comentario": com, "cagada": ""}


func solucao_teste() -> void:
	for i in VLANS.size():
		_campos[i].text = VLANS[i][2]
	for i in REGRAS.size():
		_marcas[i].button_pressed = REGRAS[i][1]
	_atualizar()
