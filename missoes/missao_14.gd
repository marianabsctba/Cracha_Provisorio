extends Node
## Dia 14: teste de intrusão física autorizado. Chegar à porta do datacenter sem crachá válido.
## Caminhos: pegar carona (tailgating) na porta de vidro atrás de alguém que passa o crachá,
## ou achar a porta corta-fogo calçada com um extintor. O Seu Josias desconfia de quem ele vê.

const Estilo := preload("res://scripts/estilo.gd")

var escritorio: Node3D

var _porta: Node3D
var _porta_aberta := 0.0          # segundos restantes de porta aberta
var _funcionario: Node3D
var _t := 0.0
var _suspeita := 0.0
var _carona := false
var _usou_corta_fogo := false
var _disfarce := false
var _pega := false
var _chegou := false
var _lado_anterior := 1.0
var _josias: Node3D


func _ready() -> void:
	# Porta de vidro na passagem das catracas
	_porta = escritorio.caixa(Vector3(0, 0, 5), Vector3(2.2, 2.4, 0.08), Color(0.55, 0.85, 1.0, 0.35))
	# Porta corta-fogo calçada com extintor (fica aberta, mas não deveria)
	escritorio.caixa(Vector3(14.25, 0, 4.35), Vector3(0.08, 2.2, 1.2), Color("b23a3a"), true)
	var ext: Node3D = escritorio.caixa(Vector3(15.62, 0, 5.0), Vector3(0.22, 0.6, 0.22), Color("d61f1f"))
	escritorio.interativo(ext, "Examinar o extintor no chão", func():
		escritorio.dialogo("Você", "Um extintor está calçando a porta corta-fogo para ela não fechar. Tem um bilhete: 'NÃO FECHAR, É POR ONDE A GENTE SAI PRA FUMAR. ass: Contabilidade'."))
	# Kit de pretexto na recepção
	var kit: Node3D = escritorio.caixa(Vector3(7.6, 0, 9.4), Vector3(0.5, 0.35, 0.35), Color("f2c200"))
	escritorio.interativo(kit, "Pegar colete refletivo e prancheta", func():
		_disfarce = true
		kit.queue_free()
		escritorio.dialogo("Você", "Colete refletivo vestido, prancheta na mão. Segundo a ciência, isso te deixa invisível em qualquer prédio comercial."))
	# Funcionário que entra de tempos em tempos
	_funcionario = escritorio.pessoa("Funcionário do Financeiro", Vector3(0, 0, 9.5), Color("6b7f9e"), 0.0)
	_josias = escritorio.npcs.get("Seu Josias")
	if _josias:
		_josias.position = Vector3(-2.2, 0, 7.0)
		_josias.rotation.y = -0.8
	escritorio.objetivo("Chegue à porta do DATACENTER (fundo à direita) sem ser {pega|pego} pelo Seu Josias. Ele desconfia de quem vê perto das catracas. Correr chama atenção.")


func _process(delta: float) -> void:
	if _chegou or _pega or escritorio.dialogo_aberto():
		return
	_mover_funcionario(delta)
	# Porta de vidro
	_porta_aberta = maxf(_porta_aberta - delta, 0.0)
	_porta.position.y = 2.5 if _porta_aberta > 0.0 else 0.0
	var j: CharacterBody3D = escritorio.jogador
	var p := j.global_position
	# Atravessou a linha das catracas?
	var lado := signf(p.z - 5.0)
	if lado < 0 and _lado_anterior > 0:
		if absf(p.x) < 1.3:
			_carona = true
		elif p.x > 14.0:
			_usou_corta_fogo = true
	if lado != 0:
		_lado_anterior = lado
	_vigiar(delta, p, j)
	# Chegou na porta do datacenter?
	if p.distance_to(Vector3(12.3, p.y, -3.3)) < 1.4:
		_chegou = true
		_relatorio()


func _mover_funcionario(delta: float) -> void:
	_t = fmod(_t + delta, 14.0)
	var f := _funcionario
	if _t < 4.0:
		f.position = Vector3(0, 0, lerpf(10.0, 5.6, _t / 4.0))
		f.rotation.y = 0.0
		escritorio.animar(f, "Walk")
	elif _t < 4.6:
		escritorio.animar(f, "Interact")   # passa o crachá no leitor
		if _porta_aberta <= 0.0:
			_porta_aberta = 3.2   # bip do crachá
	elif _t < 8.0:
		f.position = Vector3(0, 0, lerpf(5.6, 1.0, (_t - 4.6) / 3.4))
		escritorio.animar(f, "Walk")
	elif _t < 10.0:
		f.position = Vector3(lerpf(0.0, -2.5, (_t - 8.0) / 2.0), 0, 1.0)
		f.rotation.y = PI / 2
	else:
		f.position = Vector3(0, -10, 10)   # "sumiu" e volta a entrar no próximo ciclo


func _vigiar(delta: float, p: Vector3, j: CharacterBody3D) -> void:
	if not _josias:
		return
	var olho := _josias.global_position + Vector3(0, 1.6, 0)
	var para := (p + Vector3(0, 1.4, 0)) - olho
	var frente := -_josias.global_transform.basis.z
	var dist := para.length()
	var visto := false
	if dist < 7.5 and frente.angle_to(Vector3(para.x, 0, para.z).normalized()) < deg_to_rad(55):
		var consulta := PhysicsRayQueryParameters3D.create(olho, olho + para)
		consulta.exclude = [_josias.get_rid(), j.get_rid()]
		visto = escritorio.get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()
	if visto:
		var taxa := 0.35
		if absf(p.x) < 2.5 and p.z > 3.0 and p.z < 6.5:
			taxa = 1.0
		if j.correndo:
			taxa *= 2.0
		if _disfarce:
			taxa *= 0.4
		_suspeita += taxa * delta / 3.0
	else:
		_suspeita = maxf(_suspeita - delta * 0.12, 0.0)
	var barra := ""
	for i in 20:
		barra += "#" if i < int(_suspeita * 20) else "."
	escritorio.extra("Desconfiança do Seu Josias\n[%s]\n%s%s" % [barra, "ELE ESTÁ OLHANDO" if visto else "fora da vista", "\nDisfarce: colete e prancheta" if _disfarce else ""])
	if _suspeita >= 1.0:
		_pega = true
		escritorio.dialogo("Seu Josias", "Opa, opa, {mocinha|mocinho}. Cadê o crachá?")
		escritorio.dialogo("Você", "(mostra a carta de autorização assinada pela diretoria)")
		escritorio.dialogo("Seu Josias", "Ah, é teste? Então eu passei, né? Pode anotar: Josias, nota mil.", [], func(_e):
			escritorio.finalizar({"nota": 35, "comentario": "O Seu Josias te pegou. Para o relatório isso é bom (o controle humano funcionou), mas a sua missão era chegar no datacenter. Dica: carona atrás de quem passa crachá, disfarce de manutenção, ou rotas que ninguém vigia."}))


func _relatorio() -> void:
	escritorio.dialogo("Você", "Você encosta na porta do datacenter. O leitor de crachá pisca vermelho. Missão cumprida: ninguém te parou.")
	escritorio.dialogo("Jurema", "Chegou. Agora o relatório. Qual a recomendação número um?",
		["Alarme e sensor na porta corta-fogo, catraca que bloqueia carona e conscientização sobre tailgating",
		 "Instalar mais câmeras (a 3 está desligada desde 2014)",
		 "Demitir o Seu Josias"], func(e: int):
			var nota := 60
			var partes := ["Você chegou ao datacenter sem crachá."]
			if _carona:
				nota += 10
				partes.append("Pegou carona na porta de vidro (tailgating): controle de acesso que abre para um e deixa passar dois.")
			if _usou_corta_fogo:
				nota += 10
				partes.append("Achou a porta corta-fogo calçada com extintor: rota sem nenhuma vigilância.")
			if _carona and _usou_corta_fogo:
				nota -= 5
			if e == 0:
				nota += 25
				partes.append("Recomendação certa: o problema é processo e porta, não pessoa.")
			elif e == 1:
				nota += 5
				partes.append("Câmera registra, mas não impede ninguém de entrar.")
			else:
				partes.append("Demitir o vigia não fecha a porta corta-fogo. A Jurema te olhou feio.")
			escritorio.finalizar({"nota": clampi(nota, 0, 100), "comentario": " ".join(partes)}))
