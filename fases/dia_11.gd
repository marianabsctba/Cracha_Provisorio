extends "res://fases/fase.gd"
## Dia 11: pentest autorizado no portal do segurado. Editor de requisição HTTP crua,
## servidor simulado que faz parse de verdade, e uma falha de autorização por objeto (BOLA/IDOR).

const SESSAO := "sid=7f3a9c41e0b2d8"
const MEU_ID := 48213
const APOLICES := {
	48211: {"titular": "Josué Rangel Paixão", "cpf": "071.***.***-40", "produto": "Auto", "premio": "R$ 3.120,00", "placa": "QRT4E21"},
	48212: {"titular": "Rosimeire Antunes Lobo", "cpf": "433.***.***-02", "produto": "Residencial", "premio": "R$ 890,00", "placa": ""},
	48213: {"titular": "Conta de Teste Pentest", "cpf": "000.***.***-00", "produto": "Auto", "premio": "R$ 0,00", "placa": "TST0P00"},
	48214: {"titular": "Maria Aparecida Bortolotto", "cpf": "582.***.***-17", "produto": "Vida", "premio": "R$ 1.540,00", "placa": ""},
	48215: {"titular": "Wanderley Kowalski Neto", "cpf": "129.***.***-88", "produto": "Auto", "premio": "R$ 5.990,00", "placa": "BEE2G77"},
	10001: {"titular": "Ronaldo Tabajara (CEO)", "cpf": "001.***.***-01", "produto": "Vida Premium Ouro Diamante", "premio": "R$ 98.000,00", "placa": "CEO0001"},
}

var _req: TextEdit
var _resp: TextEdit
var _historico: ItemList
var _vistos := {}          # id -> titular (apólices de outras pessoas que a jogadora conseguiu ver)
var _endpoint: LineEdit
var _id: LineEdit
var _nome: LineEdit
var _classe: OptionButton
var _recomendacao: OptionButton


func _init() -> void:
	dia = 11
	titulo = "Pentest no portal"
	chamado = ("Teste autorizado (escopo: portal.tabajara.com.br, conta de teste [b]48213[/b]). Edite a requisição HTTP crua e "
		+ "clique em Enviar. Descubra se dá para ver dados de [b]outra pessoa[/b] e preencha o relatório: endpoint vulnerável, "
		+ "id e nome do titular que você conseguiu ver, classificação OWASP API Top 10 e recomendação.")


func montar() -> void:
	var l := linha()
	var esq := painel(l)
	rotulo("Requisição", 14, Estilo.CIANO, esq)
	_req = editor("GET /api/v1/apolices/48213 HTTP/1.1\nHost: portal.tabajara.com.br\nCookie: %s\nAccept: application/json\nUser-Agent: Tabajara-Pentest/1.0\n\n" % SESSAO, 200, esq)
	var lb := linha(esq)
	botao("Enviar", _enviar, lb)
	botao("Restaurar", func(): _req.text = "GET /api/v1/apolices/48213 HTTP/1.1\nHost: portal.tabajara.com.br\nCookie: %s\nAccept: application/json\n\n" % SESSAO, lb)
	var dir := painel(l)
	rotulo("Resposta", 14, Estilo.CIANO, dir)
	_resp = bloco_mono("", 230, dir)
	rotulo("Histórico", 13, Estilo.TEXTO_FRACO)
	_historico = ItemList.new()
	_historico.custom_minimum_size = Vector2(0, 80)
	corpo.add_child(_historico)

	var rel := painel()
	rotulo("Relatório de achado", 14, Estilo.CIANO, rel)
	var g := GridContainer.new()
	g.columns = 2
	rel.add_child(g)
	rotulo("Endpoint vulnerável", 14, Estilo.TEXTO, g)
	_endpoint = campo("ex.: GET /api/v1/...", g)
	rotulo("Id de apólice de outra pessoa", 14, Estilo.TEXTO, g)
	_id = campo("número", g)
	rotulo("Nome do titular exposto", 14, Estilo.TEXTO, g)
	_nome = campo("como veio na resposta", g)
	rotulo("Classificação", 14, Estilo.TEXTO, g)
	_classe = opcoes(["(escolha)", "API1:2023 Broken Object Level Authorization", "API2:2023 Broken Authentication",
		"API8:2023 Security Misconfiguration", "A03:2021 Injection"], g)
	rotulo("Recomendação", 14, Estilo.TEXTO, g)
	_recomendacao = opcoes(["(escolha)",
		"No servidor, conferir se a apólice pertence ao usuário da sessão antes de responder",
		"Trocar os ids numéricos por UUID e pronto",
		"Colocar um WAF na frente",
		"Esconder o endpoint do robots.txt"], g)
	chat("Jurema", "Autorização assinada pela diretoria, escopo e janela definidos. Sem isso não é pentest, é crime.")
	chat("Fornecedor", "O portal é 100% seguro. Tem HTTPS, cadeado verde e tudo.")
	chat("Jurema", "Cadeado protege o caminho, não a porta. Muda o número da apólice e vê o que acontece.")


func _resposta(status: int, motivo: String, corpo_txt: String, tipo := "application/json") -> String:
	var bytes := corpo_txt.to_utf8_buffer().size()
	return "HTTP/1.1 %d %s\nServer: nginx/1.18.0\nDate: Fri, 13 Nov 2026 13:%02d:07 GMT\nContent-Type: %s; charset=utf-8\nContent-Length: %d\nX-Powered-By: TabajaraPortal 2.3\n\n%s" % [
		status, motivo, randi() % 60, tipo, bytes, corpo_txt]


## Servidor simulado: recebe a requisição crua, devolve a resposta crua.
func servidor(cru: String) -> String:
	var partes := cru.replace("\r\n", "\n").split("\n\n", true, 1)
	var linhas := partes[0].strip_edges(true, false).split("\n")
	if linhas.is_empty() or linhas[0].strip_edges() == "":
		return _resposta(400, "Bad Request", "{\"erro\":\"requisição vazia\"}")
	var rl := linhas[0].strip_edges().split(" ", false)
	if rl.size() != 3 or not rl[2].begins_with("HTTP/1."):
		return _resposta(400, "Bad Request", "{\"erro\":\"linha de requisição inválida\"}")
	var metodo := rl[0]
	var caminho := rl[1].split("?")[0]
	var cab := {}
	for i in range(1, linhas.size()):
		var c := linhas[i].split(":", true, 1)
		if c.size() == 2:
			cab[c[0].strip_edges().to_lower()] = c[1].strip_edges()
	if not cab.has("host"):
		return _resposta(400, "Bad Request", "{\"erro\":\"HTTP/1.1 exige o cabeçalho Host\"}")
	if cab["host"] != "portal.tabajara.com.br":
		return _resposta(421, "Misdirected Request", "{\"erro\":\"host fora do escopo\"}")
	if caminho == "/robots.txt":
		return _resposta(200, "OK", "User-agent: *\nDisallow: /api/v1/admin/\n# lembrete: tirar o export antes de ir pra producao (Kaua)", "text/plain")
	var logado: bool = cab.get("cookie", "").contains(SESSAO)
	if caminho.begins_with("/api/v1/admin"):
		if not logado:
			return _resposta(401, "Unauthorized", "{\"erro\":\"faça login\"}")
		return _resposta(403, "Forbidden", "{\"erro\":\"requer perfil administrador\",\"perfil\":\"segurado\"}")
	if caminho == "/api/v1/me":
		if not logado:
			return _resposta(401, "Unauthorized", "{\"erro\":\"faça login\"}")
		return _resposta(200, "OK", JSON.stringify({"id": MEU_ID, "nome": "Conta de Teste Pentest", "perfil": "segurado"}, "  "))
	var rx := RegEx.create_from_string("^/api/v1/apolices/(\\d+)$")
	var m := rx.search(caminho)
	if m:
		if metodo != "GET":
			return _resposta(405, "Method Not Allowed", "{\"erro\":\"use GET\"}")
		if not logado:
			return _resposta(401, "Unauthorized", "{\"erro\":\"faça login\"}")
		var id := int(m.get_string(1))
		if not APOLICES.has(id):
			return _resposta(404, "Not Found", "{\"erro\":\"apólice não encontrada\"}")
		var dados: Dictionary = APOLICES[id].duplicate()
		dados["id"] = id
		if id != MEU_ID:
			_vistos[id] = APOLICES[id]["titular"]
		return _resposta(200, "OK", JSON.stringify(dados, "  "))
	return _resposta(404, "Not Found", "{\"erro\":\"rota inexistente\"}")


func _enviar() -> void:
	var r := servidor(_req.text)
	_resp.text = r
	var primeira := _req.text.strip_edges().split("\n")[0]
	_historico.add_item("%s  ->  %s" % [primeira, r.split("\n")[0]])
	if _vistos.size() == 1 and r.contains("200 OK") and not r.contains("Teste"):
		chat("Jurema", "Pronto. Os dados de outra pessoa, com o cookie da conta de teste. Isso é BOLA, o primeiro do OWASP API Top 10.")
	if r.contains("Ronaldo"):
		chat("Valdecir", "Isso aí é a apólice do CEO? Fecha isso. Fecha agora. Não lê o prêmio.")


func avaliar() -> Dictionary:
	var nota := 0
	var partes := []
	if _endpoint.text.contains("/api/v1/apolices"):
		nota += 15
		partes.append("Endpoint certo.")
	var id := int(_id.text.strip_edges())
	if _vistos.has(id) and _nome.text.strip_edges().to_lower() == str(_vistos[id]).to_lower():
		nota += 35
		partes.append("Prova do IDOR: a apólice %d de %s veio com o cookie da conta de teste." % [id, _vistos[id]])
	else:
		partes.append("Faltou a prova: uma apólice de outra pessoa que você viu de verdade, com o nome certo.")
	if _classe.selected == 1:
		nota += 25
		partes.append("BOLA (API1:2023): autenticado não quer dizer autorizado para aquele objeto.")
	else:
		partes.append("A classificação era API1:2023 BOLA: o login funciona, a checagem de dono do objeto não existe.")
	if _recomendacao.selected == 1:
		nota += 25
		partes.append("Correção certa: checar a posse do objeto no servidor em toda requisição.")
	else:
		partes.append("UUID e WAF só dificultam. A correção é checar no servidor se o objeto é do usuário da sessão.")
	return {"nota": nota, "comentario": " ".join(partes)}


func solucao_teste() -> void:
	_req.text = "GET /api/v1/apolices/48214 HTTP/1.1\nHost: portal.tabajara.com.br\nCookie: %s\n\n" % SESSAO
	_enviar()
	_endpoint.text = "GET /api/v1/apolices/{id}"
	_id.text = "48214"
	_nome.text = "Maria Aparecida Bortolotto"
	_classe.selected = 1
	_recomendacao.selected = 1
