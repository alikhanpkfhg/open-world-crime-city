extends CharacterBody3D
# Cars: parked / abandoned / driven by the player / traffic AI / police AI.

const U = preload("res://scripts/util.gd")
const PedScript = preload("res://scripts/ped.gd")

enum Mode { PARKED, EMPTY, PLAYER, TRAFFIC, COP }

const LANE: float = 3.6
const MAXI: int = 6

var mode: int = Mode.PARKED
var hp: float = 100.0
var speed: float = 0.0
var steer: float = 0.0
var size: Vector3 = Vector3(2.0, 1.5, 4.4)
var model: Node3D
var wrecked: bool = false
var exploded: bool = false
var burn_t: float = 4.0
var flame: MeshInstance3D = null
var engine: AudioStreamPlayer3D = null
var siren_a: MeshInstance3D = null
var siren_b: MeshInstance3D = null
var mat_a: StandardMaterial3D = null
var mat_b: StandardMaterial3D = null
var cx: int = 0
var cz: int = 0
var hx: int = 0
var hz: int = 1
var tgt: Vector3 = Vector3.ZERO
var obstacle: bool = false
var obs_t: float = 0.0
var blocked_t: float = 0.0
var ignore_t: float = 0.0
var stuck_t: float = 0.0
var reverse_t: float = 0.0
var shoot_cd: float = 1.5
var los_t: float = 0.0
var los_clear: bool = false
var chase_direct: bool = false
var was_direct: bool = false
var ped_t: float = 0.0


static func road_pos(i: int, j: int) -> Vector3:
	return Vector3(U.ROAD_C[i], 0.0, U.ROAD_C[j])


func setup(scene: PackedScene, m: int) -> void:
	collision_layer = 4
	collision_mask = 1 | 4
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("car")
	var holder: Node3D = U.fit_len(scene, 4.4)
	size = holder.get_meta("size")
	var fs: float = holder.get_meta("front")
	model = Node3D.new()
	add_child(model)
	model.add_child(holder)
	if fs > 0.0:
		holder.rotation.y = PI
	U.set_vis_range(holder, 260.0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x * 0.92, 1.1, size.z * 0.96)
	cs.shape = bs
	cs.position = Vector3(0.0, 0.75, 0.0)
	add_child(cs)
	set_mode(m)


# Place the car in the right-hand lane between road node (ci,cj) and the next one.
func nav_start(ci: int, cj: int, dx: int, dz: int, frac: float) -> void:
	cx = ci
	cz = cj
	hx = dx
	hz = dz
	var a: Vector3 = road_pos(ci, cj)
	var b: Vector3 = road_pos(ci + dx, cj + dz)
	var r: Vector3 = Vector3(-float(dz), 0.0, float(dx))
	position = a.lerp(b, frac) + r * LANE
	position.y = 0.05
	rotation.y = atan2(-float(dx), -float(dz))
	tgt = b + r * LANE


func set_mode(m: int) -> void:
	mode = m
	if m != Mode.COP and is_in_group("cop"):
		remove_from_group("cop")
	if m == Mode.COP:
		add_to_group("cop")
		_ensure_siren()
	if siren_a != null:
		siren_a.visible = (m == Mode.COP) and not wrecked
		siren_b.visible = siren_a.visible
	if (m == Mode.PLAYER or m == Mode.COP) and not wrecked:
		_start_engine()
	else:
		_stop_engine()


func _ensure_siren() -> void:
	if siren_a != null:
		return
	mat_a = StandardMaterial3D.new()
	mat_a.albedo_color = Color(1.0, 0.1, 0.1)
	mat_a.emission_enabled = true
	mat_a.emission = Color(1.0, 0.1, 0.1)
	mat_b = StandardMaterial3D.new()
	mat_b.albedo_color = Color(0.1, 0.3, 1.0)
	mat_b.emission_enabled = true
	mat_b.emission = Color(0.1, 0.3, 1.0)
	siren_a = U.box(Vector3(0.45, 0.14, 0.3), mat_a)
	siren_b = U.box(Vector3(0.45, 0.14, 0.3), mat_b)
	var y: float = size.y + 0.05
	siren_a.position = Vector3(-0.35, y, 0.0)
	siren_b.position = Vector3(0.35, y, 0.0)
	add_child(siren_a)
	add_child(siren_b)


func _start_engine() -> void:
	if engine == null:
		engine = AudioStreamPlayer3D.new()
		var s: AudioStreamOggVorbis = load("res://audio/engine.ogg") as AudioStreamOggVorbis
		if s != null:
			s.loop = true
		engine.stream = s
		engine.unit_size = 12.0
		engine.max_distance = 90.0
		engine.volume_db = -8.0
		add_child(engine)
	if not engine.playing:
		engine.play()


func _stop_engine() -> void:
	if engine != null:
		engine.stop()


func enter_as_player() -> void:
	var was: int = mode
	if was == Mode.TRAFFIC or was == Mode.COP:
		_eject_driver()
		if was == Mode.COP:
			G.add_wanted(1.5)
		else:
			G.add_wanted(0.8)
		G.message.emit("Carjacked!")
	speed = 0.0
	set_mode(Mode.PLAYER)


func leave() -> void:
	set_mode(Mode.EMPTY)


func _eject_driver() -> void:
	var p = PedScript.new()
	get_parent().add_child(p)
	p.place(randi() % 12, randi() % 12)
	p.global_position = global_position + global_transform.basis.x * 2.6
	p.scare(8.0)


func _physics_process(dt: float) -> void:
	if exploded:
		return
	if wrecked:
		_burn(dt)
		speed = move_toward(speed, 0.0, 8.0 * dt)
		_move(dt)
		return
	if mode == Mode.PARKED:
		if absf(speed) < 0.05:
			return
		speed = move_toward(speed, 0.0, 10.0 * dt)
	elif mode == Mode.EMPTY:
		speed = move_toward(speed, 0.0, 9.0 * dt)
		steer = 0.0
	elif mode == Mode.PLAYER:
		_drive_player(dt)
	else:
		_drive_ai(dt)
	_move(dt)
	_hit_peds(dt)
	_effects(dt)


func _drive_player(dt: float) -> void:
	var mv: Vector2 = G.get_move()
	var thr: float = mv.y
	steer = lerpf(steer, mv.x, minf(1.0, 8.0 * dt))
	if thr > 0.05:
		var target: float = 26.0 * thr
		if speed < target:
			speed = move_toward(speed, target, 15.0 * dt)
		elif speed > target + 1.0:
			speed = move_toward(speed, target, 6.0 * dt)
	elif thr < -0.05:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, 28.0 * dt)
		else:
			speed = move_toward(speed, -9.0, 10.0 * dt)
	else:
		speed = move_toward(speed, 0.0, 4.0 * dt)
	if G.brake_held():
		speed = move_toward(speed, 0.0, 34.0 * dt)
	_apply_steer(dt, 2.0)


func _apply_steer(dt: float, rate: float) -> void:
	var f: float = clampf(absf(speed) / 6.0, 0.0, 1.0)
	var hi: float = 1.0 - 0.5 * clampf(absf(speed) / 26.0, 0.0, 1.0)
	rotation.y -= steer * rate * f * hi * signf(speed) * dt


func _move(dt: float) -> void:
	var fwd: Vector3 = -global_transform.basis.z
	velocity = velocity.lerp(fwd * speed, minf(1.0, 7.0 * dt))
	velocity.y = 0.0
	var pre: Vector3 = velocity
	move_and_slide()
	for i in range(get_slide_collision_count()):
		var c: KinematicCollision3D = get_slide_collision(i)
		var n: Vector3 = c.get_normal()
		var impact: float = -pre.dot(n)
		if impact > 1.5:
			speed -= signf(speed) * minf(absf(speed), impact * 0.9)
			if impact > 4.0:
				take_damage(impact * 2.0, n, false)
				G.sfx("res://audio/impact.ogg", global_position, minf(0.0, -14.0 + impact), randf_range(0.8, 1.1))
				var other: Object = c.get_collider()
				if other != null and other.has_method("take_damage"):
					other.take_damage(impact * 1.5, -n, mode == Mode.PLAYER)


func _hit_peds(dt: float) -> void:
	if absf(speed) < 3.0:
		return
	ped_t -= dt
	if ped_t > 0.0:
		return
	ped_t = 0.05
	var inv: Transform3D = global_transform.affine_inverse()
	var hw: float = size.x * 0.5 + 0.35
	var hl: float = size.z * 0.5 + 0.2
	for p in get_tree().get_nodes_in_group("pedestrian"):
		if p.dead:
			continue
		if p.global_position.distance_squared_to(global_position) > 30.0:
			continue
		var l: Vector3 = inv * p.global_position
		if absf(l.x) < hw and absf(l.z) < hl:
			p.hit_by_car(velocity, mode == Mode.PLAYER)
			speed *= 0.97
	if mode != Mode.PLAYER and G.in_car == null and G.player != null and not G.player.dead:
		var l2: Vector3 = inv * G.player.global_position
		if absf(l2.x) < hw and absf(l2.z) < hl and absf(l2.y) < 2.0:
			G.player.take_damage(absf(speed) * 2.5, Vector3.ZERO, false)
			speed *= 0.8


func _effects(dt: float) -> void:
	model.rotation.z = lerpf(model.rotation.z, steer * clampf(speed, -20.0, 20.0) * 0.0035, minf(1.0, 6.0 * dt))
	if engine != null and engine.playing:
		engine.pitch_scale = 0.7 + absf(speed) / 26.0 * 1.9
	if siren_a != null and siren_a.visible:
		var on: bool = int(G.time * 6.0) % 2 == 0
		mat_a.emission_energy_multiplier = 3.0 if on else 0.1
		mat_b.emission_energy_multiplier = 0.1 if on else 3.0


# ---------------------------------------------------------------- AI

func _snap_nav() -> void:
	cx = clampi(roundi((global_position.x + 240.0) / 80.0), 0, MAXI)
	cz = clampi(roundi((global_position.z + 240.0) / 80.0), 0, MAXI)
	_choose_heading()
	tgt = road_pos(cx + hx, cz + hz) + Vector3(-float(hz), 0.0, float(hx)) * LANE


func _advance() -> void:
	cx = clampi(cx + hx, 0, MAXI)
	cz = clampi(cz + hz, 0, MAXI)
	_choose_heading()
	tgt = road_pos(cx + hx, cz + hz) + Vector3(-float(hz), 0.0, float(hx)) * LANE


func _choose_heading() -> void:
	var opts: Array = []
	var cand: Array = [Vector2i(hx, hz), Vector2i(hz, -hx), Vector2i(-hz, hx)]
	for c in cand:
		var v: Vector2i = c
		var nx: int = cx + v.x
		var nz: int = cz + v.y
		if nx < 0 or nx > MAXI or nz < 0 or nz > MAXI:
			continue
		opts.append(v)
	if opts.is_empty():
		opts.append(Vector2i(-hx, -hz))
	var pick: Vector2i = opts[0]
	if mode == Mode.COP and G.player != null:
		var best: float = 1.0e12
		for o in opts:
			var ov: Vector2i = o
			var np: Vector3 = road_pos(cx + ov.x, cz + ov.y)
			var d: float = np.distance_squared_to(G.player.global_position)
			if d < best:
				best = d
				pick = ov
	elif opts.size() > 1 and randf() > 0.55:
		pick = opts[randi() % opts.size()]
	hx = pick.x
	hz = pick.y


func _clear_to(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 1.0, 0.0), p + Vector3(0.0, 1.0, 0.0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _scan_obstacle(fwd: Vector3) -> bool:
	var pos: Vector3 = global_position
	var rgt: Vector3 = Vector3(-fwd.z, 0.0, fwd.x)
	var look: float = 8.0 + absf(speed) * 0.55
	for g in ["car", "pedestrian"]:
		for o in get_tree().get_nodes_in_group(g):
			if o == self:
				continue
			var d: Vector3 = o.global_position - pos
			var f: float = d.dot(fwd)
			if f < 1.0 or f > look:
				continue
			if absf(d.dot(rgt)) < 2.4:
				return true
	if G.player != null and G.in_car == null and not G.player.dead:
		var d2: Vector3 = G.player.global_position - pos
		var f2: float = d2.dot(fwd)
		if f2 > 1.0 and f2 < look and absf(d2.dot(rgt)) < 2.2:
			return true
	return false


func _cop_shoot(pl: Vector3) -> void:
	var from: Vector3 = global_position + Vector3(0.0, 1.5, 0.0)
	var to: Vector3 = pl + Vector3(0.0, 1.0, 0.0)
	if G.in_car != null:
		to = G.in_car.global_position + Vector3(0.0, 0.8, 0.0)
	var hit: bool = randf() < 0.45
	if not hit:
		to += Vector3(randf_range(-2.0, 2.0), randf_range(-0.5, 1.0), randf_range(-2.0, 2.0))
	U.tracer(get_parent(), from, to, Color(1.0, 0.5, 0.4))
	G.sfx("res://audio/blaster.ogg", from, -8.0, 0.8)
	if hit:
		if G.in_car != null:
			G.in_car.take_damage(6.0, Vector3.ZERO, false)
		else:
			G.player.take_damage(7.0, Vector3.ZERO, false)


func _drive_ai(dt: float) -> void:
	var cop: bool = (mode == Mode.COP)
	var pos: Vector3 = global_position
	var fwd: Vector3 = -global_transform.basis.z
	var have_pl: bool = G.player != null and not G.player.dead
	var pl: Vector3 = Vector3.ZERO
	if have_pl:
		pl = G.player.global_position
	var target_speed: float = 11.0
	var dist: float = 999.0
	if cop:
		target_speed = 19.0 + 1.5 * float(G.stars())
	chase_direct = false
	if cop and have_pl:
		dist = pos.distance_to(pl)
		los_t -= dt
		if los_t <= 0.0:
			los_t = 0.25
			los_clear = dist < 45.0 and _clear_to(pl)
		chase_direct = los_clear and dist < 45.0
		shoot_cd -= dt
		if shoot_cd <= 0.0 and los_clear and dist < 34.0:
			shoot_cd = randf_range(0.7, 1.2)
			_cop_shoot(pl)
	if was_direct and not chase_direct:
		_snap_nav()
	was_direct = chase_direct
	var to: Vector3
	if chase_direct:
		to = pl - pos
		if dist < 8.0:
			target_speed = minf(target_speed, 12.0)
	else:
		to = tgt - pos
		var along: float = to.x * float(hx) + to.z * float(hz)
		if along < 6.0:
			_advance()
			to = tgt - pos
	to.y = 0.0
	obs_t -= dt
	if obs_t <= 0.0:
		obs_t = 0.15
		obstacle = (not chase_direct) and _scan_obstacle(fwd)
	ignore_t -= dt
	if obstacle and ignore_t <= 0.0:
		target_speed = 0.0
		blocked_t += dt
		if blocked_t > 4.0:
			ignore_t = 2.5
			blocked_t = 0.0
	else:
		blocked_t = maxf(0.0, blocked_t - dt)
	var desired: float = atan2(-to.x, -to.z)
	var diff: float = angle_difference(rotation.y, desired)
	var st: float = clampf(-diff * 2.5, -1.0, 1.0)
	if absf(diff) > 0.7:
		target_speed = minf(target_speed, 7.0)
	if reverse_t > 0.0:
		reverse_t -= dt
		target_speed = -5.0
		st = -st
	steer = lerpf(steer, st, minf(1.0, 6.0 * dt))
	if target_speed >= speed:
		speed = move_toward(speed, target_speed, 12.0 * dt)
	else:
		speed = move_toward(speed, target_speed, 22.0 * dt)
	_apply_steer(dt, 2.0)
	if reverse_t <= 0.0 and target_speed > 2.0 and velocity.length() < 0.8:
		stuck_t += dt
		if stuck_t > 1.6:
			stuck_t = 0.0
			reverse_t = 1.1
	else:
		stuck_t = 0.0


# ---------------------------------------------------------------- damage

func take_damage(amount: float, _dir: Vector3 = Vector3.ZERO, by_player: bool = false) -> void:
	if exploded or wrecked:
		return
	hp -= amount
	if hp <= 0.0:
		_wreck(by_player)


func _wreck(by_player: bool) -> void:
	wrecked = true
	var m0: int = mode
	if m0 == Mode.PLAYER and G.player != null:
		G.player.exit_car(true)
		G.message.emit("Your car is on fire!")
	if by_player:
		if m0 == Mode.COP:
			G.add_money(300)
			G.add_wanted(0.5)
			G.message.emit("Cop car destroyed +$300")
		elif m0 != Mode.PLAYER:
			G.add_wanted(0.4)
	set_mode(Mode.EMPTY)
	var dark: StandardMaterial3D = U.mat(Color(0.07, 0.07, 0.08))
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = dark
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.5, 0.1)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.45, 0.05)
	fm.emission_energy_multiplier = 2.5
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	sm.radial_segments = 8
	sm.rings = 4
	flame.mesh = sm
	flame.material_override = fm
	flame.position = Vector3(0.0, 1.3, 0.0)
	add_child(flame)


func _burn(dt: float) -> void:
	burn_t -= dt
	if flame != null:
		flame.scale = Vector3.ONE * (0.8 + randf() * 0.6)
	if burn_t <= 0.0:
		_explode()


func _explode() -> void:
	exploded = true
	var scene: Node = get_parent()
	U.spark(scene, global_position + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.55, 0.1), 3.2)
	G.sfx("res://audio/enemy_destroy.ogg", global_position, 4.0, 0.7)
	if G.player != null and not G.player.dead:
		var d: float = G.player.global_position.distance_to(global_position)
		if d < 9.0:
			G.player.take_damage(45.0 * (1.0 - d / 9.0) + 5.0, Vector3.ZERO, false)
	for p in get_tree().get_nodes_in_group("pedestrian"):
		if p.dead:
			continue
		var v: Vector3 = p.global_position - global_position
		if v.length() < 9.0:
			p.hit_by_car(v.normalized() * 10.0, false)
	if flame != null:
		flame.queue_free()
		flame = null
	speed = 0.0
	get_tree().create_timer(40.0).timeout.connect(queue_free)
