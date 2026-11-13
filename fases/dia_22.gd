extends "res://fases/fase.gd"
## Dia 22: JWT HS256 com segredo fraco. Decodificar, quebrar por dicionário, forjar e virar admin.

const SEGREDO_SERVIDOR := "timao2026"
const FLAG := "TABAJARA{hs256_com_segredo_de_torcida_nao_e_seguranca}"
const WORDLIST := ["123456", "password", "secret", "segredo", "changeme", "jwt", "jwtsecret", "admin",
	"tabajara", "Tabajara@2026", "portal", "sinistro", "seguro", "kaua", "kaua123", "kaua2026",
	"corinthians", "timao", "timao2025", "timao2026", "flamengo", "palmeiras", "qwerty", "letmein", "teste"]
const RECOMENDACOES := [
	"(escolha a recomendação para o relatório)",
	"Trocar o segredo para timao2027 e mudar todo ano, sempre depois da final do campeonato",
	"Segredo de 256 bits aleatórios (CSPRNG) guardado em cofre, ou RS256/ES256 com chaves rotacionadas (kid)",
	"Aceitar alg none só em homologação, para facilitar os testes",
	"Codificar o payload em base64 duas vezes para ninguém conseguir ler",
	"Mover o campo role para um cookie separado",
]

var _agora := 0
var _inicio_ms := 0
var _token: TextEdit
var _hdr: TextEdit
var _pld: TextEdit
var _sig_info: Label
var _wordlist: TextEdit
var _saida_ataque: TextEdit
var _ed_hdr: TextEdit
var _ed_pld: TextEdit
var _segredo: LineEdit
var _resposta: TextEdit
var _rec: OptionButton
var _achado := ""
var _flag := false
var _tentou_none := false


func _init() -> void:
	dia = 22
	titulo = "JWT do portal"
	chamado = ("Pentest autorizado no portal do segurado (homologação). Você está {logada como a segurada|logado como o segurado} de teste. "
		+ "Decodifique o JWT, rode o [b]ataque de dicionário[/b] contra a assinatura HS256, forje um token com [b]role admin[/b], "
		+ "assine e envie para [code]/api/admin[/code] até pegar a flag. No fim, escolha a recomendação do relatório. "
		+ "Nota: segredo quebrado, flag e recomendação.")
	_agora = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 11, "day": 13, "hour": 12, "minute": 0, "second": 0})


# ---------------------------------------------------------------- JWT de verdade

static func b64url(raw: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(raw).replace("+", "-").replace("/", "_").replace("=", "")


static func b64url_decodificar(s: String) -> PackedByteArray:
	if s.length() % 4 == 1 or RegEx.create_from_string("^[A-Za-z0-9_-]*$").search(s) == null:
		return PackedByteArray()
	var t := s.replace("-", "+").replace("_", "/")
	while t.length() % 4 != 0:
		t += "="
	return Marshalls.base64_to_raw(t)


static func assinatura(segredo: String, dados: String) -> String:
	var c := Crypto.new()
	return b64url(c.hmac_digest(HashingContext.HASH_SHA256, segredo.to_utf8_buffer(), dados.to_utf8_buffer()))


static func gerar(header: String, payload: String, segredo: String) -> String:
	var dados := b64url(header.to_utf8_buffer()) + "." + b64url(payload.to_utf8_buffer())
	return dados + "." + assinatura(segredo, dados)


static func json_ou_null(texto: String) -> Variant:
	var j := JSON.new()
	if j.parse(texto) != OK:
		return null
	return j.data


func _agora_servidor() -> int:
	return _agora + int((Time.get_ticks_msec() - _inicio_ms) / 1000.0)


# ---------------------------------------------------------------- interface

func montar() -> void:
	_inicio_ms = Time.get_ticks_msec()
	var header := "{\"alg\":\"HS256\",\"typ\":\"JWT\"}"
	var payload := "{\"sub\":\"48213\",\"nome\":\"Joana Prado (teste)\",\"role\":\"segurado\",\"iat\":%d,\"exp\":%d}" % [_agora - 120, _agora + 8 * 3600]
	var original := gerar(header, payload, SEGREDO_SERVIDOR)

	rotulo("Authorization: Bearer (token cru, editável)", 14, Estilo.TEXTO_FRACO)
	_token = editor(original, 62)
	_token.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_token.add_theme_font_size_override("font_size", 12)
	_token.text_changed.connect(_decodificar)
	var h := linha()
	var ph := painel(h)
	rotulo("Header", 13, Estilo.DESTAQUE, ph)
	_hdr = bloco_mono("", 165, ph)
	_hdr.add_theme_font_size_override("font_size", 12)
	var pp := painel(h)
	rotulo("Payload", 13, Estilo.DESTAQUE, pp)
	_pld = bloco_mono("", 165, pp)
	_pld.add_theme_font_size_override("font_size", 12)
	_sig_info = rotulo("", 13, Estilo.TEXTO_FRACO)

	var pa := painel(null, Color("1b1626"))
	rotulo("Ataque de dicionário (HMAC-SHA256 de verdade, uma palavra por linha)", 15, Estilo.DESTAQUE, pa)
	var ha := linha(pa)
	_wordlist = editor("\n".join(WORDLIST), 150, ha)
	_wordlist.custom_minimum_size.x = 220
	_wordlist.size_flags_horizontal = Control.SIZE_FILL
	_saida_ataque = bloco_mono("", 150, ha)
	_saida_ataque.add_theme_font_size_override("font_size", 12)
	botao("Rodar ataque contra o token atual", _atacar, pa)

	var pf := painel()
	rotulo("Forjar token", 15, Estilo.DESTAQUE, pf)
	var hf := linha(pf)
	var c1 := VBoxContainer.new()
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hf.add_child(c1)
	rotulo("header (JSON)", 13, Estilo.TEXTO_FRACO, c1)
	_ed_hdr = editor(header, 150, c1)
	_ed_hdr.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	var c2 := VBoxContainer.new()
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.size_flags_stretch_ratio = 2.0
	hf.add_child(c2)
	rotulo("payload (JSON)", 13, Estilo.TEXTO_FRACO, c2)
	_ed_pld = editor(_bonito(payload), 150, c2)
	_ed_pld.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	var hs := linha(pf)
	_segredo = campo("segredo HMAC para assinar", hs)
	botao("Assinar e colocar no Bearer", _assinar, hs)

	var pe := painel()
	var he := linha(pe)
	botao("GET /api/admin com o token atual", _enviar, he)
	rotulo("servidor: portal-hml.tabajara.com.br", 13, Estilo.TEXTO_FRACO, he).autowrap_mode = TextServer.AUTOWRAP_OFF
	_resposta = bloco_mono("(sem requisição ainda)", 110, pe)
	_resposta.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_resposta.add_theme_font_size_override("font_size", 12)
	_rec = opcoes(RECOMENDACOES, pe)
	_rec.clip_text = true
	_rec.fit_to_longest_item = false
	_rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_decodificar()
	chat("Jurema", "JWT não é criptografia, é um bilhete assinado. Qualquer um lê. O segredo é o que impede de reescrever.")
	chat("Kauã", "Meu segredo é inquebrável. Só eu e mais uns 40 mil no estádio sabemos.")
	aviso("Base64url não é cifra: o header e o payload aparecem decodificados assim que o token muda.")


static func _bonito(compacto: String) -> String:
	return compacto.replace("{", "{\n  ").replace(",\"", ",\n  \"").replace("}", "\n}")


func _partes() -> PackedStringArray:
	return _token.text.strip_edges().replace("\n", "").split(".", true)


func _decodificar() -> void:
	var p := _partes()
	if p.size() != 3:
		_hdr.text = "(token precisa de 3 partes separadas por ponto)"
		_pld.text = ""
		_sig_info.text = ""
		return
	_hdr.text = b64url_decodificar(p[0]).get_string_from_utf8()
	_pld.text = _bonito(b64url_decodificar(p[1]).get_string_from_utf8())
	var j = json_ou_null(b64url_decodificar(p[1]).get_string_from_utf8())
	var extra := ""
	if j is Dictionary and j.has("exp"):
		var falta := int(j["exp"]) - _agora_servidor()
		extra = "  |  exp: %s UTC (%s)" % [Time.get_datetime_string_from_unix_time(int(j["exp"])), "expira em %d min" % int(falta / 60.0) if falta > 0 else "EXPIRADO"]
	_sig_info.text = "Assinatura (base64url, %d caracteres): %s%s" % [p[2].length(), p[2].left(18) + "...", extra]


func _atacar() -> void:
	var p := _partes()
	if p.size() != 3 or p[2] == "":
		_saida_ataque.text = "Token sem assinatura para atacar."
		return
	var dados := p[0] + "." + p[1]
	var linhas := PackedStringArray()
	var testadas := 0
	var achou := ""
	for w in _wordlist.text.split("\n"):
		var palavra := w.strip_edges()
		if palavra == "":
			continue
		testadas += 1
		if assinatura(palavra, dados) == p[2]:
			achou = palavra
			linhas.append("[OK] %-16s  HMAC confere!" % palavra)
			break
		linhas.append("[  ] %-16s  não" % palavra)
	if achou != "":
		_achado = achou
		linhas.append("")
		linhas.append("SEGREDO ENCONTRADO após %d tentativas: %s" % [testadas, achou])
		_segredo.text = achou
		aviso("Segredo quebrado. Agora mude o payload e assine com ele.", Estilo.OK)
		chat("Jurema", "%d tentativas. O hashcat faz isso a alguns bilhões por segundo numa placa de vídeo de jogo." % testadas)
		chat("Kauã", "Pô, mas o Timão nem é tão óbvio assim.")
	else:
		linhas.append("")
		linhas.append("Nenhuma das %d palavras valida a assinatura." % testadas)
	_saida_ataque.text = "\n".join(linhas)
	await get_tree().process_frame
	if is_instance_valid(_saida_ataque):
		_saida_ataque.scroll_vertical = _saida_ataque.get_line_count()


func _assinar() -> void:
	var h := _ed_hdr.text.replace("\n", "").replace("\t", "").strip_edges()
	var pl := _ed_pld.text.replace("\n", "").replace("\t", "").replace("  ", "").strip_edges()
	var jh = json_ou_null(h)
	if not (jh is Dictionary) or not (json_ou_null(pl) is Dictionary):
		aviso("Header ou payload não é JSON válido. Confira aspas e vírgulas.", Estilo.ERRO)
		return
	if str(jh.get("alg", "")).to_lower() == "none":
		_tentou_none = true
		_token.text = b64url(h.to_utf8_buffer()) + "." + b64url(pl.to_utf8_buffer()) + "."
		aviso("Token com alg none montado (sem assinatura). Boa sorte.", Estilo.ALERTA)
	else:
		_token.text = gerar(h, pl, _segredo.text)
		aviso("Token assinado com HMAC-SHA256 e colocado no Bearer.", Estilo.OK)
	_decodificar()


func _enviar() -> void:
	var p := _partes()
	var r := "GET /api/admin HTTP/1.1\nHost: portal-hml.tabajara.com.br\n\n"
	if p.size() != 3:
		_resposta.text = r + "HTTP/1.1 400 Bad Request\n{\"erro\":\"token malformado\"}"
		return
	var h = json_ou_null(b64url_decodificar(p[0]).get_string_from_utf8())
	var pl = json_ou_null(b64url_decodificar(p[1]).get_string_from_utf8())
	if not (h is Dictionary) or not (pl is Dictionary):
		_resposta.text = r + "HTTP/1.1 400 Bad Request\n{\"erro\":\"header ou payload ilegível\"}"
		return
	var alg := str(h.get("alg", ""))
	if alg.to_lower() == "none":
		_tentou_none = true
		_resposta.text = r + "HTTP/1.1 401 Unauthorized\n{\"erro\":\"alg none recusado. Corrigimos isso em 2015 (CVE-2015-9235). Até o Kauã atualizou a biblioteca.\"}"
		chat("Jurema", "Clássico. Mas a lib agora só aceita a lista de algoritmos permitidos. Ataca o segredo, não o algoritmo.")
		return
	if alg != "HS256":
		_resposta.text = r + "HTTP/1.1 401 Unauthorized\n{\"erro\":\"algoritmo %s não permitido; aceitos: [HS256]\"}" % alg
		return
	if assinatura(SEGREDO_SERVIDOR, p[0] + "." + p[1]) != p[2]:
		_resposta.text = r + "HTTP/1.1 401 Unauthorized\n{\"erro\":\"invalid signature\"}"
		return
	if not pl.has("exp") or float(pl["exp"]) <= _agora_servidor():
		_resposta.text = r + "HTTP/1.1 401 Unauthorized\n{\"erro\":\"jwt expired\"}"
		return
	if str(pl.get("role", "")) != "admin":
		_resposta.text = r + "HTTP/1.1 403 Forbidden\n{\"erro\":\"role '%s' não acessa /api/admin\"}" % str(pl.get("role", ""))
		return
	_flag = true
	_resposta.text = r + "HTTP/1.1 200 OK\n{\"painel\":\"administração de sinistros\",\"usuarios\":184223,\"flag\":\"%s\"}" % FLAG
	aviso("200 OK. Você é admin do portal. Escolha a recomendação e entregue.", Estilo.OK)
	chat("Valdecir", "Admin? Mas tem firewall! Liguei pro fornecedor do firewall e ele disse que JWT não é com ele.")


# ---------------------------------------------------------------- avaliação

func avaliar() -> Dictionary:
	var nota := 0
	var com: Array[String] = []
	if _achado == SEGREDO_SERVIDOR or _flag:
		nota += 25
		com.append("Segredo \"%s\" quebrado por dicionário: HS256 com segredo curto e previsível cai offline, sem nem tocar no servidor." % SEGREDO_SERVIDOR)
	else:
		com.append("Faltou quebrar o segredo: com um token válido dá para testar palavras offline até o HMAC bater.")
	if _flag:
		nota += 50
		com.append("Flag capturada: token forjado com role admin, assinatura válida e exp no futuro.")
	else:
		com.append("Sem flag: era preciso trocar role para admin, assinar com o segredo quebrado e manter o exp válido.")
	if _rec.selected == 2:
		nota += 25
		com.append("Recomendação certa: segredo de 256 bits aleatórios em cofre, ou assinatura assimétrica (RS256/ES256) com rotação por kid.")
	else:
		com.append("Recomendação certa: segredo de 256 bits aleatórios (CSPRNG) em cofre, ou RS256/ES256 com chaves rotacionadas.")
	if _tentou_none:
		com.append("O alg none foi uma boa tentativa; o servidor já tinha lista de algoritmos permitidos.")
	return {"nota": nota, "comentario": " ".join(com), "cagada": ""}


func solucao_teste() -> void:
	_atacar()
	_ed_pld.text = _ed_pld.text.replace("\"segurado\"", "\"admin\"")
	_assinar()
	_enviar()
	_rec.selected = 2
