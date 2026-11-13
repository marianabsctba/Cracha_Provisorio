extends "res://fases/fase.gd"
## Dia 13: certificado vencido. Montar a cadeia certa, gerar o CSR direito e
## impedir que o lembrete dependa do calendário de um estagiário.

const AGORA := "2026-11-16 09:02:00"
const HOSTS := ["tabajara.com.br", "www.tabajara.com.br", "portal.tabajara.com.br"]
const RAIZ_CONFIAVEL := "C=BR, O=Certifica Brasil S.A., CN=Certifica Brasil Root CA G2"
const CHAVES := ["RSA 1024", "RSA 2048", "RSA 3072", "RSA 4096", "ECDSA P-256", "ECDSA P-384"]

const CERTS := [
	{"id": "A", "arquivo": "tabajara_2026.crt", "rotulo": "www.tabajara.com.br (emitido hoje)",
	 "serial": "06:3f:a1:9c:22:7e:04:b8:51:d0:9a:3e:71:c4:2b:88",
	 "subject": "C=BR, ST=Paraná, L=Curitiba, O=Tabajara Seguros S.A., CN=www.tabajara.com.br",
	 "issuer": "C=BR, O=Certifica Brasil S.A., CN=Certifica Brasil TLS RSA CA 2025",
	 "nb": "2026-11-16 08:40:00", "na": "2027-06-03 23:59:59", "ca": false, "pathlen": -1,
	 "ku": "Digital Signature, Key Encipherment", "eku": "TLS Web Server Authentication",
	 "san": ["tabajara.com.br", "www.tabajara.com.br"], "chave": "RSA 2048", "sig": "sha256WithRSAEncryption"},
	{"id": "B", "arquivo": "tabajara_2025.crt", "rotulo": "www.tabajara.com.br (o do sábado)",
	 "serial": "0b:12:77:e0:4c:93:a8:1f:6d:02:c5:9e:3b:70:aa:14",
	 "subject": "C=BR, ST=Paraná, L=Curitiba, O=Tabajara Seguros S.A., CN=www.tabajara.com.br",
	 "issuer": "C=BR, O=Certifica Brasil S.A., CN=Certifica Brasil TLS RSA CA 2025",
	 "nb": "2025-10-12 00:00:00", "na": "2026-11-14 23:59:59", "ca": false, "pathlen": -1,
	 "ku": "Digital Signature, Key Encipherment", "eku": "TLS Web Server Authentication",
	 "san": ["tabajara.com.br", "www.tabajara.com.br", "portal.tabajara.com.br"], "chave": "RSA 2048", "sig": "sha256WithRSAEncryption"},
	{"id": "C", "arquivo": "intermediario.crt", "rotulo": "Certifica Brasil TLS RSA CA 2025",
	 "serial": "5a:c0:13:9f:e2:44:07:bd",
	 "subject": "C=BR, O=Certifica Brasil S.A., CN=Certifica Brasil TLS RSA CA 2025",
	 "issuer": "C=BR, O=Certifica Brasil S.A., CN=Certifica Brasil Root CA G2",
	 "nb": "2025-01-15 00:00:00", "na": "2035-01-14 23:59:59", "ca": true, "pathlen": 0,
	 "ku": "Certificate Sign, CRL Sign", "eku": "TLS Web Server Authentication, TLS Web Client Authentication",
	 "san": [], "chave": "RSA 4096", "sig": "sha384WithRSAEncryption"},
	{"id": "D", "arquivo": "intermediario_novo(1).crt", "rotulo": "Certifica Brasil TLS RSA CA 2025 (achado no Google)",
	 "serial": "1d:9e:60:3a:b7:c8:20:05",
	 "subject": "C=BR, O=Certifika Brazil Ltda, CN=Certifica Brasil TLS RSA CA 2025",
	 "issuer": "C=BR, O=Certifika Brazil Ltda, CN=Certifika Global Root R1",
	 "nb": "2024-03-01 00:00:00", "na": "2026-09-30 23:59:59", "ca": true, "pathlen": 0,
	 "ku": "Certificate Sign, CRL Sign", "eku": "TLS Web Server Authentication",
	 "san": [], "chave": "RSA 2048", "sig": "sha256WithRSAEncryption"},
	{"id": "R", "arquivo": "raiz_g2.crt", "rotulo": "Certifica Brasil Root CA G2 (raiz)",
	 "serial": "02:00:7a:31",
	 "subject": RAIZ_CONFIAVEL, "issuer": RAIZ_CONFIAVEL,
	 "nb": "2020-06-01 00:00:00", "na": "2045-05-31 23:59:59", "ca": true, "pathlen": -1,
	 "ku": "Certificate Sign, CRL Sign", "eku": "",
	 "san": [], "chave": "RSA 4096", "sig": "sha384WithRSAEncryption"},
	{"id": "K", "arquivo": "kaua_definitivo_FINAL.crt", "rotulo": "tabajara-dev (autoassinado do Kauã)",
	 "serial": "01",
	 "subject": "C=BR, O=Kaua Testes, CN=tabajara-dev",
	 "issuer": "C=BR, O=Kaua Testes, CN=tabajara-dev",
	 "nb": "2024-01-01 00:00:00", "na": "2124-01-01 00:00:00", "ca": true, "pathlen": -1,
	 "ku": "", "eku": "",
	 "san": ["localhost", "kaua-pc", "*.com.br"], "chave": "RSA 1024", "sig": "sha1WithRSAEncryption"},
]

const MEDIDAS := [
	["Renovação automática via ACME (certbot, acme.sh ou o cliente do balanceador), com teste da renovação e alerta se falhar", true],
	["Monitorar a validade de todos os certificados (inventário + alerta em 30, 14 e 7 dias) numa lista da equipe, não no calendário de uma pessoa", true],
	["Comprar um certificado de 10 anos para nunca mais passar por isso", false],
	["Instalar o autoassinado do Kauã, que vale até 2124", false],
	["Mandar e-mail para os clientes ensinando a clicar em \"Avançado > Continuar mesmo assim\"", false],
	["Colocar o lembrete no calendário do próximo estagiário", false],
]

var _abas: TabContainer
var _visor: TextEdit
var _cadeia: Array = []
var _lista_cadeia: Label
var _resultado_cadeia: RichTextLabel
var _cn: LineEdit
var _sans: TextEdit
var _chave: OptionButton
var _comando: TextEdit
var _analise_csr: RichTextLabel
var _medidas: Array = []


func _init() -> void:
	dia = 13
	titulo = "Certificado vencido"
	chamado = ("Três passos. [b]1)[/b] Monte a cadeia que o servidor deve enviar, na ordem certa, e valide (Issuer de um = Subject do próximo, todos dentro da validade em "
		+ "[b]16/11/2026 09:02[/b]; a raiz fica no navegador e não precisa ir). [b]2)[/b] O certificado de hoje esqueceu o [b]portal[/b]: preencha o CSR da reemissão "
		+ "(o navegador só olha o SAN). [b]3)[/b] Escolha o que impede a repetição. Nota por passo.")


func montar() -> void:
	_abas = TabContainer.new()
	_abas.custom_minimum_size = Vector2(0, 400)
	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_child(_abas)
	_montar_cadeia(_aba("1. Cadeia"))
	_montar_csr(_aba("2. CSR da reemissão"))
	_montar_medidas(_aba("3. Nunca mais"))
	chat("Valdecir", "Comprei um certificado novo às 8h40 com o cartão corporativo. Está na pasta. Junto com uns outros que achei. Instala aí.")
	chat("Kauã", "Tem o meu também, kaua_definitivo_FINAL.crt. Vale até 2124. De nada.")
	chat("Jurema", "Abre cada um e lê Issuer, Subject e as datas. Certificado é igual crachá: tem que ver quem assinou.")


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


# ---------------------------------------------------------------- passo 1

func _montar_cadeia(v: VBoxContainer) -> void:
	var h := linha(v)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var esq := VBoxContainer.new()
	esq.custom_minimum_size = Vector2(250, 0)
	h.add_child(esq)
	rotulo("Pasta C:\\certs\\ (clique para abrir)", 13, Estilo.TEXTO_FRACO, esq)
	var il := ItemList.new()
	il.custom_minimum_size = Vector2(250, 156)
	il.add_theme_font_size_override("font_size", 13)
	for c in CERTS:
		il.add_item("%s  %s" % [c["id"], c["arquivo"]])
	il.select(1)
	il.item_selected.connect(func(i): _abrir(CERTS[i]["id"]))
	esq.add_child(il)
	var add := botao("Adicionar o aberto à cadeia", _adicionar, esq)
	add.add_theme_color_override("font_color", Estilo.CIANO)
	var lh := linha(esq)
	botao("Desfazer último", func():
		if not _cadeia.is_empty():
			_cadeia.pop_back()
		_mostrar_cadeia(), lh)
	botao("Validar", _validar_cadeia, lh)
	_lista_cadeia = rotulo("", 13, Estilo.TEXTO, esq)
	_visor = bloco_mono("", 240, h)
	_visor.add_theme_font_size_override("font_size", 12)
	_visor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_resultado_cadeia = texto_rico("", v)
	_resultado_cadeia.add_theme_font_size_override("normal_font_size", 13)
	_resultado_cadeia.add_theme_font_size_override("bold_font_size", 13)
	_abrir("B")
	_mostrar_cadeia()


var _aberto := "B"


func _abrir(id: String) -> void:
	_aberto = id
	_visor.text = "$ openssl x509 -in %s -noout -text\n%s" % [_cert(id)["arquivo"], texto_cert(_cert(id))]
	_visor.scroll_vertical = 0


func _adicionar() -> void:
	if _cadeia.size() >= 4:
		aviso("Quatro já está bom. Cadeia não é varal.", Estilo.ALERTA)
		return
	_cadeia.append(_aberto)
	_mostrar_cadeia()


func _mostrar_cadeia() -> void:
	var t := "Cadeia que o servidor vai enviar:\n"
	if _cadeia.is_empty():
		t += "  (vazia)"
	for i in _cadeia.size():
		t += "  %d: %s\n" % [i, _cert(_cadeia[i])["rotulo"]]
	_lista_cadeia.text = t


func _validar_cadeia() -> void:
	var r := verificar(_cadeia)
	var cor := "#5ee38a" if r["ok"] else "#ff5d5d"
	_resultado_cadeia.text = "[color=#8b95a8]$ openssl verify -CAfile raizes_do_navegador.pem -untrusted cadeia.pem folha.pem[/color]\n" \
		+ "\n".join(r["linhas"]) + "\n[color=%s][b]%s[/b][/color]" % [cor, "Cadeia válida." if r["ok"] else "Cadeia inválida."]
	if r["ok"]:
		chat("Sistema", "nginx -t: syntax is ok. Recarregado. Cadeado verde em www.tabajara.com.br.")


static func _cert(id: String) -> Dictionary:
	for c in CERTS:
		if c["id"] == id:
			return c
	return {}


static func _ts(s: String) -> int:
	return Time.get_unix_time_from_datetime_string(s.replace(" ", "T"))


static func _data_openssl(s: String) -> String:
	var meses := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var d := Time.get_datetime_dict_from_datetime_string(s.replace(" ", "T"), false)
	return "%s %2d %02d:%02d:%02d %d GMT" % [meses[int(d["month"]) - 1], d["day"], d["hour"], d["minute"], d["second"], d["year"]]


static func texto_cert(c: Dictionary) -> String:
	var t := "Certificate:\n    Data:\n        Version: 3 (0x2)\n        Serial Number:\n            %s\n" % c["serial"]
	t += "        Signature Algorithm: %s\n        Issuer: %s\n" % [c["sig"], c["issuer"]]
	t += "        Validity\n            Not Before: %s\n            Not After : %s\n" % [_data_openssl(c["nb"]), _data_openssl(c["na"])]
	t += "        Subject: %s\n        Subject Public Key Info:\n" % c["subject"]
	var chave: String = c["chave"]
	if chave.begins_with("ECDSA"):
		t += "            Public Key Algorithm: id-ecPublicKey\n                Public-Key: (256 bit)\n"
	else:
		t += "            Public Key Algorithm: rsaEncryption\n                Public-Key: (%s bit)\n                Exponent: 65537 (0x10001)\n" % chave.split(" ")[1]
	t += "        X509v3 extensions:\n            X509v3 Basic Constraints: critical\n                CA:%s%s\n" % [
		"TRUE" if c["ca"] else "FALSE", (", pathlen:%d" % c["pathlen"]) if int(c["pathlen"]) >= 0 else ""]
	if c["ku"] != "":
		t += "            X509v3 Key Usage: critical\n                %s\n" % c["ku"]
	if c["eku"] != "":
		t += "            X509v3 Extended Key Usage:\n                %s\n" % c["eku"]
	if not c["san"].is_empty():
		var dns := []
		for s in c["san"]:
			dns.append("DNS:" + s)
		t += "            X509v3 Subject Alternative Name:\n                %s\n" % ", ".join(dns)
	if c["subject"] != c["issuer"]:
		t += "            Authority Information Access:\n                CA Issuers - URI:http://repo.certificabrasil.example/tlsrsa2025.crt\n"
	return t


## Verificação de cadeia de verdade sobre os dados dos certificados.
static func verificar(cadeia: Array) -> Dictionary:
	var linhas: Array = []
	var ok := true
	if cadeia.is_empty():
		return {"ok": false, "linhas": ["error: nenhum certificado enviado. O servidor está mandando um silêncio constrangedor."]}
	var agora := _ts(AGORA)
	for i in cadeia.size():
		var c := _cert(cadeia[i])
		var cn: String = c["subject"].get_slice("CN=", 1)
		if agora < _ts(c["nb"]):
			linhas.append("depth=%d %s: error 9: certificate is not yet valid" % [i, cn])
			ok = false
		elif agora > _ts(c["na"]):
			linhas.append("depth=%d %s: error 10: certificate has expired (notAfter %s)" % [i, cn, c["na"]])
			ok = false
		else:
			linhas.append("depth=%d %s: dentro da validade" % [i, cn])
		if i == 0:
			if c["ca"]:
				linhas.append("depth=0: o primeiro da cadeia é uma AC, não um certificado de servidor (folha)")
				ok = false
			if not cobre(c["san"], "www.tabajara.com.br"):
				linhas.append("depth=0: error 62: hostname mismatch (o SAN não cobre www.tabajara.com.br)")
				ok = false
		else:
			var anterior := _cert(cadeia[i - 1])
			if anterior["issuer"] != c["subject"]:
				linhas.append("depth=%d: error 20: o Issuer do anterior (%s) não é o Subject deste (%s)" % [i, anterior["issuer"], c["subject"]])
				ok = false
			if not c["ca"]:
				linhas.append("depth=%d: error 24: invalid CA certificate (CA:FALSE)" % i)
				ok = false
	var ultimo := _cert(cadeia[-1])
	if ultimo["subject"] == ultimo["issuer"]:
		if ultimo["subject"] != RAIZ_CONFIAVEL:
			linhas.append("error 18/19: self-signed certificate in certificate chain (ninguém confia em %s)" % ultimo["subject"].get_slice("CN=", 1))
			ok = false
		else:
			linhas.append("aviso: a raiz foi enviada junto. Funciona, mas é peso morto: o navegador usa a cópia dele.")
	elif ultimo["issuer"] == RAIZ_CONFIAVEL:
		linhas.append("Issuer do último = raiz Certifica Brasil Root CA G2, que está no repositório do navegador.")
	else:
		linhas.append("error 20: unable to get local issuer certificate (%s)" % ultimo["issuer"])
		ok = false
	return {"ok": ok, "linhas": linhas}


static func cobre(sans: Array, host: String) -> bool:
	for s in sans:
		var n: String = str(s).to_lower().strip_edges()
		if n == host:
			return true
		if n.begins_with("*.") and host.count(".") == n.count(".") and host.ends_with(n.substr(1)):
			return true
	return false


# ---------------------------------------------------------------- passo 2

func _montar_csr(v: VBoxContainer) -> void:
	rotulo("Sujeito fixo: C=BR, ST=Paraná, L=Curitiba, O=Tabajara Seguros S.A.", 13, Estilo.TEXTO_FRACO, v)
	var h := linha(v)
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(esq)
	rotulo("Common Name (CN):", 14, Estilo.TEXTO, esq)
	_cn = campo("ex.: www.tabajara.com.br", esq)
	_cn.text = "tabajara"
	rotulo("Tipo e tamanho da chave:", 14, Estilo.TEXTO, esq)
	_chave = opcoes(CHAVES, esq)
	_chave.selected = 0
	var dir := VBoxContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(dir)
	rotulo("subjectAltName (um nome DNS por linha):", 14, Estilo.TEXTO, dir)
	_sans = editor("tabajara\nlocalhost", 96, dir)
	_cn.text_changed.connect(func(_t): _atualizar_csr())
	_sans.text_changed.connect(_atualizar_csr)
	_chave.item_selected.connect(func(_i): _atualizar_csr())
	rotulo("Comando equivalente (gerado a partir do formulário):", 13, Estilo.TEXTO_FRACO, v)
	_comando = bloco_mono("", 112, v)
	_comando.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_comando.add_theme_font_size_override("font_size", 12)
	_analise_csr = texto_rico("", v)
	_atualizar_csr()


func _lista_sans() -> Array:
	var r: Array = []
	for l in _sans.text.split("\n"):
		var n := l.strip_edges().to_lower()
		if n != "" and not n in r:
			r.append(n)
	return r


static func comando_openssl(cn: String, sans: Array, chave: String) -> String:
	var nk: String
	if chave.begins_with("ECDSA"):
		nk = "-newkey ec -pkeyopt ec_paramgen_curve:%s" % chave.split(" ")[1]
	else:
		nk = "-newkey rsa:%s" % chave.split(" ")[1]
	var c := "openssl req -new %s -nodes \\\n  -keyout tabajara.key -out tabajara.csr -utf8 \\\n" % nk
	c += "  -subj \"/C=BR/ST=Paraná/L=Curitiba/O=Tabajara Seguros S.A./CN=%s\"" % cn.strip_edges()
	if not sans.is_empty():
		var d := []
		for s in sans:
			d.append("DNS:" + s)
		c += " \\\n  -addext \"subjectAltName=%s\"" % ",".join(d)
	return c


static func nome_dns_valido(n: String) -> bool:
	var re := RegEx.create_from_string("^(\\*\\.)?([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$")
	return re.search(n) != null


## Analisa o pedido como a AC faria. Devolve pontos (0..40) e linhas.
static func analisar_csr(cn: String, sans: Array, chave: String) -> Dictionary:
	var pts := 0
	var l: Array = []
	for h in HOSTS:
		if cobre(sans, h):
			pts += 8
			l.append("[color=#5ee38a][OK][/color] %s coberto pelo SAN" % h)
		else:
			l.append("[color=#ff5d5d]X[/color] %s fora do SAN (vai dar NET::ERR_CERT_COMMON_NAME_INVALID)" % h)
	var invalidos: Array = []
	for s in sans:
		if not nome_dns_valido(s) or not (s == "tabajara.com.br" or s.ends_with(".tabajara.com.br")) or s == "*.com.br":
			invalidos.append(s)
	if invalidos.is_empty() and not sans.is_empty():
		pts += 6
	elif not invalidos.is_empty():
		l.append("[color=#ff5d5d]X[/color] a AC recusa nomes que não são do domínio validado ou não são DNS públicos: %s" % ", ".join(invalidos))
	if chave == "RSA 1024":
		l.append("[color=#ff5d5d]X[/color] RSA 1024: recusado (mínimo do CA/Browser Forum é RSA 2048)")
	elif chave == "RSA 4096":
		pts += 8
		l.append("[color=#ffc94d]~[/color] RSA 4096 é aceito, mas é lento no handshake sem ganho prático. RSA 2048/3072 ou ECDSA P-256 bastam.")
	else:
		pts += 10
		l.append("[color=#5ee38a][OK][/color] chave %s aceita" % chave)
	var cn_l := cn.strip_edges().to_lower()
	if cn_l != "" and not cn_l in sans:
		l.append("[color=#ffc94d]~[/color] o CN não está no SAN: a AC copia o CN para o SAN ou recusa. Melhor repetir.")
	else:
		pass
	return {"pontos": pts, "linhas": l}


func _atualizar_csr() -> void:
	var sans := _lista_sans()
	var ch: String = CHAVES[_chave.selected]
	_comando.text = comando_openssl(_cn.text, sans, ch)
	var r := analisar_csr(_cn.text, sans, ch)
	_analise_csr.text = "\n".join(r["linhas"]) + "\n[color=#8b95a8]Pontuação do pedido: %d de 40[/color]" % r["pontos"]


# ---------------------------------------------------------------- passo 3

func _montar_medidas(v: VBoxContainer) -> void:
	rotulo("O que entra no plano para isso não acontecer de novo? Marque tudo que vale (marcar besteira desconta).", 15, Estilo.TEXTO, v)
	for m in MEDIDAS:
		var cb := caixa_marcar(m[0], v)
		cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_medidas.append(cb)
	texto_rico("[color=#8b95a8]Lembrete do CA/Browser Forum (votação SC-081): validade máxima de certificado TLS público caiu para 200 dias em março de 2026, "
		+ "vai a 100 dias em março de 2027 e a 47 dias em março de 2029. Renovação manual vai virar esporte radical.[/color]", v)


# ---------------------------------------------------------------- avaliação

func _nota_cadeia() -> Array:
	var r := verificar(_cadeia)
	if r["ok"] and _cadeia == ["A", "C"]:
		return [40, "Cadeia perfeita: folha nova + intermediário certo, sem a raiz."]
	if r["ok"] and _cadeia == ["A", "C", "R"]:
		return [35, "Cadeia válida, mas mandou a raiz junto: o navegador já tem a dele, é só peso no handshake."]
	if _cadeia == ["A"]:
		return [15, "Mandou só a folha. O Chrome do desktop até se vira buscando o intermediário pelo AIA, mas Android, curl e Java quebram: o servidor deve enviar o intermediário."]
	if "D" in _cadeia:
		return [5, "Caiu no intermediário parecido: o CN é igual, mas o Subject completo é de outra AC (Certifika Brazil Ltda) e ainda venceu em setembro. Compare o DN inteiro, não só o CN."]
	if "B" in _cadeia:
		return [5, "Usou o certificado que venceu no sábado. É exatamente o problema que você veio resolver."]
	if "K" in _cadeia:
		return [0, "O autoassinado do Kauã não é confiado por nenhum navegador (e ainda é SHA-1 com RSA 1024)."]
	return [0, "A cadeia não foi montada direito: a folha vem primeiro e cada Issuer tem que ser o Subject do próximo."]


func avaliar() -> Dictionary:
	var c := _nota_cadeia()
	var nota: int = c[0]
	var com: String = c[1]
	var sans := _lista_sans()
	var ch: String = CHAVES[_chave.selected]
	var csr := analisar_csr(_cn.text, sans, ch)
	nota += int(csr["pontos"])
	if csr["pontos"] >= 40:
		com += " CSR certo: os três nomes no SAN (o navegador ignora o CN desde 2017) e chave aceitável."
	else:
		var falta: Array = []
		for h in HOSTS:
			if not cobre(sans, h):
				falta.append(h)
		com += " CSR com %d de 40%s%s." % [csr["pontos"], (": faltou no SAN " + ", ".join(falta)) if not falta.is_empty() else "",
			"; RSA 1024 a AC recusa" if ch == "RSA 1024" else ""]
	var acertos := 0.0
	for i in MEDIDAS.size():
		if _medidas[i].button_pressed:
			acertos += 1.0 if MEDIDAS[i][1] else -1.0
	var pm := int(round(20.0 * clampf(acertos, 0.0, 2.0) / 2.0))
	nota += pm
	if pm == 20:
		com += " E a prevenção certa: ACME automatizado + monitoramento de validade que não depende de uma pessoa."
	else:
		com += " Prevenção incompleta: o que resolve é renovar automático (ACME) e monitorar a validade em canal da equipe; certificado longo nem existe mais."
	return {"nota": clampi(nota, 0, 100), "comentario": com, "cagada": ""}


func solucao_teste() -> void:
	_cadeia = ["A", "C"]
	_mostrar_cadeia()
	_validar_cadeia()
	_cn.text = "www.tabajara.com.br"
	_sans.text = "tabajara.com.br\nwww.tabajara.com.br\nportal.tabajara.com.br"
	_chave.selected = 4
	_atualizar_csr()
	for i in MEDIDAS.size():
		_medidas[i].button_pressed = MEDIDAS[i][1]
