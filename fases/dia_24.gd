extends "res://fases/fase.gd"
## Dia 24: linter de Dockerfile de verdade (parse linha a linha) e estimativa de tamanho por camadas.

const DOCKERFILE_KAUA := """FROM node:latest
MAINTAINER Kauã <kaua@tabajara.com.br>
ENV NODE_ENV=production
ENV DB_HOST=db-cotacao.tabajara.local DB_USER=cotacao
ENV DB_PASSWORD=Cotacao@2026
RUN apt-get update && apt-get install -y \\
    openssh-server \\
    curl \\
    vim
ADD https://pki.tabajara.com.br/ca-interna.pem /usr/local/share/ca-certificates/ca-interna.crt
WORKDIR /app
COPY . .
RUN npm install
RUN mkdir /var/run/sshd && echo 'root:tabajara' | chpasswd
EXPOSE 22 3000
CMD service ssh start && node server.js
"""

const DOCKERFILE_BOM := """# syntax=docker/dockerfile:1
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src
COPY server.js ./

FROM gcr.io/distroless/nodejs22-debian12:nonroot
WORKDIR /app
COPY --from=build /app /app
COPY certs/ca-interna.pem /app/certs/ca-interna.pem
ENV NODE_ENV=production NODE_EXTRA_CA_CERTS=/app/certs/ca-interna.pem
USER nonroot
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD ["/nodejs/bin/node", "/app/src/healthcheck.js"]
CMD ["server.js"]
"""

const IGNORE_KAUA := "# depois eu vejo isso (Kauã)\n"
const IGNORE_BOM := ".git\n.env\nnode_modules\nfotos-churrasco-2025\n*.md\nDockerfile\n"

## Imagens base disponíveis no espelho interno (MB, descompactado)
const BASES := {
	"node:latest": 1100, "node:22": 1100, "node:lts": 1100, "node:22-bookworm": 1100,
	"node:22-slim": 240, "node:22-bookworm-slim": 240, "node:lts-slim": 240,
	"node:22-alpine": 155, "node:lts-alpine": 155, "node:20-alpine": 135,
	"gcr.io/distroless/nodejs22-debian12:latest": 130, "gcr.io/distroless/nodejs22-debian12:nonroot": 130,
	"debian:bookworm-slim": 75, "ubuntu:24.04": 78, "alpine:3.20": 8, "scratch": 0,
}
## Contexto de build (o projeto do Kauã), tamanho em MB
const CONTEXTO := {
	".git": 410.0, ".env": 0.001, "node_modules": 160.0, "fotos-churrasco-2025": 300.0, "src": 2.0,
	"server.js": 0.01, "package.json": 0.002, "package-lock.json": 0.4, "certs": 0.004,
	"README.md": 0.01, "Dockerfile": 0.001,
}
const PACOTES := {"openssh-server": 6.0, "curl": 3.0, "vim": 35.0, "git": 40.0, "python3": 30.0,
	"build-essential": 220.0, "ca-certificates": 1.0, "tini": 0.1, "dumb-init": 0.1}
const INSTRUCOES := ["FROM", "RUN", "CMD", "LABEL", "MAINTAINER", "EXPOSE", "ENV", "ADD", "COPY", "ENTRYPOINT",
	"VOLUME", "USER", "WORKDIR", "ARG", "ONBUILD", "STOPSIGNAL", "HEALTHCHECK", "SHELL"]
const PESO := {"crítico": 3.0, "aviso": 1.0, "info": 0.5}
const PERGUNTA := [
	"(escolha)",
	"ARG DB_PASSWORD no build: assim não fica no ENV",
	"ENV no Dockerfile mesmo, mas com senha mais forte",
	"Secret em runtime: Docker/Kubernetes secret montado em /run/secrets ou cofre, lido pela aplicação",
	"Hardcoded no server.js, que é compilado e ninguém lê",
]

var _df: TextEdit
var _ign: TextEdit
var _achados_rt: RichTextLabel
var _tamanho: Label
var _saida: TextEdit
var _pergunta: OptionButton
var _iniciais := {}     # código -> severidade
var _build_ok := false
var _build_rodado := false


func _init() -> void:
	dia = 24
	titulo = "Dockerfile do Kauã"
	chamado = ("Corrija o Dockerfile do sistema de cotação. O linter roda a cada tecla e lista os achados com código e linha. "
		+ "Zere os [b]críticos[/b] e resolva o que puder dos avisos, sem quebrar o build (a imagem ainda precisa rodar [code]server.js[/code]). "
		+ "Use o [code].dockerignore[/code] também. Rode o [b]docker build[/b] e diga como a senha do banco deve chegar ao contêiner. "
		+ "Nota: peso 3 por crítico resolvido, 1 por aviso.")


# ---------------------------------------------------------------- parser

## Junta continuações com \ e ignora comentários. Cada item: {linha, cmd, args}
static func parsear(texto: String) -> Array:
	var saida := []
	var acum := ""
	var inicio := 0
	var linhas := texto.split("\n")
	for i in linhas.size():
		var l := linhas[i].strip_edges(false, true)
		var t := l.strip_edges()
		if acum == "" and (t == "" or t.begins_with("#")):
			continue
		if acum != "" and t.begins_with("#"):
			continue
		if acum == "":
			inicio = i + 1
		if t.ends_with("\\"):
			acum += t.left(t.length() - 1) + " "
			continue
		acum += t
		var p := acum.split(" ", false, 1)
		saida.append({"linha": inicio, "cmd": p[0].to_upper(), "args": p[1].strip_edges() if p.size() > 1 else ""})
		acum = ""
	if acum.strip_edges() != "":
		var p2 := acum.split(" ", false, 1)
		saida.append({"linha": inicio, "cmd": p2[0].to_upper(), "args": p2[1].strip_edges() if p2.size() > 1 else ""})
	return saida


static func normalizar_imagem(ref: String) -> String:
	var r := ref.split("@")[0]
	var barra := r.rfind("/")
	if r.rfind(":") <= barra and r != "scratch":
		r += ":latest"
	return r


static func ignorado(nome: String, padroes: Array) -> bool:
	var fora := false
	for p in padroes:
		var neg: bool = p.begins_with("!")
		var q: String = p.trim_prefix("!").trim_prefix("/").trim_prefix("**/").trim_suffix("/")
		if q == nome or nome.match(q):
			fora = not neg
	return fora


static func padroes_ignore(texto: String) -> Array:
	var r := []
	for l in texto.split("\n"):
		var t := l.strip_edges()
		if t != "" and not t.begins_with("#"):
			r.append(t)
	return r


static func _tokens(args: String) -> PackedStringArray:
	return args.replace("\t", " ").split(" ", false)


## Retorna {achados: [{cod, linha, sev, msg}], estagios, tamanho, detalhe, erro_build}
static func analisar(texto: String, ignore_txt: String) -> Dictionary:
	var instr := parsear(texto)
	var padroes := padroes_ignore(ignore_txt)
	var achados := []
	var estagios := []      # cada: {imagem, alias, linha, camadas: float, usuario, health, cmd}
	var erro := ""
	var aliases := {}
	var re_segredo := RegEx.create_from_string("(?i)(PASS|PWD|SECRET|TOKEN|API_?KEY|ACCESS_?KEY|PRIVATE_?KEY|CREDENTIAL)")
	var add := func(cod: String, linha: int, sev: String, msg: String) -> void:
		achados.append({"cod": cod, "linha": linha, "sev": sev, "msg": msg})

	if instr.is_empty():
		return {"achados": [], "estagios": [], "tamanho": 0.0, "detalhe": "", "erro_build": "Dockerfile vazio."}
	for it in instr:
		var cmd: String = it["cmd"]
		var args: String = it["args"]
		var ln: int = it["linha"]
		if not cmd in INSTRUCOES:
			erro = "linha %d: instrução desconhecida \"%s\"" % [ln, cmd]
			continue
		if cmd == "FROM":
			var tk := _tokens(args)
			var ref := ""
			var alias := ""
			for k in tk.size():
				if tk[k].begins_with("--"):
					continue
				if ref == "":
					ref = tk[k]
				elif tk[k].to_upper() == "AS" and k + 1 < tk.size():
					alias = tk[k + 1]
			var base_mb := 0.0
			var pai := -1
			if aliases.has(ref):
				pai = aliases[ref]
				base_mb = estagios[pai]["base"] + estagios[pai]["camadas"]
			else:
				var norm := normalizar_imagem(ref)
				var sem_tag := ref.split("@")[0].rfind(":") <= ref.rfind("/")
				if ref != "scratch" and sem_tag and not ref.contains("@"):
					add.call("DL3006", ln, "crítico", "Imagem \"%s\" sem tag: vira latest e muda sem aviso. Fixe versão (ou digest)." % ref)
				elif norm.ends_with(":latest"):
					add.call("DL3007", ln, "crítico", "Tag latest: build não reprodutível e imagem cheia. Use versão fixa, de preferência slim/alpine/distroless.")
				if not BASES.has(norm):
					erro = "linha %d: imagem %s não existe no espelho interno" % [ln, ref]
				base_mb = BASES.get(norm, 0.0)
			estagios.append({"imagem": ref, "alias": alias, "linha": ln, "base": float(base_mb), "camadas": 0.0,
				"usuario": "", "health": false, "cmd": "", "cmd_linha": ln, "copia_app": false, "deps": false, "detalhe": []})
			if alias != "":
				aliases[alias] = estagios.size() - 1
			continue
		if estagios.is_empty():
			if cmd != "ARG":
				erro = "linha %d: o Dockerfile precisa começar com FROM" % ln
			else:
				for m in re_segredo.search_all(args.split("=")[0]):
					add.call("TJ001", ln, "crítico", "Segredo em ARG: fica no histórico da imagem (docker history). Use secret em runtime ou RUN --mount=type=secret.")
					break
			continue
		var e: Dictionary = estagios[estagios.size() - 1]
		match cmd:
			"MAINTAINER":
				add.call("DL4000", ln, "info", "MAINTAINER está obsoleto. Use LABEL org.opencontainers.image.authors.")
			"ENV", "ARG":
				var chaves := []
				var tk := _tokens(args)
				if tk.size() > 0 and tk[0].contains("="):
					for t in tk:
						chaves.append(t.split("=")[0])
				elif tk.size() > 0:
					chaves.append(tk[0])
				for c in chaves:
					if re_segredo.search(c):
						add.call("TJ001", ln, "crítico", "%s %s: segredo em %s vai para a imagem e aparece no docker inspect/history. Use secret em runtime." % [cmd, c, cmd])
			"RUN":
				var r := args
				var apt := RegEx.create_from_string("apt-get\\s+(?:-\\S+\\s+)*install\\s+(.*?)(?:&&|;|\\||$)").search(r)
				if apt:
					var pk := []
					for t in _tokens(apt.get_string(1)):
						if not t.begins_with("-"):
							pk.append(t)
					var soma := 0.0
					var sem_pin := false
					for p in pk:
						var nome: String = p.split("=")[0]
						soma += PACOTES.get(nome, 10.0)
						if not p.contains("="):
							sem_pin = true
						if nome == "openssh-server":
							add.call("TJ006", ln, "crítico", "sshd dentro do contêiner: contêiner não é VM. Para depurar, docker exec / kubectl exec.")
						if nome in ["vim", "curl", "git"]:
							add.call("TJ011", ln, "info", "%s na imagem final: ferramenta a mais é superfície de ataque a mais." % nome)
					if not r.contains("--no-install-recommends"):
						soma *= 1.6
						add.call("DL3015", ln, "aviso", "apt-get install sem --no-install-recommends: vem pacote que ninguém pediu.")
					if sem_pin:
						add.call("DL3008", ln, "aviso", "Pacotes apt sem versão fixada (pacote=versão).")
					if not r.contains("rm -rf /var/lib/apt/lists"):
						soma += 45.0
						add.call("DL3009", ln, "aviso", "Listas do apt ficam na camada: termine com rm -rf /var/lib/apt/lists/* no mesmo RUN.")
					e["camadas"] += soma
					e["detalhe"].append("apt %.0f MB" % soma)
				var apk := RegEx.create_from_string("apk\\s+add\\s+(.*?)(?:&&|;|\\||$)").search(r)
				if apk:
					var soma2 := 0.0
					for t in _tokens(apk.get_string(1)):
						if not t.begins_with("-"):
							soma2 += PACOTES.get(t.split("=")[0], 10.0) * 0.5
							if t.begins_with("openssh"):
								add.call("TJ006", ln, "crítico", "sshd dentro do contêiner: contêiner não é VM.")
					if not r.contains("--no-cache"):
						soma2 += 3.0
						add.call("DL3019", ln, "aviso", "apk add sem --no-cache deixa o índice na camada.")
					e["camadas"] += soma2
				if r.contains("chpasswd") or RegEx.create_from_string("echo\\s+['\"]?\\w+:[^\\s'\"]+['\"]?\\s*\\|").search(r):
					add.call("TJ002", ln, "crítico", "Senha fixa definida no RUN (chpasswd): fica na camada para sempre.")
				var npm := RegEx.create_from_string("npm\\s+(ci|install|i)\\b").search(r)
				if npm:
					e["deps"] = true
					var enxuto := r.contains("--omit=dev") or r.contains("--production") or r.contains("--only=prod") or r.contains("npm prune")
					var mb := 95.0 if enxuto else (230.0 if npm.get_string(1) == "ci" else 240.0)
					if npm.get_string(1) != "ci":
						add.call("TJ009", ln, "aviso", "npm install no build: use npm ci (respeita o package-lock, reprodutível).")
					e["camadas"] += mb
					e["detalhe"].append("npm %.0f MB" % mb)
				if r.contains("npm run build"):
					e["camadas"] += 5.0
			"ADD":
				var tk := _tokens(args)
				var url := false
				for t in tk:
					if t.begins_with("http://") or t.begins_with("https://"):
						url = true
				if url and not args.contains("--checksum="):
					add.call("TJ003", ln, "crítico", "ADD de URL remota sem --checksum: baixa o que estiver lá no dia, sem verificar integridade.")
				elif not url and not args.contains(".tar"):
					add.call("DL3020", ln, "aviso", "Use COPY para arquivos locais; ADD tem mágicas (URL, descompactar) que surpreendem.")
			"COPY":
				var tk := _tokens(args)
				var de_estagio := ""
				var fontes := []
				for t in tk:
					if t.begins_with("--from="):
						de_estagio = t.substr(7)
					elif not t.begins_with("--"):
						fontes.append(t)
				if fontes.size() >= 2:
					fontes.pop_back()
				if de_estagio != "":
					if aliases.has(de_estagio):
						var src: Dictionary = estagios[aliases[de_estagio]]
						e["camadas"] += src["camadas"]
						e["detalhe"].append("COPY --from %.0f MB" % src["camadas"])
						if src["copia_app"]:
							e["copia_app"] = true
						if src["deps"]:
							e["deps"] = true
					else:
						erro = "linha %d: estágio \"%s\" não existe" % [ln, de_estagio]
					continue
				var inclusos := []
				for f in fontes:
					var nome: String = f.trim_prefix("./").trim_suffix("/")
					if nome == "." or nome == "" or nome == "*":
						for k in CONTEXTO:
							if not ignorado(k, padroes):
								inclusos.append(k)
					elif CONTEXTO.has(nome):
						if ignorado(nome, padroes):
							erro = "linha %d: COPY %s falhou: arquivo excluído pelo .dockerignore" % [ln, nome]
						else:
							inclusos.append(nome)
					else:
						var achou := false
						for k in CONTEXTO:
							if k.match(nome) or nome.begins_with(k + "/"):
								achou = true
								if not ignorado(k, padroes):
									inclusos.append(k)
						if not achou:
							erro = "linha %d: COPY falhou: \"%s\" não existe no contexto" % [ln, f]
				var mb := 0.0
				for k in inclusos:
					mb += CONTEXTO[k]
				e["camadas"] += mb
				e["detalhe"].append("COPY %.0f MB" % mb)
				if "server.js" in inclusos:
					e["copia_app"] = true
				if ".env" in inclusos:
					add.call("TJ004", ln, "crítico", "O .env (com a senha do banco) entra na imagem. Coloque .env no .dockerignore e copie só o necessário.")
				if ".git" in inclusos:
					add.call("TJ005", ln, "aviso", "O .git inteiro (410 MB, com o histórico de segredos) entra na imagem.")
				if "node_modules" in inclusos:
					add.call("TJ012", ln, "aviso", "node_modules do host entra na imagem (binários do notebook do Kauã).")
				if "fotos-churrasco-2025" in inclusos:
					add.call("TJ013", ln, "info", "300 MB de fotos do churrasco na imagem de produção.")
			"USER":
				e["usuario"] = args.split(":")[0].strip_edges()
				e["usuario_linha"] = ln
			"EXPOSE":
				for t in _tokens(args):
					if t.split("/")[0] == "22":
						add.call("TJ006", ln, "crítico", "EXPOSE 22: porta de SSH aberta no contêiner.")
			"HEALTHCHECK":
				e["health"] = true
			"CMD", "ENTRYPOINT":
				e["cmd"] = args
				e["cmd_linha"] = ln
				if not args.begins_with("["):
					add.call("DL3025", ln, "aviso", "%s em forma shell: use a forma JSON para o processo receber SIGTERM." % cmd)

	var tamanho := 0.0
	var detalhe := ""
	if not estagios.is_empty():
		var f: Dictionary = estagios[estagios.size() - 1]
		var u: String = f["usuario"]
		if u == "" or u == "root" or u == "0":
			add.call("DL3002", f.get("usuario_linha", f["linha"]), "crítico", "Último estágio roda como root. Crie/use um usuário sem privilégio (USER node, USER nonroot).")
		if not f["health"]:
			add.call("TJ008", f["linha"], "aviso", "Sem HEALTHCHECK: o orquestrador não sabe se a aplicação travou.")
		if estagios.size() < 2:
			add.call("TJ010", f["linha"], "info", "Sem multi-stage: ferramentas de build vão junto para produção.")
		tamanho = f["base"] + f["camadas"]
		detalhe = "base %s %s + camadas %s" % [f["imagem"], formatar_mb(f["base"]), formatar_mb(f["camadas"])]
		if erro == "":
			if f["cmd"] == "" or not f["cmd"].contains("server.js"):
				erro = "a imagem final não executa server.js (CMD/ENTRYPOINT)"
			elif not f["copia_app"]:
				erro = "server.js não foi copiado para a imagem final"
			elif not f["deps"]:
				erro = "dependências npm não instaladas (npm ci) na imagem final"
	return {"achados": achados, "estagios": estagios, "tamanho": tamanho, "detalhe": detalhe, "erro_build": erro}


static func formatar_mb(mb: float) -> String:
	if mb >= 1000.0:
		return ("%.2f GB" % (mb / 1000.0)).replace(".", ",")
	return "%.0f MB" % mb


# ---------------------------------------------------------------- interface

func montar() -> void:
	var h := linha()
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(esq)
	rotulo("Dockerfile", 13, Estilo.DESTAQUE, esq)
	_df = editor(DOCKERFILE_KAUA, 360, esq)
	_df.add_theme_font_size_override("font_size", 13)
	var dir := VBoxContainer.new()
	dir.custom_minimum_size = Vector2(250, 0)
	h.add_child(dir)
	rotulo(".dockerignore", 13, Estilo.DESTAQUE, dir)
	_ign = editor(IGNORE_KAUA, 105, dir)
	_ign.add_theme_font_size_override("font_size", 13)
	rotulo("Contexto de build (projeto)", 13, Estilo.TEXTO_FRACO, dir)
	var arv := ""
	for k in CONTEXTO:
		arv += "%-21s %s\n" % [k + ("/" if k in [".git", "node_modules", "fotos-churrasco-2025", "src", "certs"] else ""), formatar_mb(CONTEXTO[k]) if CONTEXTO[k] >= 1.0 else "<1 MB"]
	var bm := bloco_mono(arv.strip_edges(), 222, dir)
	bm.add_theme_font_size_override("font_size", 11)

	var pa := painel(null, Color("1b1626"))
	_tamanho = rotulo("", 14, Estilo.CIANO, pa)
	_achados_rt = texto_rico("", pa)
	rotulo("Bases no espelho interno: node:latest / node:22 1,1 GB · node:22-slim 240 MB · node:22-alpine 155 MB · gcr.io/distroless/nodejs22-debian12:nonroot 130 MB", 12, Estilo.TEXTO_FRACO, pa)

	var hb := linha()
	botao("docker build -t tabajara/cotacao:dev .", _build, hb)
	_saida = bloco_mono("", 190)
	_saida.add_theme_font_size_override("font_size", 12)
	rotulo("Como o DB_PASSWORD deve chegar ao contêiner?", 15, Estilo.cor_de("Jurema"))
	_pergunta = opcoes(PERGUNTA)
	_pergunta.clip_text = true
	_pergunta.fit_to_longest_item = false
	_pergunta.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_iniciais = {}
	for a in analisar(DOCKERFILE_KAUA, IGNORE_KAUA)["achados"]:
		if PESO[a["sev"]] > PESO.get(_iniciais.get(a["cod"], "info"), 0.0) or not _iniciais.has(a["cod"]):
			_iniciais[a["cod"]] = a["sev"]
	_df.text_changed.connect(_atualizar)
	_ign.text_changed.connect(_atualizar)
	_atualizar()
	chat("Kauã", "Sobe em 3 segundos! Tá, o pull leva 14 minutos, mas depois sobe em 3 segundos.")
	chat("Jurema", "Tem SSH com senha root:tabajara dentro de um contêiner. Kauã, contêiner não é VM. É um processo com crise de identidade.")
	chat("Jurema", "{Estagiária|Estagiário|Estagiárie}: zera os críticos. E a senha do banco sai do ENV. Nem ARG, que também fica no histórico.")


func _atualizar() -> void:
	var r := analisar(_df.text, _ign.text)
	var crit := 0
	var linhas := PackedStringArray()
	var ordenados: Array = r["achados"].duplicate()
	ordenados.sort_custom(func(a, b): return a["linha"] < b["linha"])
	for a in ordenados:
		var cor := "#ff5d5d" if a["sev"] == "crítico" else ("#ffc94d" if a["sev"] == "aviso" else "#8b95a8")
		if a["sev"] == "crítico":
			crit += 1
		linhas.append("[color=%s][code]L%-3d %-6s[/code] %s[/color]  %s" % [cor, a["linha"], a["cod"], a["sev"].to_upper(), a["msg"]])
	if linhas.is_empty():
		linhas.append("[color=#5ee38a]Nenhum achado. O hadolint ficaria orgulhoso.[/color]")
	_achados_rt.text = "\n".join(linhas)
	var txt := "Achados: %d (%d críticos)   ·   Tamanho estimado: %s (%s)" % [r["achados"].size(), crit, formatar_mb(r["tamanho"]), r["detalhe"]]
	if r["erro_build"] != "":
		txt += "   ·   build vai falhar"
	_tamanho.text = txt
	_build_ok = false
	_build_rodado = false


func _build() -> void:
	var r := analisar(_df.text, _ign.text)
	var instr := parsear(_df.text)
	var out := PackedStringArray()
	out.append("[+] Building (%d instruções)" % instr.size())
	var ctx := 0.0
	var pad := padroes_ignore(_ign.text)
	for k in CONTEXTO:
		if not ignorado(k, pad):
			ctx += CONTEXTO[k]
	out.append("#1 [internal] load .dockerignore")
	out.append("#2 [internal] load build context")
	out.append("#2 transferring context: %s %s" % [formatar_mb(ctx), "(o Wi-Fi da Tabajara chora)" if ctx > 100 else "done"])
	var n := 3
	var estagio := 0
	var total_est := 0
	for it in instr:
		if it["cmd"] == "FROM":
			total_est += 1
	for it in instr:
		if it["cmd"] == "FROM":
			estagio += 1
		out.append("#%d [%d/%d] %s %s" % [n, estagio, total_est, it["cmd"], it["args"].left(70)])
		n += 1
	for a in r["achados"]:
		if a["cod"] == "TJ001":
			out.append(" 1 warning found: SecretsUsedInArgOrEnv: Do not use ARG or ENV instructions for sensitive data (linha %d)" % a["linha"])
			break
	if r["erro_build"] != "":
		out.append("ERROR: failed to solve: " + r["erro_build"])
		_build_ok = false
		aviso("Build falhou. Leia o erro no fim da saída.", Estilo.ERRO)
	else:
		out.append("#%d exporting to image" % n)
		out.append("#%d naming to docker.io/tabajara/cotacao:dev done" % n)
		out.append("")
		out.append("REPOSITORY          TAG   SIZE")
		out.append("tabajara/cotacao    dev   %s" % formatar_mb(r["tamanho"]))
		_build_ok = true
		aviso("Build OK: %s." % formatar_mb(r["tamanho"]), Estilo.OK)
		if r["tamanho"] < 400:
			chat("Kauã", "%s?! O pull agora leva menos que o meu café. Que bruxaria é essa?" % formatar_mb(r["tamanho"]))
	_build_rodado = true
	_saida.text = "\n".join(out)
	await get_tree().process_frame
	if is_instance_valid(_saida):
		_saida.scroll_vertical = _saida.get_line_count()


# ---------------------------------------------------------------- avaliação

func avaliar() -> Dictionary:
	var r := analisar(_df.text, _ign.text)
	var atuais := {}
	for a in r["achados"]:
		atuais[a["cod"]] = true
	var total := 0.0
	var resolvido := 0.0
	var crit_rest := []
	for cod in _iniciais:
		var p: float = PESO[_iniciais[cod]]
		total += p
		if not atuais.has(cod):
			resolvido += p
		elif _iniciais[cod] == "crítico":
			crit_rest.append(cod)
	var novos_crit := 0
	for a in r["achados"]:
		if a["sev"] == "crítico" and not _iniciais.has(a["cod"]):
			novos_crit += 1
	var nota := 85.0 * resolvido / total
	var com: Array[String] = []
	com.append("Resolveu %.0f%% do peso dos achados; %s, tamanho final %s." % [100.0 * resolvido / total,
		"nenhum crítico restante" if crit_rest.is_empty() else "críticos restantes: " + ", ".join(crit_rest), formatar_mb(r["tamanho"])])
	if novos_crit > 0:
		nota -= 10 * novos_crit
		com.append("Você criou %d crítico(s) novo(s)." % novos_crit)
	if _pergunta.selected == 3:
		nota += 15
		com.append("Senha do banco como secret em runtime: não fica em camada, ENV, ARG nem docker history.")
	else:
		com.append("A senha vem de secret em runtime (/run/secrets, Kubernetes Secret, cofre). ARG e ENV ficam gravados na imagem.")
	if r["erro_build"] != "":
		nota = minf(nota, 30.0)
		com.append("Mas o build quebra (%s): imagem segura que não sobe não é entrega." % r["erro_build"])
	elif not _build_rodado:
		com.append("Dica: rode o docker build antes de entregar.")
	return {"nota": clampi(int(round(nota)), 0, 100), "comentario": " ".join(com), "cagada": ""}


func solucao_teste() -> void:
	_df.text = DOCKERFILE_BOM
	_ign.text = IGNORE_BOM
	_atualizar()
	_build()
	_pergunta.selected = 3
