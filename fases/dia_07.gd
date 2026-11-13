extends "res://fases/fase.gd"
## Dia 7: revisão do PR do Kauã. Marcar as linhas vulneráveis, classificar por CWE/OWASP e decidir.

const CATEGORIAS := [
	"(categoria)",
	"CWE-89 SQL Injection (A03)",
	"CWE-79 Cross-site Scripting (A03)",
	"CWE-798 Credencial no código (A07)",
	"CWE-916 Hash de senha fraco (A02)",
	"CWE-502 Desserialização insegura (A08)",
	"CWE-22 Path traversal (A01)",
	"CWE-918 SSRF (A10)",
	"CWE-489 Debug ativo em produção (A05)",
	"CWE-78 Injeção de comando (A03)",
]

# [código, categoria correta (0 = linha ok)]
const CODIGO := [
	["import base64", 0],
	["import hashlib", 0],
	["import os", 0],
	["import pickle", 0],
	["import subprocess", 0],
	["", 0],
	["import psycopg2", 0],
	["import requests", 0],
	["from flask import Flask, redirect, render_template, request, send_file, session", 0],
	["from werkzeug.utils import secure_filename", 0],
	["", 0],
	["app = Flask(__name__)", 0],
	["app.config[\"SECRET_KEY\"] = \"tabajara123\"", 3],
	["DB_DSN = \"postgresql://sinistros:Kaua2026!@10.10.30.5/sinistros\"", 3],
	["SMTP_TOKEN = os.environ[\"SMTP_TOKEN\"]", 0],
	["UPLOAD_DIR = \"/srv/sinistros/fotos\"", 0],
	["", 0],
	["def db():", 0],
	["    return psycopg2.connect(DB_DSN)", 0],
	["", 0],
	["@app.post(\"/login\")", 0],
	["def login():", 0],
	["    email = request.form[\"email\"]", 0],
	["    senha = request.form[\"senha\"]", 0],
	["    hash_senha = hashlib.md5(senha.encode()).hexdigest()", 4],
	["    cur = db().cursor()", 0],
	["    cur.execute(\"SELECT id, nome FROM corretores WHERE email = %s AND senha = %s\", (email, hash_senha))", 0],
	["    usuario = cur.fetchone()", 0],
	["    if not usuario:", 0],
	["        return \"Login inválido\", 401", 0],
	["    session[\"uid\"] = usuario[0]", 0],
	["    return redirect(\"/sinistros\")", 0],
	["", 0],
	["@app.get(\"/sinistros/busca\")", 0],
	["def busca():", 0],
	["    cpf = request.args.get(\"cpf\", \"\")", 0],
	["    cur = db().cursor()", 0],
	["    cur.execute(f\"SELECT id, placa, status FROM sinistros WHERE cpf = '{cpf}'\")", 1],
	["    linhas = cur.fetchall()", 0],
	["    if not linhas:", 0],
	["        return f\"<p>Nenhum sinistro para o CPF <b>{cpf}</b></p>\"", 2],
	["    return render_template(\"lista.html\", sinistros=linhas)", 0],
	["", 0],
	["@app.get(\"/sinistros/foto\")", 0],
	["def foto():", 0],
	["    return send_file(os.path.join(UPLOAD_DIR, request.args[\"arquivo\"]))", 6],
	["", 0],
	["@app.post(\"/sinistros/foto\")", 0],
	["def enviar_foto():", 0],
	["    arquivo = request.files[\"foto\"]", 0],
	["    nome = secure_filename(arquivo.filename)", 0],
	["    caminho = os.path.join(UPLOAD_DIR, nome)", 0],
	["    arquivo.save(caminho)", 0],
	["    subprocess.run([\"convert\", caminho, \"-resize\", \"1600x1600>\", caminho], check=True)", 0],
	["    digest = hashlib.sha256(open(caminho, \"rb\").read()).hexdigest()", 0],
	["    return {\"arquivo\": nome, \"sha256\": digest}", 0],
	["", 0],
	["@app.post(\"/sinistros/foto-url\")", 0],
	["def foto_por_url():", 0],
	["    resp = requests.get(request.form[\"url\"], timeout=5)", 7],
	["    return {\"tamanho\": len(resp.content)}", 0],
	["", 0],
	["@app.get(\"/preferencias\")", 0],
	["def preferencias():", 0],
	["    prefs = pickle.loads(base64.b64decode(request.cookies.get(\"prefs\", \"\")))", 5],
	["    return render_template(\"prefs.html\", prefs=prefs)", 0],
	["", 0],
	["if __name__ == \"__main__\":", 0],
	["    app.run(host=\"0.0.0.0\", port=8080, debug=True)", 8],
]

# Defesa do Kauã por linha (número da linha, 1-based). Vale para vulneráveis e para as que estão certas.
const DEFESAS := {
	13: "A SECRET_KEY é só pra assinar o cookie de sessão. O repositório é privado. Acho que é privado.",
	14: "Senha do banco no código facilita o deploy. Se mudar, eu mudo aqui e faço commit. Simples.",
	15: "Isso aí lê do ambiente. Igual eu vi num tutorial.",
	25: "MD5 é hash, e hash não volta. Aprendi na faculdade. No primeiro período.",
	27: "Aqui eu usei o %s com tupla. Está na documentação do psycopg2, pode ler.",
	38: "Mas CPF só tem número! Quem vai digitar aspas num CPF?",
	41: "É só uma mensagem de erro. Não tem nada sensível aí.",
	42: "render_template usa Jinja com autoescape. Isso eu sei.",
	46: "O front só manda nome de foto que existe. Ninguém digita ../ na URL.",
	51: "secure_filename tira barra e ponto ponto do nome. Foi a Jurema que mandou.",
	54: "É lista de argumentos, sem shell=True. O caminho vai como argumento, não como comando.",
	55: "SHA-256 é só pra conferir se a foto chegou inteira. Não é senha.",
	60: "É pro corretor importar foto do Google Drive. Que outra URL alguém mandaria?",
	65: "Pickle é do próprio Python, é oficial. E o cookie fui eu que gerei.",
	69: "Debug é pra ver o erro bonitinho na tela. Em produção a gente tira. Um dia.",
}
const DEFESAS_GENERICAS := [
	"Essa linha? Copiei do Stack Overflow, então é revisada pela comunidade.",
	"Testei na minha máquina. Duas vezes.",
	"Isso é padrão de mercado, todo mundo faz assim.",
]
const EXPLICACOES := {
	1: "f-string montando SQL com o CPF: ' OR '1'='1 lista todos os sinistros. Use parâmetro (%s) como no login.",
	2: "CPF refletido no HTML sem escape: XSS refletido. Use render_template ou markupsafe.escape.",
	3: "segredo no código vai parar no Git para sempre. Use variável de ambiente ou cofre de segredos.",
	4: "MD5 sem sal é quebrado em segundos com GPU e tabelas prontas. Senha pede argon2id, scrypt ou bcrypt.",
	5: "pickle.loads em cookie do cliente executa código arbitrário. Use JSON (e assine se precisar).",
	6: "arquivo=../../../etc/passwd sai do UPLOAD_DIR. Use send_from_directory ou valide o caminho final.",
	7: "a URL vem do usuário: dá para pedir http://169.254.169.254/ ou a rede interna. Use lista de domínios permitidos.",
	8: "debug=True liga o console do Werkzeug, que executa Python remoto. Nunca em produção.",
}

var _linhas: Array[Button] = []
var _marcadas := {}   # linha (1-based) -> categoria escolhida
var _lista: VBoxContainer
var _decisao := ""
var _bt_request: Button
var _bt_approve: Button
var _defendeu := {}
var _generica := 0


func _init() -> void:
	dia = 7
	titulo = "Revisão de código"
	chamado = ("PR #212 do Kauã: [i]\"feat: busca de sinistros por CPF e fotos\"[/i]. Clique nas linhas com vulnerabilidade, "
		+ "escolha a categoria (CWE e OWASP Top 10 2021) de cada marcação e decida: [b]Request changes[/b] ou [b]Approve[/b]. "
		+ "Marcação certa vale ponto; linha inocente marcada tira ponto.")


func montar() -> void:
	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(0, 340)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	corpo.add_child(rolagem)
	var fundo := PanelContainer.new()
	fundo.add_theme_stylebox_override("panel", Estilo.caixa(Color("0b0e14"), Estilo.BORDA, 4, 6))
	fundo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(fundo)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	fundo.add_child(v)
	for cab in ["diff --git a/sinistros/app.py b/sinistros/app.py", "new file mode 100644", "--- /dev/null", "+++ b/sinistros/app.py", "@@ -0,0 +1,%d @@" % CODIGO.size()]:
		var l := rotulo(cab, 12, Estilo.CIANO if cab.begins_with("@@") else Estilo.TEXTO_FRACO, v)
		l.add_theme_font_override("font", Estilo.mono())
	var vazio := StyleBoxFlat.new()
	vazio.bg_color = Color(0, 0, 0, 0)
	vazio.content_margin_left = 4
	vazio.content_margin_top = 1
	vazio.content_margin_bottom = 1
	var sobre := vazio.duplicate()
	sobre.bg_color = Color("1d2638")
	var marcado := vazio.duplicate()
	marcado.bg_color = Color("4a1d36")
	for i in CODIGO.size():
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%3d  + %s" % [i + 1, CODIGO[i][0]]
		b.add_theme_font_override("font", Estilo.mono())
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_stylebox_override("normal", vazio)
		b.add_theme_stylebox_override("hover", sobre)
		b.add_theme_stylebox_override("pressed", marcado)
		b.add_theme_stylebox_override("hover_pressed", marcado)
		b.add_theme_stylebox_override("focus", vazio)
		b.add_theme_color_override("font_color", Color("b5e8c5"))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		b.toggled.connect(_alternar.bind(i + 1))
		v.add_child(b)
		_linhas.append(b)

	var p := painel()
	rotulo("Comentários da revisão (clique numa linha do diff para comentar)", 14, Estilo.CIANO, p)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 4)
	p.add_child(_lista)
	var dec := linha()
	rotulo("Decisão do review:", 14, Estilo.TEXTO_FRACO, dec).autowrap_mode = TextServer.AUTOWRAP_OFF
	var grupo := ButtonGroup.new()
	_bt_request = botao("Request changes", _decidir.bind("request"), dec)
	_bt_approve = botao("Approve", _decidir.bind("approve"), dec)
	for b in [_bt_request, _bt_approve]:
		b.toggle_mode = true
		b.button_group = grupo
		b.custom_minimum_size = Vector2(170, 34)
	_reconstruir_lista()

	chat("Kauã", "PR rapidinho, estagi! 69 linhas. Só preciso do approve até as 18h que eu quero subir sexta.")
	chat("Jurema", "Lê linha por linha. E cuidado: nem tudo que parece perigoso é. Query com %s e tupla, por exemplo, é o jeito certo.")
	aviso("Dica: marque só o que você defenderia numa reunião com o Kauã. Falso positivo custa.")


func _alternar(ligado: bool, n: int) -> void:
	if ligado:
		_marcadas[n] = _marcadas.get(n, 0)
		if not _defendeu.has(n):
			_defendeu[n] = true
			if DEFESAS.has(n):
				chat("Kauã", "L%d: %s" % [n, DEFESAS[n]])
			elif CODIGO[n - 1][0].strip_edges() != "":
				chat("Kauã", "L%d: %s" % [n, DEFESAS_GENERICAS[_generica % DEFESAS_GENERICAS.size()]])
				_generica += 1
	else:
		_marcadas.erase(n)
	_reconstruir_lista()


func _reconstruir_lista() -> void:
	for f in _lista.get_children():
		f.queue_free()
	if _marcadas.is_empty():
		rotulo("(nenhuma linha marcada)", 13, Estilo.TEXTO_FRACO, _lista)
		return
	var chaves := _marcadas.keys()
	chaves.sort()
	for n in chaves:
		var h := linha(_lista)
		var l := rotulo("L%-3d %s" % [n, CODIGO[n - 1][0].strip_edges()], 12, Estilo.TEXTO, h)
		l.add_theme_font_override("font", Estilo.mono())
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(200, 0)
		var ob := opcoes(CATEGORIAS, h)
		ob.custom_minimum_size = Vector2(320, 0)
		ob.select(_marcadas[n])
		ob.item_selected.connect(func(i): _marcadas[n] = i)
		var x := botao("remover", _desmarcar.bind(n), h)
		x.add_theme_font_size_override("font_size", 12)


func _desmarcar(n: int) -> void:
	_linhas[n - 1].set_pressed_no_signal(false)
	_marcadas.erase(n)
	_reconstruir_lista()


func _decidir(d: String) -> void:
	_decisao = d
	if d == "approve":
		chat("Kauã", "Valeu, estagi! Merge feito, deploy na sexta às 17h55. O que pode dar errado?")
		chat("Jurema", "Tudo. Pode dar tudo errado.")
	else:
		chat("Kauã", "Request changes?! Mas eu testei na minha máquina...")
		chat("Jurema", "Sua máquina não é a internet, Kauã.")


func avaliar() -> Dictionary:
	var total := 0
	var pontos := 0.0
	var falsos: Array[int] = []
	var perdidas: Array[String] = []
	var cat_errada: Array[String] = []
	for i in CODIGO.size():
		var n := i + 1
		var certa: int = CODIGO[i][1]
		if certa > 0:
			total += 1
			if not _marcadas.has(n):
				perdidas.append("L%d: %s" % [n, EXPLICACOES[certa]])
			elif _marcadas[n] == certa:
				pontos += 1.0
			else:
				pontos += 0.4
				cat_errada.append("L%d é %s" % [n, CATEGORIAS[certa]])
		elif _marcadas.has(n):
			falsos.append(n)
	pontos -= 0.5 * falsos.size()
	var nota := int(round(85.0 * maxf(pontos, 0.0) / total))
	var com := "Achados: %.1f de %d pontos." % [maxf(pontos, 0.0), total]
	if _decisao == "request":
		nota += 15
	elif _decisao == "approve":
		nota = mini(nota, 25)
		com += " Você aprovou um PR com SQL injection, segredo no código e pickle de cookie. Approve é assinatura: o código vai para produção com o seu nome."
	else:
		com += " Faltou a decisão do review."
	if not falsos.is_empty():
		var nomes: Array[String] = []
		for n in falsos:
			nomes.append("L%d" % n)
		com += " Falsos positivos: %s (query parametrizada, subprocess com lista sem shell, SHA-256 para integridade e secure_filename estão corretos)." % ", ".join(nomes)
	if not cat_errada.is_empty():
		com += " Categoria errada: " + "; ".join(cat_errada) + "."
	if not perdidas.is_empty():
		com += " Passou batido: " + " ".join(perdidas.slice(0, 3)) + (" (e mais %d)" % (perdidas.size() - 3) if perdidas.size() > 3 else "")
	if falsos.is_empty() and cat_errada.is_empty() and perdidas.is_empty():
		com += " Revisão completa: as 9 falhas certas, nenhuma acusação injusta. O Kauã vai passar o fim de semana corrigindo."
	return {"nota": clampi(nota, 0, 100), "comentario": com, "cagada": ""}


func solucao_teste() -> void:
	for i in CODIGO.size():
		if CODIGO[i][1] > 0:
			_linhas[i].button_pressed = true
			_marcadas[i + 1] = CODIGO[i][1]
	_reconstruir_lista()
	_bt_request.button_pressed = true
	_decisao = "request"
