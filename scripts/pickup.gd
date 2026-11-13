extends Node3D
# Cash / health pickup. Collected by walking over it (player.gd checks distance).

var kind: String = "cash"
var value: int = 50
var t: float = 0.0
var mesh: MeshInstance3D
var life: float = 90.0


func _ready() -> void:
	add_to_group("pickup")
	t = randf() * 6.0
	if kind == "health":
		mesh = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.5, 0.5)
		mesh.mesh = bm
		mesh.material_override = _glow(Color(1.0, 0.25, 0.3))
		var bar := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.56, 0.14, 0.56)
		bar.mesh = bm2
		bar.material_override = _glow(Color(1, 1, 1))
		mesh.add_child(bar)
		life = 1.0e9
	else:
		mesh = MeshInstance3D.new()
		var bm3 := BoxMesh.new()
		bm3.size = Vector3(0.5, 0.1, 0.28)
		mesh.mesh = bm3
		mesh.material_override = _glow(Color(0.25, 0.9, 0.35))
	mesh.position = Vector3(0.0, 0.9, 0.0)
	add_child(mesh)


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.8
	return m


func _process(dt: float) -> void:
	t += dt
	mesh.rotation.y += 2.5 * dt
	mesh.position.y = 0.9 + sin(t * 3.0) * 0.12
	life -= dt
	if life <= 0.0:
		queue_free()


func collect(body) -> void:
	if kind == "health":
		body.health = minf(100.0, body.health + 50.0)
		G.message.emit("Health +50")
	else:
		G.add_money(value)
		G.message.emit("+$%d" % value)
	queue_free()
