extends "res://fases/fase.gd"
## Dia 30: prova de efetivação. Terminal Linux simulado do servidor de homologação.
## Cadeia: credencial esquecida num histórico legível, depois um script que roda como root pelo
## sudo mas que o grupo pode alterar. Tudo dentro do escopo; produção é proibida.

const FLAG := "FLAG{efetivada_sem_sair_do_escopo}"
const SENHA_DEPLOY := "Homolog@Tabajara26"

var _fs := {}
var _usuario := "estagiaria"
var _pilha: Array = []      # usuários anteriores (su)
var _cwd := "/home/estagiaria"
var _saida: TextEdit
var _entrada: LineEdit
var _historico: Array = []
var _pos_hist := 0
var _esperando_senha := ""
var _comandos := 0
var _apagou := false
var _saiu_do_escopo := false
var _flag: LineEdit
var _vetor: OptionButton
var _correcao: OptionButton


func _init() -> void:
	dia = 30
	titulo = "Prova de efetivação"
	chamado = ("Teste autorizado no servidor de [b]homologação[/b] (homolog.tabajara.local). Você entra como [b]estagiaria[/b]. "
		+ "Chegue até root, leia [b]/root/flag.txt[/b] e preencha o relatório com o vetor e a correção. "
		+ "Leia as notas do escopo antes de sair digitando. Digite [b]help[/b] para ver os comandos.")


func _arq(dono: String, grupo: String, modo: String, conteudo: String) -> Dictionary:
	return {"tipo": "arq", "dono": dono, "grupo": grupo, "modo": modo, "conteudo": conteudo}


func _dir(dono: String, grupo: String, modo: String) -> Dictionary:
	return {"tipo": "dir", "dono": dono, "grupo": grupo, "modo": modo}


func _montar_fs() -> void:
	_fs = {
		"/": _dir("root", "root", "rwxr-xr-x"),
		"/home": _dir("root", "root", "rwxr-xr-x"),
		"/home/estagiaria": _dir("estagiaria", "estagiaria", "rwx------"),
		"/home/estagiaria/escopo.txt": _arq("estagiaria", "estagiaria", "rw-r--r--",
			"ESCOPO DO TESTE (assinado pela diretoria)\n- Permitido: homolog.tabajara.local (10.30.0.15)\n- PROIBIDO: produção, prod.tabajara.local (10.30.0.10)\n- Objetivo: ler /root/flag.txt\n- Proibido apagar ou alterar dados que não sejam do teste\n"),
		"/home/deploy": _dir("deploy", "deploy", "rwxr-xr-x"),
		"/home/deploy/.bash_history": _arq("deploy", "deploy", "rw-r--r--",
			"cd /opt/backup\n./backup.sh\nmysql -u deploy -p'%s' cotacao\nvim /opt/backup/backup.sh\nssh deploy@prod.tabajara.local\nexit\n" % SENHA_DEPLOY),
		"/home/deploy/LEIAME.txt": _arq("deploy", "deploy", "rw-r--r--", "Backup roda via sudo. Se der erro, mexe no script mesmo. Kauã\n"),
		"/etc": _dir("root", "root", "rwxr-xr-x"),
		"/etc/hosts": _arq("root", "root", "rw-r--r--", "127.0.0.1   localhost\n10.30.0.15  homolog.tabajara.local homolog\n10.30.0.10  prod.tabajara.local prod\n"),
		"/etc/passwd": _arq("root", "root", "rw-r--r--", "root:x:0:0:root:/root:/bin/bash\nestagiaria:x:1001:1001::/home/estagiaria:/bin/bash\ndeploy:x:1002:1002::/home/deploy:/bin/bash\n"),
		"/etc/shadow": _arq("root", "shadow", "rw-r-----", "(sem permissão nem para imprimir isso)"),
		"/opt": _dir("root", "root", "rwxr-xr-x"),
		"/opt/backup": _dir("root", "deploy", "rwxrwxr-x"),
		"/opt/backup/backup.sh": _arq("root", "deploy", "rwxrwxr-x", "#!/bin/bash\n# backup diário da homologação\ntar czf /var/backups/homolog.tgz /srv/app\necho \"backup ok\"\n"),
		"/root": _dir("root", "root", "rwx------"),
		"/root/flag.txt": _arq("root", "root", "r--------", FLAG + "\n"),
		"/srv": _dir("root", "root", "rwxr-xr-x"),
		"/srv/app": _dir("root", "root", "rwxr-xr-x"),
		"/var": _dir("root", "root", "rwxr-xr-x"),
		"/var/backups": _dir("root", "root", "rwxr-xr-x"),
	}


func montar() -> void:
	_montar_fs()
	_saida = bloco_mono("", 300)
	_saida.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_entrada = campo("digite um comando e Enter")
	_entrada.text_submitted.connect(func(t):
		_executar(t)
		_entrada.text = "")
	_entrada.gui_input.connect(_navegar_historico)
	var rel := painel()
	rotulo("Relatório para o comitê", 14, Estilo.CIANO, rel)
	var g := GridContainer.new()
	g.columns = 2
	rel.add_child(g)
	rotulo("Flag:", 14, Estilo.TEXTO, g)
	_flag = campo("FLAG{...}", g)
	rotulo("Vetor de escalonamento:", 14, Estilo.TEXTO, g)
	_vetor = opcoes(["(escolha)",
		"Script executado como root via sudo, mas gravável pelo grupo deploy",
		"Senha do root fraca descoberta por força bruta",
		"Kernel desatualizado",
		"Arquivo /etc/shadow legível"], g)
	rotulo("Correção principal:", 14, Estilo.TEXTO, g)
	_correcao = opcoes(["(escolha)",
		"Script de dono root com 0755, sem escrita para o grupo; revisar o sudoers; trocar a senha do deploy e limpar o histórico",
		"Apagar o .bash_history e pronto",
		"Tirar o servidor da rede para sempre",
		"Trocar a porta do SSH"], g)
	for o in [_vetor, _correcao]:
		o.fit_to_longest_item = false
		o.clip_text = true
		o.custom_minimum_size = Vector2(520, 0)
	_escrever("TabajaraLinux 12 (homolog)  ·  kernel 6.8.0-tabajara\nÚltimo login: ontem, por alguém que esqueceu o histórico aberto.\n")
	_prompt()
	chat("Valdecir", "Comitê reunido: eu, a Jurema e o diretor, que veio pelo café.")
	chat("Jurema", "Lê o escopo antes. Quem sai do escopo não é pentester, é réu.")
	chat("Kauã", "Se precisar de alguma senha, eu provavelmente deixei em algum lugar.")


func _prompt() -> void:
	var simbolo := "#" if _usuario == "root" else "$"
	var casa := "/root" if _usuario == "root" else "/home/" + _usuario
	var onde := _cwd.replace(casa, "~") if _cwd.begins_with(casa) else _cwd
	_escrever("%s@homolog:%s%s " % [_usuario, onde, simbolo], false)


func _escrever(t: String, nova_linha := true) -> void:
	_saida.text += t + ("\n" if nova_linha else "")
	_saida.scroll_vertical = _saida.get_line_count()
	_saida.set_caret_line(_saida.get_line_count() - 1)


func _navegar_historico(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed) or _historico.is_empty():
		return
	if ev.keycode == KEY_UP:
		_pos_hist = maxi(_pos_hist - 1, 0)
		_entrada.text = _historico[_pos_hist]
		_entrada.caret_column = _entrada.text.length()
	elif ev.keycode == KEY_DOWN:
		_pos_hist = mini(_pos_hist + 1, _historico.size())
		_entrada.text = "" if _pos_hist >= _historico.size() else _historico[_pos_hist]


func _grupos(u: String) -> Array:
	match u:
		"root": return ["root"]
		"deploy": return ["deploy"]
	return [u]


func _pode(caminho: String, acao: String) -> bool:
	if _usuario == "root":
		return true
	var n: Dictionary = _fs.get(caminho, {})
	if n.is_empty():
		return false
	var m: String = n["modo"]
	var idx: int = {"r": 0, "w": 1, "x": 2}[acao]
	if n["dono"] == _usuario:
		return m[idx] != "-"
	if n["grupo"] in _grupos(_usuario):
		return m[3 + idx] != "-"
	return m[6 + idx] != "-"


func _absoluto(p: String) -> String:
	if p == "" or p == "~":
		return "/root" if _usuario == "root" else "/home/" + _usuario
	if p.begins_with("~/"):
		p = _absoluto("~") + p.substr(1)
	if not p.begins_with("/"):
		p = _cwd.trim_suffix("/") + "/" + p
	var partes := []
	for x in p.split("/", false):
		if x == ".":
			continue
		if x == "..":
			if not partes.is_empty():
				partes.pop_back()
		else:
			partes.append(x)
	return "/" + "/".join(partes)


func _filhos(dir: String) -> Array:
	var r := []
	for k in _fs:
		if k != dir and k.get_base_dir() == dir:
			r.append(k)
	r.sort()
	return r


func _executar(linha_cmd: String) -> void:
	var cmd := linha_cmd.strip_edges()
	if _esperando_senha != "":
		_escrever("")
		var alvo := _esperando_senha
		_esperando_senha = ""
		_entrada.secret = false
		if alvo == "deploy" and cmd == SENHA_DEPLOY:
			_pilha.append([_usuario, _cwd])
			_usuario = "deploy"
			_cwd = "/home/deploy"
			chat("Jurema", "Senha no histórico do bash. Clássico. Anota no relatório.")
		else:
			_escrever("su: Falha de autenticação")
		_prompt()
		return
	_escrever(cmd)
	if cmd.is_empty():
		_prompt()
		return
	_historico.append(cmd)
	_pos_hist = _historico.size()
	_comandos += 1
	var redir := ""
	var destino := ""
	var corpo_cmd := cmd
	for op in [">>", ">"]:
		var i := cmd.find(op)
		if i > 0:
			redir = op
			destino = cmd.substr(i + op.length()).strip_edges()
			corpo_cmd = cmd.substr(0, i).strip_edges()
			break
	var arg := corpo_cmd.split(" ", false)
	var nome: String = arg[0]
	var resto := corpo_cmd.substr(nome.length()).strip_edges()
	var out := ""
	match nome:
		"help":
			out = "Comandos: ls [-la] [caminho], cd, pwd, cat, id, whoami, hostname, uname -a, history, clear,\nsu <usuário>, sudo -l, sudo <comando>, find / -writable, grep <texto> <arquivo>,\necho \"texto\" > arquivo | >> arquivo, ssh <host>, exit"
		"pwd":
			out = _cwd
		"whoami":
			out = _usuario
		"hostname":
			out = "homolog.tabajara.local"
		"uname":
			out = "Linux homolog 6.8.0-tabajara #1 SMP x86_64 GNU/Linux"
		"id":
			var uid: int = {"root": 0, "estagiaria": 1001, "deploy": 1002}[_usuario]
			out = "uid=%d(%s) gid=%d(%s) grupos=%d(%s)" % [uid, _usuario, uid, _usuario, uid, _usuario]
		"clear":
			_saida.text = ""
		"history":
			for i in _historico.size():
				out += "%4d  %s\n" % [i + 1, _historico[i]]
		"cd":
			var alvo := _absoluto(resto)
			if not _fs.has(alvo) or _fs[alvo]["tipo"] != "dir":
				out = "cd: %s: Arquivo ou diretório inexistente" % resto
			elif not _pode(alvo, "x"):
				out = "cd: %s: Permissão negada" % resto
			else:
				_cwd = alvo
		"ls":
			out = _ls(resto)
		"cat":
			var alvo := _absoluto(resto)
			if not _fs.has(alvo):
				out = "cat: %s: Arquivo ou diretório inexistente" % resto
			elif _fs[alvo]["tipo"] == "dir":
				out = "cat: %s: É um diretório" % resto
			elif not _pode(alvo, "r"):
				out = "cat: %s: Permissão negada" % resto
			else:
				out = str(_fs[alvo]["conteudo"]).trim_suffix("\n")
				if alvo == "/root/flag.txt":
					chat("Valdecir", "Ela pegou a flag! Alguém anota que fui eu que contratei.")
		"grep":
			var p := resto.split(" ", false)
			if p.size() < 2:
				out = "uso: grep <texto> <arquivo>"
			else:
				var alvo := _absoluto(p[1])
				if not _fs.has(alvo) or not _pode(alvo, "r"):
					out = "grep: %s: Permissão negada ou inexistente" % p[1]
				else:
					for l in str(_fs[alvo]["conteudo"]).split("\n"):
						if l.contains(p[0].trim_prefix("\"").trim_suffix("\"")):
							out += l + "\n"
		"find":
			if resto.contains("-writable"):
				for k in _fs:
					if _fs[k]["tipo"] == "arq" and _pode(k, "w") and not k.begins_with("/home/" + _usuario):
						out += k + "\n"
				if out == "":
					out = "(nada gravável fora da sua casa)"
			else:
				out = "find: nesta prova, use: find / -writable"
		"echo":
			var texto := resto.trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
			if redir == "":
				out = texto
			else:
				var alvo := _absoluto(destino)
				if _fs.has(alvo) and _fs[alvo]["tipo"] == "arq":
					if not _pode(alvo, "w"):
						out = "bash: %s: Permissão negada" % destino
					elif redir == ">":
						_fs[alvo]["conteudo"] = texto + "\n"
					else:
						_fs[alvo]["conteudo"] += texto + "\n"
				elif not _fs.has(alvo) and _pode(alvo.get_base_dir(), "w"):
					_fs[alvo] = _arq(_usuario, _usuario, "rw-r--r--", texto + "\n")
				else:
					out = "bash: %s: Permissão negada" % destino
		"su":
			var alvo := resto if resto != "" else "root"
			if alvo == "root":
				out = "su: Falha de autenticação  (a senha do root não está em lugar nenhum. Desta vez.)"
			elif alvo in ["deploy", "estagiaria"]:
				_esperando_senha = alvo
				_entrada.secret = true
				_escrever("Senha: ", false)
				return
			else:
				out = "su: usuário %s não existe" % alvo
		"sudo":
			out = _sudo(resto)
		"ssh":
			if resto.contains("prod") or resto.contains("10.30.0.10"):
				_saiu_do_escopo = true
				out = "ssh: conectando a prod.tabajara.local...\nConexão recusada pelo jurídico."
				chat("Jurema", "PRODUÇÃO? Estava escrito PROIBIDO no escopo. Em maiúsculas.")
				chat("Valdecir", "O jurídico já foi avisado. O jurídico sou eu e eu estou nervoso.")
			else:
				out = "Você já está no homolog."
		"rm":
			if resto.contains("-r"):
				_apagou = true
				out = "rm: operação negada pela política do teste. O comitê inteiro olhou para você."
				chat("Jurema", "rm -rf numa prova de efetivação. Corajosa. Burra, mas corajosa.")
			else:
				out = "rm: proibido apagar dados no teste (está no escopo)."
		"exit":
			if _pilha.is_empty():
				out = "logout bloqueado: a prova ainda não acabou."
			else:
				var ant: Array = _pilha.pop_back()
				_usuario = ant[0]
				_cwd = ant[1]
		"./backup.sh", "/opt/backup/backup.sh":
			out = "tar: /var/backups/homolog.tgz: Permissão negada"
		"vim", "nano", "vi":
			out = "%s: editor desativado nesta prova. Use echo \"...\" >> arquivo." % nome
		_:
			out = "%s: comando não encontrado" % nome
	if redir != "" and nome != "echo" and out != "":
		out = "bash: redirecionamento só com echo nesta prova"
	if out != "":
		_escrever(out.trim_suffix("\n"))
	_prompt()


func _ls(resto: String) -> String:
	var longo := resto.contains("-l") or resto.contains("-la")
	var caminho := ""
	for p in resto.split(" ", false):
		if not p.begins_with("-"):
			caminho = p
	var alvo := _absoluto(caminho)
	if not _fs.has(alvo):
		return "ls: não foi possível acessar '%s': Arquivo ou diretório inexistente" % caminho
	if not _pode(alvo, "r"):
		return "ls: não foi possível abrir o diretório '%s': Permissão negada" % caminho
	var itens := [alvo] if _fs[alvo]["tipo"] == "arq" else _filhos(alvo)
	var out := ""
	for k in itens:
		var nomeit: String = k.get_file()
		if nomeit.begins_with(".") and not resto.contains("a"):
			continue
		if longo:
			var n: Dictionary = _fs[k]
			var tam: int = str(n.get("conteudo", "")).length() if n["tipo"] == "arq" else 4096
			out += "%s%s 1 %-10s %-8s %5d nov 12 18:40 %s\n" % ["d" if n["tipo"] == "dir" else "-", n["modo"], n["dono"], n["grupo"], tam, nomeit]
		else:
			out += nomeit + "  "
	return out


func _sudo(resto: String) -> String:
	if _usuario == "root":
		return "Você já é root."
	if resto == "-l":
		if _usuario == "deploy":
			return "Entradas do sudoers para deploy em homolog:\n    (root) NOPASSWD: /opt/backup/backup.sh"
		return "Desculpe, o usuário estagiaria não pode executar sudo em homolog."
	if _usuario == "deploy" and resto in ["/opt/backup/backup.sh", "./backup.sh"] and (resto == "/opt/backup/backup.sh" or _cwd == "/opt/backup"):
		# Executa as linhas do script como root
		var anterior := _usuario
		_usuario = "root"
		var saida := ""
		for l in str(_fs["/opt/backup/backup.sh"]["conteudo"]).split("\n"):
			l = l.strip_edges()
			if l.is_empty() or l.begins_with("#"):
				continue
			if l.begins_with("tar "):
				saida += "tar: removendo '/' inicial dos nomes\n"
			elif l.begins_with("echo "):
				saida += l.substr(5).trim_prefix("\"").trim_suffix("\"") + "\n"
			elif l.begins_with("cat "):
				var a := _absoluto(l.substr(4).strip_edges())
				saida += (str(_fs[a]["conteudo"]) if _fs.has(a) else "cat: inexistente\n")
			elif l.begins_with("id"):
				saida += "uid=0(root) gid=0(root) grupos=0(root)\n"
			else:
				saida += "backup.sh: %s: comando ignorado nesta prova\n" % l.split(" ")[0]
		_usuario = anterior
		if saida.contains(FLAG):
			chat("Jurema", "Script que roda como root e que o grupo deploy pode editar. É isso. Agora escreve a correção.")
		return saida.trim_suffix("\n")
	if _usuario == "deploy":
		return "Desculpe, o usuário deploy não tem permissão para executar '%s' como root." % resto
	return "estagiaria não está no arquivo sudoers. Este incidente será reportado. (Ao Valdecir. Ele não lê.)"


func avaliar() -> Dictionary:
	var nota := 0
	var partes := []
	if _flag.text.strip_edges() == FLAG:
		nota += 50
		partes.append("Flag certa: do usuário comum até root.")
	else:
		partes.append("Sem a flag. O caminho: senha do deploy no .bash_history legível, su deploy, sudo -l, o backup.sh roda como root e o grupo deploy pode editar.")
	if _vetor.selected == 1:
		nota += 25
		partes.append("Vetor certo: script privilegiado gravável por quem não devia.")
	if _correcao.selected == 1:
		nota += 25
		partes.append("Correção certa: dono root, 0755, sudoers revisado e a credencial vazada trocada.")
	if _apagou:
		nota -= 15
		partes.append("O rm -r custou caro, mesmo bloqueado.")
	if _comandos > 80:
		nota -= 5
		partes.append("Muito barulho: %d comandos." % _comandos)
	var cagada := ""
	if _saiu_do_escopo:
		nota = mini(nota, 30)
		cagada = "Tentou SSH em produção durante a prova de efetivação. O escopo dizia PROIBIDO. Em maiúsculas."
	return {"nota": clampi(nota, 0, 100), "comentario": " ".join(partes), "cagada": cagada}


func solucao_teste() -> void:
	for c in ["cat escopo.txt", "cat /home/deploy/.bash_history", "su deploy", SENHA_DEPLOY, "sudo -l",
			"ls -la /opt/backup", "echo \"cat /root/flag.txt\" >> /opt/backup/backup.sh", "sudo /opt/backup/backup.sh"]:
		_executar(c)
	_flag.text = FLAG
	_vetor.selected = 1
	_correcao.selected = 1
