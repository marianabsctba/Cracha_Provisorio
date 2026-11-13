extends "res://fases/fase.gd"
## Dia 5: endurecer o sshd_config do servidor de boletos sem trancar todo mundo do lado de fora.
## Parser de sshd_config com as regras do OpenSSH (primeira ocorrência vale, erros como o sshd -t),
## checagem contra a linha de base CIS e simulação do restart.

const ARQ := "/etc/ssh/sshd_config"
const UNIDADES := {"s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800}
const CHAVE_JUREMA := "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJq7Wc0tQe2rT8vLx4yPzHn1sKdFmB3aUo6gViE9RjNc jurema@note-jurema"
const GRUPOS_JUREMA := ["jurema", "sudo", "admssh"]

const ORIGINAL := """# $OpenBSD: sshd_config,v 1.104 2021/07/02 05:11:21 dtucker Exp $
# srv-boletos-01 (datacenter Uberaba). NAO MEXER. Valdecir, 2015.

Port 22
ListenAddress 0.0.0.0
Protocol 2
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

SyslogFacility AUTH
LogLevel QUIET

LoginGraceTime 2m
PermitRootLogin yes
StrictModes yes
MaxAuthTries 10
MaxSessions 10

PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

HostbasedAuthentication yes
IgnoreRhosts no
PasswordAuthentication yes
PermitEmptyPasswords yes
KbdInteractiveAuthentication no
UsePAM yes

AllowAgentForwarding yes
AllowTcpForwarding yes
X11Forwarding yes
PrintMotd no
PermitUserEnvironment yes
ClientAliveInterval 0
ClientAliveCountMax 3
MaxStartups 100
Ciphers aes128-cbc,aes256-cbc,aes256-ctr,chacha20-poly1305@openssh.com
Banner none

AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
"""

const RESOLVIDO := """# srv-boletos-01 (datacenter Uberaba). Endurecido conforme CIS.

Port 22
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

SyslogFacility AUTH
LogLevel VERBOSE

LoginGraceTime 30
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 4

PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

HostbasedAuthentication no
IgnoreRhosts yes
PasswordAuthentication no
PermitEmptyPasswords no
KbdInteractiveAuthentication no
UsePAM yes

AllowGroups admssh
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PrintMotd no
PermitUserEnvironment no
ClientAliveInterval 300
ClientAliveCountMax 3
MaxStartups 10:30:60
Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr
Banner /etc/issue.net

AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
"""

const FLAGS := ["passwordauthentication", "pubkeyauthentication", "permitemptypasswords", "x11forwarding",
	"usepam", "ignorerhosts", "hostbasedauthentication", "allowagentforwarding", "permituserenvironment",
	"kbdinteractiveauthentication", "challengeresponseauthentication", "gssapiauthentication", "usedns",
	"printmotd", "printlastlog", "tcpkeepalive", "strictmodes", "x11uselocalhost", "kerberosauthentication",
	"permittty", "exposeauthinfo", "disableforwarding", "gssapicleanupcredentials"]
const MULTI := {
	"permitrootlogin": ["yes", "no", "prohibit-password", "without-password", "forced-commands-only"],
	"allowtcpforwarding": ["yes", "no", "all", "local", "remote"],
	"allowstreamlocalforwarding": ["yes", "no", "all", "local", "remote"],
	"compression": ["yes", "no", "delayed"],
	"permittunnel": ["yes", "no", "point-to-point", "ethernet"],
	"gatewayports": ["yes", "no", "clientspecified"],
	"addressfamily": ["any", "inet", "inet6"],
}
const INTEIROS := ["maxauthtries", "maxsessions", "clientalivecountmax", "x11displayoffset"]
const TEMPOS := ["logingracetime", "clientaliveinterval"]
const NIVEIS := ["QUIET", "FATAL", "ERROR", "INFO", "VERBOSE", "DEBUG", "DEBUG1", "DEBUG2", "DEBUG3"]
const FACILIDADES := ["DAEMON", "USER", "AUTH", "AUTHPRIV", "LOCAL0", "LOCAL1", "LOCAL2", "LOCAL3", "LOCAL4", "LOCAL5", "LOCAL6", "LOCAL7"]
const LIVRES := ["listenaddress", "hostkey", "authorizedkeysfile", "acceptenv", "subsystem", "banner",
	"allowusers", "allowgroups", "denyusers", "denygroups", "include", "pidfile", "chrootdirectory",
	"forcecommand", "authenticationmethods", "versionaddendum", "trustedusercakeys", "authorizedprincipalsfile",
	"setenv", "permitopen", "match", "hostkeyalgorithms", "pubkeyacceptedalgorithms", "casignaturealgorithms",
	"authorizedkeyscommand", "authorizedkeyscommanduser", "revokedkeys", "permitlisten", "ipqos", "rekeylimit"]
const DEPRECADAS := ["protocol", "useprivilegeseparation", "rsaauthentication", "rhostsrsaauthentication",
	"serverkeybits", "keyregenerationinterval", "uselogin"]
const CIFRAS := ["3des-cbc", "aes128-cbc", "aes192-cbc", "aes256-cbc", "aes128-ctr", "aes192-ctr", "aes256-ctr",
	"aes128-gcm@openssh.com", "aes256-gcm@openssh.com", "chacha20-poly1305@openssh.com"]
const MACS := ["hmac-sha1", "hmac-sha1-96", "hmac-sha2-256", "hmac-sha2-512", "hmac-md5", "hmac-md5-96",
	"umac-64@openssh.com", "umac-128@openssh.com", "hmac-sha1-etm@openssh.com", "hmac-sha1-96-etm@openssh.com",
	"hmac-sha2-256-etm@openssh.com", "hmac-sha2-512-etm@openssh.com", "hmac-md5-etm@openssh.com",
	"hmac-md5-96-etm@openssh.com", "umac-64-etm@openssh.com", "umac-128-etm@openssh.com"]
const KEX := ["curve25519-sha256", "curve25519-sha256@libssh.org", "diffie-hellman-group1-sha1",
	"diffie-hellman-group14-sha1", "diffie-hellman-group14-sha256", "diffie-hellman-group16-sha512",
	"diffie-hellman-group18-sha512", "diffie-hellman-group-exchange-sha1", "diffie-hellman-group-exchange-sha256",
	"ecdh-sha2-nistp256", "ecdh-sha2-nistp384", "ecdh-sha2-nistp521", "sntrup761x25519-sha512@openssh.com",
	"sntrup761x25519-sha512", "mlkem768x25519-sha256"]
const LISTAS := {"ciphers": ["cipher", CIFRAS], "macs": ["mac", MACS], "kexalgorithms": ["KexAlgorithms", KEX]}

var _editor: CodeEdit
var _cis: VBoxContainer
var _cis_resumo: Label
var _saida: TextEdit
var _prompt: LineEdit
var _chaves: Array[String] = []
var _rodando := ORIGINAL
var _reinicios_ok := 0
var _trancada := ""
var _avisou_chave := false


func _init() -> void:
	dia = 5
	titulo = "Endurecendo o SSH"
	chamado = ("Deixe o [code]sshd_config[/code] do srv-boletos-01 aderente à linha de base CIS (lista à direita) "
		+ "e aplique com [code]systemctl restart sshd[/code]. Só vale o que estiver [b]rodando[/b]. "
		+ "Quem administra é a Jurema (usuária [code]jurema[/code]). Se o restart trancar todo mundo do lado de fora, "
		+ "alguém vai de carro até Uberaba. Pode ser você.")


func montar() -> void:
	var topo := linha()
	_editor = CodeEdit.new()
	_editor.text = ORIGINAL
	_editor.gutters_draw_line_numbers = true
	_editor.custom_minimum_size = Vector2(500, 300)
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.add_theme_font_size_override("font_size", 13)
	_editor.text_changed.connect(_atualizar_cis)
	topo.add_child(_editor)
	var lado := painel(topo)
	lado.custom_minimum_size = Vector2(380, 0)
	lado.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rotulo("Linha de base CIS (arquivo no editor)", 14, Estilo.CIANO, lado)
	_cis = VBoxContainer.new()
	_cis.add_theme_constant_override("separation", 0)
	lado.add_child(_cis)
	_cis_resumo = rotulo("", 13, Estilo.ALERTA, lado)

	var bts := linha()
	for par in [["sshd -t", "sshd -t"], ["sshd -T", "sshd -T"], ["id jurema", "id jurema"],
			["cat authorized_keys", "cat /home/jurema/.ssh/authorized_keys"],
			["+ chave da Jurema", "chave"], ["restart sshd", "systemctl restart sshd"]]:
		var b := botao(par[0], _rodar.bind(par[1]), bts)
		b.add_theme_font_size_override("font_size", 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lp := linha()
	var pr := rotulo("root@srv-boletos-01:~#", 13, Estilo.OK, lp)
	pr.autowrap_mode = TextServer.AUTOWRAP_OFF
	pr.add_theme_font_override("font", Estilo.mono())
	_prompt = campo("digite um comando (help) e Enter", lp)
	_prompt.text_submitted.connect(_enviar_prompt)
	_saida = bloco_mono("Conectado em srv-boletos-01 (203.0.113.25) como root. Sim, root. Com senha. Pela internet.\n", 140)
	_saida.add_theme_font_size_override("font_size", 12)
	_saida.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_atualizar_cis()

	chat("Jurema", "Regra de ouro: mexeu no sshd_config, roda sshd -t ANTES do restart. E não fecha essa sessão até testar uma nova.")
	chat("Valdecir", "Muda a porta pra 2222 que nenhum hacker acha. Eu li isso em 2011.")
	aviso("Dica: no sshd_config vale a PRIMEIRA ocorrência de cada opção. Adicionar no fim não sobrescreve o que está em cima.")


# ---------------------------------------------------------------- parser

## Divide uma linha no estilo do sshd: palavra-chave, espaço ou "=", argumentos.
static func _dividir(l: String) -> Array:
	var s := l.strip_edges()
	var re := RegEx.create_from_string("^([^\\s=]+)\\s*(=|\\s)\\s*(.*)$")
	var m := re.search(s)
	if m == null:
		return [s, []]
	var args: Array = []
	for a in m.get_string(3).split(" ", false):
		for b in a.split("\t", false):
			args.append(b)
	return [m.get_string(1), args]


static func _segundos(v: String) -> int:
	if v.is_valid_int():
		return int(v)
	var re := RegEx.create_from_string("(\\d+)([sSmMhHdDwW])")
	var total := 0
	var consumido := 0
	for m in re.search_all(v):
		var n := int(m.get_string(1))
		total += n * UNIDADES[m.get_string(2).to_lower()]
		consumido += m.get_string().length()
	return total if consumido == v.length() and consumido > 0 else -1


## Simula o sshd -t. Devolve {"saida": [linhas], "ok": bool, "efetivo": {chave: valor}, "listas": {...}}.
func analisar(texto: String) -> Dictionary:
	var saida: Array[String] = []
	var ruins := 0
	var fatal := false
	var efetivo := {}
	var listas := {"allowusers": [], "allowgroups": [], "denyusers": [], "denygroups": [], "port": [], "listenaddress": []}
	var em_match := false
	var linhas := texto.split("\n")
	for i in linhas.size():
		var n := i + 1
		var l := linhas[i].strip_edges()
		if l == "" or l.begins_with("#"):
			continue
		var partes := _dividir(l)
		var kw: String = partes[0]
		var args: Array = partes[1]
		var k := kw.to_lower()
		var erro := ""
		var unico := true
		if k in DEPRECADAS:
			saida.append("%s line %d: Deprecated option %s" % [ARQ, n, kw])
			continue
		if k in FLAGS:
			if args.is_empty(): erro = "%s line %d: %s missing argument." % [ARQ, n, kw]
			elif not (args[0].to_lower() in ["yes", "no"]): erro = "%s line %d: unsupported option \"%s\"." % [ARQ, n, args[0]]
		elif MULTI.has(k):
			if args.is_empty(): erro = "%s line %d: %s missing argument." % [ARQ, n, kw]
			elif not (args[0].to_lower() in MULTI[k]): erro = "%s line %d: unsupported option \"%s\"." % [ARQ, n, args[0]]
		elif k in INTEIROS:
			if args.is_empty(): erro = "%s line %d: %s missing argument." % [ARQ, n, kw]
			elif not args[0].is_valid_int() or int(args[0]) < 0: erro = "%s line %d: invalid integer value \"%s\"." % [ARQ, n, args[0]]
		elif k in TEMPOS:
			if args.is_empty(): erro = "%s line %d: %s missing argument." % [ARQ, n, kw]
			elif _segundos(args[0]) < 0: erro = "%s line %d: invalid time value." % [ARQ, n]
		elif k == "port":
			if args.is_empty() or not args[0].is_valid_int() or int(args[0]) < 1 or int(args[0]) > 65535:
				erro = "%s line %d: Badly formatted port number." % [ARQ, n]
			unico = false
		elif k == "loglevel":
			if args.is_empty(): erro = "%s line %d: %s missing argument." % [ARQ, n, kw]
			elif not (args[0].to_upper() in NIVEIS): erro = "%s line %d: unsupported log level '%s'" % [ARQ, n, args[0]]
		elif k == "syslogfacility":
			if args.is_empty(): erro = "%s line %d: %s missing argument." % [ARQ, n, kw]
			elif not (args[0].to_upper() in FACILIDADES): erro = "%s line %d: unsupported log facility '%s'" % [ARQ, n, args[0]]
		elif k == "maxstartups":
			if args.is_empty() or RegEx.create_from_string("^\\d+(:\\d+:\\d+)?$").search(args[0]) == null:
				erro = "%s line %d: Illegal MaxStartups spec." % [ARQ, n]
		elif LISTAS.has(k):
			if args.is_empty():
				erro = "%s line %d: %s missing argument." % [ARQ, n, kw]
			else:
				var lista: String = args[0]
				var curinga_ok := lista.begins_with("-")
				if lista.length() > 0 and lista[0] in ["+", "-", "^"]:
					lista = lista.substr(1)
				for alg in lista.split(","):
					var valido: bool = alg in LISTAS[k][1] or (curinga_ok and (alg.contains("*") or alg.contains("?")))
					if not valido:
						erro = "%s line %d: Bad SSH2 %s spec '%s'." % [ARQ, n, LISTAS[k][0], args[0]]
						break
		elif k in LIVRES:
			if args.is_empty():
				erro = "%s line %d: %s missing argument." % [ARQ, n, kw]
			unico = false
		else:
			saida.append("%s line %d: Bad configuration option: %s" % [ARQ, n, kw])
			ruins += 1
			continue
		if erro != "":
			saida.append(erro)
			fatal = true
			break
		if unico and args.size() > 1:
			saida.append("%s line %d: keyword %s extra arguments at end of line" % [ARQ, n, kw])
			fatal = true
			break
		if k == "match":
			em_match = true
			continue
		if em_match:
			continue
		if listas.has(k):
			for a in args:
				listas[k].append(a)
		if not efetivo.has(k):
			efetivo[k] = " ".join(args)
	if not fatal and ruins > 0:
		saida.append("%s: terminating, %d bad configuration options" % [ARQ, ruins])
	return {"saida": saida, "ok": not fatal and ruins == 0, "efetivo": efetivo, "listas": listas}


static func _valor(ef: Dictionary, k: String, padrao: String) -> String:
	return str(ef.get(k, padrao)).to_lower()


## Itens da linha de base (CIS Benchmark para Ubuntu, seção 5.2, mais a política de só-chave da Tabajara).
func cis(texto: String) -> Array:
	var a := analisar(texto)
	var ef: Dictionary = a["efetivo"]
	var l: Dictionary = a["listas"]
	var grace := _segundos(_valor(ef, "logingracetime", "120"))
	var maxauth := int(_valor(ef, "maxauthtries", "6"))
	var alive := _segundos(_valor(ef, "clientaliveinterval", "0"))
	var countmax := int(_valor(ef, "clientalivecountmax", "3"))
	var ms := _valor(ef, "maxstartups", "10:30:100").split(":")
	var ms_ok := int(ms[0]) <= 10 if ms.size() != 3 else (int(ms[0]) <= 10 and int(ms[1]) >= 30 and int(ms[2]) <= 60)
	var cif := _valor(ef, "ciphers", "chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com")
	var cif_ok := cif.begins_with("-") or not cif.contains("cbc")
	return [
		["LogLevel INFO ou VERBOSE", _valor(ef, "loglevel", "info") in ["info", "verbose"]],
		["LoginGraceTime entre 1 e 60 s", grace >= 1 and grace <= 60],
		["PermitRootLogin no", _valor(ef, "permitrootlogin", "prohibit-password") == "no"],
		["MaxAuthTries 4 ou menos", maxauth >= 1 and maxauth <= 4],
		["HostbasedAuthentication no", _valor(ef, "hostbasedauthentication", "no") == "no"],
		["IgnoreRhosts yes", _valor(ef, "ignorerhosts", "yes") == "yes"],
		["Senha desligada (só chave)", _valor(ef, "passwordauthentication", "yes") == "no" and not (_valor(ef, "kbdinteractiveauthentication", "yes") == "yes" and _valor(ef, "usepam", "no") == "yes")],
		["PermitEmptyPasswords no", _valor(ef, "permitemptypasswords", "no") == "no"],
		["X11Forwarding no", _valor(ef, "x11forwarding", "no") == "no"],
		["AllowTcpForwarding no", _valor(ef, "allowtcpforwarding", "yes") == "no"],
		["PermitUserEnvironment no", _valor(ef, "permituserenvironment", "no") == "no"],
		["ClientAliveInterval 1-300 e CountMax 1-3", alive >= 1 and alive <= 300 and countmax >= 1 and countmax <= 3],
		["MaxStartups 10:30:60 ou mais restrito", ms_ok],
		["Ciphers sem modo CBC", cif_ok],
		["AllowGroups ou AllowUsers definido", not l["allowgroups"].is_empty() or not l["allowusers"].is_empty()],
		["Banner de aviso legal configurado", _valor(ef, "banner", "none") != "none"],
	]


static func _casa(nome: String, padroes: Array) -> bool:
	for p in padroes:
		var pp: String = str(p).get_slice("@", 0)
		if nome.match(pp):
			return true
	return false


## Por que a Jurema não conseguiria entrar com essa configuração. "" se entra.
func motivo_tranca(texto: String) -> String:
	var a := analisar(texto)
	if not a["ok"]:
		return "O sshd -t falhou no ExecStartPre e o serviço não subiu. Sem sshd, sem login."
	var ef: Dictionary = a["efetivo"]
	var l: Dictionary = a["listas"]
	var portas: Array = l["port"] if not l["port"].is_empty() else ["22"]
	if not ("22" in portas):
		return "O sshd agora escuta na porta %s, e o firewall do datacenter só libera a 22." % ", ".join(portas)
	if not l["listenaddress"].is_empty():
		var ouvindo := false
		for end in l["listenaddress"]:
			if str(end).get_slice(":", 0) in ["0.0.0.0", "203.0.113.25", "*"] or str(end).begins_with("::") or str(end).begins_with("[::]"):
				ouvindo = true
		if not ouvindo:
			return "ListenAddress não inclui o endereço público: o sshd só escuta para dentro."
	if _casa("jurema", l["denyusers"]):
		return "DenyUsers bloqueia a jurema."
	if not l["allowusers"].is_empty() and not _casa("jurema", l["allowusers"]):
		return "AllowUsers não inclui a jurema."
	for g in GRUPOS_JUREMA:
		if _casa(g, l["denygroups"]):
			return "DenyGroups bloqueia um grupo da jurema (%s)." % g
	if not l["allowgroups"].is_empty():
		var algum := false
		for g in GRUPOS_JUREMA:
			algum = algum or _casa(g, l["allowgroups"])
		if not algum:
			return "AllowGroups (%s) não inclui nenhum grupo da jurema (jurema, sudo, admssh)." % " ".join(l["allowgroups"])
	var por_chave := _valor(ef, "pubkeyauthentication", "yes") == "yes" and not _chaves.is_empty() and _valor(ef, "authorizedkeysfile", ".ssh/authorized_keys").contains("authorized_keys")
	var senha := _valor(ef, "passwordauthentication", "yes") == "yes"
	var teclado := _valor(ef, "kbdinteractiveauthentication", "yes") == "yes" and _valor(ef, "usepam", "no") == "yes"
	if not por_chave and not senha and not teclado:
		if _chaves.is_empty():
			return "Senha desligada e nenhuma chave pública no authorized_keys da jurema. Não sobrou método de login."
		return "Nenhum método de autenticação sobrou para a jurema."
	return ""


# ---------------------------------------------------------------- terminal

func _escrever(t: String) -> void:
	_saida.text += t + "\n"
	_saida.scroll_vertical = _saida.get_line_count()


func _rodar(cmd: String) -> void:
	if _trancada != "":
		_escrever("Write failed: Broken pipe")
		return
	cmd = cmd.strip_edges()
	if cmd == "":
		return
	if cmd == "chave":
		_escrever("# a Jurema mandou a chave pública dela no chat; colando no authorized_keys")
		cmd = "echo \"%s\" >> /home/jurema/.ssh/authorized_keys" % CHAVE_JUREMA
	_escrever("root@srv-boletos-01:~# " + cmd)
	var c := cmd.replace("~jurema", "/home/jurema").replace("/usr/sbin/", "")
	if c.begins_with("echo ") and c.contains(">> /home/jurema/.ssh/authorized_keys"):
		var re := RegEx.create_from_string("echo\\s+\"?([^\">]+?)\"?\\s*>>")
		var m := re.search(c)
		var chave := m.get_string(1).strip_edges() if m else ""
		if RegEx.create_from_string("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256) [A-Za-z0-9+/=]{40,}( .*)?$").search(chave) == null:
			_escrever("(isso não parece uma chave pública OpenSSH)")
			return
		if chave in _chaves:
			_escrever("(chave já estava lá)")
			return
		_chaves.append(chave)
		if chave == CHAVE_JUREMA:
			chat("Jurema", "Essa é a minha, do notebook. A privada fica comigo, com senha. Aprendeu algo hoje.")
		return
	match c:
		"help":
			_escrever("Comandos: sshd -t | sshd -T | id jurema | cat /home/jurema/.ssh/authorized_keys | systemctl restart sshd | systemctl status sshd")
		"sshd -t":
			var a := analisar(_editor.text)
			for l in a["saida"]:
				_escrever(l)
			_escrever("[saída %d]" % (0 if a["ok"] else 255))
		"sshd -T":
			var a := analisar(_editor.text)
			if not a["ok"]:
				for l in a["saida"]:
					_escrever(l)
				return
			var ef: Dictionary = a["efetivo"]
			for k in ["port", "permitrootlogin", "passwordauthentication", "pubkeyauthentication", "permitemptypasswords",
					"maxauthtries", "logingracetime", "x11forwarding", "allowtcpforwarding", "allowgroups", "allowusers", "loglevel"]:
				if ef.has(k):
					var v: String = ef[k]
					if k in TEMPOS:
						v = str(_segundos(v))
					_escrever("%s %s" % [k, v.to_lower() if k != "loglevel" else v.to_upper()])
		"id jurema":
			_escrever("uid=1001(jurema) gid=1001(jurema) groups=1001(jurema),27(sudo),1500(admssh)")
		"cat /home/jurema/.ssh/authorized_keys":
			_escrever("# chaves autorizadas da jurema")
			for k in _chaves:
				_escrever(k)
			if _chaves.is_empty() and not _avisou_chave:
				_avisou_chave = true
				chat("Jurema", "Vazio. Eu entro com senha nesse servidor desde 2014. Se você desligar a senha sem cadastrar minha chave, nem eu entro.")
		"systemctl status sshd", "systemctl status ssh":
			_escrever("* ssh.service - OpenBSD Secure Shell server\n     Active: active (running)  Main PID: 812 (sshd)")
		"systemctl restart sshd", "systemctl restart ssh", "service ssh restart", "service sshd restart":
			_reiniciar()
		_:
			if c.begins_with("vi ") or c.begins_with("nano ") or c.begins_with("vim "):
				_escrever("(o arquivo já está aberto no editor ao lado)")
			else:
				_escrever("bash: %s: command not found" % c.get_slice(" ", 0))


func _reiniciar() -> void:
	var motivo := motivo_tranca(_editor.text)
	var a := analisar(_editor.text)
	if not a["ok"]:
		for l in a["saida"]:
			_escrever(l)
		_escrever("Job for ssh.service failed because the control process exited with error code.\nSee \"systemctl status ssh.service\" and \"journalctl -xeu ssh.service\" for details.")
	if motivo != "":
		_trancada = motivo
		_escrever("\nConnection to 203.0.113.25 closed by remote host.\n$ ssh jurema@203.0.113.25\nPermission denied. (ou Connection refused, tanto faz: ninguém entra)")
		_editor.editable = false
		_prompt.editable = false
		chat("Jurema", "Acabei de tentar entrar. Nada. " + motivo)
		chat("Valdecir", "Alguém sabe o telefone do datacenter de Uberaba? O boleto não está gerando.")
		aviso("Servidor inacessível. Clique em Entregar.", Estilo.ERRO)
		return
	_rodando = _editor.text
	_reinicios_ok += 1
	_escrever("[saída 0]")
	var itens := cis(_rodando)
	var ok := 0
	for i in itens:
		if i[1]:
			ok += 1
	_atualizar_cis()
	chat("Jurema", "Abri uma sessão nova e entrei. Ufa. Rodando agora: %d de %d itens CIS." % [ok, itens.size()])


func _atualizar_cis() -> void:
	for f in _cis.get_children():
		f.queue_free()
	var itens := cis(_editor.text)
	for i in itens:
		var r := rotulo(("[OK] " if i[1] else "[  ] ") + i[0], 13, Estilo.OK if i[1] else Estilo.ERRO, _cis)
		r.add_theme_font_override("font", Estilo.mono())
		r.add_theme_font_size_override("font_size", 12)
	var rodando := 0
	for i in cis(_rodando):
		if i[1]:
			rodando += 1
	_cis_resumo.text = "Em execução (último restart): %d de %d" % [rodando, itens.size()]


func avaliar() -> Dictionary:
	var itens := cis(_rodando)
	var ok := 0
	var faltam: Array[String] = []
	for i in itens:
		if i[1]:
			ok += 1
		else:
			faltam.append(i[0])
	var nota := int(round(80.0 * ok / itens.size()))
	if _trancada != "":
		return {"nota": mini(nota, 20), "comentario": "Você trancou o servidor: %s Teste sempre com sshd -t e mantenha a sessão antiga aberta até uma nova entrar." % _trancada,
			"cagada": "Restart do sshd com todo mundo trancado do lado de fora. Você foi de ônibus até Uberaba. 7 horas. Com o Valdecir."}
	if _reinicios_ok > 0:
		nota += 20
	var com := ""
	if _reinicios_ok == 0:
		com = "Nada foi aplicado: arquivo editado não é configuração rodando. Faltou o restart (depois do sshd -t). "
	if faltam.is_empty():
		com += "Servidor no padrão CIS: root sem login, só chave, sem encaminhamentos, tentativas e tempo limitados, acesso restrito ao grupo admssh."
	else:
		com += "Itens CIS rodando: %d de %d. Faltou: %s." % [ok, itens.size(), ", ".join(faltam)]
	return {"nota": nota, "comentario": com.strip_edges(), "cagada": ""}


func solucao_teste() -> void:
	_rodar("chave")
	_editor.text = RESOLVIDO
	_rodar("sshd -t")
	_rodar("systemctl restart sshd")


func _enviar_prompt(t: String) -> void:
	_prompt.text = ""
	_rodar(t)
