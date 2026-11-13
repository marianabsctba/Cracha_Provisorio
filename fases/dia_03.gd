extends "res://fases/fase.gd"
## Dia 3: revisão de acessos. Cruzar o export do RH com o export do AD e decidir o destino de cada conta.

const ACOES := [
	"(escolha)",
	"Manter",
	"Desabilitar",
	"Desabilitar e abrir incidente",
	"Remover de grupo",
	"Investigar dono",
	"Manter e registrar exceção",
]

# Matrícula, nome, cargo/área, situação no RH.
const RH := [
	["10233", "Jurema Almeida", "Segurança da Informação", "Ativa"],
	["10871", "Rogério Figueiredo", "Infraestrutura", "Desligado em 14/08/2026"],
	["11204", "Patrícia Matos", "Marketing", "Ativa (transferida do Financeiro em 02/10/2026)"],
	["11319", "Camila Nogueira", "Atuária", "Licença-maternidade desde 05/09/2026"],
	["12002", "Lucas Santos", "Estágio TI", "Contrato de estágio encerrado em 30/06/2026"],
	["09114", "Valdecir Prado", "Gerência de TI", "Ativo"],
	["11788", "Ana Costa", "Financeiro", "Ativa"],
	["10540", "Fábio Rezende", "Comercial", "Desligado em 20/07/2026"],
	["12150", "Kauã Souza", "Desenvolvimento", "Ativo"],
	["11502", "Marcos Oliveira", "Infraestrutura", "Ativo"],
]

# Conta, employeeID, habilitada, último logon, senha nunca expira, grupos,
# respostas com peso (ação -> peso), comentário do gabarito.
const CONTAS := [
	{"conta": "j.almeida", "id": "10233", "hab": "True", "logon": "13/11/2026", "nunca": "False",
	 "grupos": "SegInfo, VPN", "pesos": {1: 1.0, 6: 0.5},
	 "porque": "j.almeida: ativa e com acesso compatível. Manter."},
	{"conta": "r.figueiredo", "id": "10871", "hab": "True", "logon": "12/11/2026", "nunca": "False",
	 "grupos": "Domain Admins, VPN", "pesos": {3: 1.0, 2: 0.5, 5: 0.4},
	 "porque": "r.figueiredo: desligado em agosto, Domain Admin e com logon ONTEM. Desabilitar já e tratar como incidente (alguém está usando a conta)."},
	{"conta": "p.matos", "id": "11204", "hab": "True", "logon": "13/11/2026", "nunca": "False",
	 "grupos": "Marketing, Financeiro", "pesos": {4: 1.0},
	 "porque": "p.matos: mudou de área e levou o acesso antigo junto (acúmulo de privilégio). Remover do grupo Financeiro."},
	{"conta": "c.nogueira", "id": "11319", "hab": "True", "logon": "04/09/2026", "nunca": "False",
	 "grupos": "Atuaria", "pesos": {1: 1.0, 6: 0.5},
	 "porque": "c.nogueira: licença-maternidade não é desligamento. O vínculo está ativo; desabilitar sem processo combinado com o RH é erro (e dor de cabeça trabalhista)."},
	{"conta": "teste123", "id": "", "hab": "True", "logon": "10/11/2026", "nunca": "True",
	 "grupos": "VPN, Domain Users", "pesos": {3: 1.0, 5: 0.75, 2: 0.5},
	 "porque": "teste123: sem dono, sem matrícula, senha que nunca expira, VPN e logon há 3 dias. Desabilitar e investigar quem usa."},
	{"conta": "svc_backup", "id": "", "hab": "True", "logon": "13/11/2026", "nunca": "True",
	 "grupos": "Backup Operators", "pesos": {6: 1.0, 1: 0.5, 5: 0.5},
	 "porque": "svc_backup: conta de serviço do backup. Senha que nunca expira é exceção aceitável se documentada (dono, justificativa, rotação controlada). Manter e registrar exceção."},
	{"conta": "l.santos", "id": "12002", "hab": "True", "logon": "28/06/2026", "nunca": "False",
	 "grupos": "Estagiarios, VPN", "pesos": {2: 1.0, 3: 0.75},
	 "porque": "l.santos: estágio encerrado em junho e conta ainda habilitada. Último logon antes do fim do contrato, então não há sinal de uso indevido: desabilitar."},
	{"conta": "v.prado", "id": "09114", "hab": "True", "logon": "13/11/2026", "nunca": "True",
	 "grupos": "Domain Admins, Financeiro, VPN", "pesos": {4: 1.0},
	 "porque": "v.prado: gerente não precisa de Domain Admins nem de Financeiro para ler e-mail. Menor privilégio: remover dos grupos."},
	{"conta": "a.costa", "id": "11788", "hab": "True", "logon": "13/11/2026", "nunca": "False",
	 "grupos": "Financeiro, VPN", "pesos": {1: 1.0},
	 "porque": "a.costa: ativa no Financeiro, grupos coerentes. Manter."},
	{"conta": "f.rezende", "id": "10540", "hab": "False", "logon": "19/07/2026", "nunca": "False",
	 "grupos": "Comercial, VPN", "pesos": {1: 0.75, 4: 1.0, 2: 0.75},
	 "porque": "f.rezende: desligado e já desabilitado. O ideal é limpar os grupos (VPN) para a conta não voltar com acesso se alguém reabilitar."},
	{"conta": "k.souza", "id": "12150", "hab": "True", "logon": "13/11/2026", "nunca": "False",
	 "grupos": "Desenvolvimento, Domain Admins", "pesos": {4: 1.0},
	 "porque": "k.souza: dev em Domain Admins \"para instalar o Node\". Remover do grupo; instalação se resolve com outra coisa, não com a chave do reino."},
	{"conta": "m.oliveira", "id": "11502", "hab": "True", "logon": "13/11/2026", "nunca": "False",
	 "grupos": "Infra-Suporte, Domain Admins", "pesos": {1: 1.0, 6: 0.5},
	 "porque": "m.oliveira: administrador de infraestrutura ativo. Domain Admins faz parte do cargo. Manter."},
]

var _escolhas: Array[OptionButton] = []
var _contador: Label
var _reagiu := {}


func _init() -> void:
	dia = 3
	titulo = "Revisão de acessos"
	chamado = ("Cruze o [b]export do RH[/b] com o [b]export do AD[/b] pela matrícula (employeeID) e escolha uma ação para cada uma das 12 contas. "
		+ "Ex-funcionário não fica habilitado, ninguém acumula grupo que não usa, conta sem dono é suspeita "
		+ "e conta de serviço não se desliga no impulso. Hoje é 13/11/2026.")


func montar() -> void:
	var abas := TabContainer.new()
	abas.custom_minimum_size = Vector2(0, 285)
	corpo.add_child(abas)

	var rh := "MATRIC  NOME                    ÁREA                      SITUAÇÃO\n"
	for r in RH:
		rh += "%-7s %-23s %-25s %s\n" % [r[0], r[1], r[2], r[3]]
	var t_rh := bloco_mono(rh.strip_edges(false, true), 250, abas)
	abas.set_tab_title(0, "RH: folha_ativos_2026-11.csv")
	t_rh.add_theme_font_size_override("font_size", 13)

	var ad := "PS> Get-ADUser -Filter * -Properties employeeID,LastLogonDate,PasswordNeverExpires,MemberOf\n\n"
	ad += "SamAccountName employeeID Enabled LastLogonDate PwdNeverExpires MemberOf\n"
	for c in CONTAS:
		ad += "%-14s %-10s %-7s %-13s %-15s %s\n" % [c["conta"], c["id"] if c["id"] != "" else "(vazio)", c["hab"], c["logon"], c["nunca"], c["grupos"]]
	var t_ad := bloco_mono(ad.strip_edges(false, true), 250, abas)
	abas.set_tab_title(1, "AD: Get-ADUser (tabajara.local)")
	t_ad.add_theme_font_size_override("font_size", 13)

	var cab := linha()
	rotulo("Decisão por conta", 15, Estilo.DESTAQUE, cab).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contador = rotulo("", 13, Estilo.TEXTO_FRACO, cab)
	_contador.autowrap_mode = TextServer.AUTOWRAP_OFF

	var grade := GridContainer.new()
	grade.columns = 4
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 6)
	corpo.add_child(grade)
	for i in CONTAS.size():
		var nome := rotulo(CONTAS[i]["conta"], 14, Estilo.CIANO, grade)
		nome.custom_minimum_size = Vector2(120, 0)
		nome.add_theme_font_override("font", Estilo.mono())
		var ob := opcoes(ACOES, grade)
		ob.custom_minimum_size = Vector2(290, 0)
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.item_selected.connect(_escolheu.bind(i))
		_escolhas.append(ob)
	_atualizar_contador()

	chat("Valdecir", "A auditoria quer a revisão de 2023. Mas faz a de agora, que a de 2023 eu perdi o arquivo.")
	chat("Jurema", "Cruza pela matrícula, não pelo nome. Nome tem homônimo, matrícula não. E olha a data do último logon com carinho.")
	aviso("Dica: as duas listas estão nas abas acima. Conta sem matrícula não tem dono no RH.")


func _escolheu(acao: int, i: int) -> void:
	_atualizar_contador()
	var conta: String = CONTAS[i]["conta"]
	var chave := "%s:%d" % [conta, acao]
	if _reagiu.has(chave):
		return
	_reagiu[chave] = true
	if conta == "v.prado" and acao == 4:
		chat("Valdecir", "Me tirar do Domain Admins? Eu sou o GERENTE. Como eu vou trocar o papel de parede dos outros?")
	elif conta == "k.souza" and acao == 4:
		chat("Kauã", "Mas eu preciso de admin pra instalar o Node! E o Python. E um jogo de corrida, mas esse é pra testar a placa.")
	elif conta == "teste123" and acao in [3, 5]:
		chat("Dona Cida", "teste123? Isso aí o rapaz da consultoria criou em 2019. Ele foi embora, a conta ficou. Igual a caneca dele na copa.")
	elif conta == "r.figueiredo" and acao in [2, 3]:
		chat("Jurema", "Logon ontem de um cara desligado em agosto. Ou ele virou fantasma ou alguém tem a senha dele. Nenhuma das duas é boa.")


func _atualizar_contador() -> void:
	var feitas := 0
	for ob in _escolhas:
		if ob.selected > 0:
			feitas += 1
	_contador.text = "%d de %d contas decididas" % [feitas, CONTAS.size()]


func avaliar() -> Dictionary:
	var pontos := 0.0
	var erros: Array[String] = []
	for i in CONTAS.size():
		var acao := _escolhas[i].selected
		var pesos: Dictionary = CONTAS[i]["pesos"]
		var p: float = pesos.get(acao, 0.0)
		pontos += p
		if p < 1.0:
			erros.append(CONTAS[i]["porque"])
	var nota := proporcao(pontos, CONTAS.size())

	var cagada := ""
	var acao_backup := _escolhas[5].selected
	if acao_backup == 2 or acao_backup == 3:
		cagada = "Você desabilitou a svc_backup. O backup das 2h falhou, o de amanhã também, e ninguém percebeu até o ransomware do dia 16."

	var comentario := ""
	if erros.is_empty():
		comentario = "Revisão impecável: desligados fora, acúmulos removidos, conta órfã investigada e a exceção da conta de serviço documentada."
	else:
		comentario = "Acertos ponderados: %.1f de %d. " % [pontos, CONTAS.size()]
		var mostrar := mini(erros.size(), 3)
		for k in mostrar:
			comentario += erros[k] + " "
		if erros.size() > mostrar:
			comentario += "(e mais %d conta(s) com decisão discutível)" % (erros.size() - mostrar)
	return {"nota": nota, "comentario": comentario.strip_edges(), "cagada": cagada}


func solucao_teste() -> void:
	for i in CONTAS.size():
		var melhor := 0
		var maior := 0.0
		var pesos: Dictionary = CONTAS[i]["pesos"]
		for k in pesos:
			if pesos[k] > maior:
				maior = pesos[k]
				melhor = k
		_escolhas[i].select(melhor)
	_atualizar_contador()
