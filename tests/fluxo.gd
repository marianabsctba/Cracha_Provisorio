extends SceneTree
## Teste de ponta a ponta sem janela:
##   godot --headless --path . --script res://tests/fluxo.gd
## Abre o escritório de cada dia, joga a fase ou a missão, e confere o registro e os desfechos.

const Catalogo := preload("res://scripts/catalogo.gd")

var falhas := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU  ", msg)


## Fecha todas as falas pendentes escolhendo a opção `i` (ou continuar).
func _responder(esc, i: int) -> void:
	var guarda := 0
	while is_instance_valid(esc) and esc.dialogo_aberto() and guarda < 20:
		guarda += 1
		var tem_opcoes: bool = esc._dlg_opcoes.get_child_count() > 1
		esc._escolher(i if tem_opcoes else -1)
		await process_frame


func _jogar_missao(n: int, esc) -> void:
	await _responder(esc, -1)   # briefing
	var m = esc.missao
	match n:
		2:
			for i in m.APARELHOS.size():
				m._inspecionar(i)
				await _responder(esc, 0 if m.APARELHOS[i][8] else 1)
			m.usar_pc()
			await _responder(esc, 0)
		14:
			m._carona = true
			m._usou_corta_fogo = false
			m._relatorio()
			await _responder(esc, 0)
		19:
			m._examinar()
			await _responder(esc, 0)
		29:
			for i in m.EVIDENCIAS.size():
				m._coletadas[i] = true
			m._examinar_cafeteira()
			await _responder(esc, 0)
			m._examinar_postit()
			await _responder(esc, 0)
			m.usar_pc()
			await process_frame
			for i in m.EVIDENCIAS.size():
				m._seletores[i].disabled = false
				m._seletores[i].selected = m.EVIDENCIAS[i][3] + 1
			esc.finalizar(m._avaliar())
	await process_frame


func _rodar() -> void:
	var jogo = root.get_node("Jogo")
	jogo.novo_jogo()
	var principal: Node = load("res://cenas/principal.tscn").instantiate()
	root.add_child(principal)
	await process_frame
	for n in range(1, 31):
		principal._iniciar_dia(n)
		await process_frame
		await process_frame
		var esc = principal._atual
		_ok(esc != null, "dia %d: escritório não abriu" % n)
		if Catalogo.dia(n)["tipo"] == "pc":
			esc.sentou_no_pc.emit()
			await process_frame
			var fase = principal._camada.get_child(principal._camada.get_child_count() - 1)
			_ok(fase.has_method("solucao_teste"), "dia %d: fase não abriu" % n)
			fase.solucao_teste()
			await process_frame
			fase._entregar()
		else:
			_ok(esc.missao != null, "dia %d: missão 3D não carregou" % n)
			await _jogar_missao(n, esc)
			_ok(jogo.notas.get(n, 0) >= 90, "dia %d: missão resolvida deu %d" % [n, jogo.notas.get(n, -1)])
		await process_frame
		_ok(jogo.notas.has(n), "dia %d: nota não registrada" % n)
		print("dia %02d  nota %d" % [n, jogo.notas.get(n, -1)])
	_ok(jogo.terminou(), "campanha não terminou")
	print("desfecho: ", jogo.desfecho(), "  média ", jogo.media())
	for tipo in ["promovida", "estagiaria", "demitida"]:
		principal._mostrar_final(tipo)
		await process_frame
	principal._menu()
	await process_frame
	jogo.novo_jogo()
	print("\nfluxo: %d falhas" % falhas)
	quit(1 if falhas > 0 else 0)
