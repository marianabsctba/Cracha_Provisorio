extends "res://fases/fase.gd"
## Dia 20: STRIDE por elemento no diagrama de fluxo de dados do app de sinistro por foto.

const CATS := ["S", "T", "R", "I", "D", "E"]
const CAT_NOMES := [
	"(categoria STRIDE)",
	"S: Spoofing (identidade)",
	"T: Tampering (adulterar)",
	"R: Repudiation (negar)",
	"I: Info disclosure (vazar)",
	"D: Denial of service",
	"E: Elevation of privilege",
]

## id, nome, tipo (E entidade, P processo, D depósito, L depósito de log, F fluxo)
const ELEMENTOS := [
	["E1", "Segurado no app", "E"],
	["P1", "API Gateway", "P"],
	["P2", "Análise de foto", "P"],
	["D1", "Bucket de fotos", "D"],
	["D2", "Banco de sinistros", "D"],
	["D3", "Logs de auditoria", "L"],
	["F1", "foto + token (app > gateway)", "F"],
	["F2", "status/resposta (gateway > app)", "F"],
	["F3", "foto na fila (gateway > análise)", "F"],
	["F4", "grava foto (análise > bucket)", "F"],
	["F5", "grava laudo (análise > banco)", "F"],
	["F6", "eventos (gateway > logs)", "F"],
]
const TIPO_NOME := {"E": "entidade externa", "P": "processo", "D": "depósito", "L": "depósito de log", "F": "fluxo"}

const MITIGACOES := [
	"(mitigação)",
	"Instalar antivírus no servidor do gateway",
	"Bloquear acesso público do bucket e servir fotos só por URL pré-assinada de curta duração",
	"Token de curta duração vinculado ao dispositivo, MFA no app e revogação de sessão",
	"Limite de taxa e cota por segurado, tamanho máximo de upload e fila com backpressure",
	"Mensagens de erro genéricas para o cliente; detalhe só no log interno",
	"Seguir a POL-SEG-0001 (rev. 2009) com rigor",
	"Registrar cada envio com identidade, horário e hash da foto, em trilha que o usuário não altera",
	"TLS 1.2+ obrigatório, HSTS e pinning de certificado no app",
	"Autorização decidida no servidor pelo papel do token; ignorar perfil vindo do cliente",
	"Adicionar CAPTCHA na tela de login e pronto",
	"Credenciais individuais com mínimo privilégio no banco e trilha de alteração por linha",
	"Logs enviados em tempo real para armazenamento imutável (WORM) fora do alcance dos analistas",
	"mTLS entre serviços com identidade de serviço verificada (certificado por workload)",
]

## texto, categoria certa, elementos aceitos, índice da mitigação certa
const CARTOES := [
	["O Jeferson achou o token de sessão do cunhado num print do grupo da família e abriu três sinistros em nome dele.", "S", ["E1"], 3],
	["Segurado jura que nunca enviou a foto do para-choque amassado. O app só registra \"upload ok\", sem quem, quando ou o quê.", "R", ["E1", "P1"], 7],
	["O app aceita http:// e, no Wi-Fi do posto de gasolina, alguém troca a foto do carro batido por outra no caminho.", "T", ["F1"], 8],
	["Qualquer um com a URL do bucket lista tudo e baixa fotos de placas, CNH e rosto de segurado.", "I", ["D1"], 2],
	["Um script manda 50 mil fotos de 40 MB por hora; a fila de análise trava e os sinistros de verdade ficam parados.", "D", ["P2", "F3"], 4],
	["Trocando \"perfil\": \"segurado\" por \"perfil\": \"analista\" no corpo da requisição, o usuário aprova o próprio sinistro.", "E", ["P1"], 9],
	["Um analista com a senha compartilhada do banco muda a indenização de R$ 1.800 para R$ 18.000 direto na tabela.", "T", ["D2"], 11],
	["Depois da fraude, alguém apaga as linhas do log de auditoria e ninguém consegue provar quem aprovou o quê.", "R", ["D3"], 12],
	["Quando dá erro, a API devolve stack trace com a string de conexão do banco para o celular do segurado.", "I", ["P1", "F2"], 5],
	["Alguém sobe na rede um serviço que se apresenta como \"analise-foto\" e o gateway passa a mandar as fotos para ele.", "S", ["P2"], 13],
]

var _dfd: Control
var _cat: Array[OptionButton] = []
var _elem: Array[OptionButton] = []
var _mit: Array[OptionButton] = []
var _regra: Array[Label] = []


func _init() -> void:
	dia = 20
	titulo = "Modelagem de ameaças"
	chamado = ("Use o [b]STRIDE por elemento[/b] no diagrama de fluxo de dados (DFD) do app de sinistro por foto. "
		+ "Para cada cartão: escolha a [b]categoria[/b], o [b]elemento[/b] do DFD atingido e a [b]mitigação[/b]. "
		+ "A regra vale: entidade externa só sofre S e R; processo, todas; depósito T, I, D (R só em log); fluxo T, I, D. "
		+ "Nota parcial por cartão.")


func montar() -> void:
	rotulo("DFD nível 1: app de sinistro por foto (desenhado pelo Kauã num guardanapo, passado a limpo pela Jurema)", 14, Estilo.TEXTO_FRACO)
	_dfd = Control.new()
	_dfd.custom_minimum_size = Vector2(0, 290)
	_dfd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dfd.draw.connect(_desenhar_dfd)
	_dfd.resized.connect(_dfd.queue_redraw)
	corpo.add_child(_dfd)
	texto_rico("[color=#8b95a8]Legenda: [b]retângulo[/b] = entidade externa, [b]círculo[/b] = processo, [b]duas linhas[/b] = depósito de dados, "
		+ "[b]seta[/b] = fluxo, [b]tracejado rosa[/b] = fronteira de confiança (internet x rede Tabajara).[/color]")

	var nomes_elem := ["(elemento do DFD)"]
	for e in ELEMENTOS:
		nomes_elem.append("%s %s (%s)" % [e[0], e[1], TIPO_NOME[e[2]]])
	for i in CARTOES.size():
		var p := painel()
		rotulo("Ameaça %d. %s" % [i + 1, CARTOES[i][0]], 15, Estilo.TEXTO, p)
		var h := linha(p)
		var oc := opcoes(CAT_NOMES, h)
		oc.custom_minimum_size = Vector2(250, 0)
		oc.clip_text = true
		oc.fit_to_longest_item = false
		var oe := opcoes(nomes_elem, h)
		oe.custom_minimum_size = Vector2(360, 0)
		oe.clip_text = true
		oe.fit_to_longest_item = false
		var lr := rotulo("", 13, Estilo.TEXTO_FRACO, h)
		lr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var om := opcoes(MITIGACOES, p)
		om.clip_text = true
		om.fit_to_longest_item = false
		om.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		oc.item_selected.connect(func(_x): _checar(i))
		oe.item_selected.connect(func(_x): _checar(i))
		_cat.append(oc)
		_elem.append(oe)
		_mit.append(om)
		_regra.append(lr)
		_checar(i)
	chat("Kauã", "STRIDE achei que era chiclete. Mas já entendi: são seis jeitos de o app dar ruim, né? Só seis? Que alívio.")
	chat("Jurema", "Seis categorias, Kauã. Jeitos de dar ruim com você no projeto são infinitos.")
	chat("Jurema", "{Estagiária|Estagiário}: não chuta categoria. Olha o elemento. Entidade externa não sofre DoS no nosso modelo, sofre gente fingindo ser ela.")
	aviso("A etiqueta ao lado de cada cartão diz se a combinação respeita a regra do STRIDE por elemento.")


# ---------------------------------------------------------------- regra STRIDE por elemento

static func permitido(tipo: String, cat: String) -> bool:
	match tipo:
		"E":
			return cat in ["S", "R"]
		"P":
			return true
		"D":
			return cat in ["T", "I", "D"]
		"L":
			return cat in ["T", "R", "I", "D"]
		"F":
			return cat in ["T", "I", "D"]
	return false


func _cat_de(i: int) -> String:
	var s := _cat[i].selected
	return CATS[s - 1] if s >= 1 else ""


func _elem_de(i: int) -> Array:
	var s := _elem[i].selected
	return ELEMENTOS[s - 1] if s >= 1 else []


func _checar(i: int) -> void:
	var c := _cat_de(i)
	var e := _elem_de(i)
	var l := _regra[i]
	if c == "" or e.is_empty():
		l.text = "regra: aguardando"
		l.add_theme_color_override("font_color", Estilo.TEXTO_FRACO)
	elif permitido(e[2], c):
		l.text = "[OK] %s em %s" % [c, TIPO_NOME[e[2]]]
		l.add_theme_color_override("font_color", Estilo.OK)
	else:
		l.text = "X: %s não se aplica a %s" % [c, TIPO_NOME[e[2]]]
		l.add_theme_color_override("font_color", Estilo.ERRO)


# ---------------------------------------------------------------- desenho do DFD

func _desenhar_dfd() -> void:
	var c := _dfd
	var w := c.size.x
	var sx := w / 900.0
	var fonte := ThemeDB.fallback_font
	var fs := 13
	var linha_cor := Color("c8cfdc")
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("0b0e14"))

	# Fronteira de confiança: retângulo tracejado em volta da rede interna.
	var r := Rect2(Vector2(190 * sx, 12), Vector2(w - 200 * sx, 268))
	var cantos := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		c.draw_dashed_line(cantos[k], cantos[(k + 1) % 4], Estilo.DESTAQUE, 2.0, 8.0)
	c.draw_string(fonte, Vector2(r.position.x + 8, r.position.y + 16), "fronteira de confiança: rede Tabajara", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Estilo.DESTAQUE)
	c.draw_string(fonte, Vector2(10, 30), "internet", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Estilo.TEXTO_FRACO)

	# Posições
	var e1 := Rect2(Vector2(14 * sx, 110), Vector2(130 * sx, 62))
	var p1 := Vector2(330 * sx, 141)
	var p2 := Vector2(590 * sx, 141)
	var raio := minf(54.0, 54.0 * sx)
	var d1 := Rect2(Vector2(720 * sx, 40), Vector2(165 * sx, 40))
	var d2 := Rect2(Vector2(720 * sx, 205), Vector2(165 * sx, 40))
	var d3 := Rect2(Vector2(255 * sx, 228), Vector2(150 * sx, 40))

	# Fluxos (desenhados antes para ficarem por baixo)
	_seta(c, Vector2(e1.end.x, p1.y - 14), Vector2(p1.x - raio, p1.y - 14), "F1 foto + token", Vector2(14, -10))
	_seta(c, Vector2(p1.x - raio, p1.y + 14), Vector2(e1.end.x, p1.y + 14), "F2 status", Vector2(0, 20))
	_seta(c, Vector2(p1.x + raio, p1.y), Vector2(p2.x - raio, p2.y), "F3 fila", Vector2(0, -8))
	_seta(c, p2 + Vector2(raio * 0.7, -raio * 0.7), Vector2(d1.position.x, d1.get_center().y), "F4 grava foto", Vector2(-60, -10))
	_seta(c, p2 + Vector2(raio * 0.7, raio * 0.7), Vector2(d2.position.x, d2.get_center().y), "F5 grava laudo", Vector2(-60, 20))
	_seta(c, p1 + Vector2(0, raio), Vector2(p1.x, d3.position.y), "F6 eventos", Vector2(52, 4))

	# Entidade externa
	c.draw_rect(e1, Color("1e2a3d"))
	c.draw_rect(e1, linha_cor, false, 2.0)
	c.draw_string(fonte, e1.position + Vector2(8, 26), "E1 Segurado", HORIZONTAL_ALIGNMENT_LEFT, e1.size.x - 10, fs, Estilo.TEXTO)
	c.draw_string(fonte, e1.position + Vector2(8, 46), "(no app)", HORIZONTAL_ALIGNMENT_LEFT, e1.size.x - 10, 12, Estilo.TEXTO_FRACO)
	# Processos
	for pr in [[p1, "P1 API", "Gateway"], [p2, "P2 Análise", "de foto"]]:
		c.draw_circle(pr[0], raio, Color("23203a"))
		c.draw_arc(pr[0], raio, 0, TAU, 48, Estilo.CIANO, 2.0)
		c.draw_string(fonte, pr[0] + Vector2(-raio, -2), pr[1], HORIZONTAL_ALIGNMENT_CENTER, raio * 2, fs, Estilo.TEXTO)
		c.draw_string(fonte, pr[0] + Vector2(-raio, 16), pr[2], HORIZONTAL_ALIGNMENT_CENTER, raio * 2, fs, Estilo.TEXTO)
	# Depósitos
	for d in [[d1, "D1 Bucket de fotos"], [d2, "D2 Banco de sinistros"], [d3, "D3 Logs de auditoria"]]:
		var rr: Rect2 = d[0]
		c.draw_rect(rr, Color("1f2a24"))
		c.draw_line(rr.position, Vector2(rr.end.x, rr.position.y), Estilo.OK, 2.0)
		c.draw_line(Vector2(rr.position.x, rr.end.y), rr.end, Estilo.OK, 2.0)
		c.draw_string(fonte, rr.position + Vector2(6, 26), d[1], HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 8, fs, Estilo.TEXTO)


func _seta(c: Control, de: Vector2, para: Vector2, texto: String, desloc: Vector2) -> void:
	var cor := Color("c8cfdc")
	c.draw_line(de, para, cor, 2.0)
	var dir := (para - de).normalized()
	var n := Vector2(-dir.y, dir.x)
	c.draw_colored_polygon(PackedVector2Array([para, para - dir * 11 + n * 5, para - dir * 11 - n * 5]), cor)
	var meio := (de + para) / 2.0 + desloc
	c.draw_string(ThemeDB.fallback_font, meio - Vector2(40, 0), texto, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Estilo.ALERTA)


# ---------------------------------------------------------------- avaliação

func avaliar() -> Dictionary:
	var pontos := 0.0
	var certos_cat := 0
	var certos_elem := 0
	var certos_mit := 0
	var violacoes := 0
	var erros: Array[String] = []
	for i in CARTOES.size():
		var cart: Array = CARTOES[i]
		var c := _cat_de(i)
		var e := _elem_de(i)
		var ok_c: bool = c == cart[1]
		var ok_e: bool = not e.is_empty() and e[0] in cart[2]
		var ok_m: bool = _mit[i].selected == cart[3]
		if c != "" and not e.is_empty() and not permitido(e[2], c):
			violacoes += 1
		pontos += (0.4 if ok_c else 0.0) + (0.3 if ok_e else 0.0) + (0.3 if ok_m else 0.0)
		certos_cat += int(ok_c)
		certos_elem += int(ok_e)
		certos_mit += int(ok_m)
		if not (ok_c and ok_e) and erros.size() < 3:
			erros.append("ameaça %d é %s em %s" % [i + 1, cart[1], "/".join(cart[2])])
	var nota := proporcao(pontos, CARTOES.size()) - violacoes * 3
	var com := "Categorias certas: %d/10, elementos: %d/10, mitigações: %d/10." % [certos_cat, certos_elem, certos_mit]
	if violacoes > 0:
		com += " %d combinação(ões) violam o STRIDE por elemento (ex.: fluxo não sofre Spoofing, depósito comum não sofre Repudiation)." % violacoes
	if not erros.is_empty():
		com += " Revise: " + "; ".join(erros) + "."
	if nota >= 90:
		com += " Modelo aprovado: cada ameaça amarrada a um elemento e a um controle. O Kauã finalmente sabe que STRIDE não é chiclete."
	else:
		com += " Lembre: Spoofing ataca identidade (entidades e processos), Tampering e Disclosure atacam dados (fluxos e depósitos), Repudiation se resolve com trilha que o próprio usuário não altera."
	return {"nota": clampi(nota, 0, 100), "comentario": com, "cagada": ""}


func solucao_teste() -> void:
	for i in CARTOES.size():
		var cart: Array = CARTOES[i]
		_cat[i].selected = CATS.find(cart[1]) + 1
		for k in ELEMENTOS.size():
			if ELEMENTOS[k][0] == cart[2][0]:
				_elem[i].selected = k + 1
		_mit[i].selected = cart[3]
		_checar(i)
