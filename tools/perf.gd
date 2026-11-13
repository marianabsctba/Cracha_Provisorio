extends SceneTree
## Mede a duração dos quadros nas transições: menu -> dia -> computador -> resultado.
##   godot --path . --rendering-driver opengl3_angle --script res://tools/perf.gd


func _initialize() -> void:
	_rodar.call_deferred()


func _quadros(rotulo: String, n := 4) -> void:
	var linha := []
	for i in n:
		var t := Time.get_ticks_msec()
		await process_frame
		linha.append(Time.get_ticks_msec() - t)
	print("PERF %-28s %s" % [rotulo, linha])


func _rodar() -> void:
	var p: Node = load("res://cenas/principal.tscn").instantiate()
	root.add_child(p)
	await _quadros("menu")
	var t := Time.get_ticks_msec()
	p._iniciar_dia(5)
	print("PERF construir dia (ms) ", Time.get_ticks_msec() - t)
	await _quadros("dia 5 escritorio")
	var esc = p._atual
	esc._escolher(-1)
	await _quadros("depois do briefing")
	t = Time.get_ticks_msec()
	esc.sentou_no_pc.emit()
	print("PERF abrir fase (ms) ", Time.get_ticks_msec() - t)
	await _quadros("fase 5", 6)
	var fase = p._camada.get_child(p._camada.get_child_count() - 1)
	fase._entregar()
	await _quadros("resultado")
	p._iniciar_dia(14)
	await _quadros("dia 14")
	quit()
