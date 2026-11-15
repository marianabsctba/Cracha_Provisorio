extends SceneTree
## Confere se todo objeto interativo das missões 3D pode ser alcançado pela mira:
## existe um ponto livre no chão, a até 2,3 m, de onde o raio dos olhos acerta o objeto
## antes de qualquer outra coisa.
##   godot --headless --path . --script res://tests/alcance.gd

var Escritorio: GDScript
const OLHO := 1.7
const ALCANCE := 2.25

var falhas := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	Escritorio = load("res://scripts/escritorio.gd")
	for dia in [2, 14, 19, 29]:
		var esc: Node3D = Escritorio.new()
		esc.dia = dia
		root.add_child(esc)
		await physics_frame
		await physics_frame
		esc.jogador.process_mode = Node.PROCESS_MODE_DISABLED
		esc.jogador.position = Vector3(0, -50, 0)
		await physics_frame
		if esc.missao == null:
			falhas += 1
			print("FALHOU  dia %d: a missão não carregou" % dia)
		var alvos: Array = []
		for n in esc.find_children("*", "CollisionObject3D", true, false):
			if n.has_meta("interagir") and n.get_parent() == esc and not esc.npcs.values().has(n):
				alvos.append(n)
		if dia == 19:
			# testa os cinco esconderijos possíveis do ponto de acesso
			var m = esc.missao
			for e in m.ESCONDERIJOS:
				m._ap.position = e[0]
				await physics_frame
				await physics_frame
				_conferir(esc, m._ap, "dia 19 " + str(e[1]))
		else:
			for alvo in alvos:
				_conferir(esc, alvo, "dia %d %s" % [dia, alvo.get_meta("nome")])
		esc.queue_free()
		await process_frame
	print("\nalcance: %d objeto(s) fora de alcance" % falhas)
	quit(1 if falhas > 0 else 0)


func _centro(alvo: CollisionObject3D) -> Vector3:
	for c in alvo.get_children():
		if c is CollisionShape3D:
			return (c as CollisionShape3D).global_position
	return alvo.global_position


func _conferir(esc: Node3D, alvo: CollisionObject3D, nome: String) -> void:
	var espaco := esc.get_world_3d().direct_space_state
	var c := _centro(alvo)
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.3
	capsula.height = 1.7
	for r in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]:
		for k in 24:
			var ang := TAU * k / 24.0
			var pe := Vector3(c.x + cos(ang) * r, 0.0, c.z + sin(ang) * r)
			if absf(pe.x) > 16.6 or absf(pe.z) > 10.6:
				continue
			# a personagem cabe ali?
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = capsula
			q.transform = Transform3D(Basis.IDENTITY, pe + Vector3(0, 0.87, 0))
			q.collide_with_areas = false
			var choques := espaco.intersect_shape(q, 4)
			var livre := true
			for ch in choques:
				var o: Object = ch["collider"]
				if o is StaticBody3D and (o as Node3D).global_position.y > -0.05:
					livre = false
			if not livre:
				continue
			var olho := pe + Vector3(0, OLHO, 0)
			if olho.distance_to(c) > ALCANCE:
				continue
			var rq := PhysicsRayQueryParameters3D.create(olho, olho + (c - olho).normalized() * ALCANCE)
			rq.collide_with_areas = true
			var hit := espaco.intersect_ray(rq)
			if hit.is_empty():
				continue
			var n: Node = hit["collider"]
			while n and not n.has_meta("interagir"):
				n = n.get_parent()
			if n == alvo:
				return
	falhas += 1
	print("FORA DE ALCANCE  %s  (em %s)" % [nome, c])
