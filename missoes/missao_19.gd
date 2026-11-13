extends Node
## Dia 19: caça ao ponto de acesso clandestino "Tabajara-Visitante2" com medidor de sinal.
## RSSI pelo modelo log-distância: RSSI = P(1 m) - 10·n·log10(d) - perda por parede.

const Estilo := preload("res://scripts/estilo.gd")

const P1M := -38.0         # dBm a 1 metro
const EXPOENTE := 2.8      # ambiente de escritório
const PERDA_PAREDE := 6.0  # dB por parede (drywall/vidro)

const ESCONDERIJOS := [
	[Vector3(-16.0, 0.5, 4.2), "dentro do vaso da planta, no canto do open space"],
	[Vector3(3.8, 0.75, -9.6), "na mesa da sala de reunião, disfarçado de carregador"],
	[Vector3(-5.5, 0.74, -8.3), "na mesa da copa, no meio dos potes de sorvete"],
	[Vector3(15.6, 1.12, 2.5), "em cima da impressora Godzilla, atrás da bandeja"],
	[Vector3(-16.4, 0.05, -1.5), "no chão, encostado no rodapé perto do switch"],
]

var escritorio: Node3D
var _ap: Node3D
var _lugar := ""
var _achou := false
var _tempo := 0.0
var _rng := RandomNumberGenerator.new()
var _rssi_suave := -95.0


func _ready() -> void:
	_rng.randomize()
	var e: Array = ESCONDERIJOS[_rng.randi_range(0, ESCONDERIJOS.size() - 1)]
	_lugar = e[1]
	_ap = escritorio.caixa(e[0], Vector3(0.11, 0.035, 0.08), Color("101010"))
	escritorio.caixa(Vector3(0.03, 0.035, -0.041), Vector3(0.012, 0.012, 0.004), Color("ff2a2a"), false, 5.0, _ap)
	escritorio.interativo(_ap, "Examinar o aparelhinho", _examinar)
	escritorio.objetivo("Use o medidor (canto superior direito) para achar o ponto de acesso clandestino. O sinal sobe quando você chega perto; paredes atrapalham. Ande devagar e observe.")


func _process(delta: float) -> void:
	if _achou:
		return
	_tempo += delta
	var j: CharacterBody3D = escritorio.jogador
	var cabeca := j.global_position + Vector3(0, 1.2, 0)
	var origem := _ap.global_position + Vector3(0, 0.05, 0)
	var d := maxf(cabeca.distance_to(origem), 0.3)
	var paredes := _contar_paredes(origem, cabeca, j)
	var rssi := P1M - 10.0 * EXPOENTE * (log(d) / log(10.0)) - PERDA_PAREDE * paredes + _rng.randf_range(-2.0, 2.0)
	rssi = clampf(rssi, -95.0, -20.0)
	_rssi_suave = lerpf(_rssi_suave, rssi, 0.15)
	var nivel := int(remap(_rssi_suave, -95.0, -30.0, 0.0, 24.0))
	var barra := ""
	for i in 24:
		barra += "|" if i < nivel else "."
	var dist_est := pow(10.0, (P1M - (_rssi_suave + PERDA_PAREDE * paredes)) / (10.0 * EXPOENTE))
	escritorio.extra("airodump-ng wlan0mon --essid Tabajara-Visitante2\n\nBSSID  02:1F:7C:B0:0B:19   CH 6   WPA2-PSK\nENC    CCMP   PWR %4d dBm\n[%s]\n\nparedes no caminho (estimado): %d\ndistância estimada: %.1f m\ntempo: %ds" % [int(_rssi_suave), barra, paredes, dist_est, int(_tempo)])


func _contar_paredes(de: Vector3, ate: Vector3, j: CharacterBody3D) -> int:
	var espaco: PhysicsDirectSpaceState3D = escritorio.get_world_3d().direct_space_state
	var excluir: Array[RID] = [j.get_rid(), (_ap as CollisionObject3D).get_rid()]
	var n := 0
	var inicio := de
	for _i in 6:
		var q := PhysicsRayQueryParameters3D.create(inicio, ate)
		q.exclude = excluir
		var r: Dictionary = espaco.intersect_ray(q)
		if r.is_empty():
			break
		var col: CollisionObject3D = r["collider"]
		excluir.append(col.get_rid())
		# só conta obstáculos altos (paredes), não mesas
		var forma := col.get_child(0) as CollisionShape3D
		if forma and forma.shape is BoxShape3D and (forma.shape as BoxShape3D).size.y >= 2.0:
			n += 1
		inicio = r["position"]
	return n


func _examinar() -> void:
	_achou = true
	escritorio.extra("")
	escritorio.dialogo("Você", "Achei: um roteador de viagem do tamanho de uma caixa de fósforos, %s, ligado num carregador de celular. SSID: Tabajara-Visitante2." % _lugar)
	escritorio.dialogo("Jurema", "O que você faz com ele?", [
		"Fotografar no lugar, anotar hora, MAC e SSID, desligar, lacrar em saco de evidência e abrir incidente",
		"Arrancar da tomada e jogar no lixo antes que alguém veja",
		"Plugar no meu notebook da rede corporativa para ver quem configurou",
	], func(e: int):
		var nota := 50
		var partes := ["Você achou o AP clandestino em %d segundos usando o RSSI." % int(_tempo)]
		if _tempo < 150:
			nota += 10
		if e == 0:
			nota += 20
			partes.append("Procedimento certo: documentar antes de mexer e preservar a cadeia de custódia.")
		elif e == 1:
			partes.append("Jogar no lixo destrói a evidência. Quem colocou e o que capturou? Ninguém vai saber.")
		else:
			partes.append("Plugar um aparelho desconhecido na rede corporativa é exatamente o que o atacante queria.")
		escritorio.dialogo("Jurema", "Última. Que ataque esse aparelho com nome parecido com o nosso facilita?", [
			"Evil twin: as pessoas conectam achando que é nosso, e um portal falso pega as senhas",
			"Ataque de negação de serviço no SSID oficial por excesso de potência",
			"Nenhum, ele só dá internet grátis para os visitantes",
		], func(r: int):
			if r == 0:
				nota += 20
				partes.append("E sim: evil twin com portal cativo falso para roubar credenciais. WPA3/802.1X com validação de certificado e WIDS ajudam.")
			else:
				partes.append("O risco principal é evil twin: SSID parecido, portal falso, senha capturada.")
			escritorio.finalizar({"nota": clampi(nota, 0, 100), "comentario": " ".join(partes)})))
