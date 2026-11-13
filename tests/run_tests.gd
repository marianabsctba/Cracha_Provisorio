extends SceneTree
## Testa as fases de computador sem janela:
##   godot --headless --path . --script res://tests/run_tests.gd [-- --dia=N]
## Para cada fase: sem fazer nada a nota deve ser < 50; com solucao_teste() deve ser >= 90.

const Catalogo := preload("res://scripts/catalogo.gd")


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var so_dia := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dia="):
			so_dia = int(a.substr(6))
	var falhas := 0
	var testados := 0
	for n in range(1, 31):
		if so_dia != 0 and n != so_dia:
			continue
		if Catalogo.dia(n)["tipo"] != "pc":
			continue
		var caminho := "res://fases/dia_%02d.gd" % n
		if not ResourceLoader.exists(caminho):
			print("FALTA   dia %02d" % n)
			continue
		testados += 1
		var vazia := await _nota(caminho, false)
		var resolvida := await _nota(caminho, true)
		var ok: bool = vazia["nota"] < 50 and resolvida["nota"] >= 90 and resolvida.get("cagada", "") == ""
		if not ok:
			falhas += 1
		print("%s dia %02d  vazia=%d  resolvida=%d  %s" % ["OK    " if ok else "FALHOU", n, vazia["nota"], resolvida["nota"], resolvida.get("comentario", "")])
	print("\n%d fases testadas, %d falhas" % [testados, falhas])
	quit(1 if falhas > 0 else 0)


func _nota(caminho: String, resolver: bool) -> Dictionary:
	var script: Script = load(caminho)
	var fase: Control = script.new()
	root.add_child(fase)
	await process_frame
	await process_frame
	if resolver:
		fase.solucao_teste()
		await process_frame
	var r: Dictionary = fase.avaliar()
	fase.queue_free()
	await process_frame
	return r
