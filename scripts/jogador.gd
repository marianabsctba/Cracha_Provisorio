extends CharacterBody3D
## Primeira pessoa: WASD/setas, mouse para olhar, Shift corre, clique captura o mouse.

const VELOCIDADE := 3.6
const CORRIDA := 6.0
const SENSIBILIDADE := 0.0025

var camera: Camera3D
var raio: RayCast3D
var travado := false   # true durante diálogos e telas
var correndo := false
var _pitch := 0.0


func _ready() -> void:
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.3
	capsula.height = 1.7
	forma.shape = capsula
	forma.position.y = 0.85
	add_child(forma)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.fov = 72
	camera.near = 0.05
	add_child(camera)
	raio = RayCast3D.new()
	raio.target_position = Vector3(0, 0, -2.3)
	raio.collide_with_areas = true
	raio.add_exception(self)
	camera.add_child(raio)


func _unhandled_input(evento: InputEvent) -> void:
	if travado:
		return
	if evento is InputEventMouseButton and evento.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-evento.relative.x * SENSIBILIDADE)
		_pitch = clampf(_pitch - evento.relative.y * SENSIBILIDADE, -1.3, 1.3)
		camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	var dir := Vector2.ZERO
	if not travado:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): dir.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): dir.y += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): dir.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): dir.x += 1
	correndo = Input.is_physical_key_pressed(KEY_SHIFT) and dir != Vector2.ZERO
	var v := (CORRIDA if correndo else VELOCIDADE)
	var mundo := (transform.basis * Vector3(dir.x, 0, dir.y)).normalized() * v
	velocity.x = mundo.x
	velocity.z = mundo.z
	move_and_slide()


## O que está na mira (nó com meta "interagir"), ou null.
func alvo() -> Node:
	if travado or not raio.is_colliding():
		return null
	var n: Node = raio.get_collider()
	while n and not n.has_meta("interagir"):
		n = n.get_parent()
	return n
