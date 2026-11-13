extends SceneTree
## Ferramenta de desenvolvimento: enfileira modelos .glb, lista animações e tamanhos e salva uma captura.
##   godot --path . --script res://tools/vitrine.gd -- --pasta=res://modelos/personagens --captura=C:/x.png


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var p := a.trim_prefix("--").split("=", true, 1)
		args[p[0]] = p[1] if p.size() > 1 else "1"
	var pasta: String = args.get("pasta", "res://modelos/personagens")
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2a3140")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	raiz.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 30, 0)
	raiz.add_child(sol)
	var arquivos := []
	for f in DirAccess.get_files_at(pasta):
		if f.ends_with(".glb") or f.ends_with(".obj") or f.ends_with(".gltf"):
			arquivos.append(f)
	arquivos.sort()
	var x := 0.0
	var passo := float(args.get("passo", "1.3"))
	for f in arquivos:
		var res = load(pasta + "/" + f)
		var no: Node3D
		if res is PackedScene:
			no = res.instantiate()
		elif res is Mesh:
			no = MeshInstance3D.new()
			no.mesh = res
		else:
			continue
		raiz.add_child(no)
		no.position.x = x
		var caixa := _aabb(no)
		var anims := []
		var ap := no.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			anims = ap.get_animation_list()
			for nome in anims:
				if nome.to_lower().ends_with("idle") or nome.to_lower() == "idle":
					ap.play(nome)
					break
		print("%s  tamanho=%s  anims=%s" % [f, caixa.size, ", ".join(anims)])
		var l := Label3D.new()
		l.text = f.get_basename()
		l.font_size = 24
		l.position = Vector3(x, -0.15, 0.5)
		raiz.add_child(l)
		x += passo
	var cam := Camera3D.new()
	raiz.add_child(cam)
	cam.position = Vector3((x - passo) / 2.0, float(args.get("altura", "1.2")), float(args.get("dist", "6")))
	cam.look_at(Vector3((x - passo) / 2.0, float(args.get("alvo", "0.9")), 0))
	await create_timer(1.0).timeout
	if args.has("captura"):
		root.get_texture().get_image().save_png(args["captura"])
	quit()


func _aabb(no: Node) -> AABB:
	var total := AABB()
	var primeiro := true
	var lista: Array = no.find_children("*", "MeshInstance3D", true, false)
	if no is MeshInstance3D:
		lista.append(no)
	for m in lista:
		var a: AABB = m.global_transform * m.get_aabb()
		total = a if primeiro else total.merge(a)
		primeiro = false
	return total
