extends "res://fases/fase.gd"
## Dia 23: carving de JPEG numa imagem de pendrive formatado. Hexdump, busca, extração, hash e custódia.

const BYTES_POR_PAGINA := 256
const INICIO_JPEG := 0x1000   # cluster 6 (dados começam em 0x800, cluster de 512 bytes)
const FALSO_INICIO := 0x0A31
const FD9_SOLTO_ANTES := 0x0C40
const PERGUNTA := [
	"(escolha)",
	"Porque o pendrive original é lento e a cópia roda mais rápido no notebook",
	"Preservar a evidência: até montar o volume escreve no original; o hash prova que a cópia é idêntica e intacta",
	"Porque o SHA-256 criptografa a cópia e impede que ela vaze",
	"Não precisa: com autorização do diretor dá para trabalhar direto no original",
]

var _disco := PackedByteArray()
var _jpeg_tam := 0
var _fim_real := 0
var _fd9_lixo := 0
var _hash_disco := ""
var _pagina := 0
var _hex: TextEdit
var _rotulo_pag: Label
var _ir: LineEdit
var _busca: LineEdit
var _res_busca: Label
var _ini: LineEdit
var _fim: LineEdit
var _res_extracao: Label
var _foto: TextureRect
var _extraido := PackedByteArray()
var _extraido_ok := false
var _custodia: TextEdit
var _hash_registrado := ""
var _pergunta: OptionButton
var _chkdsk := false


func _init() -> void:
	dia = 23
	titulo = "Pendrive formatado"
	chamado = ("A Jurema já tirou a imagem forense do pendrive (com bloqueador de escrita). A formatação rápida zerou a FAT, "
		+ "mas os dados continuam lá. Ache no hexdump o [b]início[/b] do JPEG (assinatura FF D8 FF) e o [b]fim[/b] (FF D9), digite os offsets, "
		+ "[b]extraia[/b], gere o [b]SHA-256[/b] para a cadeia de custódia e responda à pergunta. Nota: offsets, extração, hash e resposta.")


# ---------------------------------------------------------------- geração da evidência

static func _foto_contrato() -> Image:
	var img := Image.create_empty(160, 100, false, Image.FORMAT_RGB8)
	img.fill(Color("f4f1e8"))
	# Cabeçalho e linhas de "texto" do contrato
	img.fill_rect(Rect2i(12, 8, 136, 6), Color("2b3a55"))
	for i in 7:
		var largura := 120 - (i * 13) % 37
		img.fill_rect(Rect2i(12, 22 + i * 7, largura, 2), Color("9a978f"))
	# Assinatura: curva em pixels
	for x in range(20, 110):
		var t := float(x - 20) / 90.0
		var y := int(80.0 + sin(t * 9.0) * 6.0 * (1.0 - t) - t * 6.0)
		img.fill_rect(Rect2i(x, y, 2, 2), Color("1c2f8f"))
	img.fill_rect(Rect2i(18, 88, 96, 1), Color("555555"))
	# Carimbo vermelho
	for k in 3:
		img.fill_rect(Rect2i(118 + k, 66 + k, 32 - 2 * k, 1), Color("c8202a"))
		img.fill_rect(Rect2i(118 + k, 92 - k, 32 - 2 * k, 1), Color("c8202a"))
		img.fill_rect(Rect2i(118 + k, 66 + k, 1, 26 - 2 * k), Color("c8202a"))
		img.fill_rect(Rect2i(149 - k, 66 + k, 1, 26 - 2 * k), Color("c8202a"))
	img.fill_rect(Rect2i(124, 76, 20, 6), Color("c8202a"))
	return img


static func _escrever(d: PackedByteArray, pos: int, dados: PackedByteArray) -> void:
	for i in dados.size():
		d[pos + i] = dados[i]


static func _ascii(s: String) -> PackedByteArray:
	return s.to_ascii_buffer()


func _gerar_disco() -> void:
	var jpeg := _foto_contrato().save_jpg_to_buffer(0.85)
	_jpeg_tam = jpeg.size()
	var total := INICIO_JPEG + _jpeg_tam + 1024
	total += (512 - total % 512) % 512
	_disco.resize(total)
	_disco.fill(0)
	# Setor de boot FAT16 (formatação rápida reescreve, mas não apaga os dados)
	_escrever(_disco, 0, PackedByteArray([0xEB, 0x3C, 0x90]))
	_escrever(_disco, 3, _ascii("MSDOS5.0"))
	_escrever(_disco, 11, PackedByteArray([0x00, 0x02, 0x01, 0x02, 0x00, 0x02, 0x10, 0x00]))
	_escrever(_disco, 43, _ascii("NO NAME    FAT16   "))
	_disco[510] = 0x55
	_disco[511] = 0xAA
	# FAT zerada pela formatação (só o cabeçalho F8 FF FF FF)
	_escrever(_disco, 0x200, PackedByteArray([0xF8, 0xFF, 0xFF, 0xFF]))
	# Diretório raiz: rótulo e uma entrada apagada (0xE5) que ainda guarda cluster e tamanho
	_escrever(_disco, 0x400, _ascii("PENDRIVE   "))
	_disco[0x400 + 11] = 0x08
	var ent := 0x420
	_disco[ent] = 0xE5
	_escrever(_disco, ent + 1, _ascii("SSINAT JPG"))
	_disco[ent + 11] = 0x20
	_disco[ent + 26] = 6
	_disco[ent + 27] = 0
	for k in 4:
		_disco[ent + 28 + k] = (_jpeg_tam >> (8 * k)) & 0xFF
	# Lixo de uso anterior nos clusters livres (sem 0xFF, para não criar assinaturas por acaso)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2310
	for i in range(0x800, total):
		_disco[i] = rng.randi_range(0, 0xFE)
	for i in range(0x0900, 0x0960):
		_disco[i] = 0
	_escrever(_disco, 0x0900, _ascii("contrato_v3_FINAL_agora_vai_REVISADO.docx"))
	_escrever(_disco, 0x0B10, _ascii("SALARIOS 2027 (NAO ABRIR)"))
	# Pegadinhas: FF D8 sem o FF seguinte e um FF D9 solto antes do arquivo
	_escrever(_disco, FALSO_INICIO, PackedByteArray([0xFF, 0xD8, 0x00, 0x13]))
	_escrever(_disco, FD9_SOLTO_ANTES, PackedByteArray([0xFF, 0xD9]))
	# O JPEG de verdade
	_escrever(_disco, INICIO_JPEG, jpeg)
	_fim_real = INICIO_JPEG + _jpeg_tam - 2
	# Outro FF D9 logo depois, no slack do cluster (quem pega o último FF D9 leva lixo junto)
	_fd9_lixo = _fim_real + 2 + 37
	_escrever(_disco, _fd9_lixo, PackedByteArray([0xFF, 0xD9]))
	_hash_disco = sha256(_disco)


static func sha256(dados: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(dados)
	return ctx.finish().hex_encode()


# ---------------------------------------------------------------- interface

func montar() -> void:
	_gerar_disco()
	var hi := linha()
	texto_rico("[color=#8b95a8]Evidência:[/color] [code]pendrive_diretor.dd[/code]  %d bytes  ·  SHA-256 [code]%s...[/code]" % [_disco.size(), _hash_disco.left(16)], hi)
	var bc := botao("chkdsk E: /f no original", _rodar_chkdsk, hi)
	bc.add_theme_color_override("font_color", Estilo.ALERTA)
	bc.tooltip_text = "Sugestão do Valdecir"

	_hex = bloco_mono("", 372)
	_hex.add_theme_font_size_override("font_size", 13)
	var hn := linha()
	botao("<< Anterior", func(): _ir_pagina(_pagina - 1), hn)
	botao("Próxima >>", func(): _ir_pagina(_pagina + 1), hn)
	_rotulo_pag = rotulo("", 13, Estilo.TEXTO_FRACO, hn)
	_rotulo_pag.autowrap_mode = TextServer.AUTOWRAP_OFF
	_rotulo_pag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ir = campo("ir para offset (0x420)", hn)
	_ir.custom_minimum_size.x = 190
	_ir.size_flags_horizontal = Control.SIZE_FILL
	_ir.text_submitted.connect(func(_t): _ir_offset())
	botao("Ir", _ir_offset, hn)
	var hb := linha()
	_busca = campo("padrão hex, ex.: FF D8 FF", hb)
	_busca.text_submitted.connect(func(_t): _buscar())
	botao("Buscar no disco inteiro", _buscar, hb)
	_res_busca = rotulo("", 13, Estilo.TEXTO_FRACO)

	var pe := painel(null, Color("1b1626"))
	rotulo("Carving", 15, Estilo.DESTAQUE, pe)
	var he := linha(pe)
	_ini = campo("offset do FF D8 FF inicial", he)
	_fim = campo("offset do FF D9 final (posição do FF)", he)
	botao("Extrair", _extrair, he)
	_res_extracao = rotulo("", 14, Estilo.TEXTO_FRACO, pe)
	_foto = TextureRect.new()
	_foto.custom_minimum_size = Vector2(0, 0)
	_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_foto.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pe.add_child(_foto)

	var pc := painel()
	rotulo("Cadeia de custódia", 15, Estilo.DESTAQUE, pc)
	botao("Gerar SHA-256 do arquivo extraído e registrar", _registrar_hash, pc)
	_custodia = bloco_mono("2026-11-13 08:41 | pendrive_diretor.dd (imagem bit a bit, dd conv=noerror,sync) | SHA-256 %s | Jurema Antunes\n" % _hash_disco, 110, pc)
	_custodia.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_custodia.add_theme_font_size_override("font_size", 12)
	rotulo("Por que trabalhar na imagem forense com hash, e não no pendrive original?", 15, Estilo.cor_de("Jurema"), pc)
	_pergunta = opcoes(PERGUNTA, pc)
	_pergunta.clip_text = true
	_pergunta.fit_to_longest_item = false
	_pergunta.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_ir_pagina(0)
	chat("Valdecir", "O diretor saiu do banheiro. Disse que se a foto voltar ele aprova o orçamento do antivírus de firewall.")
	chat("Jurema", "Formatação rápida só recria a FAT e o diretório. Os bytes da foto continuam nos clusters. Procura a assinatura.")
	chat("Jurema", "E olha o diretório raiz em 0x400: arquivo apagado vira 0xE5 no primeiro byte, mas cluster e tamanho ficam.")


func _ir_pagina(p: int) -> void:
	var paginas := int(ceil(_disco.size() / float(BYTES_POR_PAGINA)))
	_pagina = clampi(p, 0, paginas - 1)
	_hex.text = hexdump(_disco, _pagina * BYTES_POR_PAGINA, BYTES_POR_PAGINA)
	_rotulo_pag.text = "página %d de %d" % [_pagina + 1, paginas]


static func hexdump(d: PackedByteArray, inicio: int, qtd: int) -> String:
	var linhas := PackedStringArray()
	var fim := mini(inicio + qtd, d.size())
	for off in range(inicio, fim, 16):
		var hexa := ""
		var asc := ""
		for i in 16:
			if off + i < fim:
				var b := d[off + i]
				hexa += "%02X " % b
				asc += char(b) if b >= 0x20 and b < 0x7F else "."
			else:
				hexa += "   "
			if i == 7:
				hexa += " "
		linhas.append("%08X  %s |%s|" % [off, hexa, asc])
	return "\n".join(linhas)


static func ler_offset(s: String) -> int:
	var t := s.strip_edges().to_lower()
	if t.begins_with("0x"):
		var h := t.substr(2)
		return h.hex_to_int() if h.is_valid_hex_number() else -1
	if t.is_valid_int():
		return t.to_int()
	return -1


func _ir_offset() -> void:
	var o := ler_offset(_ir.text)
	if o < 0 or o >= _disco.size():
		aviso("Offset inválido. Use 0x... para hexadecimal ou um número decimal.", Estilo.ERRO)
		return
	_ir_pagina(int(o / float(BYTES_POR_PAGINA)))


static func padrao_hex(s: String) -> PackedByteArray:
	var limpo := s.replace(" ", "").replace(",", "").to_lower()
	if limpo.length() == 0 or limpo.length() % 2 != 0 or not limpo.is_valid_hex_number():
		return PackedByteArray()
	return limpo.hex_decode()


static func procurar(d: PackedByteArray, p: PackedByteArray) -> Array:
	var achados := []
	if p.is_empty():
		return achados
	for i in range(0, d.size() - p.size() + 1):
		if d[i] != p[0]:
			continue
		var ok := true
		for k in range(1, p.size()):
			if d[i + k] != p[k]:
				ok = false
				break
		if ok:
			achados.append(i)
	return achados


func _buscar() -> void:
	var p := padrao_hex(_busca.text)
	if p.is_empty():
		_res_busca.text = "Padrão inválido: use pares hexadecimais, ex.: FF D8 FF"
		return
	var achados := procurar(_disco, p)
	if achados.is_empty():
		_res_busca.text = "Nenhuma ocorrência de %s." % p.hex_encode().to_upper()
		return
	var lista := PackedStringArray()
	for a in achados.slice(0, 12):
		lista.append("0x%04X" % a)
	_res_busca.text = "%d ocorrência(s) de %s: %s%s (pulei para a primeira)" % [achados.size(), p.hex_encode().to_upper(), ", ".join(lista), " ..." if achados.size() > 12 else ""]
	_ir_pagina(int(achados[0] / float(BYTES_POR_PAGINA)))


func _extrair() -> void:
	var a := ler_offset(_ini.text)
	var b := ler_offset(_fim.text)
	_extraido_ok = false
	_foto.texture = null
	_foto.custom_minimum_size = Vector2.ZERO
	if a < 0 or b < 0 or a >= _disco.size() or b >= _disco.size() or b <= a:
		_res_extracao.text = "Offsets inválidos (o fim precisa vir depois do início)."
		_res_extracao.add_theme_color_override("font_color", Estilo.ERRO)
		return
	# Aceita o offset do FF ou do D9 do marcador final.
	var fim_excl := b + 2
	if b > 0 and _disco[b] == 0xD9 and _disco[b - 1] == 0xFF:
		fim_excl = b + 1
	fim_excl = mini(fim_excl, _disco.size())
	_extraido = _disco.slice(a, fim_excl)
	var n := _extraido.size()
	if n < 4 or _extraido[0] != 0xFF or _extraido[1] != 0xD8 or _extraido[2] != 0xFF:
		_res_extracao.text = "Os primeiros bytes são %s: isso não é um cabeçalho JPEG (FF D8 FF)." % _extraido.slice(0, 4).hex_encode().to_upper()
		_res_extracao.add_theme_color_override("font_color", Estilo.ERRO)
		return
	if _extraido[n - 2] != 0xFF or _extraido[n - 1] != 0xD9:
		_res_extracao.text = "O recorte não termina em FF D9 (EOI). O arquivo ficaria truncado."
		_res_extracao.add_theme_color_override("font_color", Estilo.ERRO)
		return
	var img := Image.new()
	if img.load_jpg_from_buffer(_extraido) != OK:
		_res_extracao.text = "O decodificador recusou o arquivo (%d bytes)." % n
		_res_extracao.add_theme_color_override("font_color", Estilo.ERRO)
		return
	_extraido_ok = true
	_foto.texture = ImageTexture.create_from_image(img)
	_foto.custom_minimum_size = Vector2(0, img.get_height() * 2.4)
	if a == INICIO_JPEG and fim_excl == _fim_real + 2:
		_res_extracao.text = "assinatura_contrato.jpg recuperada: %d bytes, %dx%d. Bate com o tamanho da entrada apagada no diretório." % [n, img.get_width(), img.get_height()]
		_res_extracao.add_theme_color_override("font_color", Estilo.OK)
		chat("Valdecir", "A ASSINATURA! O diretor parou de chorar. Agora está chorando de alegria. Mesma coisa no banheiro.")
	else:
		_res_extracao.text = "A imagem abre, mas o arquivo tem %d bytes e a entrada do diretório diz %d. Tem byte sobrando: o hash não vai bater com o original." % [n, _jpeg_tam]
		_res_extracao.add_theme_color_override("font_color", Estilo.ALERTA)


func _registrar_hash() -> void:
	if not _extraido_ok:
		aviso("Extraia um JPEG válido antes de gerar o hash.", Estilo.ERRO)
		return
	_hash_registrado = sha256(_extraido)
	_custodia.text += "2026-11-13 %s | assinatura_contrato.jpg (carving de 0x%X, %d bytes) | SHA-256 %s | estagiaria.prov\n" % [_relogio.text, ler_offset(_ini.text), _extraido.size(), _hash_registrado]
	aviso("Hash registrado na cadeia de custódia.", Estilo.OK)


func _rodar_chkdsk() -> void:
	if _chkdsk:
		return
	_chkdsk = true
	chat("Sistema", "chkdsk E: /f ... Corrigindo erros no volume. 1 cadeia perdida convertida em FILE0000.CHK. Clusters livres zerados.")
	chat("Jurema", "VOCÊ RODOU CHKDSK NO ORIGINAL?! Escreveu na evidência. O hash mudou, a custódia já era e a perícia do contrato também.")
	aviso("O pendrive original foi alterado.", Estilo.ERRO)


# ---------------------------------------------------------------- avaliação

func avaliar() -> Dictionary:
	var nota := 0
	var com: Array[String] = []
	var a := ler_offset(_ini.text)
	var b := ler_offset(_fim.text)
	if a == INICIO_JPEG:
		nota += 20
	elif a == FALSO_INICIO:
		com.append("0x%X é um FF D8 solto (seguido de 00): JPEG começa com FF D8 FF." % FALSO_INICIO)
	else:
		com.append("O JPEG começava em 0x%X (cluster 6, como diz a entrada apagada no diretório)." % INICIO_JPEG)
	if b == _fim_real or b == _fim_real + 1:
		nota += 20
	elif b == _fd9_lixo or b == _fd9_lixo + 1:
		com.append("Você pegou um FF D9 depois do fim: o EOI certo é o primeiro depois do início, em 0x%X (início + tamanho - 2)." % _fim_real)
	else:
		com.append("O FF D9 final certo ficava em 0x%X." % _fim_real)
	var exato := _extraido_ok and _extraido.size() == _jpeg_tam and a == INICIO_JPEG
	if exato:
		nota += 10
	var hash_certo := sha256(_disco.slice(INICIO_JPEG, _fim_real + 2))
	if _hash_registrado == hash_certo:
		nota += 20
		com.append("Arquivo recuperado e SHA-256 registrado: qualquer um pode reextrair e conferir o mesmo hash.")
	elif _hash_registrado != "":
		nota += 5
		com.append("Você registrou um hash, mas de um recorte errado: não bate com o arquivo original.")
	else:
		com.append("Faltou registrar o SHA-256 do arquivo extraído na cadeia de custódia.")
	if _pergunta.selected == 2:
		nota += 30
		com.append("E sim: perícia se faz na cópia bit a bit, com hash da origem e da cópia, para o original ficar intocado.")
	else:
		com.append("Trabalha-se na cópia porque qualquer escrita altera a evidência; o hash prova integridade (ABNT NBR ISO/IEC 27037).")
	var cagada := ""
	if _chkdsk:
		nota = mini(nota, 30)
		cagada = "Você rodou chkdsk /f no pendrive original. A evidência foi alterada e o advogado da outra parte agradece."
	return {"nota": nota, "comentario": " ".join(com), "cagada": cagada}


func solucao_teste() -> void:
	_busca.text = "FF D8 FF"
	_buscar()
	_ini.text = "0x%X" % INICIO_JPEG
	_fim.text = "0x%X" % _fim_real
	_extrair()
	_registrar_hash()
	_pergunta.selected = 2
