extends CharacterBody3D
# Pedestrian: walks the sidewalk grid, panics when shot, dies as a physics ragdoll.

const U = preload("res://scripts/util.gd")
const H = preload("res://scripts/humanoid.gd")
const PickupScript = preload("res://scripts/pickup.gd")

var parts: Dictionary = {}
var colors: Array = []
var model: Node3D
var ni: int = 0
var nj: int = 0
var prev_i: int = -1
var prev_j: int = -1
var target: Vector3 = Vector3.ZERO
var speed: float = 1.6
var panic: float = 0.0
var hp: float = 50.0
var phase: float = 0.0
var dead: bool = false


func _ready() -> void:
	add_to_group("pedestrian")
	collision_layer = 16
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0.0, 0.9, 0.0)
	add_child(cs)
	colors = H.random_colors()
	parts = H.build(colors[0], colors[1], colors[2])
	model = parts["root"]
	add_child(model)
	speed = randf_range(1.3, 2.0)
	phase = randf() * 6.0


func place(i: int, j: int) -> void:
	ni = i
	nj = j
	position = U.nav_pos(i, j) + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	_pick()


func _pick() -> void:
	var opts: Array = []
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var n: int = U.NAV.size()
	for d in dirs:
		var a: int = ni + d.x
		var b: int = nj + d.y
		if a < 0 or b < 0 or a >= n or b >= n:
			continue
		if a == prev_i and b == prev_j:
			continue
		opts.append(Vector2i(a, b))
	if opts.is_empty():
		opts.append(Vector2i(prev_i, prev_j))
	var o: Vector2i = opts[randi() % opts.size()]
	prev_i = ni
	prev_j = nj
	ni = o.x
	nj = o.y
	target = U.nav_pos(ni, nj) + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))


func scare(t: float) -> void:
	panic = maxf(panic, t)


func _physics_process(dt: float) -> void:
	if dead:
		return
	var near: bool = true
	if G.player != null:
		near = global_position.distance_squared_to(G.player.global_position) < 12000.0
	visible = near
	var to: Vector3 = target - global_position
	to.y = 0.0
	var d: float = to.length()
	if d < 0.7:
		_pick()
		return
	var dirv: Vector3 = to / d
	var sp: float = speed
	if panic > 0.0:
		sp = 5.2
		panic -= dt
	global_position += dirv * sp * dt
	global_position.y = U.CURB
	rotation.y = lerp_angle(rotation.y, atan2(-dirv.x, -dirv.z), minf(1.0, 8.0 * dt))
	if near:
		phase += sp * dt * 3.0
		H.animate(parts, phase, clampf(sp / 2.0, 0.4, 1.4), false)


func take_damage(amount: float, dir: Vector3, by_player: bool) -> void:
	if dead:
		return
	hp -= amount
	panic = 10.0
	G.sfx("res://audio/enemy_hurt.ogg", global_position, -6.0, randf_range(0.8, 1.2))
	if hp <= 0.0:
		if by_player:
			G.kills += 1
			G.add_wanted(0.55)
		die(dir * 7.0 + Vector3(0.0, 2.5, 0.0))


func hit_by_car(vel: Vector3, by_player: bool) -> void:
	if dead:
		return
	G.sfx("res://audio/impact.ogg", global_position, -4.0, randf_range(0.9, 1.3))
	if by_player:
		G.kills += 1
		G.add_wanted(0.5)
	die(vel * 1.1 + Vector3(0.0, 4.0, 0.0))


func die(impulse: Vector3) -> void:
	if dead:
		return
	dead = true
	var parent: Node = get_parent()
	H.spawn_ragdoll(parent, model.global_transform, colors, impulse)
	var pk = PickupScript.new()
	pk.kind = "cash"
	pk.value = randi_range(15, 90)
	parent.add_child(pk)
	pk.global_position = Vector3(global_position.x, 0.0, global_position.z)
	G.ped_died.emit()
	queue_free()
