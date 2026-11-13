extends RefCounted

const U = preload("res://scripts/util.gd")


static func _limb(parent: Node3D, pivot: Vector3, size: Vector3, mat: Material, tip_mat: Material, tip_size: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pivot
	parent.add_child(p)
	var m: MeshInstance3D = U.box(size, mat)
	m.position = Vector3(0.0, -size.y * 0.5, 0.0)
	p.add_child(m)
	if tip_mat != null:
		var t: MeshInstance3D = U.box(tip_size, tip_mat)
		t.position = Vector3(0.0, -size.y + tip_size.y * 0.5 - 0.02, 0.0)
		if tip_size.z > 0.25:
			t.position.z = -0.04
		p.add_child(t)
	return p


# Builds a blocky humanoid facing -Z. Returns {root, arm_l, arm_r, leg_l, leg_r, head}.
static func build(shirt: Color, pants: Color, skin: Color, cap: Color = Color(0, 0, 0, 0)) -> Dictionary:
	var root := Node3D.new()
	var sm: StandardMaterial3D = U.mat(shirt)
	var pm: StandardMaterial3D = U.mat(pants)
	var km: StandardMaterial3D = U.mat(skin)
	var shoe: StandardMaterial3D = U.mat(Color(0.1, 0.1, 0.1))
	var torso: MeshInstance3D = U.box(Vector3(0.5, 0.6, 0.28), sm)
	torso.position = Vector3(0.0, 1.1, 0.0)
	root.add_child(torso)
	var head: MeshInstance3D = U.box(Vector3(0.26, 0.28, 0.26), km)
	head.position = Vector3(0.0, 1.56, 0.0)
	root.add_child(head)
	var hair_col: Color = Color(0.15, 0.1, 0.07)
	if cap.a > 0.0:
		hair_col = cap
	var hair: MeshInstance3D = U.box(Vector3(0.29, 0.1, 0.29), U.mat(hair_col))
	hair.position = Vector3(0.0, 0.12, 0.0)
	head.add_child(hair)
	var arm_l: Node3D = _limb(root, Vector3(-0.34, 1.38, 0.0), Vector3(0.14, 0.58, 0.14), sm, km, Vector3(0.13, 0.13, 0.13))
	var arm_r: Node3D = _limb(root, Vector3(0.34, 1.38, 0.0), Vector3(0.14, 0.58, 0.14), sm, km, Vector3(0.13, 0.13, 0.13))
	var leg_l: Node3D = _limb(root, Vector3(-0.13, 0.8, 0.0), Vector3(0.2, 0.8, 0.2), pm, shoe, Vector3(0.22, 0.1, 0.3))
	var leg_r: Node3D = _limb(root, Vector3(0.13, 0.8, 0.0), Vector3(0.2, 0.8, 0.2), pm, shoe, Vector3(0.22, 0.1, 0.3))
	return {"root": root, "arm_l": arm_l, "arm_r": arm_r, "leg_l": leg_l, "leg_r": leg_r, "head": head}


static func animate(parts: Dictionary, phase: float, amount: float, aim: bool) -> void:
	var s: float = sin(phase) * amount * 0.9
	(parts["leg_l"] as Node3D).rotation.x = s
	(parts["leg_r"] as Node3D).rotation.x = -s
	(parts["arm_l"] as Node3D).rotation.x = -s * 0.8
	var ar: Node3D = parts["arm_r"] as Node3D
	if aim:
		ar.rotation.x = lerpf(ar.rotation.x, PI * 0.5, 0.35)
	else:
		ar.rotation.x = lerpf(ar.rotation.x, s * 0.8, 0.35)


static func _part(parent: Node3D, size: Vector3, pos: Vector3, material: Material, mass: float) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.mass = mass
	rb.collision_layer = 8
	rb.collision_mask = 5
	rb.linear_damp = 0.15
	rb.angular_damp = 1.5
	rb.add_to_group("ragdoll")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	rb.add_child(cs)
	rb.add_child(U.box(size, material))
	parent.add_child(rb)
	rb.position = pos
	return rb


static func _joint(parent: Node3D, a: RigidBody3D, b: RigidBody3D, pos: Vector3, axis_down: bool) -> void:
	var j := ConeTwistJoint3D.new()
	parent.add_child(j)
	j.position = pos
	if axis_down:
		j.rotation.z = -PI * 0.5
	else:
		j.rotation.z = PI * 0.5
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)


# Spawns a physics ragdoll (6 rigid bodies + cone-twist joints) at xf.
static func spawn_ragdoll(parent: Node, xf: Transform3D, colors: Array, vel: Vector3) -> void:
	var tree: SceneTree = parent.get_tree()
	var old: Array = tree.get_nodes_in_group("ragdoll_root")
	if old.size() >= 8:
		(old[0] as Node).queue_free()
	var rag := Node3D.new()
	rag.add_to_group("ragdoll_root")
	parent.add_child(rag)
	rag.global_transform = xf
	var sm: StandardMaterial3D = U.mat(colors[0])
	var pm: StandardMaterial3D = U.mat(colors[1])
	var km: StandardMaterial3D = U.mat(colors[2])
	var torso: RigidBody3D = _part(rag, Vector3(0.5, 0.6, 0.28), Vector3(0.0, 1.1, 0.0), sm, 12.0)
	var head: RigidBody3D = _part(rag, Vector3(0.26, 0.28, 0.26), Vector3(0.0, 1.58, 0.0), km, 4.0)
	var arm_l: RigidBody3D = _part(rag, Vector3(0.14, 0.62, 0.14), Vector3(-0.34, 1.08, 0.0), sm, 3.0)
	var arm_r: RigidBody3D = _part(rag, Vector3(0.14, 0.62, 0.14), Vector3(0.34, 1.08, 0.0), sm, 3.0)
	var leg_l: RigidBody3D = _part(rag, Vector3(0.2, 0.8, 0.2), Vector3(-0.13, 0.4, 0.0), pm, 7.0)
	var leg_r: RigidBody3D = _part(rag, Vector3(0.2, 0.8, 0.2), Vector3(0.13, 0.4, 0.0), pm, 7.0)
	_joint(rag, torso, head, Vector3(0.0, 1.42, 0.0), false)
	_joint(rag, torso, arm_l, Vector3(-0.34, 1.38, 0.0), true)
	_joint(rag, torso, arm_r, Vector3(0.34, 1.38, 0.0), true)
	_joint(rag, torso, leg_l, Vector3(-0.13, 0.8, 0.0), true)
	_joint(rag, torso, leg_r, Vector3(0.13, 0.8, 0.0), true)
	for rb in [torso, head, arm_l, arm_r, leg_l, leg_r]:
		var body: RigidBody3D = rb as RigidBody3D
		body.linear_velocity = vel + Vector3(randf_range(-1.0, 1.0), randf_range(0.0, 1.5), randf_range(-1.0, 1.0))
		body.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	tree.create_timer(15.0).timeout.connect(rag.queue_free)



const SHIRTS: Array = [Color(0.85, 0.2, 0.2), Color(0.2, 0.45, 0.85), Color(0.9, 0.8, 0.2), Color(0.25, 0.7, 0.35), Color(0.9, 0.9, 0.9), Color(0.6, 0.3, 0.7), Color(0.95, 0.5, 0.15), Color(0.15, 0.15, 0.18)]
const PANTS: Array = [Color(0.15, 0.17, 0.3), Color(0.2, 0.2, 0.22), Color(0.4, 0.3, 0.2), Color(0.3, 0.35, 0.5), Color(0.55, 0.55, 0.6)]
const SKINS: Array = [Color(0.96, 0.8, 0.65), Color(0.8, 0.6, 0.45), Color(0.55, 0.38, 0.28), Color(0.38, 0.25, 0.18)]


static func random_colors() -> Array:
	return [SHIRTS[randi() % SHIRTS.size()], PANTS[randi() % PANTS.size()], SKINS[randi() % SKINS.size()]]
