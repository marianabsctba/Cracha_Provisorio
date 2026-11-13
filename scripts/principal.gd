extends Node
## Fluxo do jogo (versão provisória: só o modo de captura de tela das fases).
##   godot --path . -- --dia=N --captura=C:/caminho/tela.png [--solucao]

const Catalogo := preload("res://scripts/catalogo.gd")

var _camada: CanvasLayer


func _ready() -> void:
	_camada = CanvasLayer.new()
	add_child(_camada)
	var args := {}
	for a in OS.get_cmdline_user_args():
		var p := a.trim_prefix("--").split("=", true, 1)
		args[p[0]] = p[1] if p.size() > 1 else "1"
	if args.has("dia"):
		var fase := _abrir_fase(int(args["dia"]))
		if args.has("solucao"):
			await get_tree().process_frame
			fase.solucao_teste()
		if args.has("captura"):
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png(args["captura"])
			get_tree().quit()


func _abrir_fase(n: int) -> Control:
	var fase: Control = load("res://fases/dia_%02d.gd" % n).new()
	_camada.add_child(fase)
	return fase
