extends "res://fases/fase.gd"
## Dia 6: regras de firewall com motor first-match de verdade (CIDR, portas, protocolo)
## contra uma bateria de pacotes de teste.

const ORIGINAL := """# Firewall de borda da Tabajara (Valdecir, 2009)
# Política de portas abertas. Nunca deu problema que eu tenha visto.
ACCEPT any any -> any
"""

const RESOLVIDO := """# Web pública
ACCEPT tcp any -> 10.10.10.10:443
ACCEPT tcp any -> 10.10.10.10:80
# Administração
ACCEPT tcp 10.10.99.0/24 -> 10.10.0.0/16:22
# Banco só da aplicação
ACCEPT tcp 10.10.20.5 -> 10.10.30.5:5432
# DNS de saída só para os resolvedores
ACCEPT udp 10.10.0.0/16 -> 198.51.100.53:53
ACCEPT udp 10.10.0.0/16 -> 198.51.100.54:53
ACCEPT tcp 10.10.0.0/16 -> 198.51.100.53:53
ACCEPT tcp 10.10.0.0/16 -> 198.51.100.54:53
"""

# proto, origem, destino, porta, esperado, descrição
const PACOTES := [
	["tcp", "203.0.113.7", "10.10.10.10", 443, "ACCEPT", "Cliente acessando o portal (HTTPS)"],
	["tcp", "198.51.100.200", "10.10.10.10", 80, "ACCEPT", "Cliente digitou http:// (vai ser redirecionado)"],
	["tcp", "203.0.113.7", "10.10.10.10", 22, "DROP", "SSH no servidor web vindo da internet"],
	["tcp", "10.10.99.15", "10.10.10.10", 22, "ACCEPT", "Jurema administrando o servidor web"],
	["tcp", "10.10.99.15", "10.10.30.5", 22, "ACCEPT", "Jurema administrando o banco"],
	["tcp", "10.10.20.5", "10.10.30.5", 22, "DROP", "Servidor de aplicação tentando SSH no banco"],
	["tcp", "10.10.20.5", "10.10.30.5", 5432, "ACCEPT", "Aplicação consultando o PostgreSQL"],
	["tcp", "10.10.99.15", "10.10.30.5", 5432, "DROP", "Rede de administração direto no banco"],
	["tcp", "203.0.113.7", "10.10.30.5", 5432, "DROP", "Internet no PostgreSQL (o sonho do atacante)"],
	["udp", "10.10.20.5", "198.51.100.53", 53, "ACCEPT", "Aplicação resolvendo nome no resolvedor 1"],
	["tcp", "10.10.30.5", "198.51.100.54", 53, "ACCEPT", "Resposta DNS grande (TCP) no resolvedor 2"],
	["udp", "10.10.20.5", "203.0.113.53", 53, "DROP", "DNS direto para servidor desconhecido (túnel?)"],
	["tcp", "10.10.99.15", "10.10.10.10", 23, "DROP", "Telnet, mesmo da administração"],
	["tcp", "203.0.113.7", "10.10.10.10", 8080, "DROP", "Painel de admin do Tomcat que o Kauã esqueceu"],
	["tcp", "10.10.10.10", "203.0.113.80", 4444, "DROP", "Servidor web abrindo conexão para fora (shell reverso?)"],
	["udp", "203.0.113.7", "10.10.10.10", 161, "DROP", "SNMP vindo da internet"],
]

var _editor: CodeEdit
var _politica: OptionButton
var _erros: RichTextLabel
var _tabela: RichTextLabel
var _placar: Label
var _valdecir_reagiu := false


func _init() -> void:
	dia = 6
	titulo = "Regras de firewall"
	chamado = ("Reescreva as regras do firewall de borda. Uma regra por linha: "
		+ "[code]AÇÃO PROTO ORIGEM -> DESTINO[:PORTAS][/code]. AÇÃO: ACCEPT, DROP ou REJECT. PROTO: tcp, udp, icmp ou any. "
		+ "ORIGEM/DESTINO: IP, CIDR ou any. PORTAS: 443, 80,443, 1024-2048 ou nada (todas). [code]#[/code] comenta. "
		+ "Vale a [b]primeira regra que casar[/b]; se nenhuma casar, vale a política padrão. O firewall é stateful: respostas já são liberadas.")


func montar() -> void:
	var topo := linha()
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(esq)
	_editor = CodeEdit.new()
	_editor.text = ORIGINAL
	_editor.gutters_draw_line_numbers = true
	_editor.custom_minimum_size = Vector2(470, 235)
	_editor.add_theme_font_size_override("font_size", 13)
	_editor.text_changed.connect(_atualizar)
	esq.add_child(_editor)
	var lp := linha(esq)
	rotulo("Política padrão:", 14, Estilo.TEXTO_FRACO, lp).autowrap_mode = TextServer.AUTOWRAP_OFF
	_politica = opcoes(["ACCEPT", "DROP", "REJECT"], lp)
	_politica.item_selected.connect(_mudou_politica)
	_placar = rotulo("", 14, Estilo.ALERTA, lp)
	_placar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_placar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var req := painel(topo)
	req.get_parent().custom_minimum_size = Vector2(420, 0)
	req.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_END
	rotulo("Requisitos (aprovados pela Jurema)", 14, Estilo.CIANO, req)
	texto_rico("[font_size=13]"
		+ "1. Portal [code]10.10.10.10[/code]: HTTPS (tcp 443) para o mundo.\n"
		+ "2. Mesmo servidor: HTTP (tcp 80) para o mundo, só para redirecionar.\n"
		+ "3. SSH (tcp 22) nos servidores [code]10.10.0.0/16[/code] só da rede de administração [code]10.10.99.0/24[/code].\n"
		+ "4. PostgreSQL [code]10.10.30.5:5432[/code] só do servidor de aplicação [code]10.10.20.5[/code].\n"
		+ "5. DNS (udp e tcp 53) saindo da rede [code]10.10.0.0/16[/code] só para os resolvedores [code]198.51.100.53[/code] e [code]198.51.100.54[/code].\n"
		+ "6. Telnet: nunca, para ninguém.\n"
		+ "7. Todo o resto: bloqueado.[/font_size]", req)

	_erros = texto_rico("")
	var tp := painel()
	rotulo("Bateria de testes (cada pacote é o primeiro de uma conexão nova)", 14, Estilo.CIANO, tp)
	_tabela = texto_rico("", tp)
	_atualizar()

	chat("Valdecir", "A minha regra ANY ANY ACCEPT é a mais segura que existe: nunca bloqueou nenhum cliente. Nem nenhum hacker, mas isso é detalhe.")
	chat("Jurema", "Firewall bom é chato: começa negando tudo e libera só o que tem dono e justificativa. E ordem importa, primeira que casa ganha.")
	aviso("Dica: rode a bateria de cabeça antes de entregar. Regra larga em cima engole as regras de baixo.")


# ---------------------------------------------------------------- motor

static func ip_para_int(ip: String) -> int:
	var p := ip.split(".")
	if p.size() != 4:
		return -1
	var v := 0
	for o in p:
		if not o.is_valid_int() or int(o) < 0 or int(o) > 255:
			return -1
		v = v * 256 + int(o)
	return v


## "any", "10.0.0.0/8" ou "10.1.2.3" -> [rede, prefixo] ou [] se inválido.
static func cidr(s: String) -> Array:
	if s.to_lower() == "any":
		return [0, 0]
	var ip := s
	var pre := 32
	if s.contains("/"):
		ip = s.get_slice("/", 0)
		var ps := s.get_slice("/", 1)
		if not ps.is_valid_int() or int(ps) < 0 or int(ps) > 32:
			return []
		pre = int(ps)
	var v := ip_para_int(ip)
	if v < 0:
		return []
	var mascara := (0xFFFFFFFF << (32 - pre)) & 0xFFFFFFFF if pre > 0 else 0
	return [v & mascara, pre]


static func no_cidr(ip: int, rede: Array) -> bool:
	var pre: int = rede[1]
	if pre == 0:
		return true
	var mascara := (0xFFFFFFFF << (32 - pre)) & 0xFFFFFFFF
	return (ip & mascara) == rede[0]


## Portas: [] = todas; senão lista de [ini, fim].
static func portas(s: String) -> Variant:
	if s == "" or s.to_lower() == "any":
		return []
	var r: Array = []
	for parte in s.split(","):
		var a := parte.strip_edges()
		var ini := a
		var fim := a
		if a.contains("-"):
			ini = a.get_slice("-", 0)
			fim = a.get_slice("-", 1)
		if not ini.is_valid_int() or not fim.is_valid_int():
			return null
		if int(ini) < 1 or int(fim) > 65535 or int(ini) > int(fim):
			return null
		r.append([int(ini), int(fim)])
	return r


func parse(texto: String) -> Dictionary:
	var regras: Array = []
	var erros: Array[String] = []
	var re := RegEx.create_from_string("^(\\S+)\\s+(\\S+)\\s+(\\S+)\\s*->\\s*(\\S+)$")
	var linhas := texto.split("\n")
	for i in linhas.size():
		var l := linhas[i].strip_edges()
		if l.contains("#"):
			l = l.substr(0, l.find("#")).strip_edges()
		if l == "":
			continue
		var n := i + 1
		var m := re.search(l)
		if m == null:
			erros.append("Linha %d: formato esperado AÇÃO PROTO ORIGEM -> DESTINO[:PORTAS]." % n)
			continue
		var acao := m.get_string(1).to_upper()
		var proto := m.get_string(2).to_lower()
		if not (acao in ["ACCEPT", "DROP", "REJECT"]):
			erros.append("Linha %d: ação \"%s\" não existe (ACCEPT, DROP, REJECT)." % [n, m.get_string(1)])
			continue
		if not (proto in ["tcp", "udp", "icmp", "any"]):
			erros.append("Linha %d: protocolo \"%s\" desconhecido (tcp, udp, icmp, any)." % [n, m.get_string(2)])
			continue
		var src := cidr(m.get_string(3))
		if src.is_empty():
			erros.append("Linha %d: origem \"%s\" não é IP nem CIDR válido." % [n, m.get_string(3)])
			continue
		var dst_txt := m.get_string(4)
		var porta_txt := ""
		if dst_txt.contains(":"):
			porta_txt = dst_txt.get_slice(":", 1)
			dst_txt = dst_txt.get_slice(":", 0)
		var dst := cidr(dst_txt)
		if dst.is_empty():
			erros.append("Linha %d: destino \"%s\" não é IP nem CIDR válido." % [n, dst_txt])
			continue
		var pts: Variant = portas(porta_txt)
		if pts == null:
			erros.append("Linha %d: portas \"%s\" inválidas (1 a 65535)." % [n, porta_txt])
			continue
		if proto in ["icmp", "any"] and not pts.is_empty():
			erros.append("Linha %d: porta só faz sentido com tcp ou udp." % n)
			continue
		var host_bits := ip_para_int(m.get_string(3).get_slice("/", 0))
		if m.get_string(3).contains("/") and host_bits != src[0]:
			erros.append("Linha %d: aviso, %s tem bits de host; o firewall usa %s." % [n, m.get_string(3), _int_para_ip(src[0]) + "/" + str(src[1])])
		regras.append({"linha": n, "acao": acao, "proto": proto, "src": src, "dst": dst, "portas": pts, "texto": l})
	# Regras sombreadas: uma regra anterior já cobre tudo o que esta casaria.
	for j in regras.size():
		for i in j:
			if _cobre(regras[i], regras[j]):
				erros.append("Linha %d: aviso, nunca vai casar; a linha %d já pega tudo isso antes." % [regras[j]["linha"], regras[i]["linha"]])
				break
	return {"regras": regras, "erros": erros}


static func _int_para_ip(v: int) -> String:
	return "%d.%d.%d.%d" % [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255]


static func _cidr_contem(a: Array, b: Array) -> bool:
	return a[1] <= b[1] and no_cidr(b[0], a)


static func _cobre(a: Dictionary, b: Dictionary) -> bool:
	if a["proto"] != "any" and a["proto"] != b["proto"]:
		return false
	if not _cidr_contem(a["src"], b["src"]) or not _cidr_contem(a["dst"], b["dst"]):
		return false
	if a["portas"].is_empty():
		return true
	if b["portas"].is_empty():
		return false
	for fb in b["portas"]:
		var dentro := false
		for fa in a["portas"]:
			dentro = dentro or (fa[0] <= fb[0] and fb[1] <= fa[1])
		if not dentro:
			return false
	return true


## Veredito para um pacote: [ação, linha da regra ou 0 para a política].
func veredito(regras: Array, proto: String, src: String, dst: String, porta: int) -> Array:
	var s := ip_para_int(src)
	var d := ip_para_int(dst)
	for r in regras:
		if r["proto"] != "any" and r["proto"] != proto:
			continue
		if not no_cidr(s, r["src"]) or not no_cidr(d, r["dst"]):
			continue
		if not r["portas"].is_empty():
			var casa := false
			for f in r["portas"]:
				casa = casa or (porta >= f[0] and porta <= f[1])
			if not casa:
				continue
		return [r["acao"], r["linha"]]
	return [_politica.get_item_text(_politica.selected), 0]


func _resultados() -> Array:
	var p := parse(_editor.text)
	var res: Array = []
	for pk in PACOTES:
		var v := veredito(p["regras"], pk[0], pk[1], pk[2], pk[3])
		var bloqueou: bool = v[0] != "ACCEPT"
		var certo: bool = bloqueou == (pk[4] != "ACCEPT")
		res.append({"v": v, "certo": certo})
	return res


func _atualizar() -> void:
	var p := parse(_editor.text)
	var bb := ""
	for e in p["erros"]:
		bb += "[color=%s]%s[/color]\n" % ["#ffc94d" if e.contains("aviso") else "#ff5d5d", e]
	_erros.text = "[font_size=13]" + (bb.strip_edges() if bb != "" else "[color=#5ee38a]%d regra(s) válida(s), nenhum erro.[/color]" % p["regras"].size()) + "[/font_size]"
	var res := _resultados()
	var s := "[font_size=12][table=6]"
	for h in ["Proto", "Origem", "Destino:porta", "Esperado", "Obtido", "Situação"]:
		s += "[cell padding=0,1,12,1][color=#8b95a8]%s[/color][/cell]" % h
	var acertos := 0
	for i in PACOTES.size():
		var pk: Array = PACOTES[i]
		var r: Dictionary = res[i]
		if r["certo"]:
			acertos += 1
		var origem: String = "regra L%d" % r["v"][1] if r["v"][1] > 0 else "política"
		var esperado: String = "ACCEPT" if pk[4] == "ACCEPT" else "bloquear"
		s += "[cell padding=0,1,12,1]%s[/cell][cell padding=0,1,12,1][code]%s[/code][/cell][cell padding=0,1,12,1][code]%s:%d[/code][/cell][cell padding=0,1,12,1]%s[/cell][cell padding=0,1,12,1]%s (%s)[/cell][cell][color=%s]%s[/color] [color=#8b95a8]%s[/color][/cell]" % [
			pk[0], pk[1], pk[2], pk[3], esperado, r["v"][0], origem,
			"#5ee38a" if r["certo"] else "#ff5d5d", "OK" if r["certo"] else "X", pk[5]]
	_tabela.text = s + "[/table][/font_size]"
	_placar.text = "%d de %d pacotes certos" % [acertos, PACOTES.size()]
	if not _valdecir_reagiu and not _editor.text.to_lower().contains("accept any any -> any"):
		_valdecir_reagiu = true
		chat("Valdecir", "Você apagou a minha regra? Ela tinha 17 anos! Era praticamente da família.")


func _mudou_politica(i: int) -> void:
	_atualizar()
	if i == 0:
		chat("Jurema", "Política ACCEPT é lista negra: tudo que você esqueceu fica aberto. E você sempre esquece alguma coisa.")


func avaliar() -> Dictionary:
	var res := _resultados()
	var acertos := 0
	var errados: Array[String] = []
	for i in res.size():
		if res[i]["certo"]:
			acertos += 1
		else:
			errados.append("%s:%d (%s)" % [PACOTES[i][2], PACOTES[i][3], PACOTES[i][5]])
	var nota := proporcao(acertos, PACOTES.size())
	var com := "Pacotes com veredito certo: %d de %d." % [acertos, PACOTES.size()]
	if _politica.selected == 0:
		nota -= 30
		com += " Política padrão ACCEPT: tudo que não foi previsto passa (lista negra). O certo é DROP ou REJECT e liberar só o necessário (lista branca)."
	var liberados := 0
	for i in res.size():
		if PACOTES[i][4] == "ACCEPT" and res[i]["certo"]:
			liberados += 1
	if liberados == 0:
		nota -= 25
		com += " Nenhum tráfego legítimo passa: bloqueou tudo, inclusive o portal. Segurança que derruba o negócio também é incidente."
	if not errados.is_empty():
		com += " Errou: " + ", ".join(errados.slice(0, 4)) + ("..." if errados.size() > 4 else ".")
	else:
		com += " Menor privilégio de rede aplicado: cada liberação tem origem, destino e porta, e o resto cai na política."
	return {"nota": clampi(nota, 0, 100), "comentario": com, "cagada": ""}


func solucao_teste() -> void:
	_editor.text = RESOLVIDO
	_politica.select(1)
	_atualizar()
