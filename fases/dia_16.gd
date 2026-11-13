extends "res://fases/fase.gd"
## Dia 16: simulado de ransomware. Escolher o conjunto de restauração de cada
## sistema: cadeia válida, limpa (anterior à infecção), dentro do RPO e do RTO.

const INFECCAO := "2026-11-09 23:48"
const CRIPTOGRAFIA := "2026-11-12 03:10"
const HORAS_SUBIR := 1.0   # verificação de integridade e subir o serviço

const LOCAIS := {
	"nas": {"nome": "NAS", "longo": "NAS nas01 (mesma rede, compartilhamento SMB)", "setup": 0.0, "gbh": 500.0},
	"fita": {"nome": "Fita", "longo": "Fita LTO-8 offline (cofre externo, 3 h para buscar)", "setup": 3.0, "gbh": 400.0},
	"nuvem": {"nome": "Nuvem", "longo": "Nuvem com Object Lock em modo compliance (link de 500 Mb/s)", "setup": 0.5, "gbh": 200.0},
}

## id, tipo (full/inc/dif), data, local, GB, pai
const SISTEMAS := [
	{"nome": "Sinistros", "desc": "SQL Server do sistema de sinistros", "gb": 800, "rpo": 24, "rto": 8, "backups": [
		["SIN-F1", "full", "2026-11-01 01:00", "fita", 780, ""],
		["SIN-F2", "full", "2026-11-08 01:00", "nuvem", 800, ""],
		["SIN-I1", "inc", "2026-11-09 01:00", "nuvem", 35, "SIN-F2"],
		["SIN-I2", "inc", "2026-11-10 01:00", "nuvem", 38, "SIN-I1"],
		["SIN-I3", "inc", "2026-11-11 01:00", "nuvem", 41, "SIN-I2"],
		["SIN-N1", "full", "2026-11-11 22:00", "nas", 805, ""]]},
	{"nome": "Folha", "desc": "Folha de pagamento (fecha dia 25)", "gb": 300, "rpo": 72, "rto": 24, "backups": [
		["FOL-F1", "full", "2026-11-02 20:00", "fita", 290, ""],
		["FOL-D1", "dif", "2026-11-05 20:00", "fita", 25, "FOL-F1"],
		["FOL-D2", "dif", "2026-11-09 20:00", "fita", 48, "FOL-F1"],
		["FOL-D3", "dif", "2026-11-10 20:00", "fita", 55, "FOL-F1"],
		["FOL-N1", "full", "2026-11-11 20:00", "nas", 301, ""]]},
	{"nome": "Site", "desc": "Site institucional e cotação on-line", "gb": 20, "rpo": 168, "rto": 4, "backups": [
		["WEB-F1", "full", "2026-11-01 03:00", "nuvem", 18, ""],
		["WEB-F2", "full", "2026-11-08 03:00", "nuvem", 19, ""],
		["WEB-F3", "full", "2026-11-11 03:00", "nuvem", 20, ""],
		["WEB-N1", "full", "2026-11-12 00:00", "nas", 20, ""]]},
	{"nome": "E-mail", "desc": "Servidor de e-mail (Exchange local, sim, ainda)", "gb": 1200, "rpo": 48, "rto": 24, "backups": [
		["MAIL-F1", "full", "2026-11-07 23:00", "fita", 1150, ""],
		["MAIL-I1", "inc", "2026-11-08 23:00", "fita", 30, "MAIL-F1"],
		["MAIL-I2", "inc", "2026-11-09 23:00", "fita", 28, "MAIL-I1"],
		["MAIL-I3", "inc", "2026-11-10 23:00", "fita", 31, "MAIL-I2"],
		["MAIL-F2", "full", "2026-11-07 23:00", "nuvem", 1150, ""],
		["MAIL-N1", "full", "2026-11-11 23:00", "nas", 1210, ""]]},
	{"nome": "Apólices", "desc": "Servidor de arquivos com apólices digitalizadas", "gb": 2000, "rpo": 96, "rto": 12, "backups": [
		["ARQ-F1", "full", "2026-11-01 02:00", "fita", 1950, ""],
		["ARQ-F2", "full", "2026-11-08 02:00", "nuvem", 1980, ""],
		["ARQ-I1", "inc", "2026-11-09 02:00", "nuvem", 15, "ARQ-F2"],
		["ARQ-I2", "inc", "2026-11-10 02:00", "nuvem", 12, "ARQ-I1"],
		["ARQ-N1", "full", "2026-11-11 02:00", "nas", 2010, ""]]},
]

const PERGUNTA := [
	"(escolha)",
	"3 backups por dia, 2 administradores com a senha, 1 planilha de controle",
	"3 cópias dos dados, em 2 mídias diferentes, 1 delas fora do local (hoje: 3-2-1-1-0, com 1 offline ou imutável e 0 erros no teste de restauração)",
	"3 NAS na mesma rede, 2 em RAID 6, 1 no rack do lado para facilitar",
	"3 semanas de retenção, 2 fitas, 1 estagiária responsável por tudo",
]

var _abas: TabContainer
var _marcas: Array = []      # por sistema: {id: CheckBox}
var _saidas: Array = []      # por sistema: RichTextLabel
var _pergunta: Array = []


func _init() -> void:
	dia = 16
	titulo = "Simulado de ransomware"
	chamado = ("Para cada sistema, marque os backups a restaurar (um [b]full[/b] e, se quiser, a cadeia de incrementais ou um diferencial). "
		+ "A perda de dados conta até a criptografia (12/11 03:10) e o relógio do RTO começa agora. [b]Leia a linha do tempo[/b]: o que foi copiado "
		+ "depois do início da infecção leva junto o ransomware dormente. Busque o ponto limpo mais recente que caiba no RTO.")


func montar() -> void:
	_abas = TabContainer.new()
	_abas.custom_minimum_size = Vector2(0, 400)
	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_child(_abas)
	_montar_linha_do_tempo(_aba("Linha do tempo"))
	for i in SISTEMAS.size():
		_montar_sistema(_aba(SISTEMAS[i]["nome"]), i)
	var v := _aba("3-2-1")
	rotulo("Pergunta do auditor para o relatório do simulado: o que é a regra 3-2-1 de backup?", 15, Estilo.TEXTO, v)
	var grupo := ButtonGroup.new()
	for k in range(1, PERGUNTA.size()):
		var cb := caixa_marcar(PERGUNTA[k], v)
		cb.button_group = grupo
		cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pergunta.append(cb)
	rotulo("Jurema: se o NAS estivesse fora do domínio, com outra credencial e snapshot imutável, a gente estaria em casa agora.", 14, Estilo.cor_de("Jurema"), v)
	chat("Valdecir", "Tranquilo, o NAS tem backup de hora em hora. Tem RAID 6!")
	chat("Sistema", "nas01: 14.882 arquivos renomeados para *.tabajara_lock. LEIA-ME.txt criado em todas as pastas.")
	chat("Jurema", "RAID protege de disco queimado, não de gente. Sobrou a fita e a nuvem imutável. Olha as datas com carinho.")


func _aba(nome: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_abas.add_child(sc)
	_abas.set_tab_title(_abas.get_tab_count() - 1, nome)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v


func _montar_linha_do_tempo(v: VBoxContainer) -> void:
	texto_rico("[b]Linha do tempo do incidente (reconstruída pelo EDR que o Valdecir quase cancelou)[/b]", v)
	var t := bloco_mono("""09/11 (seg) 23:31  E-mail "Boleto_Sinistro_8812.pdf.iso" chega para valdecir.moreira
09/11 (seg) 23:48  Valdecir abre o anexo no notebook, pela VPN. Primeiro beacon do
                   loader para 198.51.100.66:443. INÍCIO DA INFECÇÃO.
10/11 (ter) 00:02  Credencial de admin de domínio extraída da memória (o Valdecir
                   é admin de domínio "para agilizar")
10/11 (ter) 00:40  GPO nova copia o binário dormente para todos os servidores
10/11 a 11/11      rclone envia 140 GB para um armazenamento externo (exfiltração)
12/11 (qui) 02:55  Tarefa agendada dispara a criptografia em massa
12/11 (qui) 03:10  Criptografia detectada. NAS nas01 também criptografado
                   (estava montado com a mesma credencial de domínio)

Locais de backup:
  NAS   nas01 na mesma rede: CRIPTOGRAFADO, inutilizável
  Fita  LTO-8 offline no cofre externo: 3 h para buscar, 400 GB/h
  Nuvem armazenamento com Object Lock (compliance): 30 min para preparar, 200 GB/h
  + 1 h por sistema para verificar a integridade e subir o serviço

Full = cópia completa. Incremental = mudanças desde o backup anterior (precisa
de toda a corrente). Diferencial = mudanças desde o último full (precisa só do full).""", 412, v)
	t.add_theme_font_size_override("font_size", 13)


func _montar_sistema(v: VBoxContainer, i: int) -> void:
	var s: Dictionary = SISTEMAS[i]
	texto_rico("[b]%s[/b]: %s, %d GB.   [color=#ffc94d]RPO %d h[/color]  ·  [color=#38d9e8]RTO %d h[/color]" % [s["nome"], s["desc"], s["gb"], s["rpo"], s["rto"]], v)
	rotulo("   ID        tipo          data          local    tamanho  depende de", 13, Estilo.TEXTO_FRACO, v).add_theme_font_override("font", Estilo.mono())
	var m := {}
	for b in s["backups"]:
		var tipo: String = {"full": "full", "inc": "incremental", "dif": "diferencial"}[b[1]]
		var cb := caixa_marcar("%-8s  %-12s  %s  %-6s  %5d GB  %s" % [b[0], tipo, _fmt(b[2]), LOCAIS[b[3]]["nome"], b[4], b[5] if b[5] != "" else "-"], v)
		cb.add_theme_font_override("font", Estilo.mono())
		cb.add_theme_font_size_override("font_size", 13)
		cb.toggled.connect(func(_x): _atualizar(i))
		m[b[0]] = cb
	_marcas.append(m)
	var saida := texto_rico("", v)
	saida.add_theme_font_size_override("normal_font_size", 14)
	saida.add_theme_font_size_override("bold_font_size", 14)
	_saidas.append(saida)
	_atualizar(i)


# ---------------------------------------------------------------- cálculo

static func _ts(s: String) -> int:
	return Time.get_unix_time_from_datetime_string(s.replace(" ", "T") + ":00")


static func _fmt(s: String) -> String:
	var d := Time.get_datetime_dict_from_datetime_string(s.replace(" ", "T") + ":00", false)
	return "%02d/%02d %02d:%02d" % [d["day"], d["month"], d["hour"], d["minute"]]


static func _horas(h: float) -> String:
	var m := int(round(h * 60.0))
	return "%dh%02d" % [m / 60, m % 60]


## Calcula de verdade a restauração de um conjunto de backups de um sistema.
static func restauracao(sis: Dictionary, ids: Array) -> Dictionary:
	var r := {"ok": false, "erro": "", "ponto": 0, "perda": 0.0, "tempo": 0.0, "infectado": [], "fulls": 0}
	if ids.is_empty():
		r["erro"] = "nada selecionado"
		return r
	var por_id := {}
	for b in sis["backups"]:
		por_id[b[0]] = b
	var locais_usados := {}
	var transferencia := 0.0
	for id in ids:
		var b: Array = por_id[id]
		if b[3] == "nas":
			r["erro"] = "%s está no NAS, que foi criptografado junto. Inutilizável." % id
			return r
		if b[1] == "full":
			r["fulls"] += 1
		elif not b[5] in ids:
			r["erro"] = "%s depende de %s, que não foi selecionado: cadeia quebrada." % [id, b[5]]
			return r
		locais_usados[b[3]] = true
		transferencia += float(b[4]) / float(LOCAIS[b[3]]["gbh"])
		r["ponto"] = maxi(r["ponto"], _ts(b[2]))
		if _ts(b[2]) > _ts(INFECCAO):
			r["infectado"].append(id)
	if r["fulls"] != 1:
		r["erro"] = "selecione exatamente um full (marcou %d)." % r["fulls"]
		return r
	# Cada peça precisa descender do full escolhido.
	for id in ids:
		var atual: Array = por_id[id]
		while atual[1] != "full":
			atual = por_id[atual[5]]
		if not atual[0] in ids:
			r["erro"] = "%s pertence a outra cadeia." % id
			return r
	var setup := 0.0
	for l in locais_usados:
		setup += float(LOCAIS[l]["setup"])
	r["tempo"] = setup + transferencia + HORAS_SUBIR
	r["perda"] = float(_ts(CRIPTOGRAFIA) - r["ponto"]) / 3600.0
	r["ok"] = true
	return r


## Melhor escolha limpa: dentro do RTO, ponto mais recente, depois menor tempo.
static func melhor(sis: Dictionary) -> Dictionary:
	var ids: Array = []
	for b in sis["backups"]:
		ids.append(b[0])
	var melhor_r := {}
	for mascara in range(1, 1 << ids.size()):
		var sel: Array = []
		for k in ids.size():
			if mascara & (1 << k):
				sel.append(ids[k])
		var r := restauracao(sis, sel)
		if not r["ok"] or not r["infectado"].is_empty() or r["tempo"] > sis["rto"]:
			continue
		if melhor_r.is_empty() or r["ponto"] > melhor_r["ponto"] or (r["ponto"] == melhor_r["ponto"] and r["tempo"] < melhor_r["tempo"]):
			melhor_r = r
			melhor_r["sel"] = sel
	return melhor_r


func _selecionados(i: int) -> Array:
	var sel: Array = []
	for id in _marcas[i]:
		if _marcas[i][id].button_pressed:
			sel.append(id)
	return sel


func _atualizar(i: int) -> void:
	var s: Dictionary = SISTEMAS[i]
	var r := restauracao(s, _selecionados(i))
	if not r["ok"]:
		_saidas[i].text = "[color=#ff5d5d]Cadeia inválida: %s[/color]" % r["erro"]
		return
	var rpo_ok: bool = r["perda"] <= s["rpo"]
	var rto_ok: bool = r["tempo"] <= s["rto"]
	_saidas[i].text = ("[color=#5ee38a]Cadeia válida.[/color] Ponto de restauração: [b]%s[/b]\n" % _fmt_ts(r["ponto"])
		+ "Perda de dados: [b]%s[/b]  [color=%s](RPO %d h: %s)[/color]\n" % [_horas(r["perda"]), "#5ee38a" if rpo_ok else "#ff5d5d", s["rpo"], "cumprido" if rpo_ok else "ESTOURADO"]
		+ "Tempo de restauração: [b]%s[/b]  [color=%s](RTO %d h: %s)[/color]" % [_horas(r["tempo"]), "#5ee38a" if rto_ok else "#ff5d5d", s["rto"], "cumprido" if rto_ok else "ESTOURADO"])


static func _fmt_ts(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%02d/%02d %02d:%02d" % [d["day"], d["month"], d["hour"], d["minute"]]


# ---------------------------------------------------------------- avaliação

func avaliar() -> Dictionary:
	var nota := 0
	var partes: Array = []
	var infectados: Array = []
	var rpo_impossivel: Array = []
	var vazios: Array = []
	for i in SISTEMAS.size():
		var s: Dictionary = SISTEMAS[i]
		var r := restauracao(s, _selecionados(i))
		var m := melhor(s)
		if m["perda"] > s["rpo"]:
			rpo_impossivel.append(s["nome"])
		if not r["ok"]:
			if r["erro"] == "nada selecionado":
				vazios.append(s["nome"])
			else:
				partes.append("%s: %s" % [s["nome"], str(r["erro"]).trim_suffix(".")])
			continue
		if not r["infectado"].is_empty():
			infectados.append("%s (%s)" % [s["nome"], ", ".join(r["infectado"])])
			continue
		var p := 0
		if r["ponto"] == m["ponto"]:
			p += 12
		elif r["perda"] <= s["rpo"]:
			p += 6
			partes.append("%s: dava para voltar até %s" % [s["nome"], _fmt_ts(m["ponto"])])
		else:
			p += 2
			partes.append("%s: ponto antigo demais, o limpo mais recente era %s" % [s["nome"], _fmt_ts(m["ponto"])])
		if r["tempo"] <= s["rto"]:
			p += 6
		else:
			partes.append("%s: %s estoura o RTO de %d h" % [s["nome"], _horas(r["tempo"]), s["rto"]])
		nota += p
	if not vazios.is_empty():
		partes.append("sem restauração escolhida: " + ", ".join(vazios))
	if _pergunta[1].button_pressed:
		nota += 10
	else:
		partes.append("3-2-1 é 3 cópias, 2 mídias, 1 fora do local (e hoje 1 imutável/offline e 0 erros no teste)")
	var com := ""
	if partes.is_empty() and infectados.is_empty():
		com = "Restauração perfeita: só backups anteriores às 23:48 do dia 09, fora do NAS, cadeias completas e dentro do RTO."
	else:
		com = "; ".join(partes) + "."
	if not rpo_impossivel.is_empty():
		com += " Repare: %s não %s como cumprir o RPO, porque a infecção dormiu 51 horas antes de agir. Tempo de permanência come RPO; detecção também é continuidade." % [" e ".join(rpo_impossivel), "tinha" if rpo_impossivel.size() == 1 else "tinham"]
	var cagada := ""
	if not infectados.is_empty():
		com = "Restaurou backup posterior ao início da infecção: " + ", ".join(infectados) + ". " + com
		cagada = "Você restaurou um backup com o ransomware dormente dentro. Às 02:55 do dia seguinte ele acordou e criptografou tudo de novo. O ransomware agradece a hospitalidade."
	return {"nota": clampi(nota, 0, 100), "comentario": com, "cagada": cagada}


func solucao_teste() -> void:
	for i in SISTEMAS.size():
		var m := melhor(SISTEMAS[i])
		for id in _marcas[i]:
			_marcas[i][id].button_pressed = id in m["sel"]
		_atualizar(i)
	_pergunta[1].button_pressed = true
	_abas.current_tab = 1
