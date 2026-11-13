extends Node
## Estado global da campanha: dia atual, notas, cagadas graves e salvamento.

const CAMINHO := "user://progresso.cfg"
const TOTAL_DIAS := 30

var dia_atual := 1
var genero := ""       # "f" (estagiária) ou "m" (estagiário); vazio = ainda não escolheu
var _rx_genero := RegEx.create_from_string("\\{([^{}|]*)\\|([^{}|]*)\\}")
var notas := {}        # dia (int) -> nota 0..100
var comentarios := {}  # dia (int) -> texto do resultado
var cagadas := {}      # dia (int) -> descrição da cagada grave


func _ready() -> void:
	carregar()


## Troca os marcadores {feminino|masculino} pela forma do gênero escolhido.
func txt(s: String) -> String:
	if not s.contains("|"):
		return s
	var usar := 1 if genero != "m" else 2
	var saida := ""
	var pos := 0
	for m in _rx_genero.search_all(s):
		saida += s.substr(pos, m.get_start() - pos) + m.get_string(usar)
		pos = m.get_end()
	return saida + s.substr(pos)


## Atalho: g("a", "o") devolve a forma do gênero escolhido.
func g(feminino: String, masculino: String) -> String:
	return masculino if genero == "m" else feminino


func novo_jogo() -> void:
	dia_atual = 1
	notas.clear()
	comentarios.clear()
	cagadas.clear()
	salvar()


func registrar(dia: int, resultado: Dictionary) -> void:
	notas[dia] = clampi(int(resultado.get("nota", 0)), 0, 100)
	comentarios[dia] = str(resultado.get("comentario", ""))
	var cagada := str(resultado.get("cagada", ""))
	if cagada != "":
		cagadas[dia] = cagada
	else:
		cagadas.erase(dia)
	if dia >= dia_atual:
		dia_atual = mini(dia + 1, TOTAL_DIAS + 1)
	salvar()


func terminou() -> bool:
	return dia_atual > TOTAL_DIAS


func media() -> float:
	if notas.is_empty():
		return 0.0
	var soma := 0
	for d in notas:
		soma += int(notas[d])
	return float(soma) / float(TOTAL_DIAS)


## "promovida", "estagiaria" ou "demitida".
func desfecho() -> String:
	var m := media()
	if cagadas.size() >= 2 or m < 45.0:
		return "demitida"
	if cagadas.is_empty() and m >= 75.0:
		return "promovida"
	return "estagiaria"


func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("jogo", "dia_atual", dia_atual)
	cfg.set_value("jogo", "genero", genero)
	cfg.set_value("jogo", "notas", notas)
	cfg.set_value("jogo", "comentarios", comentarios)
	cfg.set_value("jogo", "cagadas", cagadas)
	cfg.save(CAMINHO)


func carregar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CAMINHO) != OK:
		return
	dia_atual = int(cfg.get_value("jogo", "dia_atual", 1))
	genero = str(cfg.get_value("jogo", "genero", ""))
	notas = cfg.get_value("jogo", "notas", {})
	comentarios = cfg.get_value("jogo", "comentarios", {})
	cagadas = cfg.get_value("jogo", "cagadas", {})


func tem_progresso() -> bool:
	return dia_atual > 1
