extends RefCounted
## Cores, fontes e tema do TabajaraOS. Use com preload("res://scripts/estilo.gd").

const FUNDO := Color("0f131b")
const PAINEL := Color("171d29")
const PAINEL_CLARO := Color("222a3a")
const BORDA := Color("33405a")
const TEXTO := Color("e6e9f0")
const TEXTO_FRACO := Color("8b95a8")
const DESTAQUE := Color("ff4fa3")   # rosa
const CIANO := Color("38d9e8")
const OK := Color("5ee38a")
const ERRO := Color("ff5d5d")
const ALERTA := Color("ffc94d")

const PERSONAGENS := {
	"Valdecir": Color("ffc94d"),
	"Jurema": Color("c792ff"),
	"Kauã": Color("5ee38a"),
	"CEO": Color("ff5d5d"),
	"RH": Color("38d9e8"),
	"Sistema": Color("8b95a8"),
	"Você": Color("ff4fa3"),
	"Auditor": Color("ffa04d"),
	"Dona Cida": Color("7fc4ff"),
}

static var _mono: Font
static var _tema: Theme
static var _fontes := {}


## Fonte do texto (Plus Jakarta Sans, peso variável).
static func texto(peso := 500) -> Font:
	return _variavel("res://fontes/PlusJakartaSans.ttf", peso)


## Fonte de títulos e placas (Bricolage Grotesque, peso variável).
static func titulo(peso := 800) -> Font:
	return _variavel("res://fontes/BricolageGrotesque.ttf", peso)


static func _variavel(caminho: String, peso: int) -> Font:
	var chave := "%s|%d" % [caminho, peso]
	if not _fontes.has(chave):
		var fv := FontVariation.new()
		fv.base_font = load(caminho)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): peso}
		_fontes[chave] = fv
	return _fontes[chave]


static func mono() -> Font:
	if _mono == null:
		# Sem ligaduras: "--" e "->" aparecem como dois caracteres, como no terminal.
		var fv := FontVariation.new()
		fv.base_font = load("res://fontes/JetBrainsMono.ttf")
		fv.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("calt"): 0,
			TextServerManager.get_primary_interface().name_to_tag("liga"): 0}
		_mono = fv
	return _mono


static func cor_de(quem: String) -> Color:
	return PERSONAGENS.get(quem, CIANO)


static func caixa(cor: Color, borda: Color = BORDA, raio := 6, margem := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.border_color = borda
	s.set_border_width_all(1)
	s.set_corner_radius_all(raio)
	s.content_margin_left = margem
	s.content_margin_right = margem
	s.content_margin_top = margem * 0.6
	s.content_margin_bottom = margem * 0.6
	return s


static func tema() -> Theme:
	if _tema != null:
		return _tema
	var t := Theme.new()
	t.default_font = texto(500)
	t.default_font_size = 15
	t.set_font("bold_font", "RichTextLabel", texto(750))
	t.set_color("font_color", "Label", TEXTO)
	t.set_color("default_color", "RichTextLabel", TEXTO)
	t.set_font("normal_font", "RichTextLabel", null)
	t.set_font("mono_font", "RichTextLabel", mono())
	t.set_stylebox("panel", "Panel", caixa(PAINEL))
	t.set_stylebox("panel", "PanelContainer", caixa(PAINEL))

	t.set_stylebox("normal", "Button", caixa(PAINEL_CLARO, BORDA, 5, 12))
	t.set_stylebox("hover", "Button", caixa(Color("2c3750"), DESTAQUE, 5, 12))
	t.set_stylebox("pressed", "Button", caixa(Color("3a2a40"), DESTAQUE, 5, 12))
	t.set_stylebox("disabled", "Button", caixa(Color("1a1f2a"), Color("252c3b"), 5, 12))
	t.set_stylebox("focus", "Button", caixa(Color(0, 0, 0, 0), DESTAQUE, 5, 12))
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", DESTAQUE)
	t.set_color("font_disabled_color", "Button", TEXTO_FRACO)

	for tipo in ["LineEdit", "TextEdit", "CodeEdit"]:
		t.set_stylebox("normal", tipo, caixa(Color("0b0e14"), BORDA, 4, 8))
		t.set_stylebox("focus", tipo, caixa(Color("0b0e14"), CIANO, 4, 8))
		t.set_stylebox("read_only", tipo, caixa(Color("12161f"), BORDA, 4, 8))
		t.set_color("font_color", tipo, TEXTO)
		t.set_color("caret_color", tipo, DESTAQUE)
		t.set_color("font_readonly_color", tipo, Color("c3cad8"))
		t.set_color("selection_color", tipo, Color(1.0, 0.31, 0.64, 0.35))
		t.set_font("font", tipo, mono())
		t.set_font_size("font_size", tipo, 14)

	t.set_stylebox("normal", "OptionButton", caixa(PAINEL_CLARO, BORDA, 5, 12))
	t.set_stylebox("hover", "OptionButton", caixa(Color("2c3750"), DESTAQUE, 5, 12))
	t.set_stylebox("pressed", "OptionButton", caixa(Color("2c3750"), DESTAQUE, 5, 12))
	t.set_stylebox("panel", "PopupMenu", caixa(PAINEL, BORDA, 4, 6))
	t.set_stylebox("panel", "TooltipPanel", caixa(PAINEL, DESTAQUE, 4, 8))
	t.set_stylebox("tab_selected", "TabContainer", caixa(PAINEL_CLARO, DESTAQUE, 4, 10))
	t.set_stylebox("tab_unselected", "TabContainer", caixa(PAINEL, BORDA, 4, 10))
	t.set_stylebox("panel", "TabContainer", caixa(PAINEL, BORDA, 4, 10))
	t.set_stylebox("panel", "Tree", caixa(Color("0b0e14"), BORDA, 4, 4))
	t.set_stylebox("panel", "ItemList", caixa(Color("0b0e14"), BORDA, 4, 4))
	t.set_color("font_color", "Tree", TEXTO)
	t.set_color("font_color", "ItemList", TEXTO)
	t.set_color("font_color", "CheckBox", TEXTO)
	_tema = t
	return t
