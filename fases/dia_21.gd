extends "res://fases/fase.gd"
## Dia 21: chave da AWS no histórico do Git. Investigar com git log -S e remediar na ordem certa.

# Montadas por partes para não parecerem chaves de verdade no repositório.
const CHAVE_ID := "AK" + "IA4TABAJARAKAUA7Q2"
const CHAVE_SECRET := "Kq8vT2/xTabajara" + "NaoCommitaIsso+9fLmZ3pQw"
const HASH_CERTO := "c7d88f2"

## Do mais antigo para o mais novo: hash, autor, data, mensagem, diff
var COMMITS := [
	["a1c03e9", "Kauã Ferreira <kaua@tabajara.com.br>", "Mon Sep 14 09:12:44 2026 -0300", "commit inicial (agora vai)",
"""diff --git a/package.json b/package.json
new file mode 100644
--- /dev/null
+++ b/package.json
@@ -0,0 +1,8 @@
+{
+  "name": "sinistro-foto-api",
+  "version": "0.0.1",
+  "main": "src/index.js",
+  "dependencies": {
+    "@aws-sdk/client-s3": "^3.600.0",
+    "express": "^4.19.2"
+  }
+}
diff --git a/src/index.js b/src/index.js
new file mode 100644
--- /dev/null
+++ b/src/index.js
@@ -0,0 +1,4 @@
+const express = require('express');
+const app = express();
+app.get('/ping', (req, res) => res.send('pong'));
+app.listen(3000); // TODO: tudo"""],
	["5d2f7b1", "Jurema Antunes <jurema@tabajara.com.br>", "Mon Sep 14 10:03:10 2026 -0300", "adiciona .gitignore porque alguém tinha que fazer",
"""diff --git a/.gitignore b/.gitignore
new file mode 100644
--- /dev/null
+++ b/.gitignore
@@ -0,0 +1,3 @@
+node_modules/
+.env
+*.pem"""],
	["3aa6b19", "Thiago Lins (ex-estagiário) <thiago.lins@tabajara.com.br>", "Tue Sep 15 16:40:02 2026 -0300", "docs: exemplo de configuração da AWS",
"""diff --git a/docs/aws.md b/docs/aws.md
new file mode 100644
--- /dev/null
+++ b/docs/aws.md
@@ -0,0 +1,7 @@
+# Configurar acesso ao S3
+
+Use variáveis de ambiente. NUNCA coloque a chave no código. Exemplo da documentação da AWS:
+
+    export AWS_ACCESS_KEY_ID=@@EX1@@
+    export AWS_SECRET_ACCESS_KEY=@@EX2@@
+    export AWS_REGION=sa-east-1"""],
	["9e41c0a", "Kauã Ferreira <kaua@tabajara.com.br>", "Wed Sep 16 11:22:51 2026 -0300", "fix",
"""diff --git a/src/index.js b/src/index.js
--- a/src/index.js
+++ b/src/index.js
@@ -1,4 +1,4 @@
 const express = require('express');
 const app = express();
-app.get('/ping', (req, res) => res.send('pong'));
+app.get('/ping', (req, res) => res.send('pong!!'));
 app.listen(3000); // TODO: tudo"""],
	[HASH_CERTO, "Kauã Ferreira <kaua@tabajara.com.br>", "Thu Sep 17 23:47:18 2026 -0300", "integração com S3 pra subir foto do sinistro",
"""diff --git a/src/config/aws.js b/src/config/aws.js
new file mode 100644
--- /dev/null
+++ b/src/config/aws.js
@@ -0,0 +1,10 @@
+const { S3Client } = require('@aws-sdk/client-s3');
+
+// depois eu tiro daqui (Kauã)
+module.exports = new S3Client({
+  region: 'sa-east-1',
+  credentials: {
+    accessKeyId: '@@ID@@',
+    secretAccessKey: '@@SECRET@@',
+  },
+});"""],
	["0b5e6a4", "Valdecir Moura <valdecir@tabajara.com.br>", "Fri Sep 18 08:01:00 2026 -0300", "atualiza README conforme POL-SEG-0001 (rev. 2009)",
"""diff --git a/README.md b/README.md
new file mode 100644
--- /dev/null
+++ b/README.md
@@ -0,0 +1,3 @@
+# Sinistro por Foto
+Sistema protegido por firewall (antivírus de rede).
+Proibido o uso de pendrive. Proibido rir deste README."""],
	["4f9a1d3", "Kauã Ferreira <kaua@tabajara.com.br>", "Fri Sep 18 17:31:09 2026 -0300", "agora vai",
"""diff --git a/src/index.js b/src/index.js
--- a/src/index.js
+++ b/src/index.js
@@ -1,4 +1,6 @@
 const express = require('express');
+const s3 = require('./config/aws');
 const app = express();
 app.get('/ping', (req, res) => res.send('pong!!'));
+app.post('/sinistro/foto', require('./upload')(s3));
 app.listen(3000); // TODO: tudo"""],
	["e2b7c55", "Kauã Ferreira <kaua@tabajara.com.br>", "Fri Sep 18 17:44:37 2026 -0300", "agora vai mesmo",
"""diff --git a/src/upload.js b/src/upload.js
new file mode 100644
--- /dev/null
+++ b/src/upload.js
@@ -0,0 +1,5 @@
+const { PutObjectCommand } = require('@aws-sdk/client-s3');
+module.exports = (s3) => async (req, res) => {
+  await s3.send(new PutObjectCommand({ Bucket: 'tabajara-sinistros', Key: req.query.nome, Body: req.body }));
+  res.send('ok'); // validação fica pra v2
+};"""],
	["81d3f0e", "Kauã Ferreira <kaua@tabajara.com.br>", "Mon Sep 21 09:15:02 2026 -0300", "remove senha (Kauã)",
"""diff --git a/src/config/aws.js b/src/config/aws.js
--- a/src/config/aws.js
+++ b/src/config/aws.js
@@ -1,10 +1,6 @@
 const { S3Client } = require('@aws-sdk/client-s3');

-// depois eu tiro daqui (Kauã)
+// tirei, a Jurema pode ficar tranquila
 module.exports = new S3Client({
   region: 'sa-east-1',
-  credentials: {
-    accessKeyId: '@@ID@@',
-    secretAccessKey: '@@SECRET@@',
-  },
 });"""],
	["d90c2e8", "Kauã Ferreira <kaua@tabajara.com.br>", "Mon Sep 21 14:20:45 2026 -0300", "testei na minha máquina",
"""diff --git a/src/upload.js b/src/upload.js
--- a/src/upload.js
+++ b/src/upload.js
@@ -2,4 +2,4 @@
 module.exports = (s3) => async (req, res) => {
   await s3.send(new PutObjectCommand({ Bucket: 'tabajara-sinistros', Key: req.query.nome, Body: req.body }));
-  res.send('ok'); // validação fica pra v2
+  res.send('ok'); // validação fica pra v3
 };"""],
	["6b3f4a7", "Kauã Ferreira <kaua@tabajara.com.br>", "Tue Sep 22 10:02:11 2026 -0300", "fix fix",
"""diff --git a/src/index.js b/src/index.js
--- a/src/index.js
+++ b/src/index.js
@@ -3,4 +3,4 @@
 const app = express();
-app.get('/ping', (req, res) => res.send('pong!!'));
+app.get('/ping', (req, res) => res.send('pong'));
 app.post('/sinistro/foto', require('./upload')(s3));"""],
	["f00dba5", "Kauã Ferreira <kaua@tabajara.com.br>", "Fri Oct 09 17:58:12 2026 -0300", "sexta 17h58, deploy (não mexam)",
"""diff --git a/package.json b/package.json
--- a/package.json
+++ b/package.json
@@ -1,5 +1,5 @@
 {
   "name": "sinistro-foto-api",
-  "version": "0.0.1",
+  "version": "1.0.0",
   "main": "src/index.js","""],
]

const PASSOS := [
	"Desativar a chave na AWS (IAM) e emitir outra: rotacionar",
	"Conferir no CloudTrail tudo o que a chave fez desde o vazamento",
	"Reescrever o histórico com git filter-repo e fazer force push",
	"Pedir ao GitHub limpeza de cache e avisar quem tem fork ou clone",
	"Pre-commit com detector de segredos, secret scanning e push protection",
	"Mover a credencial para cofre de segredos (papel IAM, nada de chave fixa)",
	"Apagar o arquivo num commit novo e pronto",
	"Tornar o repositório privado e pronto",
]
const CERTOS := [0, 1, 2, 3, 4, 5]
const DISTRATOR_APAGAR := 6
const DISTRATOR_PRIVADO := 7

var _lista: ItemList
var _mostrados: Array = []   # índices de COMMITS na ordem exibida
var _show: TextEdit
var _busca: LineEdit
var _resultado_busca: Label
var _hash: LineEdit
var _chave: LineEdit
var _ordem: Array = [7, 2, 4, 6, 0, 5, 1, 3]
var _incluido := {}
var _caixa_passos: VBoxContainer


func _init() -> void:
	for c in COMMITS:
		c[4] = str(c[4]).replace("@@ID@@", CHAVE_ID).replace("@@SECRET@@", CHAVE_SECRET).replace("@@EX1@@", "AK" + "IAIOSFODNN7EXAMPLE").replace("@@EX2@@", "wJalrXUtnFEMI/K7MDENG/" + "bPxRfiCYEXAMPLEKEY")
	dia = 21
	titulo = "Chave vazada no Git"
	chamado = ("Investigue o histórico do repositório [b]sinistro-foto-api[/b]. Clique num commit para ver o diff e use a busca "
		+ "(igual a [code]git log -p -S[/code]) no histórico inteiro. Informe o [b]hash do commit que introduziu[/b] a chave real "
		+ "e o [b]Access Key ID[/b]. Depois monte o plano de remediação: marque os passos que entram e ponha na ordem. "
		+ "Nota: identificação + passos certos + ordem.")


func montar() -> void:
	rotulo("$ git log --oneline   (clique para git show)", 14, Estilo.TEXTO_FRACO)
	var h := linha()
	_lista = ItemList.new()
	_lista.custom_minimum_size = Vector2(390, 250)
	_lista.add_theme_font_override("font", Estilo.mono())
	_lista.add_theme_font_size_override("font_size", 13)
	_lista.item_selected.connect(_mostrar_commit)
	h.add_child(_lista)
	_show = bloco_mono("", 250, h)
	_show.add_theme_font_size_override("font_size", 12)

	var hb := linha()
	rotulo("git log -p -S", 14, Estilo.CIANO, hb).autowrap_mode = TextServer.AUTOWRAP_OFF
	_busca = campo("texto a procurar no histórico inteiro (ex.: AKIA)", hb)
	_busca.text_submitted.connect(func(_t): _buscar())
	botao("Buscar", _buscar, hb)
	botao("Limpar", _limpar_busca, hb)
	_resultado_busca = rotulo("", 13, Estilo.TEXTO_FRACO)
	_preencher_lista(range(COMMITS.size()))

	var p := painel(null, Color("1b1626"))
	rotulo("Identificação", 15, Estilo.DESTAQUE, p)
	var hi := linha(p)
	_hash = campo("hash do commit que introduziu a chave", hi)
	_chave = campo("Access Key ID vazado", hi)

	var p2 := painel()
	rotulo("Plano de remediação: marque o que entra e use Subir/Descer. O que vem primeiro é o que você faz primeiro.", 15, Estilo.DESTAQUE, p2)
	_caixa_passos = VBoxContainer.new()
	_caixa_passos.add_theme_constant_override("separation", 4)
	p2.add_child(_caixa_passos)
	_desenhar_passos()

	chat("Jurema", "E-mail da AWS: \"We have detected that your AWS access key is publicly available\". Repositório público. Do Kauã.")
	chat("Kauã", "Mas eu removi! Tá lá o commit \"remove senha (Kauã)\". Até assinei.")
	chat("Jurema", "Git não esquece, querido. Git é a Dona Cida dos sistemas de versão.")


# ---------------------------------------------------------------- histórico

func _preencher_lista(indices: Array) -> void:
	_lista.clear()
	_mostrados = []
	for k in range(indices.size() - 1, -1, -1):   # git log mostra o mais novo primeiro
		var i: int = indices[k]
		_lista.add_item("%s %s" % [COMMITS[i][0], COMMITS[i][3]])
		_mostrados.append(i)


func _mostrar_commit(idx: int) -> void:
	var c: Array = COMMITS[_mostrados[idx]]
	_show.text = "commit %s\nAuthor: %s\nDate:   %s\n\n    %s\n\n%s" % [c[0] + _sufixo(c[0]), c[1], c[2], c[3], c[4]]
	_show.scroll_vertical = 0


## Completa o hash curto até 40 caracteres de forma determinística (só para parecer git show de verdade).
static func _sufixo(curto: String) -> String:
	return curto.sha1_text().substr(0, 33)


## Semântica do pickaxe (-S): commits em que o número de ocorrências do texto muda entre antes e depois.
static func ocorrencias_alteradas(diff: String, texto: String) -> int:
	var mais := 0
	var menos := 0
	for l in diff.split("\n"):
		if l.begins_with("+++") or l.begins_with("---"):
			continue
		if l.begins_with("+"):
			mais += l.count(texto)
		elif l.begins_with("-"):
			menos += l.count(texto)
	return mais - menos


func _buscar() -> void:
	var t := _busca.text
	if t.strip_edges() == "":
		_limpar_busca()
		return
	var achados := []
	var partes := []
	for i in COMMITS.size():
		var delta := ocorrencias_alteradas(COMMITS[i][4], t)
		if delta != 0:
			achados.append(i)
			partes.append("%s (%s%d)" % [COMMITS[i][0], "+" if delta > 0 else "", delta])
	_preencher_lista(achados)
	if achados.is_empty():
		_resultado_busca.text = "Nenhum commit muda a contagem de \"%s\"." % t
	else:
		_resultado_busca.text = "%d commit(s) mudam a contagem de \"%s\": %s" % [achados.size(), t, ", ".join(partes)]
	_show.text = ""


func _limpar_busca() -> void:
	_busca.text = ""
	_resultado_busca.text = ""
	_preencher_lista(range(COMMITS.size()))


# ---------------------------------------------------------------- remediação

func _desenhar_passos() -> void:
	for c in _caixa_passos.get_children():
		c.queue_free()
	for pos in _ordem.size():
		var id: int = _ordem[pos]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		_caixa_passos.add_child(h)
		var n := rotulo("%d." % (pos + 1), 14, Estilo.TEXTO_FRACO, h)
		n.custom_minimum_size = Vector2(24, 0)
		var cb := caixa_marcar(PASSOS[id], h)
		cb.button_pressed = _incluido.get(id, false)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.toggled.connect(func(v): _incluido[id] = v)
		var s := botao("Subir", _mover.bind(pos, -1), h)
		s.disabled = pos == 0
		var d := botao("Descer", _mover.bind(pos, 1), h)
		d.disabled = pos == _ordem.size() - 1


func _mover(pos: int, delta: int) -> void:
	var novo := pos + delta
	if novo < 0 or novo >= _ordem.size():
		return
	var tmp = _ordem[pos]
	_ordem[pos] = _ordem[novo]
	_ordem[novo] = tmp
	_desenhar_passos()


## Distância de Kendall: pares fora de ordem entre os passos certos marcados.
func _inversoes(seq: Array) -> int:
	var inv := 0
	for a in seq.size():
		for b in range(a + 1, seq.size()):
			if seq[a] > seq[b]:
				inv += 1
	return inv


# ---------------------------------------------------------------- avaliação

func avaliar() -> Dictionary:
	var nota := 0.0
	var com: Array[String] = []
	var h := _hash.text.strip_edges().to_lower()
	if h.length() >= 7 and (HASH_CERTO + _sufixo(HASH_CERTO)).begins_with(h):
		nota += 20
		com.append("Commit certo: %s introduziu a chave; o \"remove senha\" só tirou do HEAD." % HASH_CERTO)
	elif h == "81d3f0e":
		com.append("Esse é o commit que removeu, não o que introduziu. Quem colocou foi o %s." % HASH_CERTO)
	elif h == "3aa6b19":
		com.append("O 3aa6b19 tem a chave de EXEMPLO da documentação da AWS (@@EX1@@). A real entrou no %s." % HASH_CERTO)
	else:
		com.append("Commit que introduziu a chave: %s (git log -p -S AKIA mostra quem adicionou e quem removeu)." % HASH_CERTO)
	var k := _chave.text.strip_edges().to_upper()
	if k == CHAVE_ID:
		nota += 20
	elif k == "@@EX1@@":
		com.append("A @@EX1@@ é a chave de exemplo da AWS, não vale nada.")
	else:
		com.append("O Access Key ID é %s (AKIA + 16 caracteres, chave de longo prazo de usuário IAM)." % CHAVE_ID)

	var certos_marcados := []
	var distratores := 0
	for id in _ordem:
		if not _incluido.get(id, false):
			continue
		if id in CERTOS:
			certos_marcados.append(id)
		else:
			distratores += 1
	var cobertura := certos_marcados.size() / 6.0
	var maximo := certos_marcados.size() * (certos_marcados.size() - 1) / 2.0
	var inv := _inversoes(certos_marcados)
	var fator_ordem := 1.0 if maximo == 0 else 1.0 - float(inv) / maximo
	nota += 60.0 * cobertura * fator_ordem
	nota -= 10 * distratores
	com.append("Plano: %d de 6 passos certos, %d par(es) fora de ordem." % [certos_marcados.size(), inv])
	if distratores > 0:
		com.append("Commit novo apagando o arquivo ou repositório privado não resolvem: a chave já foi copiada por robôs em minutos.")
	if inv > 0 or certos_marcados.size() < 6:
		com.append("Ordem certa: revogar e rotacionar primeiro, CloudTrail para ver o estrago, filter-repo + force push, caches e forks, pre-commit/secret scanning, cofre.")
	var cagada := ""
	if _incluido.get(DISTRATOR_PRIVADO, false) and not _incluido.get(0, false):
		cagada = "Você tornou o repositório privado e foi almoçar. A chave continuou ativa e alguém subiu 300 instâncias de mineração na conta da Tabajara."
	return {"nota": clampi(int(round(nota)), 0, 100), "comentario": " ".join(com), "cagada": cagada}


func solucao_teste() -> void:
	_busca.text = "AKIA4"
	_buscar()
	_hash.text = HASH_CERTO
	_chave.text = CHAVE_ID
	_ordem = [0, 1, 2, 3, 4, 5, 6, 7]
	for id in CERTOS:
		_incluido[id] = true
	_desenhar_passos()
	_lista.select(_mostrados.size() - 1)
	_mostrar_commit(_mostrados.size() - 1)
