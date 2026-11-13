extends "res://fases/fase.gd"
## Dia 10: LGPD. Classificar colunas, decidir a campanha e calcular o prazo de comunicação
## de incidente à ANPD (3 dias úteis, Resolução CD/ANPD nº 15/2024) com feriados de verdade.

const PESSOAL := 0
const SENSIVEL := 1
const ANONIMO := 2

# coluna, exemplo, classe certa, explicação
const COLUNAS := [
	["nome_completo", "Odair José da Silva", PESSOAL, "identifica diretamente"],
	["cpf", "318.445.207-??", PESSOAL, "identifica diretamente"],
	["email", "odair.ze@exemplo.com.br", PESSOAL, "identifica diretamente"],
	["data_nascimento", "1971-03-08", PESSOAL, "pessoal comum"],
	["cid_sinistro_saude", "E11.9", SENSIVEL, "dado de saúde (art. 5º, II)"],
	["religiao_seguro_funeral", "Católica", SENSIVEL, "convicção religiosa (art. 5º, II)"],
	["biometria_facial_app", "<template 512 bytes>", SENSIVEL, "dado biométrico (art. 5º, II)"],
	["placa_veiculo", "ABC1D23", PESSOAL, "identifica indiretamente"],
	["cpf_sha256_sem_sal", "9f2c...e81a", PESSOAL, "pseudonimizado, mas reversível por força bruta"],
	["faixa_etaria_por_cidade", "Curitiba, 40-49: 18.322", ANONIMO, "agregado em grupos grandes"],
	["ip_acesso", "198.51.100.23", PESSOAL, "identifica indiretamente"],
	["renda_mensal", "R$ 4.870,00", PESSOAL, "pessoal comum (financeiro não é sensível na LGPD)"],
]

const FERIADOS_2026 := ["2026-01-01", "2026-04-03", "2026-04-21", "2026-05-01", "2026-09-07",
	"2026-10-12", "2026-11-02", "2026-11-15", "2026-11-20", "2026-12-25"]
const CONHECIMENTO := "2026-03-31"

var _classes: Array = []
var _campanha: OptionButton
var _data: LineEdit


func _init() -> void:
	dia = 10
	titulo = "LGPD na planilha"
	chamado = ("1) Classifique cada coluna da base de segurados: dado pessoal, dado pessoal [b]sensível[/b] (art. 5º, II da LGPD) ou "
		+ "[b]anonimizado[/b]. 2) Diga como a campanha de Dia dos Namorados pode usar a base. 3) Um incidente com dados pessoais foi "
		+ "confirmado na terça, 31/03/2026. Pela Resolução CD/ANPD nº 15/2024, a comunicação à ANPD e aos titulares é em "
		+ "[b]3 dias úteis[/b] contados do conhecimento. Digite a data limite (dd/mm/aaaa).")


func montar() -> void:
	var p1 := painel()
	rotulo("1. Classificação das colunas", 14, Estilo.CIANO, p1)
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 14)
	p1.add_child(grade)
	for c in COLUNAS:
		var n := rotulo(c[0], 14, Estilo.TEXTO, grade)
		n.add_theme_font_override("font", Estilo.mono())
		rotulo(c[1], 13, Estilo.TEXTO_FRACO, grade)
		var ob := opcoes(["(classificar)", "Pessoal", "Pessoal sensível", "Anonimizado"], grade)
		_classes.append(ob)
	rotulo("Sobre o cpf_sha256_sem_sal: CPF tem 9 dígitos livres + 2 verificadores, ou seja, 10^9 possibilidades. "
		+ "Uma GPU comum faz bilhões de SHA-256 por segundo: a tabela inteira de CPFs sai em menos de um segundo. Hash sem sal de dado de espaço pequeno é só um apelido.", 13, Estilo.TEXTO_FRACO, p1)

	var p2 := painel()
	rotulo("2. Campanha de Dia dos Namorados", 14, Estilo.CIANO, p2)
	_campanha = opcoes(["(escolha)",
		"Usar a base inteira: os dados já são nossos, foram coletados pelo seguro",
		"Nome e e-mail, com base no legítimo interesse, teste de balanceamento documentado, opt-out fácil em todo e-mail e nenhum dado sensível",
		"Usar o CID de saúde para oferecer seguro de vida mais caro a quem tem doença crônica",
		"Pedir consentimento genérico no rodapé do site: 'ao navegar você concorda com tudo'"], p2)
	_campanha.clip_text = true
	_campanha.fit_to_longest_item = false
	_campanha.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var p3 := painel()
	rotulo("3. Prazo de comunicação do incidente", 14, Estilo.CIANO, p3)
	rotulo(_calendario(), 13, Estilo.TEXTO, p3).add_theme_font_override("font", Estilo.mono())
	var l := linha(p3)
	rotulo("Data limite:", 14, Estilo.TEXTO, l)
	_data = campo("dd/mm/aaaa", l)
	chat("Valdecir", "Pergunta rápida: religião é dado sensível? Porque o seguro funeral pergunta a religião para saber se é missa ou culto.")
	chat("Jurema", "É sensível. E renda, Valdecir, por mais que doa, é só pessoal comum.")
	chat("Valdecir", "E o prazo de incidente, é 72 horas igual na Europa?")
	chat("Jurema", "Aqui são 3 dias ÚTEIS. Feriado e fim de semana não contam. Conta direito, que a ANPD conta.")


func _calendario() -> String:
	var t := "Feriados nacionais 2026: " + ", ".join(FERIADOS_2026.map(func(d): return "%s/%s" % [d.substr(8, 2), d.substr(5, 2)])) + "\n\n"
	t += "        MARÇO / ABRIL 2026\n  dom  seg  ter  qua  qui  sex  sáb\n"
	var u := Time.get_unix_time_from_datetime_string("2026-03-29T12:00:00")
	for semana in 2:
		var l := ""
		for d in 7:
			var dd := Time.get_datetime_dict_from_unix_time(u + (semana * 7 + d) * 86400)
			var marca := " "
			var iso := "%04d-%02d-%02d" % [dd.year, dd.month, dd.day]
			if iso in FERIADOS_2026:
				marca = "F"
			if iso == CONHECIMENTO:
				marca = "*"
			l += "  %02d%s" % [dd.day, marca]
		t += l + "\n"
	t += "\n* dia do conhecimento do incidente   F feriado nacional"
	return t


## Soma `n` dias úteis a partir da data ISO (o dia inicial não conta).
static func somar_dias_uteis(inicio: String, n: int) -> String:
	var u := Time.get_unix_time_from_datetime_string(inicio + "T12:00:00")
	var contados := 0
	while contados < n:
		u += 86400
		var dd := Time.get_datetime_dict_from_unix_time(u)
		var iso := "%04d-%02d-%02d" % [dd.year, dd.month, dd.day]
		if dd.weekday != 0 and dd.weekday != 6 and not (iso in FERIADOS_2026):
			contados += 1
	var f := Time.get_datetime_dict_from_unix_time(u)
	return "%02d/%02d/%04d" % [f.day, f.month, f.year]


func avaliar() -> Dictionary:
	var certos := 0
	var erros := []
	for i in COLUNAS.size():
		if _classes[i].selected - 1 == COLUNAS[i][2]:
			certos += 1
		else:
			erros.append("%s (%s)" % [COLUNAS[i][0], COLUNAS[i][3]])
	var nota := int(round(50.0 * certos / COLUNAS.size()))
	var partes := ["Classificou %d de %d colunas." % [certos, COLUNAS.size()]]
	if not erros.is_empty() and erros.size() <= 4:
		partes.append("Errou: " + ", ".join(erros) + ".")
	var cagada := ""
	match _campanha.selected:
		2:
			nota += 20
			partes.append("Campanha certa: dado mínimo, base legal documentada e opt-out.")
		3:
			cagada = "Propôs usar o CID de saúde dos sinistros para segmentar marketing. A LGPD (art. 11) e a ANS já estão ligando."
			partes.append("Usar dado de saúde para precificar ou fazer marketing é proibido e discriminatório.")
		_:
			partes.append("Dado coletado para o seguro não vira automaticamente dado de marketing: precisa de base legal, finalidade compatível e opt-out.")
	var prazo := somar_dias_uteis(CONHECIMENTO, 3)
	if _data.text.strip_edges() == prazo:
		nota += 30
		partes.append("Prazo certo: %s (pula a Sexta-feira Santa e o fim de semana)." % prazo)
	else:
		partes.append("O prazo era %s: quarta 01/04 (1), quinta 02/04 (2), sexta 03/04 é feriado, fim de semana não conta, segunda 06/04 (3)." % prazo)
	return {"nota": nota, "comentario": " ".join(partes), "cagada": cagada}


func solucao_teste() -> void:
	for i in COLUNAS.size():
		_classes[i].selected = COLUNAS[i][2] + 1
	_campanha.selected = 2
	_data.text = somar_dias_uteis(CONHECIMENTO, 3)
