extends RefCounted
## Personagens humanos (Quaternius, CC0) com roupa recolorida por material e animação.
## Use: preload("res://scripts/gente3d.gd").criar("Valdecir")

const PASTA := "res://modelos/personagens/"

# nome -> [modelo, {material: cor}]
const ELENCO := {
	"Valdecir": ["homem_terno_empresa", {"Suit": "6e5b44", "Tie": "c23c7e", "Hair": "a3a3a3", "Eyebrows": "8a8a8a"}],
	"Jurema": ["mulher_animada_b", {"White": "5d3b80", "Orange": "272a33", "Hair_Blond": "b5b5b5", "Hair_Brown": "8e8e8e", "Grey": "1b1b20"}],
	"Kauã": ["homem_moletom", {"Purple": "1d7a48", "LightBlue": "2a3340"}],
	"Dona Cida": ["mulher_animada_a", {"LimeGreen": "4d7fae", "Gold": "efe9da", "Red": "2b1b14"}],
	"Seu Josias": ["homem_casual", {"LightBrown": "1f2d4a", "LightBlue": "15181e", "Hair": "d8d8d8", "Eyebrows": "bdbdbd", "Red_Dark": "141414"}],
	"CEO": ["homem_terno_empresa", {"Suit": "15171c", "Tie": "8a1c1c", "Hair": "2a221b"}],
	"Funcionário do Financeiro": ["homem_casual", {"LightBrown": "9cc0e2", "LightBlue": "3b414c", "Red_Dark": "3a2a1a"}],
	"Leidiane": ["mulher_animada_a", {"LimeGreen": "b0413e", "Gold": "2b2b2b", "Red": "1e140f"}],
	"Analista de Marketing": ["homem_moletom", {"Purple": "e07a2e", "LightBlue": "e5e1d8", "Hair": "1c1612"}],
	"Contadora": ["mulher_animada_b", {"White": "2e6f8e", "Orange": "1e2430", "Hair_Blond": "2a1d14", "Hair_Brown": "1e140e"}],
	"Técnico do Ar": ["homem_uniforme", {}],
}

static var _cache := {}


static func existe(nome: String) -> bool:
	return ELENCO.has(nome)


## Devolve o nó do modelo (já recolorido e animado), virado para -Z.
static func criar(nome: String, animacao := "Idle") -> Node3D:
	var dados: Array = ELENCO.get(nome, ELENCO["Funcionário do Financeiro"])
	var cena: PackedScene = _cache.get(dados[0])
	if cena == null:
		cena = load(PASTA + dados[0] + ".glb")
		_cache[dados[0]] = cena
	var modelo: Node3D = cena.instantiate()
	modelo.rotation.y = PI
	var cores: Dictionary = dados[1]
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat and cores.has(mat.resource_name) and mat is StandardMaterial3D:
				var novo := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				novo.albedo_color = Color(cores[mat.resource_name])
				mi.set_surface_override_material(i, novo)
	tocar(modelo, animacao, true)
	return modelo


static func _player(modelo: Node) -> AnimationPlayer:
	return modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer


## Toca uma animação pelo nome curto ("Idle", "Walk", "Wave", "Interact"...).
static func tocar(modelo: Node, nome: String, aleatorio := false) -> void:
	var ap := _player(modelo)
	if ap == null:
		return
	var alvo := ""
	for a in ap.get_animation_list():
		if a == nome or a.ends_with("|" + nome):
			alvo = a
			break
	if alvo == "":
		return
	var anim := ap.get_animation(alvo)
	if nome in ["Idle", "Idle_Neutral", "Walk", "Run"]:
		anim.loop_mode = Animation.LOOP_LINEAR
	if ap.current_animation == alvo:
		return
	ap.play(alvo, 0.25)
	if aleatorio:
		ap.seek(randf() * anim.length, true)


## Um aceno e volta para o repouso.
static func acenar(modelo: Node, gesto := "Wave") -> void:
	var ap := _player(modelo)
	if ap == null:
		return
	tocar(modelo, gesto)
	var volta := func(_n): tocar(modelo, "Idle")
	if not ap.animation_finished.is_connected(volta):
		ap.animation_finished.connect(volta, CONNECT_ONE_SHOT)
