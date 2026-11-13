extends "res://fases/fase.gd"
## Dia 18: OSINT na Tabajara. Um navegador falso com rede profissional, rede de
## fotos, site de vagas, repositório público e o EXIF de uma foto. A jogadora
## junta as pistas e monta o relatório.

const SENHA_WIFI := "Tabajara@Sinistro77"
const LAT := -25.434      # 25° 26' 2.40" S
const LON := -49.277      # 49° 16' 37.20" W
const TOLERANCIA := 0.0015

const POSTS := [
	{"aba": "linkadoin", "autor": "Valdecir Moreira · Gerente de TI na Tabajara Seguros S.A.",
	 "texto": "17 anos protegendo a Tabajara. Firewall é investimento, antivírus é despesa. Contato: [i]visível só para conexões[/i]. 500+ conexões (aceito todo mundo)."},
	{"aba": "linkadoin", "autor": "Jurema Batista · Analista de Segurança da Informação Sênior",
	 "texto": "22 anos de Tabajara. Não aceito convite de quem eu não conheço. Informações de contato: [b]jurema.batista@tabajara.com.br[/b]"},
	{"aba": "linkadoin", "autor": "Kauã Ferreira · Desenvolvedor Full Stack | Ninja | Rockstar | Testei na minha máquina",
	 "texto": "Apaixonado por entregar rápido. Meus projetos pessoais estão no GitRaposa (link no perfil)."},
	{"aba": "linkadoin", "autor": "RH Tabajara Seguros · publicação",
	 "texto": "Estamos contratando! Analista de Infraestrutura Pleno em Curitiba. Todos os detalhes da vaga no VagasJá. #vemprotabajara"},
	{"aba": "linkadoin", "autor": "Valdecir Moreira · publicação",
	 "texto": "Orgulho do meu time: trocamos a VPN inteira em 2 dias! Sem janela de mudança e sem teste, porque aqui a gente confia nas pessoas. #lideranca #agilidade"},
	{"aba": "insta", "autor": "@valdecir.ti.oficial", "foto": "aniversario",
	 "texto": "Niver do setor! Bolo de prestígio da Dona Cida e o quadro branco cheio de ideias. Time que trabalha junto come junto. #familiatabajara #ti"},
	{"aba": "insta", "autor": "@valdecir.ti.oficial", "foto": "cracha",
	 "texto": "Crachá novo chegou! Agora tem até código de barras, segurança de primeiro mundo. #seguranca #crachanovo"},
	{"aba": "insta", "autor": "@valdecir.ti.oficial", "foto": "datacenter", "baixar": true,
	 "texto": "Visitei o coração da Tabajara hoje. Não posso dizer onde fica, é segredo de estado ;) #datacenter #orgulho"},
	{"aba": "insta", "autor": "@valdecir.ti.oficial",
	 "texto": "Golfe com o CEO! Ele deixou o celular no carro de novo, por isso o MFA dele vive dando problema kkkk #networking"},
	{"aba": "insta", "autor": "@valdecir.ti.oficial",
	 "texto": "Segunda-feira sem café da Dona Cida não é segunda-feira. #cafe #copa"},
	{"aba": "vagas", "autor": "Analista de Infraestrutura Pleno · Tabajara Seguros S.A. · Curitiba/PR",
	 "texto": "Requisitos: experiência com firewall [b]Palo Alto Networks série PA[/b] e VPN [b]GlobalProtect[/b] (portal vpn.tabajara.com.br, 600 usuários), Active Directory 2012 R2 (ainda), backup em fita LTO-8, Exchange local. Diferencial: paciência com o gerente. Salário: compatível com o mercado de 2009."},
	{"aba": "vagas", "autor": "Estagiário(a) de Segurança da Informação · Tabajara Seguros S.A.",
	 "texto": "Atividades: tudo. Requisitos: saber tudo. Benefícios: crachá provisório, café da copa e 30 dias de emoção."},
	{"aba": "git", "autor": "kauaferreira / scripts-uteis-tabajara · público · 3 estrelas (todas do Kauã)",
	 "texto": "[code]commit 9f2c1ab\nAuthor: Kauã Ferreira <kaua.ferreira@tabajara.com.br>\nDate:   Tue Nov 3 22:41:07 2026 -0300\n\n    adiciona script da vpn (funciona na minha máquina)[/code]"},
	{"aba": "git", "autor": "scripts-uteis-tabajara / conecta_vpn.ps1",
	 "texto": "[code]$portal = \"vpn.tabajara.com.br\"\n& \"C:\\Program Files\\Palo Alto Networks\\GlobalProtect\\PanGPA.exe\"\n# TODO: tirar a senha daqui depois (já tirei, está no histórico só)[/code]"},
]

const EXIF := """$ exiftool IMG_20261103_101522.jpg
ExifTool Version Number         : 12.76
File Name                       : IMG_20261103_101522.jpg
File Size                       : 3.1 MB
MIME Type                       : image/jpeg
Make                            : samsung
Camera Model Name               : Galaxy A54 5G
Date/Time Original              : 2026:11:03 10:15:22
Offset Time Original            : -03:00
Image Size                      : 4080x3060
GPS Version ID                  : 2.2.0.0
GPS Latitude Ref                : South
GPS Longitude Ref               : West
GPS Altitude Ref                : Above Sea Level
GPS Altitude                    : 934 m Above Sea Level
GPS Latitude                    : 25 deg 26' 2.40" S
GPS Longitude                   : 49 deg 16' 37.20" W
GPS Position                    : 25 deg 26' 2.40" S, 49 deg 16' 37.20" W"""

const RECOMENDACOES := [
	["Trocar a senha do Wi-Fi já, tirar do quadro e levar a rede corporativa para 802.1X (WPA2/WPA3-Enterprise)", true],
	["Remover metadados (EXIF/GPS) antes de publicar foto e desligar a geolocalização da câmera do celular corporativo", true],
	["Política de redes sociais com conscientização: nada de crachá, quadro branco ou datacenter em post", true],
	["Vaga sem marca, modelo e versão da infraestrutura (\"experiência com firewall corporativo\" basta)", true],
	["Bloquear o LinkadoIn no proxy da empresa e considerar o problema resolvido", false],
	["Trocar o padrão de e-mail para algo impossível de adivinhar, tipo kx7q9@tabajara.com.br", false],
	["Pedir para o Instagrão apagar a internet", false],
]

var _abas: TabContainer
var _busca: LineEdit
var _listas := {}
var _wifi: LineEdit
var _email: LineEdit
var _vpn: LineEdit
var _lat: LineEdit
var _lon: LineEdit
var _recs: Array = []


func _init() -> void:
	dia = 18
	titulo = "OSINT na Tabajara"
	chamado = ("OSINT [b]passivo[/b]: só olhe o que é público, não logue em nada. Vasculhe as abas do navegador (a busca filtra as publicações) e preencha o "
		+ "[b]Relatório[/b]: a senha de Wi-Fi exposta, o padrão de e-mail, a tecnologia da VPN, as coordenadas do datacenter em graus decimais e as recomendações. Nota por campo.")


func montar() -> void:
	var barra := linha()
	rotulo("https://", 14, Estilo.TEXTO_FRACO, barra)
	var url := rotulo("navegador-anonimo.example/busca?q=tabajara", 14, Estilo.TEXTO, barra)
	url.custom_minimum_size = Vector2(330, 0)
	_busca = campo("Buscar nas publicações (ex.: vpn, senha, crachá)", barra)
	_busca.text_changed.connect(func(_t): _renderizar())
	_abas = TabContainer.new()
	_abas.custom_minimum_size = Vector2(0, 400)
	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_child(_abas)
	_listas["linkadoin"] = _aba("LinkadoIn")
	_listas["insta"] = _aba("Instagrão")
	_listas["vagas"] = _aba("VagasJá")
	_listas["git"] = _aba("GitRaposa")
	var ex := _aba("Foto original")
	rotulo("Arquivo baixado do post do datacenter (a rede social removeu o EXIF da miniatura, mas o link de download entrega o original).", 14, Estilo.TEXTO_FRACO, ex)
	var te := bloco_mono(EXIF, 400, ex)
	te.add_theme_font_size_override("font_size", 12)
	_montar_relatorio(_aba("Relatório"))
	_renderizar()
	chat("Jurema", "Pensa como atacante, age como auditora. Olhar pode. Logar, testar senha, mandar mensagem, não pode.")
	chat("Valdecir", "Pode olhar meu Instagrão, não tem nada lá. Só coisa de família. A família Tabajara.")


func _aba(nome: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_abas.add_child(sc)
	_abas.set_tab_title(_abas.get_tab_count() - 1, nome)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	return v


static func sem_acento(s: String) -> String:
	var de := "áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ"
	var para := "aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC"
	var r := ""
	for c in s:
		var k := de.find(c)
		r += para[k] if k >= 0 else c
	return r


static func casa_busca(post: Dictionary, q: String) -> bool:
	q = sem_acento(q.strip_edges().to_lower())
	if q == "":
		return true
	var alvo := sem_acento((post["autor"] + " " + post["texto"] + " " + post.get("foto", "")).to_lower())
	if post.get("foto", "") == "aniversario":
		alvo += " quadro wi-fi wifi senha"
	if post.get("foto", "") == "cracha":
		alvo += " cracha 004127"
	for termo in q.split(" ", false):
		if not alvo.contains(termo):
			return false
	return true


func _renderizar() -> void:
	var contagem := {}
	for k in _listas:
		for c in _listas[k].get_children():
			c.queue_free()
		contagem[k] = 0
	for p in POSTS:
		if not casa_busca(p, _busca.text):
			continue
		contagem[p["aba"]] += 1
		var v := painel(_listas[p["aba"]])
		rotulo(p["autor"], 14, Estilo.CIANO, v)
		if p.has("foto"):
			_foto(p["foto"], v)
		texto_rico(p["texto"], v)
		if p.get("baixar", false):
			botao("Baixar foto original (IMG_20261103_101522.jpg)", func(): _abas.current_tab = 4, v)
	for k in contagem:
		if contagem[k] == 0:
			rotulo("Nenhuma publicação com \"%s\" aqui." % _busca.text, 14, Estilo.TEXTO_FRACO, _listas[k])


## Fotos desenhadas na hora (nada de arquivo externo).
func _foto(tipo: String, pai: Control) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(520, 200)
	pai.add_child(c)
	var f: Font = Estilo.mono()
	match tipo:
		"aniversario":
			c.draw.connect(func():
				c.draw_rect(Rect2(0, 0, 520, 200), Color("6b5a4a"))
				c.draw_rect(Rect2(150, 14, 340, 132), Color("eef1f2"))
				c.draw_rect(Rect2(150, 14, 340, 132), Color("9aa3a8"), false, 3.0)
				c.draw_string(f, Vector2(166, 40), "REUNIÃO SEGUNDA 9H (OBRIGATÓRIA)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("1d4fb8"))
				c.draw_string(f, Vector2(166, 74), "WI-FI: TABAJARA-CORP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c0262d"))
				c.draw_string(f, Vector2(166, 96), "senha: " + SENHA_WIFI, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c0262d"))
				c.draw_string(f, Vector2(166, 128), "não apagar!!! - Valdecir", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("333333"))
				c.draw_rect(Rect2(14, 120, 124, 70), Color("5a3a22"))
				c.draw_rect(Rect2(14, 120, 124, 14), Color("f2e3c6"))
				for k in 5:
					c.draw_rect(Rect2(28 + k * 22, 100, 5, 20), Color("ffd84d"))
				c.draw_circle(Vector2(60, 50), 26, Color("ff4fa3"))
				c.draw_circle(Vector2(105, 38), 22, Color("38d9e8"))
				c.draw_string(f, Vector2(300, 188), "(foto do aniversário do setor)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e6e9f0")))
		"cracha":
			c.draw.connect(func():
				c.draw_rect(Rect2(0, 0, 520, 200), Color("2b3140"))
				c.draw_rect(Rect2(150, 10, 220, 180), Color("f7f7f7"))
				c.draw_rect(Rect2(150, 10, 220, 34), Color("ff4fa3"))
				c.draw_string(f, Vector2(162, 33), "TABAJARA SEGUROS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
				c.draw_rect(Rect2(162, 54, 60, 72), Color("9aa3a8"))
				c.draw_circle(Vector2(192, 80), 16, Color("d9b38c"))
				c.draw_string(f, Vector2(230, 70), "VALDECIR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("111111"))
				c.draw_string(f, Vector2(230, 86), "MOREIRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("111111"))
				c.draw_string(f, Vector2(230, 106), "Gerente de TI", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("444444"))
				c.draw_string(f, Vector2(230, 122), "Nº 004127", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("111111"))
				var x := 166.0
				for k in 46:
					var w := 1.0 + float((k * 7) % 3)
					c.draw_rect(Rect2(x, 140, w, 34), Color("111111"))
					x += w + 2.0
				c.draw_string(f, Vector2(390, 188), "(crachá novo)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e6e9f0")))
		"datacenter":
			c.draw.connect(func():
				c.draw_rect(Rect2(0, 0, 520, 200), Color("10141c"))
				for r in 5:
					var x0 := 20.0 + r * 100.0
					c.draw_rect(Rect2(x0, 16, 80, 170), Color("1e2533"))
					for u in 14:
						c.draw_rect(Rect2(x0 + 6, 22 + u * 11.5, 68, 8), Color("2c3546"))
						c.draw_circle(Vector2(x0 + 66, 26 + u * 11.5), 2.0, Color("5ee38a") if (u + r) % 3 else Color("ffc94d"))
				c.draw_string(f, Vector2(330, 196), "(foto do datacenter)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e6e9f0")))


# ---------------------------------------------------------------- relatório

func _montar_relatorio(v: VBoxContainer) -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	var l0 := rotulo("Senha de Wi-Fi exposta:", 14, Estilo.TEXTO, g)
	l0.custom_minimum_size = Vector2(250, 0)
	_wifi = campo("exatamente como aparece", g)
	rotulo("Padrão de e-mail:", 14, Estilo.TEXTO, g)
	_email = campo("ex.: inicial+sobrenome@dominio", g)
	rotulo("Tecnologia da VPN:", 14, Estilo.TEXTO, g)
	_vpn = campo("fabricante e produto", g)
	rotulo("Datacenter, latitude decimal:", 14, Estilo.TEXTO, g)
	_lat = campo("ex.: -12.345678", g)
	rotulo("Datacenter, longitude decimal:", 14, Estilo.TEXTO, g)
	_lon = campo("ex.: -45.678901", g)
	texto_rico("[color=#8b95a8]Decimal = graus + minutos/60 + segundos/3600. Sul e Oeste são negativos.[/color]", v)
	rotulo("Recomendações (marcar besteira desconta):", 14, Estilo.TEXTO, v)
	for r in RECOMENDACOES:
		var cb := caixa_marcar(r[0], v)
		cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cb.add_theme_font_size_override("font_size", 14)
		_recs.append(cb)


static func dms_para_decimal(graus: float, minutos: float, segundos: float, hemisferio: String) -> float:
	var d := graus + minutos / 60.0 + segundos / 3600.0
	return -d if hemisferio in ["S", "W", "O"] else d


static func _numero(s: String) -> float:
	var t := s.strip_edges().replace(",", ".").replace("°", "")
	if not t.is_valid_float():
		return NAN
	return float(t)


static func padrao_email_ok(s: String) -> bool:
	var t := sem_acento(s.strip_edges().to_lower()).replace(" ", "")
	if t == "valdecir.moreira@tabajara.com.br":
		return true
	var re := RegEx.create_from_string("^[\\{\\[<(]?(nome|primeironome|primeiro_nome|primeiro-nome|firstname|first|prenome)[\\}\\]>)]?\\.[\\{\\[<(]?(sobrenome|ultimosobrenome|ultimo_sobrenome|ultimo-sobrenome|lastname|last)[\\}\\]>)]?@tabajara\\.com\\.br$")
	return re.search(t) != null


func avaliar() -> Dictionary:
	var nota := 0.0
	var ok: Array = []
	var ruim: Array = []
	if _wifi.text.strip_edges() == SENHA_WIFI:
		nota += 20
		ok.append("senha do Wi-Fi no quadro branco da foto do aniversário")
	else:
		ruim.append("a senha do Wi-Fi está no quadro branco ao fundo da foto do aniversário (%s)" % SENHA_WIFI)
	if padrao_email_ok(_email.text):
		nota += 20
		ok.append("padrão nome.sobrenome@tabajara.com.br (Jurema no LinkadoIn + Kauã no commit, sem acento)")
	else:
		ruim.append("o padrão é nome.sobrenome@tabajara.com.br, deduzido de jurema.batista e kaua.ferreira")
	var vpn := sem_acento(_vpn.text.to_lower())
	if vpn.contains("globalprotect") or vpn.contains("global protect") or vpn.contains("palo alto"):
		nota += 20
		ok.append("VPN GlobalProtect da Palo Alto (vaga + script do Kauã)")
	else:
		ruim.append("a VPN é GlobalProtect (Palo Alto), entregue pela vaga e pelo script do Kauã")
	var lat := _numero(_lat.text)
	var lon := _numero(_lon.text)
	var sinal := false
	for par in [[lat, LAT], [lon, LON]]:
		if is_nan(par[0]):
			continue
		if absf(par[0] - par[1]) <= TOLERANCIA:
			nota += 10
		elif absf(par[0] + par[1]) <= TOLERANCIA:
			nota += 3
			sinal = true
	if not is_nan(lat) and not is_nan(lon) and absf(lat - LAT) <= TOLERANCIA and absf(lon - LON) <= TOLERANCIA:
		ok.append("coordenadas do datacenter pelo EXIF")
	else:
		ruim.append("as coordenadas são %.6f, %.6f (25°26'2.40\"S = -(25 + 26/60 + 2.4/3600))%s" % [LAT, LON, "; Sul e Oeste ficam negativos" if sinal else ""])
	var acertos := 0.0
	for i in RECOMENDACOES.size():
		if _recs[i].button_pressed:
			acertos += 1.0 if RECOMENDACOES[i][1] else -1.0
	nota += 20.0 * clampf(acertos, 0.0, 4.0) / 4.0
	if acertos < 4.0:
		ruim.append("recomendação certa: trocar a senha e usar 802.1X, tirar EXIF, política de redes sociais e vagas sem detalhar a infraestrutura")
	var com := ""
	if not ok.is_empty():
		com += "Achou: " + "; ".join(ok) + ". "
	if not ruim.is_empty():
		com += "Faltou: " + "; ".join(ruim) + "."
	else:
		com += "Relatório completo: tudo isso estava aberto para qualquer um, sem tocar num servidor sequer."
	return {"nota": clampi(int(round(nota)), 0, 100), "comentario": com.strip_edges(), "cagada": ""}


func solucao_teste() -> void:
	_wifi.text = SENHA_WIFI
	_email.text = "nome.sobrenome@tabajara.com.br"
	_vpn.text = "Palo Alto GlobalProtect"
	_lat.text = "%.6f" % dms_para_decimal(25, 26, 2.40, "S")
	_lon.text = "%.6f" % dms_para_decimal(49, 16, 37.20, "W")
	for i in RECOMENDACOES.size():
		_recs[i].button_pressed = RECOMENDACOES[i][1]
	_abas.current_tab = 5
