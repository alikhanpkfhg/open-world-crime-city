extends Node3D
# World builder + game director: city, traffic, peds, cops, missions.

const U = preload("res://scripts/util.gd")
const CarScript = preload("res://scripts/car.gd")
const PedScript = preload("res://scripts/ped.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const PlayerScript = preload("res://scripts/player.gd")
const HudScript = preload("res://scripts/hud.gd")

const CARS: Array = [
	preload("res://models/cars/vehicle-truck-yellow.glb"),
	preload("res://models/cars/vehicle-truck-green.glb"),
	preload("res://models/cars/vehicle-truck-red.glb"),
	preload("res://models/cars/vehicle-truck-purple.glb"),
]
const COP_MODEL: int = 3
const BUILDINGS: Array = [
	preload("res://models/city/building-small-a.glb"),
	preload("res://models/city/building-small-b.glb"),
	preload("res://models/city/building-small-c.glb"),
	preload("res://models/city/building-small-d.glb"),
	preload("res://models/city/building-garage.glb"),
]
const TREES: Array = [
	preload("res://models/city/grass-trees.glb"),
	preload("res://models/city/grass-trees-tall.glb"),
]
const FOUNTAIN: PackedScene = preload("res://models/city/pavement-fountain.glb")

const TRAFFIC_COUNT: int = 14
const PED_COUNT: int = 38

var traffic: Array = []
var ped_pending: int = 0
var ped_timer: float = 4.0
var cop_timer: float = 1.0
var cull_timer: float = 0.5
var health_timer: float = 20.0
var beacon: MeshInstance3D
var beacon_ring: MeshInstance3D
var player


func _ready() -> void:
	randomize()
	_build_env()
	_build_ground()
	_build_roads()
	_build_markings()
	_build_blocks()
	_build_player()
	_build_hud()
	_spawn_starters()
	_spawn_parked()
	for i in range(TRAFFIC_COUNT):
		_spawn_traffic()
	for i in range(PED_COUNT):
		_spawn_ped()
	_spawn_pickups()
	_build_marker()
	G.ped_died.connect(func() -> void: ped_pending += 1)
	G.message.emit("Welcome to Crime City")
	# Roadmap
	# 1. More vehicles (sports car, police cruiser model) and motorbikes.
	# 2. Missions: timed deliveries, chase-the-suspect, taxi fares.
	# 3. Day/night cycle with street lights on at night.
	# 4. Save/load (money, wanted, position) to user://config.json.
	# 5. Ragdoll impulse tuning + blood decals for heavier hits.


# ------------------------------------------------------------ world

func _build_env() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.48, 0.85)
	sky_mat.sky_horizon_color = Color(0.72, 0.82, 0.92)
	sky_mat.ground_horizon_color = Color(0.72, 0.82, 0.92)
	sky_mat.ground_bottom_color = Color(0.45, 0.5, 0.55)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.82, 0.92)
	env.fog_density = 0.0065
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)


func _plane(sx: float, sz: float, mat: Material, y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(sx, sz)
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(0.0, y, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _static_box(parent: Node, size: Vector3, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	parent.add_child(sb)
	sb.position = pos
	return sb


func _build_ground() -> void:
	_static_box(self, Vector3(900.0, 2.0, 900.0), Vector3(0.0, -1.0, 0.0))
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = U.mip_tex("res://textures/aerial_grass_rock_diff_1k.jpg")
	gm.uv1_scale = Vector3(120.0, 120.0, 1.0)
	gm.roughness = 1.0
	add_child(_plane(900.0, 900.0, gm, 0.0))
	# Invisible walls around the city
	var e: float = 262.0
	_static_box(self, Vector3(4.0, 30.0, 540.0), Vector3(e, 14.0, 0.0))
	_static_box(self, Vector3(4.0, 30.0, 540.0), Vector3(-e, 14.0, 0.0))
	_static_box(self, Vector3(540.0, 30.0, 4.0), Vector3(0.0, 14.0, e))
	_static_box(self, Vector3(540.0, 30.0, 4.0), Vector3(0.0, 14.0, -e))
	var edge := U.box(Vector3(2.0, 3.0, 524.0), U.mat(Color(0.35, 0.37, 0.4)))
	for s in [-1.0, 1.0]:
		var a: MeshInstance3D = edge.duplicate() as MeshInstance3D
		a.position = Vector3(260.0 * s, 1.5, 0.0)
		add_child(a)
		var b := U.box(Vector3(524.0, 3.0, 2.0), U.mat(Color(0.35, 0.37, 0.4)))
		b.position = Vector3(0.0, 1.5, 260.0 * s)
		add_child(b)
	edge.queue_free()


func _build_roads() -> void:
	var tex: Texture2D = U.mip_tex("res://textures/asphalt_02_diff_1k.jpg")
	var mh := StandardMaterial3D.new()
	mh.albedo_texture = tex
	mh.roughness = 0.95
	mh.albedo_color = Color(0.85, 0.85, 0.9)
	var mv: StandardMaterial3D = mh.duplicate() as StandardMaterial3D
	# One texture tile covers ~6 m of road.
	mh.uv1_scale = Vector3(83.0, 2.7, 1.0)
	mv.uv1_scale = Vector3(2.7, 83.0, 1.0)
	for c in U.ROAD_C:
		var h: MeshInstance3D = _plane(500.0, 16.0, mh, 0.05)
		h.position.z = c
		add_child(h)
		var v: MeshInstance3D = _plane(16.0, 500.0, mv, 0.06)
		v.position.x = c
		add_child(v)


func _build_markings() -> void:
	var xfs: Array = []
	var cols: Array = []
	var yellow: Color = Color(0.95, 0.78, 0.12)
	var white: Color = Color(0.92, 0.92, 0.92)
	var rc: Array = U.ROAD_C
	for r in range(rc.size()):
		var c: float = rc[r]
		for g in range(rc.size() - 1):
			var mid: float = (float(rc[g]) + float(rc[g + 1])) * 0.5
			for off in [-0.2, 0.2]:
				xfs.append(Transform3D(Basis.from_scale(Vector3(62.0, 0.03, 0.14)), Vector3(mid, 0.07, c + off)))
				cols.append(yellow)
				xfs.append(Transform3D(Basis.from_scale(Vector3(0.14, 0.03, 62.0)), Vector3(c + off, 0.075, mid)))
				cols.append(yellow)
	for ci in range(rc.size()):
		for cj in range(rc.size()):
			var cx: float = rc[ci]
			var cz: float = rc[cj]
			for s in [-1.0, 1.0]:
				for k in range(10):
					var o: float = -7.2 + float(k) * 1.6
					xfs.append(Transform3D(Basis.from_scale(Vector3(0.7, 0.03, 2.4)), Vector3(cx + o, 0.08, cz + 10.0 * s)))
					cols.append(white)
					xfs.append(Transform3D(Basis.from_scale(Vector3(2.4, 0.03, 0.7)), Vector3(cx + 10.0 * s, 0.085, cz + o)))
					cols.append(white)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = xfs.size()
	for i in range(xfs.size()):
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_blocks() -> void:
	var slab_mat: StandardMaterial3D = U.mat(Color(0.62, 0.62, 0.6))
	var park_mat: StandardMaterial3D = U.mat(Color(0.36, 0.56, 0.3))
	var parks: Array = [Vector2i(3, 3)]
	while parks.size() < 5:
		var v := Vector2i(randi() % 6, randi() % 6)
		if not parks.has(v):
			parks.append(v)
	for bi in range(6):
		for bj in range(6):
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			add_child(body)
			body.position = Vector3(U.BLOCK_C[bi], 0.0, U.BLOCK_C[bj])
			var is_park: bool = parks.has(Vector2i(bi, bj))
			var slab: MeshInstance3D = U.box(Vector3(64.0, U.CURB, 64.0), park_mat if is_park else slab_mat)
			slab.position = Vector3(0.0, U.CURB * 0.5, 0.0)
			slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(slab)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(64.0, U.CURB, 64.0)
			cs.shape = bs
			cs.position = Vector3(0.0, U.CURB * 0.5, 0.0)
			body.add_child(cs)
			if is_park:
				_fill_park(body)
			else:
				_fill_buildings(body)


func _flat(n: Node, vis: float, shadows: bool) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		m.visibility_range_end = vis
		if not shadows:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _fill_buildings(body: StaticBody3D) -> void:
	for gx in range(3):
		for gz in range(3):
			if randf() < 0.08:
				continue
			var idx: int = randi() % BUILDINGS.size()
			var target: float = randf_range(13.5, 16.0)
			var m: Node3D = U.fit_len(BUILDINGS[idx], target)
			var sz: Vector3 = m.get_meta("size")
			var pos := Vector3((float(gx) - 1.0) * 19.5, U.CURB, (float(gz) - 1.0) * 19.5)
			m.position = pos
			body.add_child(m)
			_flat(m, 230.0, false)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(sz.x, sz.y, sz.z)
			cs.shape = bs
			cs.position = pos + Vector3(0.0, sz.y * 0.5, 0.0)
			body.add_child(cs)


func _fill_park(body: StaticBody3D) -> void:
	for i in range(6):
		for j in range(6):
			if i >= 2 and i <= 3 and j >= 2 and j <= 3:
				continue
			if randf() < 0.2:
				continue
			var t: Node3D = U.fit_len(TREES[randi() % TREES.size()], 8.0)
			t.position = Vector3((float(i) - 2.5) * 8.0, U.CURB, (float(j) - 2.5) * 8.0)
			body.add_child(t)
			_flat(t, 170.0, false)
	var f: Node3D = U.fit_len(FOUNTAIN, 16.0)
	f.position = Vector3(0.0, U.CURB, 0.0)
	body.add_child(f)
	_flat(f, 200.0, false)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var fs: Vector3 = f.get_meta("size")
	bs.size = Vector3(minf(fs.x, 7.0), maxf(minf(fs.y, 1.2), 0.5), minf(fs.z, 7.0))
	cs.shape = bs
	cs.position = Vector3(0.0, U.CURB + bs.size.y * 0.5, 0.0)
	body.add_child(cs)


# ------------------------------------------------------------ actors

func _build_player() -> void:
	player = PlayerScript.new()
	player.spawn_pos = Vector3(22.0, 0.3, 10.2)
	add_child(player)
	player.global_position = player.spawn_pos


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.set_script(HudScript)
	layer.add_child(hud)


func _make_car(idx: int, mode: int):
	var c = CarScript.new()
	add_child(c)
	c.setup(CARS[idx], mode)
	return c


func _place_car(car, min_d: float, max_d: float) -> void:
	var pp: Vector3 = player.global_position
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for k in range(40):
		var ci: int = randi() % 7
		var cj: int = randi() % 7
		var d: Vector2i = dirs[randi() % 4]
		if ci + d.x < 0 or ci + d.x > 6 or cj + d.y < 0 or cj + d.y > 6:
			continue
		car.nav_start(ci, cj, d.x, d.y, randf_range(0.15, 0.85))
		var dist: float = car.global_position.distance_to(pp)
		if dist < min_d or dist > max_d:
			continue
		var ok: bool = true
		for o in get_tree().get_nodes_in_group("car"):
			if o != car and o.global_position.distance_to(car.global_position) < 9.0:
				ok = false
				break
		if ok:
			break
	car.speed = 0.0
	car.velocity = Vector3.ZERO


func _spawn_traffic() -> void:
	var c = _make_car(randi() % 3, CarScript.Mode.TRAFFIC)
	_place_car(c, 30.0, 400.0)
	traffic.append(c)


func _spawn_starters() -> void:
	var a = _make_car(0, CarScript.Mode.PARKED)
	a.nav_start(3, 3, 1, 0, 0.3)
	a.position += Vector3(0.0, 0.0, 2.6)
	var b = _make_car(2, CarScript.Mode.PARKED)
	b.nav_start(3, 3, 0, 1, 0.3)
	b.position += Vector3(-2.6, 0.0, 0.0)
	var c = _make_car(1, CarScript.Mode.PARKED)
	c.nav_start(3, 3, 1, 0, 0.62)
	c.position += Vector3(0.0, 0.0, 2.6)


func _spawn_parked() -> void:
	for r in range(7):
		for g in range(6):
			for axis in range(2):
				if randf() > 0.38:
					continue
				var c = _make_car(randi() % 4, CarScript.Mode.PARKED)
				var frac: float = 0.3 if randf() < 0.5 else 0.7
				var dx: int = 1 if axis == 0 else 0
				var dz: int = 1 - dx
				var ci: int = g if axis == 0 else r
				var cj: int = r if axis == 0 else g
				c.nav_start(ci, cj, dx, dz, frac)
				c.position += Vector3(-float(dz), 0.0, float(dx)) * 2.6
				var clash: bool = false
				for o in get_tree().get_nodes_in_group("car"):
					if o != c and o.global_position.distance_to(c.global_position) < 6.5:
						clash = true
						break
				if clash:
					c.remove_from_group("car")
					c.queue_free()


func _spawn_ped() -> void:
	var p = PedScript.new()
	add_child(p)
	for k in range(8):
		p.place(randi() % 12, randi() % 12)
		if p.global_position.distance_to(player.global_position) > 30.0:
			break


func _spawn_pickups() -> void:
	for k in range(10):
		var pk = PickupScript.new()
		pk.kind = "health"
		add_child(pk)
		pk.global_position = U.nav_pos(randi() % 12, randi() % 12)
	for k in range(26):
		var pk2 = PickupScript.new()
		pk2.kind = "cash"
		pk2.value = 25
		pk2.life = 1.0e9
		add_child(pk2)
		pk2.global_position = U.nav_pos(randi() % 12, randi() % 12)


# ------------------------------------------------------------ mission marker

func _build_marker() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.15, 0.3)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	beacon = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.0
	cm.bottom_radius = 3.0
	cm.height = 70.0
	cm.radial_segments = 16
	beacon.mesh = cm
	beacon.material_override = m
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beacon)
	beacon_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 5.5
	tm.outer_radius = 6.5
	tm.rings = 24
	tm.ring_segments = 6
	beacon_ring.mesh = tm
	beacon_ring.material_override = m
	beacon_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beacon_ring)
	_new_marker()


func _new_marker() -> void:
	var pp: Vector3 = player.global_position
	var pos: Vector3 = Vector3.ZERO
	for k in range(25):
		pos = Vector3(U.ROAD_C[randi() % 7], 0.0, U.ROAD_C[randi() % 7])
		if pos.distance_to(pp) > 110.0:
			break
	G.marker_pos = pos
	beacon.position = pos + Vector3(0.0, 35.0, 0.0)
	beacon_ring.position = pos + Vector3(0.0, 0.3, 0.0)


# ------------------------------------------------------------ director

func _process(dt: float) -> void:
	if player == null:
		return
	var pp: Vector3 = player.global_position
	# Delivery missions
	if G.in_car != null:
		var d: Vector3 = G.in_car.global_position - G.marker_pos
		d.y = 0.0
		if d.length() < 9.0:
			var pay: int = 150 + int(G.in_car.hp) * 3
			G.add_money(pay)
			G.message.emit("Delivery complete +$%d" % pay)
			_new_marker()
	# Respawn pedestrians
	if ped_pending > 0:
		ped_timer -= dt
		if ped_timer <= 0.0:
			ped_timer = 4.0
			ped_pending -= 1
			_spawn_ped()
	# Health pickups
	health_timer -= dt
	if health_timer <= 0.0:
		health_timer = 25.0
		var hc: int = 0
		for p in get_tree().get_nodes_in_group("pickup"):
			if p.kind == "health":
				hc += 1
		if hc < 10:
			var pk = PickupScript.new()
			pk.kind = "health"
			add_child(pk)
			pk.global_position = U.nav_pos(randi() % 12, randi() % 12)
	# Cops
	cop_timer -= dt
	if cop_timer <= 0.0:
		cop_timer = 1.5
		_manage_cops(pp)
	# Traffic culling / refilling
	cull_timer -= dt
	if cull_timer <= 0.0:
		cull_timer = 0.6
		_manage_traffic(pp)


func _manage_cops(pp: Vector3) -> void:
	var cops: Array = []
	for c in get_tree().get_nodes_in_group("cop"):
		if is_instance_valid(c) and not c.wrecked:
			cops.append(c)
	var stars: int = G.stars()
	if stars == 0:
		for c in cops:
			c.set_mode(CarScript.Mode.TRAFFIC)
			c._snap_nav()
			c.hp = 100.0
			traffic.append(c)
		return
	var want: int = mini(stars + 1, 6)
	if cops.size() < want:
		var c = _make_car(COP_MODEL, CarScript.Mode.COP)
		c.hp = 80.0
		_place_car(c, 85.0, 160.0)
	for c in cops:
		if c.global_position.distance_to(pp) > 230.0:
			_place_car(c, 90.0, 160.0)


func _manage_traffic(pp: Vector3) -> void:
	var alive: Array = []
	for c in traffic:
		if is_instance_valid(c) and not c.exploded and c.mode == CarScript.Mode.TRAFFIC and not c.wrecked:
			alive.append(c)
	traffic = alive
	while traffic.size() < TRAFFIC_COUNT:
		var c = _make_car(randi() % 3, CarScript.Mode.TRAFFIC)
		_place_car(c, 100.0, 200.0)
		traffic.append(c)
	for c in traffic:
		if c.global_position.distance_to(pp) > 230.0:
			_place_car(c, 100.0, 190.0)
