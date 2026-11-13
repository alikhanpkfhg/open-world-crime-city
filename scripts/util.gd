extends RefCounted

# Road centre lines (both axes) and block centres. Roads are 16 m wide,
# blocks are 64 m wide, so the period is 80 m.
const ROAD_C: Array = [-240.0, -160.0, -80.0, 0.0, 80.0, 160.0, 240.0]
const BLOCK_C: Array = [-200.0, -120.0, -40.0, 40.0, 120.0, 200.0]
# Sidewalk corner coordinates (road centre +/- 10 m). Pedestrians walk between them.
const NAV: Array = [-230.0, -170.0, -150.0, -90.0, -70.0, -10.0, 10.0, 70.0, 90.0, 150.0, 170.0, 230.0]
const CITY_HALF: float = 248.0


const CURB: float = 0.12


static func nav_pos(ix: int, iz: int) -> Vector3:
	return Vector3(NAV[ix], CURB, NAV[iz])


# Loads a texture and gives it mipmaps (imported textures have none by default).
static func mip_tex(path: String) -> Texture2D:
	var t: Texture2D = load(path) as Texture2D
	if t == null:
		return null
	var img: Image = t.get_image()
	if img == null or img.is_compressed() or img.has_mipmaps():
		return t
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


static func unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func box(size: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	return mi


static func _collect_aabbs(node: Node, xf: Transform3D, out: Array) -> void:
	var cur: Transform3D = xf
	if node is Node3D:
		cur = xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			out.append(cur * mi.mesh.get_aabb())
	for c in node.get_children():
		_collect_aabbs(c, cur, out)


static func model_aabb(root: Node3D) -> AABB:
	var out: Array = []
	_collect_aabbs(root, Transform3D.IDENTITY, out)
	if out.is_empty():
		return AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
	var box_aabb: AABB = out[0]
	for i in range(1, out.size()):
		box_aabb = box_aabb.merge(out[i])
	return box_aabb


# +1 when the model's front points to +Z (Kenney vehicles), -1 when it points to -Z.
static func front_sign(inst: Node3D) -> float:
	var f: Node = inst.find_child("wheel-front-left", true, false)
	var b: Node = inst.find_child("wheel-back-left", true, false)
	if f is Node3D and b is Node3D:
		var dz: float = (f as Node3D).position.z - (b as Node3D).position.z
		if absf(dz) > 0.01:
			return signf(dz)
	return 1.0


# Instantiates a model, scales it uniformly so its longest horizontal side is
# `target` metres, and centres it so the origin is at bottom-centre.
static func fit_len(scene: PackedScene, target: float) -> Node3D:
	var inst: Node3D = scene.instantiate() as Node3D
	inst.transform = Transform3D.IDENTITY
	var bb: AABB = model_aabb(inst)
	var s: float = target / maxf(maxf(bb.size.x, bb.size.z), 0.001)
	var holder := Node3D.new()
	holder.scale = Vector3(s, s, s)
	holder.add_child(inst)
	inst.position = Vector3(-(bb.position.x + bb.size.x * 0.5), -bb.position.y, -(bb.position.z + bb.size.z * 0.5))
	holder.set_meta("size", bb.size * s)
	holder.set_meta("front", front_sign(inst))
	return holder


# Same but stretches the model to an exact w x h x d box (bottom-centred).
static func fit_box(scene: PackedScene, w: float, d: float, h: float) -> Node3D:
	var inst: Node3D = scene.instantiate() as Node3D
	inst.transform = Transform3D.IDENTITY
	var bb: AABB = model_aabb(inst)
	var holder := Node3D.new()
	holder.scale = Vector3(w / maxf(bb.size.x, 0.001), h / maxf(bb.size.y, 0.001), d / maxf(bb.size.z, 0.001))
	holder.add_child(inst)
	inst.position = Vector3(-(bb.position.x + bb.size.x * 0.5), -bb.position.y, -(bb.position.z + bb.size.z * 0.5))
	return holder


# The rocket launcher: no model in the asset pool, so it is built from
# primitives (a tube, grip, sight and a red warhead tip), aimed down -Z.
static func rocket_launcher() -> Node3D:
	var holder := Node3D.new()
	var tube := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.09
	cm.height = 0.95
	cm.radial_segments = 12
	tube.mesh = cm
	tube.rotation.x = PI * 0.5
	tube.material_override = mat(Color(0.36, 0.42, 0.3), 0.55)
	tube.position = Vector3(0.0, 0.0, -0.12)
	holder.add_child(tube)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.09
	cone.height = 0.2
	cone.radial_segments = 12
	tip.mesh = cone
	tip.rotation.x = -PI * 0.5
	tip.position = Vector3(0.0, 0.0, -0.7)
	tip.material_override = mat(Color(0.75, 0.2, 0.15), 0.5)
	holder.add_child(tip)
	var grip := box(Vector3(0.09, 0.24, 0.15), mat(Color(0.2, 0.2, 0.22), 0.7))
	grip.position = Vector3(0.0, -0.17, 0.06)
	holder.add_child(grip)
	var sight := box(Vector3(0.05, 0.1, 0.12), mat(Color(0.15, 0.15, 0.17), 0.7))
	sight.position = Vector3(0.0, 0.14, 0.12)
	holder.add_child(sight)
	return holder


static func set_vis_range(root: Node, dist: float) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).visibility_range_end = dist



# Short-lived bullet tracer between two points.
static func tracer(parent: Node, a: Vector3, b: Vector3, color: Color = Color(1.0, 0.9, 0.4)) -> void:
	var dist: float = a.distance_to(b)
	if dist < 0.1:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, dist)
	mi.mesh = bm
	mi.material_override = unshaded(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = (a + b) * 0.5
	var up: Vector3 = Vector3.UP
	if absf((b - a).normalized().dot(up)) > 0.98:
		up = Vector3.RIGHT
	mi.look_at(b, up)
	parent.get_tree().create_timer(0.07).timeout.connect(mi.queue_free)


# Short-lived impact flash.
static func spark(parent: Node, pos: Vector3, color: Color, radius: float = 0.18) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = unshaded(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	parent.get_tree().create_timer(0.12).timeout.connect(mi.queue_free)
