extends "res://fases/fase.gd"
## Dia 15: bucket público. Reescrever a bucket policy e rodar contra um motor
## de avaliação no estilo da AWS (negação explícita > permissão > negação implícita).

const BUCKET := "arn:aws:s3:::tabajara-apolices"
const PARCEIRO := "arn:aws:iam::111122223333:role/parceiro-download"
const OPERADORES := ["StringEquals", "StringNotEquals", "StringEqualsIgnoreCase", "StringNotEqualsIgnoreCase",
	"StringLike", "StringNotLike", "Bool", "IpAddress", "NotIpAddress", "Null", "ArnEquals", "ArnLike", "ArnNotEquals", "ArnNotLike"]
const CHAVES_STATEMENT := ["Sid", "Effect", "Principal", "NotPrincipal", "Action", "NotAction", "Resource", "NotResource", "Condition"]

const POLITICA_KAUA := """{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicoPraFacilitar",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::tabajara-apolices",
        "arn:aws:s3:::tabajara-apolices/*"
      ]
    }
  ]
}"""

const POLITICA_CERTA := """{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ParceiroLeSoAPastaDele",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::111122223333:role/parceiro-download"},
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::tabajara-apolices/apolices/parceiro-x/*",
      "Condition": {"IpAddress": {"aws:SourceIp": "203.0.113.0/24"}}
    },
    {
      "Sid": "SoComTLS",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::tabajara-apolices",
        "arn:aws:s3:::tabajara-apolices/*"
      ],
      "Condition": {"Bool": {"aws:SecureTransport": "false"}}
    }
  ]
}"""

## [descrição, principal ("" = anônimo), ação, recurso, TLS, IP, esperado]
const TESTES := [
	["Anônimo baixa apólice do parceiro X", "", "s3:GetObject", "/apolices/parceiro-x/AP-2026-0001.pdf", true, "198.51.100.23", "Deny"],
	["Parceiro baixa apólice da pasta dele", PARCEIRO, "s3:GetObject", "/apolices/parceiro-x/AP-2026-0001.pdf", true, "203.0.113.10", "Allow"],
	["Parceiro baixa apólice em subpasta dele", PARCEIRO, "s3:GetObject", "/apolices/parceiro-x/2026/11/AP-2026-0999.pdf", true, "203.0.113.44", "Allow"],
	["Parceiro tenta a pasta do parceiro Y", PARCEIRO, "s3:GetObject", "/apolices/parceiro-y/AP-2026-0417.pdf", true, "203.0.113.10", "Deny"],
	["Parceiro tenta enviar arquivo", PARCEIRO, "s3:PutObject", "/apolices/parceiro-x/novo.pdf", true, "203.0.113.10", "Deny"],
	["Parceiro tenta apagar apólice", PARCEIRO, "s3:DeleteObject", "/apolices/parceiro-x/AP-2026-0001.pdf", true, "203.0.113.10", "Deny"],
	["Parceiro lista o bucket inteiro", PARCEIRO, "s3:ListBucket", "", true, "203.0.113.10", "Deny"],
	["Parceiro baixa por HTTP sem TLS", PARCEIRO, "s3:GetObject", "/apolices/parceiro-x/AP-2026-0001.pdf", false, "203.0.113.10", "Deny"],
	["Credencial do parceiro usada fora da rede dele", PARCEIRO, "s3:GetObject", "/apolices/parceiro-x/AP-2026-0001.pdf", true, "198.51.100.77", "Deny"],
	["Role de mesmo nome em outra conta (999988887777)", "arn:aws:iam::999988887777:role/parceiro-download", "s3:GetObject", "/apolices/parceiro-x/AP-2026-0001.pdf", true, "203.0.113.10", "Deny"],
	["Anônimo apaga o bucket", "", "s3:DeleteBucket", "", true, "198.51.100.23", "Deny"],
	["Anônimo sobe um index.html \"hackeado\"", "", "s3:PutObject", "/index.html", true, "198.51.100.23", "Deny"],
]

var _editor: TextEdit
var _status: RichTextLabel
var _resultados: RichTextLabel


func _init() -> void:
	dia = 15
	titulo = "Bucket público"
	chamado = ("Reescreva a bucket policy de [code]tabajara-apolices[/code]. Requisitos: só a role [code]" + PARCEIRO + "[/code] pode "
		+ "[b]baixar[/b] (GetObject) o que está em [code]apolices/parceiro-x/[/code], só a partir da rede do parceiro [code]203.0.113.0/24[/code] e "
		+ "[b]só com TLS[/b]. O resto, ninguém. Rode a bateria de 12 requisições: nota = acertos.")


func montar() -> void:
	var h := linha()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esq.size_flags_stretch_ratio = 1.05
	h.add_child(esq)
	rotulo("aws s3api put-bucket-policy --bucket tabajara-apolices --policy file://politica.json", 12, Estilo.TEXTO_FRACO, esq)
	_editor = editor(POLITICA_KAUA, 360, esq)
	_editor.add_theme_font_size_override("font_size", 13)
	var lh := linha(esq)
	botao("Rodar a bateria de testes", _rodar, lh)
	botao("Voltar à do Kauã", func():
		_editor.text = POLITICA_KAUA
		_rodar(), lh)
	_status = texto_rico("", esq)
	_status.add_theme_font_size_override("normal_font_size", 13)
	var dir := VBoxContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(dir)
	_resultados = texto_rico("", dir)
	_resultados.add_theme_font_size_override("normal_font_size", 12)
	_resultados.add_theme_font_size_override("bold_font_size", 12)
	_rodar()
	chat("Kauã", "Principal asterisco, Action asterisco. Fica bem flexível, né? A política mais inclusiva da empresa.")
	chat("Jurema", "Inclusiva até com o atacante. Lembra: Deny explícito ganha de tudo, e o que não está liberado já está negado.")


# ---------------------------------------------------------------- motor

static func como_lista(v) -> Array:
	if v is Array:
		return v
	if v == null:
		return []
	return [v]


## Curinga no estilo IAM: * = qualquer sequência, ? = um caractere qualquer.
static func casa_curinga(padrao: String, valor: String, ignorar_caixa: bool) -> bool:
	if ignorar_caixa:
		padrao = padrao.to_lower()
		valor = valor.to_lower()
	var re := "^"
	for c in padrao:
		if c == "*":
			re += ".*"
		elif c == "?":
			re += "."
		elif "\\.^$|()[]{}+".contains(c):
			re += "\\" + c
		else:
			re += c
	re += "$"
	var rx := RegEx.create_from_string(re)
	return rx != null and rx.search(valor) != null


static func ip_para_int(ip: String) -> int:
	var p := ip.strip_edges().split(".")
	if p.size() != 4:
		return -1
	var n := 0
	for x in p:
		if not x.is_valid_int() or int(x) < 0 or int(x) > 255:
			return -1
		n = (n << 8) | int(x)
	return n


static func ip_na_faixa(ip: String, cidr: String) -> int:
	# 1 = dentro, 0 = fora, -1 = CIDR inválido
	var partes := cidr.strip_edges().split("/")
	var rede := ip_para_int(partes[0])
	var pref := 32
	if partes.size() == 2:
		if not partes[1].is_valid_int():
			return -1
		pref = int(partes[1])
	if rede < 0 or pref < 0 or pref > 32:
		return -1
	var mascara := 0 if pref == 0 else ((0xFFFFFFFF << (32 - pref)) & 0xFFFFFFFF)
	return 1 if (ip_para_int(ip) & mascara) == (rede & mascara) else 0


## Valida a política como o PutBucketPolicy faria. Devolve "" se ok, ou a mensagem.
static func validar(pol) -> String:
	if not pol is Dictionary:
		return "MalformedPolicy: a política tem que ser um objeto JSON."
	for k in pol.keys():
		if not k in ["Version", "Id", "Statement"]:
			return "MalformedPolicy: chave desconhecida no topo: %s" % k
	if str(pol.get("Version", "")) != "2012-10-17":
		return "MalformedPolicy: use \"Version\": \"2012-10-17\" (a de 2008 não tem variáveis de política; sem Version vale a de 2008)."
	var sts := como_lista(pol.get("Statement"))
	if sts.is_empty():
		return "MalformedPolicy: Statement ausente ou vazio."
	for i in sts.size():
		var s = sts[i]
		if not s is Dictionary:
			return "MalformedPolicy: Statement %d não é um objeto." % (i + 1)
		for k in s.keys():
			if not k in CHAVES_STATEMENT:
				return "MalformedPolicy: Statement %d tem chave desconhecida \"%s\"." % [i + 1, k]
		if not str(s.get("Effect", "")) in ["Allow", "Deny"]:
			return "MalformedPolicy: Statement %d: Effect precisa ser \"Allow\" ou \"Deny\" (com maiúscula)." % (i + 1)
		if s.has("NotPrincipal"):
			return "Statement %d: NotPrincipal não é aceito neste simulador (e a própria AWS desaconselha). Use Principal." % (i + 1)
		if not s.has("Principal"):
			return "MalformedPolicy: Statement %d: bucket policy exige Principal." % (i + 1)
		var p = s["Principal"]
		if not (p is String and p == "*") and not (p is Dictionary and p.has("AWS")):
			return "MalformedPolicy: Statement %d: Principal deve ser \"*\" ou {\"AWS\": \"arn...\"}." % (i + 1)
		if s.has("Action") == s.has("NotAction"):
			return "MalformedPolicy: Statement %d precisa de Action (ou NotAction), um dos dois." % (i + 1)
		for a in como_lista(s.get("Action", s.get("NotAction"))):
			if not (str(a) == "*" or str(a).to_lower().begins_with("s3:")):
				return "MalformedPolicy: Statement %d: ação \"%s\" não é do S3." % [i + 1, a]
		if s.has("Resource") == s.has("NotResource"):
			return "MalformedPolicy: Statement %d precisa de Resource (ou NotResource), um dos dois." % (i + 1)
		for r in como_lista(s.get("Resource", s.get("NotResource"))):
			var rs := str(r)
			if not (rs == BUCKET or rs.begins_with(BUCKET + "/") or rs == "*" or (rs.begins_with(BUCKET) and rs.contains("*"))):
				return "MalformedPolicy: Statement %d: Policy has invalid resource \"%s\" (tem que ser deste bucket)." % [i + 1, rs]
		if s.has("Condition"):
			if not s["Condition"] is Dictionary:
				return "MalformedPolicy: Statement %d: Condition tem que ser objeto." % (i + 1)
			for op in s["Condition"].keys():
				var base: String = str(op).trim_suffix("IfExists")
				if not base in OPERADORES:
					return "MalformedPolicy: Statement %d: Invalid Condition type \"%s\"." % [i + 1, op]
				if not s["Condition"][op] is Dictionary:
					return "MalformedPolicy: Statement %d: o operador %s precisa de {chave: valor}." % [i + 1, op]
				if base.ends_with("IpAddress"):
					for cv in s["Condition"][op].values():
						for c in como_lista(cv):
							if ip_na_faixa("0.0.0.0", str(c)) < 0:
								return "MalformedPolicy: Statement %d: CIDR inválido \"%s\"." % [i + 1, c]
	return ""


static func _casa_principal(p, quem: String) -> bool:
	if p is String:
		return p == "*"
	for v in como_lista(p.get("AWS")):
		var s := str(v)
		if s == "*":
			return true
		if quem == "":
			continue
		var conta := quem.get_slice(":", 4)
		if s == quem or s == conta or s == "arn:aws:iam::%s:root" % conta:
			return true
	return false


static func _casa_condicao(cond: Dictionary, ctx: Dictionary) -> bool:
	for op in cond.keys():
		var nome: String = str(op)
		var se_existir := nome.ends_with("IfExists")
		nome = nome.trim_suffix("IfExists")
		for chave in cond[op].keys():
			var valores := como_lista(cond[op][chave])
			var k := str(chave).to_lower()
			if nome == "Null":
				var quer_ausente := str(valores[0]).to_lower() == "true"
				if quer_ausente == ctx.has(k):
					return false
				continue
			if not ctx.has(k):
				if se_existir or nome.begins_with("StringNot") or nome.begins_with("ArnNot") or nome == "NotIpAddress":
					continue
				return false
			var atual := str(ctx[k])
			var algum := false
			for v in valores:
				var sv := str(v)
				match nome:
					"StringEquals", "StringNotEquals", "ArnEquals", "ArnNotEquals":
						algum = algum or sv == atual
					"StringEqualsIgnoreCase", "StringNotEqualsIgnoreCase":
						algum = algum or sv.to_lower() == atual.to_lower()
					"StringLike", "StringNotLike", "ArnLike", "ArnNotLike":
						algum = algum or casa_curinga(sv, atual, false)
					"Bool":
						algum = algum or sv.to_lower() == atual.to_lower()
					"IpAddress", "NotIpAddress":
						algum = algum or ip_na_faixa(atual, sv) == 1
			var negado := nome.contains("Not")
			if algum == negado:
				return false
	return true


static func _aplica(s: Dictionary, quem: String, acao: String, recurso: String, ctx: Dictionary) -> bool:
	if not _casa_principal(s["Principal"], quem):
		return false
	var achou := false
	for a in como_lista(s.get("Action", s.get("NotAction"))):
		achou = achou or casa_curinga(str(a), acao, true)
	if achou != s.has("Action"):
		return false
	achou = false
	for r in como_lista(s.get("Resource", s.get("NotResource"))):
		achou = achou or casa_curinga(str(r), recurso, false)
	if achou != s.has("Resource"):
		return false
	if s.has("Condition") and not _casa_condicao(s["Condition"], ctx):
		return false
	return true


## Avalia uma requisição. Devolve [decisão, motivo].
static func decidir(pol: Dictionary, t: Array) -> Array:
	var quem: String = t[1]
	var ctx := {"aws:securetransport": "true" if t[4] else "false", "aws:sourceip": t[5],
		"aws:principaltype": "Anonymous" if quem == "" else "AssumedRole"}
	if quem != "":
		ctx["aws:principalaccount"] = quem.get_slice(":", 4)
	var recurso: String = BUCKET + t[3]
	var permitiu := ""
	var sts := como_lista(pol["Statement"])
	for i in sts.size():
		var s: Dictionary = sts[i]
		if _aplica(s, quem, t[2], recurso, ctx):
			var sid := str(s.get("Sid", "Statement %d" % (i + 1)))
			if s["Effect"] == "Deny":
				return ["Deny", "Deny explícito (%s)" % sid]
			if permitiu == "":
				permitiu = sid
	if permitiu != "":
		return ["Allow", "Allow (%s)" % permitiu]
	return ["Deny", "negação implícita"]


## Interpreta o texto. Devolve {"pol": Dictionary ou null, "erro": String}.
static func interpretar(texto: String) -> Dictionary:
	var j := JSON.new()
	var e := j.parse(texto)
	if e != OK:
		return {"pol": null, "erro": "JSON inválido na linha %d: %s" % [j.get_error_line() + 1, j.get_error_message()]}
	# A AWS não aceita vírgula sobrando antes de } ou ].
	var virgula := RegEx.create_from_string(",\\s*[\\]}]").search(texto)
	if virgula:
		return {"pol": null, "erro": "JSON inválido na linha %d: vírgula sobrando antes de fechar" % (texto.substr(0, virgula.get_start()).count("\n") + 1)}
	var msg := validar(j.data)
	if msg != "":
		return {"pol": null, "erro": msg}
	return {"pol": j.data, "erro": ""}


## Roda a bateria. Política inválida: a AWS recusa e a anterior (do Kauã) continua valendo.
static func bateria(texto: String) -> Dictionary:
	var r := interpretar(texto)
	var pol = r["pol"]
	var vigente_kaua := pol == null
	if vigente_kaua:
		pol = JSON.parse_string(POLITICA_KAUA)
	var linhas: Array = []
	var acertos := 0
	for t in TESTES:
		var d := decidir(pol, t)
		var ok: bool = d[0] == t[6]
		if ok:
			acertos += 1
		linhas.append({"teste": t, "obtido": d[0], "motivo": d[1], "ok": ok})
	return {"erro": r["erro"], "kaua": vigente_kaua, "linhas": linhas, "acertos": acertos}


# ---------------------------------------------------------------- interface

func _rodar() -> void:
	var b := bateria(_editor.text)
	if b["erro"] != "":
		_status.text = "[color=#ff5d5d]%s[/color]\n[color=#8b95a8]A AWS recusou. A política do Kauã continua no ar.[/color]" % b["erro"]
		var ln := RegEx.create_from_string("linha (\\d+)").search(b["erro"])
		if ln:
			_editor.set_caret_line(maxi(int(ln.get_string(1)) - 1, 0))
	else:
		_status.text = "[color=#5ee38a]Política aceita pelo PutBucketPolicy.[/color]"
	var t := "[b]Bateria: %d de %d como esperado[/b]\n" % [b["acertos"], TESTES.size()]
	for i in b["linhas"].size():
		var l: Dictionary = b["linhas"][i]
		var te: Array = l["teste"]
		t += "[color=%s]%s[/color] #%d %s [color=#8b95a8](quer %s)[/color]\n" % [
			"#5ee38a" if l["ok"] else "#ff5d5d", "[OK]" if l["ok"] else "[X] ", i + 1, te[0], te[6]]
		t += "[color=#8b95a8]      %s %s %s: %s[/color]\n" % [
			te[2].trim_prefix("s3:"), ("(bucket)" if te[3] == "" else te[3].get_file()), ("TLS" if te[4] else "HTTP"), l["motivo"]]
	_resultados.text = t


func avaliar() -> Dictionary:
	var b := bateria(_editor.text)
	var nota := proporcao(b["acertos"], TESTES.size())
	var com := "%d de %d requisições com a decisão certa." % [b["acertos"], TESTES.size()]
	var cagada := ""
	if b["erro"] != "":
		com = "A política não passou na validação (%s), então a pública do Kauã continuou valendo. " % b["erro"] + com
	var l: Array = b["linhas"]
	if not l[1]["ok"] or not l[2]["ok"]:
		nota = mini(nota, 40)
		com += " O parceiro não consegue baixar as apólices dele: segurança por indisponibilidade não conta."
	var erros: Array = []
	for i in l.size():
		if not l[i]["ok"]:
			erros.append("#%d" % (i + 1))
	if not erros.is_empty():
		com += " Erradas: %s." % ", ".join(erros)
	if b["acertos"] == TESTES.size():
		com += " Mínimo privilégio de verdade: Allow só do GetObject na pasta, com IpAddress, e um Deny com aws:SecureTransport=false, que vence qualquer Allow."
	else:
		com += " Lembre: Principal \"*\" inclui o anônimo, s3:* inclui DeleteBucket, o que não é liberado já é negado, e só um Deny explícito com aws:SecureTransport=false barra o HTTP."
	if l[10]["obtido"] == "Allow" or l[11]["obtido"] == "Allow":
		cagada = "O bucket continuou aberto para escrita anônima. Às 3h da manhã alguém trocou as apólices por um PDF com o rosto do Kauã e apagou o resto."
	return {"nota": nota, "comentario": com, "cagada": cagada}


func solucao_teste() -> void:
	_editor.text = POLITICA_CERTA
	_rodar()
