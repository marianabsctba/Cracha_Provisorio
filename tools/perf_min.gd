extends SceneTree
## Experimento: quanto custa compilar o mínimo (uma caixa) em cada configuração.
## EXP: E = com ambiente/tonemap, D = com luz direcional, T = caixa com textura, X = segunda caixa com emissão


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var exp := OS.get_environment("EXP")
	var raiz := Node3D.new()
	root.add_child(raiz)
	if exp.contains("E"):
		var amb := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_energy = 0.7
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		amb.environment = env
		raiz.add_child(amb)
	if exp.contains("D"):
		var sol := DirectionalLight3D.new()
		sol.rotation_degrees = Vector3(-60, 30, 0)
		raiz.add_child(sol)
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	var m: Material
	if exp.contains("S"):
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/simples.gdshader")
		sm.set_shader_parameter("cor", Color.CORAL)
		m = sm
	else:
		var st := StandardMaterial3D.new()
		st.albedo_color = Color.CORAL
		if exp.contains("U"):
			st.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m = st
	mi.material_override = m
	raiz.add_child(mi)
	if exp.contains("X"):
		var m2 := StandardMaterial3D.new()
		m2.emission_enabled = true
		m2.emission = Color.RED
		var mi2 := MeshInstance3D.new()
		mi2.mesh = BoxMesh.new()
		mi2.material_override = m2
		mi2.position.x = 1.5
		raiz.add_child(mi2)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1, 4)
	raiz.add_child(cam)
	var linha := []
	for i in 4:
		var t := Time.get_ticks_msec()
		await process_frame
		linha.append(Time.get_ticks_msec() - t)
	print("MIN EXP=%s %s" % [exp, linha])
	quit()
