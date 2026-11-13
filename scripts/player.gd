extends CharacterBody3D
# The player on foot. Also owns the third-person camera (and keeps following the car).

const U = preload("res://scripts/util.gd")
const C = preload("res://scripts/char_model.gd")
const RocketScript = preload("res://scripts/rocket.gd")

# Some gun models point +Z; flip this one line if a weapon looks back to front.
const GUN_YAW: float = PI

const WEAPONS: Array = [
	{"name": "Repeater", "model": preload("res://models/weapons/blaster-repeater.glb"), "dmg": 14.0, "cd": 0.12, "pellets": 1, "spread": 0.012, "range": 75.0, "snd": "res://audio/blaster_repeater.ogg"},
	{"name": "Scattergun", "model": preload("res://models/weapons/blaster.glb"), "dmg": 16.0, "cd": 0.55, "pellets": 5, "spread": 0.075, "range": 42.0, "snd": "res://audio/blaster.ogg"},
	{"name": "Rocket Launcher", "model": null, "dmg": 0.0, "cd": 1.4, "pellets": 1, "spread": 0.0, "range": 95.0, "snd": "res://audio/impact.ogg", "rocket": true},
]

var health: float = 100.0
var dead: bool = false
var parts: Dictionary = {}
var model: Node3D
var hand_ref: Node3D
var gun_holder: Node3D
var guns: Array = []
var wi: int = 0
var cd: float = 0.0
var cam: Camera3D
var pitch: float = 0.3
var last_look: float = -10.0
var in_car = null
var near_car = null
var jump_req: bool = false
var pick_t: float = 0.0
var spawn_pos: Vector3 = Vector3(-3.0, 0.2, 16.0)
var skin: Color = Color(0.9, 0.72, 0.58)


func _ready() -> void:
	G.player = self
	collision_layer = 32
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0.0, 0.9, 0.0)
	add_child(cs)
	parts = C.build(C.SOLDIER, Color(0.12, 0.42, 0.58), Color(0.12, 0.12, 0.16), skin, Color(0.95, 0.8, 0.2))
	model = parts["root"]
	add_child(model)
	hand_ref = parts.get("hand", null) as Node3D
	gun_holder = Node3D.new()
	gun_holder.position = Vector3(0.3, 1.14, -0.3)
	model.add_child(gun_holder)
	for w in WEAPONS:
		var g: Node3D = U.rocket_launcher() if w.get("rocket", false) else U.fit_len(w["model"], 0.7)
		g.rotation.y = GUN_YAW
		g.position = Vector3(0.0, -0.06, -0.12)
		g.visible = false
		gun_holder.add_child(g)
		guns.append(g)
	(guns[0] as Node3D).visible = true
	cam = Camera3D.new()
	cam.top_level = true
	cam.fov = 70.0
	cam.far = 450.0
	cam.near = 0.25
	add_child(cam)
	cam.make_current()
	G.action_jump.connect(func() -> void: jump_req = true)
	G.action_interact.connect(_on_interact)
	G.action_weapon.connect(_on_weapon)


func weapon_name() -> String:
	return WEAPONS[wi]["name"]


func _process(dt: float) -> void:
	var look: Vector2 = G.look_delta
	G.look_delta = Vector2.ZERO
	if look != Vector2.ZERO:
		G.cam_yaw -= look.x * 0.0055
		pitch = clampf(pitch + look.y * 0.004, -0.12, 1.15)
		last_look = G.time
	if in_car != null and G.time - last_look > 1.3:
		G.cam_yaw = lerp_angle(G.cam_yaw, in_car.rotation.y, minf(1.0, 2.5 * dt))
	var tpos: Vector3 = global_position + Vector3(0.0, 1.55, 0.0)
	var dist: float = 3.9
	var shoulder: float = 0.55
	if in_car != null:
		tpos = in_car.global_position + Vector3(0.0, 1.3, 0.0)
		dist = 8.5
		shoulder = 0.0
	var yaw: float = G.cam_yaw
	var back: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	var rgt: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var off: Vector3 = back * cos(pitch) * dist + Vector3(0.0, sin(pitch) * dist, 0.0) + rgt * shoulder
	var want: Vector3 = tpos + off
	var q := PhysicsRayQueryParameters3D.create(tpos, want, 1)
	var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		want = (h["position"] as Vector3) + (tpos - want).normalized() * 0.3
	# Keep the camera above the ground the player stands on. A hard street-level
	# clamp would bury the camera in the ground slab above the house room, which
	# sits 20 m below the city.
	want.y = maxf(want.y, global_position.y + 0.35)
	cam.global_position = want
	cam.look_at(tpos + rgt * shoulder, Vector3.UP)


func _physics_process(dt: float) -> void:
	if dead:
		return
	cd = maxf(0.0, cd - dt)
	pick_t -= dt
	if pick_t <= 0.0:
		pick_t = 0.1
		_pickups()
	if in_car != null:
		global_position = in_car.global_position
		return
	_move(dt)
	_find_car()
	if G.fire_held():
		_shoot()
	if global_position.y < -60.0:
		global_position = spawn_pos
		velocity = Vector3.ZERO


func _move(dt: float) -> void:
	var mv: Vector2 = G.get_move()
	var yaw: float = G.cam_yaw
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var rgt: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var dir: Vector3 = rgt * mv.x + fwd * mv.y
	var hv: Vector3 = Vector3(velocity.x, 0.0, velocity.z).lerp(dir * 5.4, minf(1.0, 12.0 * dt))
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = -0.5
		if jump_req:
			velocity.y = 7.0
	else:
		velocity.y -= 22.0 * dt
	jump_req = false
	move_and_slide()
	var face: float = model.rotation.y
	if G.fire_held():
		face = G.cam_yaw
	elif dir.length() > 0.1:
		face = atan2(-dir.x, -dir.z)
	model.rotation.y = lerp_angle(model.rotation.y, face, minf(1.0, 12.0 * dt))
	_mount_gun()
	var spd: float = hv.length()
	C.animate(parts, spd, G.fire_held(), dt)


# Keeps the gun at the character's right hand, aimed where the body faces.
func _mount_gun() -> void:
	if hand_ref == null or not is_instance_valid(hand_ref):
		return
	gun_holder.global_position = hand_ref.global_position
	gun_holder.global_basis = Basis(Vector3.UP, model.rotation.y)


func _find_car() -> void:
	near_car = null
	var best: float = 4.8
	for c in get_tree().get_nodes_in_group("car"):
		if c.wrecked:
			continue
		var d: float = c.global_position.distance_to(global_position)
		if d < best:
			best = d
			near_car = c


func _pickups() -> void:
	var r2: float = 5.0
	if in_car != null:
		r2 = 16.0
	for p in get_tree().get_nodes_in_group("pickup"):
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length_squared() < r2:
			p.collect(self)


func _on_weapon() -> void:
	if dead:
		return
	wi = (wi + 1) % WEAPONS.size()
	for i in range(guns.size()):
		(guns[i] as Node3D).visible = (i == wi)
	G.message.emit("Weapon: " + weapon_name())


func _shoot() -> void:
	if cd > 0.0:
		return
	var w: Dictionary = WEAPONS[wi]
	cd = w["cd"]
	if w.get("rocket", false):
		_fire_rocket()
		return
	var fwd: Vector3 = -cam.global_transform.basis.z
	var head: Vector3 = global_position + Vector3(0.0, 1.5, 0.0)
	var start: Vector3 = cam.global_position + fwd * (cam.global_position.distance_to(head) * 0.9)
	var yawm: float = model.rotation.y
	var muzzle: Vector3 = gun_holder.global_position + Vector3(-sin(yawm), 0.0, -cos(yawm)) * 0.5
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var rng_m: float = w["range"]
	G.sfx(w["snd"], muzzle, -3.0)
	var parent: Node = get_parent()
	for n in range(int(w["pellets"])):
		var sp: float = w["spread"]
		var d: Vector3 = (fwd + Vector3(randf_range(-sp, sp), randf_range(-sp, sp), randf_range(-sp, sp))).normalized()
		var to: Vector3 = start + d * rng_m
		var q := PhysicsRayQueryParameters3D.create(start, to, 1 | 4 | 8 | 16)
		q.exclude = [get_rid()]
		var h: Dictionary = space.intersect_ray(q)
		var hit_pos: Vector3 = to
		var collider: Object = null
		if not h.is_empty():
			hit_pos = h["position"]
			collider = h["collider"]
		if n == 0:
			var assist: Node3D = _assist(start, fwd, rng_m, space, muzzle)
			if assist != null:
				collider = assist
				hit_pos = assist.global_position + Vector3(0.0, 0.9, 0.0)
				d = (hit_pos - muzzle).normalized()
		_apply_hit(collider, hit_pos, d, w["dmg"])
		U.tracer(parent, muzzle, hit_pos)
		U.spark(parent, hit_pos, Color(1.0, 0.85, 0.35), 0.12)


# Rockets fly from the muzzle along the camera's aim and blow up on contact.
func _fire_rocket() -> void:
	var fwd: Vector3 = -cam.global_transform.basis.z
	var yawm: float = model.rotation.y
	var muzzle: Vector3 = gun_holder.global_position + Vector3(-sin(yawm), 0.0, -cos(yawm)) * 0.6
	G.sfx("res://audio/impact.ogg", muzzle, -4.0, 1.3)
	U.spark(get_parent(), muzzle, Color(1.0, 0.7, 0.3), 0.5)
	var r = RocketScript.new()
	get_parent().add_child(r)
	r.start(muzzle, fwd)


func _assist(start: Vector3, fwd: Vector3, rng_m: float, space: PhysicsDirectSpaceState3D, muzzle: Vector3) -> Node3D:
	var best: Node3D = null
	var best_along: float = 1.0e9
	for g in ["pedestrian", "cop"]:
		for t in get_tree().get_nodes_in_group(g):
			if g == "pedestrian" and t.dead:
				continue
			var c: Vector3 = t.global_position + Vector3(0.0, 0.9, 0.0)
			var v: Vector3 = c - start
			var along: float = v.dot(fwd)
			if along < 2.0 or along > rng_m or along > best_along:
				continue
			var perp: float = (v - fwd * along).length()
			if perp > 1.15:
				continue
			var q := PhysicsRayQueryParameters3D.create(muzzle, c, 1)
			if not space.intersect_ray(q).is_empty():
				continue
			best = t
			best_along = along
	return best


func _apply_hit(collider: Object, pos: Vector3, dir: Vector3, dmg: float) -> void:
	if collider == null:
		return
	if collider.has_method("take_damage"):
		collider.take_damage(dmg, dir, true)
	elif collider is RigidBody3D:
		var rb: RigidBody3D = collider as RigidBody3D
		rb.apply_impulse(dir * dmg * 0.5, pos - rb.global_position)


func _on_interact() -> void:
	if dead:
		return
	if in_car != null:
		exit_car(false)
		return
	if G.house != null and G.house.try_use(self):
		return
	if near_car != null:
		enter_car(near_car)


func enter_car(c) -> void:
	in_car = c
	G.in_car = c
	c.enter_as_player()
	model.visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	G.message.emit("Drive! Use EXIT to get out")


func exit_car(forced: bool) -> void:
	var c = in_car
	if c == null:
		return
	in_car = null
	G.in_car = null
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var rgt: Vector3 = c.global_transform.basis.x
	var base: Vector3 = c.global_position
	var spot: Vector3 = base + Vector3(0.0, 2.5, 0.0)
	var cands: Array = [base + rgt * 2.8, base - rgt * 2.8, base + c.global_transform.basis.z * 3.6, base - c.global_transform.basis.z * 3.6]
	for p in cands:
		var q := PhysicsRayQueryParameters3D.create(base + Vector3(0.0, 0.8, 0.0), (p as Vector3) + Vector3(0.0, 0.8, 0.0), 1)
		if space.intersect_ray(q).is_empty():
			spot = p
			break
	c.leave()
	model.visible = true
	collision_layer = 32
	collision_mask = 1 | 4
	global_position = Vector3(spot.x, 0.15, spot.z)
	velocity = Vector3.ZERO
	if forced:
		health -= 8.0


# Moves the player somewhere else at once (house door, respawn), leaving any car.
func teleport(pos: Vector3) -> void:
	if in_car != null:
		exit_car(false)
	global_position = pos
	velocity = Vector3.ZERO
	jump_req = false
	model.rotation.y = G.cam_yaw


func take_damage(amount: float, _dir: Vector3 = Vector3.ZERO, _by_player: bool = false) -> void:
	if dead:
		return
	health -= amount
	G.sfx("res://audio/enemy_hurt.ogg", global_position, -2.0, 0.7)
	if health <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	if in_car != null:
		exit_car(true)
	C.spawn_corpse(get_parent(), parts, model.global_transform, Vector3(0.0, 3.0, 0.0))
	model.visible = false
	collision_layer = 0
	collision_mask = 0
	G.message.emit("WASTED")
	get_tree().create_timer(3.5).timeout.connect(respawn)


func respawn() -> void:
	G.money = int(float(G.money) * 0.9)
	G.wanted = 0.0
	health = 100.0
	dead = false
	model.visible = true
	collision_layer = 32
	collision_mask = 1 | 4
	global_position = spawn_pos
	velocity = Vector3.ZERO
	G.message.emit("Hospital bill: 10% of your cash")
