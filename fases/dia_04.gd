extends "res://fases/fase.gd"
## Dia 4: SPF e DMARC de tabajara.com.br, com validador e avaliação de check_host() de verdade
## (RFC 7208) sobre um DNS fictício, e alinhamento DMARC (RFC 7489).

const DOMINIO := "tabajara.com.br"
const LIMITE_LOOKUPS := 10
const QUALIF := {"+": "pass", "-": "fail", "~": "softfail", "?": "neutral"}
const POLITICA := {"none": "Caixa de entrada (só relatório)", "quarantine": "Spam (quarentena)", "reject": "Rejeitado"}

# DNS fictício: TXT de cada nome. O TXT de tabajara.com.br é o que a jogadora escrever.
const TXT := {
	"_spf.google.com": "v=spf1 include:_netblocks.google.com include:_netblocks2.google.com include:_netblocks3.google.com ~all",
	"_netblocks.google.com": "v=spf1 ip4:35.190.247.0/24 ip4:64.233.160.0/19 ip4:66.102.0.0/20 ip4:66.249.80.0/20 ip4:72.14.192.0/18 ip4:74.125.0.0/16 ip4:108.177.8.0/21 ip4:173.194.0.0/16 ip4:209.85.128.0/17 ip4:216.58.192.0/19 ip4:216.239.32.0/19 ~all",
	"_netblocks2.google.com": "v=spf1 ip6:2001:4860:4000::/36 ip6:2404:6800:4000::/36 ip6:2607:f8b0:4000::/36 ~all",
	"_netblocks3.google.com": "v=spf1 ip4:172.217.0.0/19 ip4:172.253.56.0/21 ip4:172.253.112.0/20 ~all",
	"spf.megamailcrm.example": "v=spf1 include:mta1.megamailcrm.example include:mta2.megamailcrm.example include:mta3.megamailcrm.example include:mta4.megamailcrm.example include:mta5.megamailcrm.example include:mta6.megamailcrm.example -all",
	"mta1.megamailcrm.example": "v=spf1 ip4:198.51.100.0/28 -all",
	"mta2.megamailcrm.example": "v=spf1 ip4:198.51.100.16/28 -all",
	"mta3.megamailcrm.example": "v=spf1 ip4:198.51.100.32/28 -all",
	"mta4.megamailcrm.example": "v=spf1 ip4:198.51.100.48/28 -all",
	"mta5.megamailcrm.example": "v=spf1 ip6:2001:db8:4d4d::/48 -all",
	"mta6.megamailcrm.example": "v=spf1 ip6:2001:db8:4d4e::/48 -all",
	"megamailcrm.example": "\"Precisa de SPF? Use include:spf.megamailcrm.example. Se estourar o limite de 10 lookups, autorize nossos IPv4: 198.51.100.0/26\"",
	"boleto-facil.example": "v=spf1 ip4:192.0.2.66 -all",
}
const REG_A := {
	"tabajara.com.br": ["192.0.2.10"],
	"www.tabajara.com.br": ["192.0.2.10"],
	"aspmx.l.google.com": ["142.250.150.26"],
	"boletos.tabajara.com.br": ["203.0.113.25"],
}
const REG_MX := {"tabajara.com.br": ["aspmx.l.google.com"]}

# IP, MAIL FROM (envelope), From do cabeçalho, domínio d= da assinatura DKIM válida, legítimo?
const EMAILS := [
	{"rotulo": "Google Workspace (Ana, Financeiro)", "ip": "209.85.220.41", "env": "tabajara.com.br", "from": "financeiro@tabajara.com.br", "dkim": "tabajara.com.br", "legit": true},
	{"rotulo": "MegaMail CRM (newsletter)", "ip": "198.51.100.23", "env": "tabajara.com.br", "from": "novidades@tabajara.com.br", "dkim": "megamailcrm.example", "legit": true},
	{"rotulo": "Servidor de boletos", "ip": "203.0.113.25", "env": "tabajara.com.br", "from": "boletos@tabajara.com.br", "dkim": "", "legit": true},
	{"rotulo": "Golpe: boleto falso", "ip": "198.51.100.200", "env": "tabajara.com.br", "from": "cobranca@tabajara.com.br", "dkim": "", "legit": false},
	{"rotulo": "Golpe: MAIL FROM boleto-facil.example", "ip": "192.0.2.66", "env": "boleto-facil.example", "from": "atendimento@tabajara.com.br", "dkim": "", "legit": false},
]

var _spf: LineEdit
var _dmarc: LineEdit
var _validador: RichTextLabel
var _simulacao: RichTextLabel
var _dig: LineEdit
var _dig_saida: TextEdit
var _avisou_lookup := false
var _avisou_all := false


func _init() -> void:
	dia = 4
	titulo = "O domínio manda spam"
	chamado = ("Escreva o TXT de SPF de [b]tabajara.com.br[/b] e o de [b]_dmarc.tabajara.com.br[/b]. "
		+ "SPF: cobrir os remetentes legítimos, no máximo 10 consultas DNS e barrar o resto no final. "
		+ "DMARC: política e endereço de relatórios (rua). "
		+ "Validador e simulação reagem a cada tecla.")


func montar() -> void:
	var info := painel()
	rotulo("Quem manda e-mail como @tabajara.com.br (levantamento da Jurema):", 14, Estilo.DESTAQUE, info)
	texto_rico("[font_size=13]1. [b]Google Workspace[/b]: caixas de todo mundo. O Google manda usar [code]include:_spf.google.com[/code].\n"
		+ "2. [b]MegaMail CRM[/b]: newsletter do marketing. O fornecedor manda usar [code]include:spf.megamailcrm.example[/code].\n"
		+ "3. [b]Servidor de boletos[/b] (boletos.tabajara.com.br): manda direto do IP [code]203.0.113.25[/code].\n"
		+ "4. [b]Multifuncional do 3º andar[/b] (10.20.3.40): envia scan pelo smtp-relay.gmail.com, autenticada na conta do Workspace.[/font_size]", info)

	var l1 := linha()
	var r1 := rotulo("TXT tabajara.com.br", 14, Estilo.TEXTO_FRACO, l1)
	r1.custom_minimum_size = Vector2(225, 0)
	_spf = campo("v=spf1 ... -all", l1)
	var l2 := linha()
	var r2 := rotulo("TXT _dmarc.tabajara.com.br", 14, Estilo.TEXTO_FRACO, l2)
	r2.custom_minimum_size = Vector2(225, 0)
	_dmarc = campo("v=DMARC1; p=...; rua=mailto:...", l2)
	_spf.text_changed.connect(func(_t): _atualizar())
	_dmarc.text_changed.connect(func(_t): _atualizar())

	_validador = texto_rico("")

	var sim := painel()
	rotulo("Simulação: 5 e-mails chegando agora no Gmail de um segurado", 14, Estilo.CIANO, sim)
	_simulacao = texto_rico("", sim)

	var dg := painel()
	var ld := linha(dg)
	rotulo("Terminal:  dig +short TXT", 14, Estilo.CIANO, ld).autowrap_mode = TextServer.AUTOWRAP_OFF
	_dig = campo("nome, ex.: spf.megamailcrm.example", ld)
	_dig.text_submitted.connect(func(_t): _rodar_dig())
	botao("dig", _rodar_dig, ld)
	_dig_saida = bloco_mono("", 110, dg)
	_dig_saida.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_dig_saida.add_theme_font_size_override("font_size", 12)

	_atualizar()
	chat("Jurema", "SPF diz quais IPs podem mandar e-mail pelo domínio. DMARC diz o que fazer quando falha, e exige que o domínio do From bata com o que foi validado.")
	chat("Valdecir", "Coloca aquele +all que eu vi num fórum. Mais é sempre melhor que menos.")
	aviso("Dica: cada include, a, mx, ptr, exists e redirect custa uma consulta DNS, inclusive os que estão dentro dos includes.")


# ---------------------------------------------------------------- IPv4 e domínios

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


static func no_cidr(ip: String, rede: String, prefixo: int) -> bool:
	var a := ip_para_int(ip)
	var b := ip_para_int(rede)
	if a < 0 or b < 0:
		return false
	if prefixo == 0:
		return true
	var mascara := (0xFFFFFFFF << (32 - prefixo)) & 0xFFFFFFFF
	return (a & mascara) == (b & mascara)


static func dominio_org(d: String) -> String:
	var p := d.to_lower().split(".")
	var n := 3 if d.to_lower().ends_with(".com.br") else 2
	if p.size() <= n:
		return d.to_lower()
	return ".".join(p.slice(p.size() - n))


static func dominio_valido(d: String) -> bool:
	return RegEx.create_from_string("^([A-Za-z0-9_]([A-Za-z0-9_-]{0,62})\\.)+[A-Za-z]{2,}$").search(d) != null


# ---------------------------------------------------------------- SPF

func _txt(nome: String) -> String:
	if nome.to_lower() == DOMINIO:
		return _spf.text.strip_edges()
	return TXT.get(nome.to_lower(), "")


## Faz o parse de um registro SPF. Devolve {"termos": [...], "erros": [...], "avisos": [...]}.
func parse_spf(reg: String) -> Dictionary:
	var r := {"termos": [], "erros": [], "avisos": []}
	var partes: Array = []
	for p in reg.strip_edges().split(" ", false):
		partes.append(p)
	if partes.is_empty():
		r["erros"].append("Registro vazio.")
		return r
	if partes[0] != "v=spf1":
		r["erros"].append("O registro precisa começar exatamente com v=spf1 (achei \"%s\")." % partes[0])
		return r
	var viu_all := false
	var redirects := 0
	for i in range(1, partes.size()):
		var t: String = partes[i]
		if viu_all:
			r["avisos"].append("\"%s\" vem depois do all e nunca será avaliado." % t)
		var low := t.to_lower()
		# Modificadores
		if low.begins_with("redirect=") or low.begins_with("exp="):
			var alvo := t.substr(t.find("=") + 1)
			if not dominio_valido(alvo):
				r["erros"].append("Domínio inválido em %s." % t)
				continue
			if low.begins_with("redirect="):
				redirects += 1
				if redirects > 1:
					r["erros"].append("redirect= aparece mais de uma vez.")
				r["termos"].append({"q": "", "mec": "redirect", "arg": alvo.to_lower(), "cidr": 32})
			continue
		var q := "+"
		if t.length() > 0 and t[0] in ["+", "-", "~", "?"]:
			q = t[0]
			t = t.substr(1)
			low = t.to_lower()
		var mec := low
		var arg := ""
		var sep := low.find(":")
		var barra := low.find("/")
		if sep >= 0:
			mec = low.substr(0, sep)
			arg = t.substr(sep + 1)
		elif barra >= 0:
			mec = low.substr(0, barra)
			arg = t.substr(barra)
		var termo := {"q": q, "mec": mec, "arg": "", "cidr": 32, "texto": partes[i]}
		match mec:
			"all":
				if arg != "":
					r["erros"].append("all não aceita argumento: %s." % partes[i])
					continue
				viu_all = true
			"ip4":
				var ip := arg
				var pre := 32
				if arg.contains("/"):
					ip = arg.get_slice("/", 0)
					var ps := arg.get_slice("/", 1)
					if not ps.is_valid_int() or int(ps) < 0 or int(ps) > 32:
						r["erros"].append("Prefixo inválido em %s (precisa ser 0 a 32)." % partes[i])
						continue
					pre = int(ps)
				if ip_para_int(ip) < 0:
					r["erros"].append("Endereço IPv4 inválido em %s." % partes[i])
					continue
				termo["arg"] = ip
				termo["cidr"] = pre
				if pre < 16:
					r["avisos"].append("%s autoriza %d endereços. Isso é quase um +all." % [partes[i], 1 << (32 - pre)])
				if ip.begins_with("10.") or ip.begins_with("192.168.") or RegEx.create_from_string("^172\\.(1[6-9]|2[0-9]|3[01])\\.").search(ip) != null:
					r["avisos"].append("%s é IP privado: o servidor de destino nunca vê esse endereço. Não serve para nada no SPF." % partes[i])
			"ip6":
				if arg == "" or not arg.contains(":"):
					r["erros"].append("Endereço IPv6 inválido em %s." % partes[i])
					continue
				termo["arg"] = arg
			"include", "exists":
				if not dominio_valido(arg):
					r["erros"].append("%s precisa de um domínio válido (%s)." % [mec, partes[i]])
					continue
				termo["arg"] = arg.to_lower()
			"a", "mx":
				var d := arg
				if d.begins_with("/"):
					d = ""
				elif d.contains("/"):
					d = d.get_slice("/", 0)
				if d != "" and not dominio_valido(d):
					r["erros"].append("Domínio inválido em %s." % partes[i])
					continue
				termo["arg"] = d.to_lower()
			"ptr":
				r["avisos"].append("ptr é lento, pouco confiável e desaconselhado pela RFC 7208. Evite.")
				termo["arg"] = arg.to_lower()
			_:
				r["erros"].append("Mecanismo desconhecido: \"%s\" (PermError)." % partes[i])
				continue
		r["termos"].append(termo)
	return r


## Conta as consultas DNS que o registro de `nome` exige, descendo pelos includes e redirects.
func contar_lookups(nome: String, profundidade := 0) -> int:
	if profundidade > 10:
		return 99
	var reg := _txt(nome)
	if not reg.begins_with("v=spf1"):
		return 0
	var total := 0
	for t in parse_spf(reg)["termos"]:
		match t["mec"]:
			"include", "redirect":
				total += 1 + contar_lookups(t["arg"], profundidade + 1)
			"a", "mx", "ptr", "exists":
				total += 1
	return total


## check_host() da RFC 7208: pass, fail, softfail, neutral, none, permerror.
func check_host(ip: String, nome: String, profundidade := 0) -> String:
	if profundidade > 10:
		return "permerror"
	var reg := _txt(nome)
	if not reg.begins_with("v=spf1"):
		return "none"
	var p := parse_spf(reg)
	if not p["erros"].is_empty():
		return "permerror"
	var redirect := ""
	for t in p["termos"]:
		var casou := false
		match t["mec"]:
			"all":
				casou = true
			"ip4":
				casou = no_cidr(ip, t["arg"], t["cidr"])
			"a":
				for end in REG_A.get(t["arg"] if t["arg"] != "" else nome, []):
					casou = casou or end == ip
			"mx":
				for mx in REG_MX.get(t["arg"] if t["arg"] != "" else nome, []):
					for end in REG_A.get(mx, []):
						casou = casou or end == ip
			"exists":
				casou = REG_A.has(t["arg"])
			"include":
				var sub := check_host(ip, t["arg"], profundidade + 1)
				if sub == "pass":
					casou = true
				elif sub == "permerror" or sub == "none":
					return "permerror"
			"redirect":
				redirect = t["arg"]
		if casou:
			return QUALIF[t["q"]]
	if redirect != "":
		var r := check_host(ip, redirect, profundidade + 1)
		return "permerror" if r == "none" else r
	return "neutral"


func _all_final(p: Dictionary) -> String:
	for t in p["termos"]:
		if t["mec"] == "all":
			return t["q"]
	return ""


## Resultado SPF de um e-mail, já considerando o estouro de lookups.
func resultado_spf(e: Dictionary) -> String:
	var dom: String = e["env"]
	if dom == DOMINIO:
		var p := parse_spf(_spf.text)
		if _spf.text.strip_edges() == "":
			return "none"
		if not p["erros"].is_empty() or contar_lookups(DOMINIO) > LIMITE_LOOKUPS:
			return "permerror"
	return check_host(e["ip"], dom)


# ---------------------------------------------------------------- DMARC

func parse_dmarc(reg: String) -> Dictionary:
	var r := {"tags": {}, "erros": [], "avisos": []}
	var s := reg.strip_edges()
	if s == "":
		r["erros"].append("Registro vazio.")
		return r
	var ordem: Array[String] = []
	for parte in s.split(";", false):
		var p := parte.strip_edges()
		if p == "":
			continue
		if not p.contains("="):
			r["erros"].append("Tag sem valor: \"%s\"." % p)
			continue
		var k := p.get_slice("=", 0).strip_edges().to_lower()
		var v := p.substr(p.find("=") + 1).strip_edges()
		ordem.append(k)
		r["tags"][k] = v
	if ordem.is_empty() or ordem[0] != "v" or r["tags"].get("v", "") != "DMARC1":
		r["erros"].append("A primeira tag precisa ser v=DMARC1 (exatamente assim).")
	if not r["tags"].has("p"):
		r["erros"].append("Falta a tag obrigatória p= (none, quarantine ou reject).")
	elif not (r["tags"]["p"] in ["none", "quarantine", "reject"]):
		r["erros"].append("p=%s não existe. Use none, quarantine ou reject." % r["tags"]["p"])
	elif ordem.size() > 1 and ordem[1] != "p":
		r["avisos"].append("A RFC 7489 pede o p= logo depois do v=.")
	var email := RegEx.create_from_string("^[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,}$")
	for k in ["rua", "ruf"]:
		if r["tags"].has(k):
			for uri in r["tags"][k].split(",", false):
				var u: String = uri.strip_edges()
				if not u.to_lower().begins_with("mailto:"):
					r["erros"].append("%s precisa de URIs mailto: (achei \"%s\")." % [k, u])
					continue
				var end := u.substr(7).get_slice("!", 0)
				if email.search(end) == null:
					r["erros"].append("Endereço inválido em %s: %s." % [k, end])
				elif dominio_org(end.get_slice("@", 1)) != DOMINIO:
					r["avisos"].append("%s em domínio externo: o domínio %s precisa publicar a autorização %s._report._dmarc.%s." % [k, end.get_slice("@", 1), DOMINIO, end.get_slice("@", 1)])
	if r["tags"].has("pct"):
		var pct: String = r["tags"]["pct"]
		if not pct.is_valid_int() or int(pct) < 0 or int(pct) > 100:
			r["erros"].append("pct precisa ser inteiro de 0 a 100.")
		elif int(pct) < 100:
			r["avisos"].append("pct=%s: a política só vale para parte das mensagens." % pct)
	if r["tags"].has("sp") and not (r["tags"]["sp"] in ["none", "quarantine", "reject"]):
		r["erros"].append("sp=%s inválido." % r["tags"]["sp"])
	for k in ["adkim", "aspf"]:
		if r["tags"].has(k) and not (r["tags"][k] in ["r", "s"]):
			r["erros"].append("%s aceita só r (relaxado) ou s (estrito)." % k)
	for k in r["tags"]:
		if not (k in ["v", "p", "rua", "ruf", "pct", "sp", "adkim", "aspf", "fo", "rf", "ri", "np"]):
			r["avisos"].append("Tag desconhecida \"%s\": os receptores vão ignorar." % k)
	return r


func _dmarc_valido() -> Dictionary:
	var d := parse_dmarc(_dmarc.text)
	return d if d["erros"].is_empty() else {}


func destino(e: Dictionary) -> Dictionary:
	var spf := resultado_spf(e)
	var dom_from: String = e["from"].get_slice("@", 1)
	var spf_alinhado := spf == "pass" and dominio_org(e["env"]) == dominio_org(dom_from)
	var dkim_alinhado: bool = e["dkim"] != "" and dominio_org(e["dkim"]) == dominio_org(dom_from)
	var d := _dmarc_valido()
	var res := {"spf": spf, "dmarc": "-", "fim": ""}
	if d.is_empty():
		res["dmarc"] = "sem política"
		match spf:
			"pass": res["fim"] = "Caixa de entrada"
			"fail": res["fim"] = "Provável rejeição"
			"softfail": res["fim"] = "Talvez spam"
			"permerror": res["fim"] = "Imprevisível"
			_: res["fim"] = "Caixa de entrada"
		return res
	if spf_alinhado or dkim_alinhado:
		res["dmarc"] = "pass"
		res["fim"] = "Caixa de entrada"
	else:
		res["dmarc"] = "fail"
		res["fim"] = POLITICA[d["tags"]["p"]]
	return res


# ---------------------------------------------------------------- interface

func _atualizar() -> void:
	var p := parse_spf(_spf.text)
	var bb := "[font_size=13]"
	if _spf.text.strip_edges() == "":
		bb += "[color=#8b95a8]SPF: (vazio)[/color]\n"
	else:
		var n := contar_lookups(DOMINIO) if p["erros"].is_empty() else 0
		for er in p["erros"]:
			bb += "[color=#ff5d5d]SPF ERRO: %s[/color]\n" % er
		if p["erros"].is_empty():
			var cor := "#5ee38a" if n <= LIMITE_LOOKUPS else "#ff5d5d"
			bb += "[color=%s]SPF: sintaxe OK. Consultas DNS: %d de %d%s[/color]\n" % [cor, n, LIMITE_LOOKUPS, "" if n <= LIMITE_LOOKUPS else " (PermError!)"]
			if n > LIMITE_LOOKUPS and not _avisou_lookup:
				_avisou_lookup = true
				chat("Jurema", "Estourou os 10 lookups. Quando isso acontece o SPF inteiro vira PermError, e PermError não protege ninguém. Olha o TXT do fornecedor.")
			var q := _all_final(p)
			if q == "":
				bb += "[color=#ffc94d]SPF: sem all no final. Quem não casar fica neutral (não barra nada).[/color]\n"
			elif q == "+":
				bb += "[color=#ff5d5d]SPF: +all autoriza QUALQUER servidor do planeta a mandar como tabajara.com.br![/color]\n"
				if not _avisou_all:
					_avisou_all = true
					chat("Jurema", "+all? É literalmente assinar embaixo do golpe. Tira isso antes de alguém ver.")
			elif q == "?":
				bb += "[color=#ffc94d]SPF: ?all é neutro. Não ajuda a barrar nada.[/color]\n"
		for av in p["avisos"]:
			bb += "[color=#ffc94d]SPF aviso: %s[/color]\n" % av
	if _dmarc.text.strip_edges() == "":
		bb += "[color=#8b95a8]DMARC: (vazio)[/color]"
	else:
		var d := parse_dmarc(_dmarc.text)
		for er in d["erros"]:
			bb += "[color=#ff5d5d]DMARC ERRO: %s[/color]\n" % er
		if d["erros"].is_empty():
			bb += "[color=#5ee38a]DMARC: sintaxe OK, p=%s[/color]\n" % d["tags"]["p"]
			if d["tags"]["p"] == "none":
				bb += "[color=#ffc94d]DMARC: p=none só monitora. O golpe continua chegando.[/color]\n"
			if not d["tags"].has("rua"):
				bb += "[color=#ffc94d]DMARC: sem rua= você nunca vai saber quem está usando seu domínio.[/color]\n"
		for av in d["avisos"]:
			bb += "[color=#ffc94d]DMARC aviso: %s[/color]\n" % av
	_validador.text = bb.strip_edges() + "[/font_size]"

	var s := "[font_size=13][table=5][cell padding=0,1,14,1][color=#8b95a8]E-mail[/color][/cell][cell padding=0,1,14,1][color=#8b95a8]IP[/color][/cell][cell padding=0,1,14,1][color=#8b95a8]SPF[/color][/cell][cell padding=0,1,14,1][color=#8b95a8]DMARC[/color][/cell][cell][color=#8b95a8]Destino[/color][/cell]"
	for e in EMAILS:
		var r := destino(e)
		var cor_spf := "#5ee38a" if r["spf"] == "pass" else ("#ff5d5d" if r["spf"] in ["fail", "permerror"] else "#ffc94d")
		var bom: bool = (r["fim"] == "Caixa de entrada") == e["legit"]
		var cor_fim := "#5ee38a" if bom else "#ff5d5d"
		s += "[cell padding=0,1,14,1]%s[/cell][cell padding=0,1,14,1][code]%s[/code][/cell][cell padding=0,1,14,1][color=%s]%s[/color][/cell][cell padding=0,1,14,1]%s[/cell][cell][color=%s]%s[/color][/cell]" % [
			e["rotulo"], e["ip"], cor_spf, r["spf"], r["dmarc"], cor_fim, r["fim"]]
	_simulacao.text = s + "[/table][/font_size]"


func _rodar_dig() -> void:
	var nome := _dig.text.strip_edges().trim_suffix(".")
	for pre in ["dig +short txt ", "dig txt ", "dig "]:
		if nome.to_lower().begins_with(pre):
			nome = nome.substr(pre.length())
	var saida := "$ dig +short TXT %s\n" % nome
	var reg := _txt(nome)
	if nome.to_lower() == DOMINIO:
		saida += "\"google-site-verification=Xq3v8TabajaraKk91lPz0\"\n"
		if reg != "":
			saida += "\"%s\"\n" % reg
	elif nome.to_lower() == "_dmarc." + DOMINIO:
		if _dmarc.text.strip_edges() != "":
			saida += "\"%s\"\n" % _dmarc.text.strip_edges()
	elif reg != "":
		saida += (reg if reg.begins_with("\"") else "\"%s\"" % reg) + "\n"
	if saida.count("\n") == 1:
		saida += "(nenhuma resposta)\n"
	_dig_saida.text = saida + _dig_saida.text
	_dig.text = ""


func avaliar() -> Dictionary:
	var nota := 0
	var com: Array[String] = []
	var cagada := ""
	var p := parse_spf(_spf.text)
	var spf_ok: bool = _spf.text.strip_edges() != "" and p["erros"].is_empty()
	var n := contar_lookups(DOMINIO) if spf_ok else 0
	if not spf_ok:
		com.append("SPF ausente ou com erro de sintaxe (vira PermError ou none).")
	elif n > LIMITE_LOOKUPS:
		com.append("SPF com %d consultas DNS: acima de 10 é PermError. Troque o include pesado do fornecedor pelos IPs dele (ip4:198.51.100.0/26)." % n)
	else:
		nota += 20
	var cobertos := 0
	for i in 3:
		if resultado_spf(EMAILS[i]) == "pass":
			cobertos += 1
			nota += 10
		else:
			com.append("%s não passa no SPF." % EMAILS[i]["rotulo"])
	if spf_ok:
		match _all_final(p):
			"-":
				nota += 10
			"~":
				nota += 8
				com.append("~all funciona (softfail), mas com DMARC em reject o -all deixa a intenção mais clara.")
			"+":
				cagada = "Você publicou +all: agora qualquer servidor do mundo passa no SPF como tabajara.com.br. O golpista do boleto mandou um e-mail de agradecimento. Com SPF pass."
				com.append("+all autoriza todo mundo.")
			_:
				com.append("O SPF precisa terminar com -all (ou ~all) para barrar quem não está na lista.")
	if spf_ok and resultado_spf(EMAILS[3]) == "pass" and cagada == "":
		nota -= 15
		com.append("O IP do golpista (198.51.100.200) passa no seu SPF: a faixa autorizada está larga demais.")
	if spf_ok:
		for av in p["avisos"]:
			if av.contains("IP privado"):
				nota -= 3
				com.append("IP privado no SPF não serve para nada: a multifuncional já sai pelo relay do Google.")
				break
	var d := parse_dmarc(_dmarc.text)
	if _dmarc.text.strip_edges() != "" and d["erros"].is_empty():
		nota += 10
		match d["tags"]["p"]:
			"reject":
				nota += 20
			"quarantine":
				nota += 15
				com.append("DMARC em quarantine manda o golpe para o spam; reject nem deixa entrar.")
			"none":
				nota += 5
				com.append("DMARC p=none só gera relatório: é o primeiro passo, não a proteção.")
		if d["tags"].has("rua"):
			nota += 10
		else:
			com.append("Faltou rua=mailto: para receber os relatórios agregados.")
	else:
		com.append("DMARC ausente ou inválido: sem ele, ninguém sabe o que fazer quando o SPF falha, e o From do cabeçalho nem é checado.")
	nota = clampi(nota, 0, 100)
	if cagada != "":
		nota = mini(nota, 10)
	var comentario := ""
	if com.is_empty():
		comentario = "Domínio blindado: SPF dentro do limite de 10 consultas, cobrindo os 3 remetentes reais, -all no fim e DMARC barrando o From falsificado (até o golpe com envelope de outro domínio, porque não alinha)."
	else:
		comentario = "Remetentes cobertos: %d de 3. " % cobertos + " ".join(com)
	return {"nota": nota, "comentario": comentario, "cagada": cagada}


func solucao_teste() -> void:
	_spf.text = "v=spf1 include:_spf.google.com ip4:198.51.100.0/26 ip4:203.0.113.25 -all"
	_dmarc.text = "v=DMARC1; p=reject; rua=mailto:dmarc@tabajara.com.br; adkim=r; aspf=r"
	_atualizar()
