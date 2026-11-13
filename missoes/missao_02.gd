extends Node
## Dia 2: inventário de ativos. A planilha tem 14 itens, o switch vê 19 MACs.
## A jogadora compara o MAC de cada aparelho com a planilha e etiqueta o que é TI paralela.

const Estilo := preload("res://scripts/estilo.gd")

var escritorio: Node3D

# nome, posição, tamanho, cor, MAC, IP, portas, etiqueta visível, está na planilha?, observação
const APARELHOS := [
	["Impressora 'Godzilla'", Vector3(15.6, 0, 2.5), Vector3.ZERO, Color.WHITE, "00:1B:A9:4C:22:10", "10.0.5.20", "443 (HTTPS), 631 (IPP), 9100 (RAW)", "PAT-0007", true, "Etiqueta patrimonial colada. Cheira a toner."],
	["Telefone IP da recepção", Vector3(-5.6, 1.15, 7.4), Vector3(0.22, 0.12, 0.2), Color("222831"), "00:04:F2:91:7A:03", "10.0.7.11", "5060 (SIP)", "sem etiqueta (caiu atrás do balcão)", true, "A etiqueta está no chão, embaixo do balcão."],
	["Notebook do Valdecir", Vector3(-12.4, 0.77, -7.9), Vector3(0.36, 0.03, 0.25), Color("9aa0aa"), "3C:52:82:0E:44:91", "10.0.3.101", "445 (SMB), 3389 (RDP)", "PAT-0001", true, "Adesivo: 'Eu amo meu chefe'. Foi presente dele para ele mesmo."],
	["Switch do andar", Vector3(-16.6, 0.6, 0.6), Vector3(0.25, 0.5, 0.9), Color("2a2f3a"), "70:4C:A5:10:00:01", "10.0.0.2", "22 (SSH), 443 (HTTPS)", "PAT-0003", true, "Tem 19 MACs na tabela de endereços. A planilha tem 14."],
	["Raspberry Pi embaixo da mesa", Vector3(-9.0, 0.02, -1.15), Vector3(0.1, 0.03, 0.07), Color("2f8f46"), "B8:27:EB:5D:13:37", "10.0.5.66", "22 (SSH), 8080 (HTTP)", "post-it: 'NÃO DESLIGAR. ass: estagiário 2024'", false, "OUI B8:27:EB é da Raspberry Pi Foundation. Cabo de rede ligado direto na tomada da parede."],
	["Impressora velha da gerência", Vector3(-10.0, 0, -10.2), Vector3(0.6, 0.7, 0.5), Color("cfcab8"), "00:10:83:0A:BB:01", "10.0.3.250", "23 (Telnet), 21 (FTP), 80 (HTTP)", "sem etiqueta", false, "LaserJet de 1999. Telnet aberto, senha padrão. O Valdecir chama de 'a confiável'."],
	["Smart TV da sala de reunião", Vector3(3.8, 1.0, -10.85), Vector3.ZERO, Color.WHITE, "A8:23:FE:77:10:42", "10.0.5.140", "8008, 8009 (cast), 9080", "sem etiqueta", false, "Ligada na rede corporativa para 'espelhar o PowerPoint'. Também espelha qualquer um no Wi-Fi."],
	["Roteador 4G do Kauã", Vector3(10.45, 0.76, -1.2), Vector3(0.14, 0.04, 0.1), Color("f2f2f2"), "0C:80:63:AA:19:5E", "10.0.5.77", "80 (HTTP), 53 (DNS)", "sem etiqueta", false, "Escondido atrás do monitor. 'É pra fugir do proxy, rapidinho.' Faz ponte entre a rede interna e a internet."],
	["Câmera IP na copa", Vector3(-8.85, 2.4, -6.4), Vector3(0.12, 0.12, 0.16), Color("eeeeee"), "E0:50:8B:3C:00:9A", "10.0.5.201", "554 (RTSP), 80 (HTTP), admin:admin", "sem etiqueta", false, "Instalada pelo Valdecir para descobrir quem come o iogurte dos outros. Transmite sem senha."],
]

const PLANILHA := """PLANILHA DE ATIVOS (v_final_FINAL_2.xlsx)
PAT-0001  Notebook gerência   3C:52:82:0E:44:91
PAT-0002  Servidor arquivos   00:50:56:01:AA:02
PAT-0003  Switch andar        70:4C:A5:10:00:01
PAT-0004  Firewall            00:09:0F:11:22:33
PAT-0005  Desktop recepção    D8:9E:F3:41:22:07
PAT-0006  Desktop Jurema      D8:9E:F3:41:22:15
PAT-0007  Impressora andar    00:1B:A9:4C:22:10
PAT-0008  Desktop Kauã        D8:9E:F3:41:22:16
PAT-0009  Desktop estagiária  D8:9E:F3:41:22:19
PAT-0010  AP Wi-Fi corp       F0:9F:C2:7D:01:01
PAT-0011  Telefone recepção   00:04:F2:91:7A:03
PAT-0012  NVR câmeras         BC:AD:28:00:31:0C
PAT-0013  Nobreak DC          00:C0:B7:5A:00:01
PAT-0014  Servidor boletos    00:50:56:01:AA:09"""

var _decisao := {}       # índice -> "planilha" | "etiqueta"
var _ligou_raspberry := false


func _ready() -> void:
	for i in APARELHOS.size():
		var a: Array = APARELHOS[i]
		var no: Node3D
		if a[2] == Vector3.ZERO:
			# aparelho já existe no cenário: cria só uma área interativa em volta
			no = StaticBody3D.new()
			var forma := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.0, 1.2, 0.9) if i == 0 else Vector3(2.4, 1.3, 0.3)
			forma.shape = bs
			forma.position.y = bs.size.y / 2.0
			no.add_child(forma)
			no.position = a[1]
			escritorio.add_child(no)
		else:
			no = escritorio.caixa(a[1], a[2], a[3])
			escritorio.caixa(Vector3(a[2].x * 0.3, a[2].y, 0), Vector3(0.025, 0.025, 0.025), Color("39ff6a"), false, 4.0, no)
		escritorio.interativo(no, "Inspecionar: " + a[0], _inspecionar.bind(i))
	escritorio.objetivo("Inspecione os aparelhos do andar (E), compare o MAC com a planilha e etiquete o que não está lá. Depois entregue no seu computador.")
	_atualizar_hud()


func _atualizar_hud() -> void:
	var etiquetados := 0
	for k in _decisao:
		if _decisao[k] == "etiqueta":
			etiquetados += 1
	escritorio.extra(PLANILHA + "\n\nInspecionados: %d de %d  ·  Etiquetados: %d" % [_decisao.size(), APARELHOS.size(), etiquetados])


func _inspecionar(i: int) -> void:
	var a: Array = APARELHOS[i]
	var texto := "%s\nMAC: %s   IP: %s\nPortas abertas: %s\nEtiqueta: %s\n%s" % [a[0], a[4], a[5], a[6], a[7], a[9]]
	if _decisao.has(i):
		texto += "\n(Você marcou: %s)" % ("está na planilha" if _decisao[i] == "planilha" else "TI paralela, etiquetado")
	var opcoes := ["Está na planilha", "Etiquetar: não inventariado"]
	if i == 4 and not _ligou_raspberry:
		opcoes.append("Ligar na tomada para ver o que faz")
	escritorio.dialogo("Sistema", texto, opcoes, func(e: int):
		if e == 0:
			_decisao[i] = "planilha"
		elif e == 1:
			_decisao[i] = "etiqueta"
			escritorio.dialogo("Você", "Etiqueta amarela colada: \"ATIVO NÃO INVENTARIADO. NÃO REMOVER. SEGURANÇA DA INFORMAÇÃO.\"")
		elif e == 2:
			_ligou_raspberry = true
			_decisao[i] = "etiqueta"
			escritorio.dialogo("Sistema", "O Raspberry ligou. O LED piscou. Dez segundos depois a impressora Godzilla começou a imprimir 400 páginas de 'pwned by estagiario 2024' e o switch acusou varredura ARP no andar inteiro.")
			escritorio.dialogo("Jurema", "Eu falei. Para. De. Ligar. Coisa. Que. Você. Acha.")
		_atualizar_hud())


func usar_pc() -> void:
	escritorio.dialogo("Sistema", "Entregar o inventário com %d de %d aparelhos avaliados?" % [_decisao.size(), APARELHOS.size()],
		["Entregar", "Ainda não"], func(e: int):
			if e == 0:
				escritorio.finalizar(_avaliar()))


func _avaliar() -> Dictionary:
	var acertos := 0
	var erros := []
	for i in APARELHOS.size():
		var certo: String = "planilha" if APARELHOS[i][8] else "etiqueta"
		if _decisao.get(i, "") == certo:
			acertos += 1
		else:
			erros.append(APARELHOS[i][0])
	var nota := int(round(100.0 * acertos / APARELHOS.size()))
	var comentario := "Você classificou %d de %d aparelhos certo comparando o MAC com a planilha." % [acertos, APARELHOS.size()]
	if not erros.is_empty():
		comentario += " Errou ou deixou de ver: %s." % ", ".join(erros)
	comentario += " Inventário é o controle número 1 do CIS: não dá para proteger o que você não sabe que existe."
	var cagada := ""
	if _ligou_raspberry:
		nota = mini(nota, 40)
		cagada = "Ligou um Raspberry Pi desconhecido na rede de produção para 'ver o que fazia'. Ele fazia isso."
	return {"nota": nota, "comentario": comentario, "cagada": cagada}
