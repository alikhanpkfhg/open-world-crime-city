extends RefCounted
# Real rigged, animated characters: Mixamo's "Vanguard" soldier and "X Bot"
# robot, the free Mixamo models shipped with the three.js example assets.
# Each GLB carries idle/walk/run clips; if a model is missing the blocky
# humanoid in humanoid.gd is used instead so the game always runs.

const H = preload("res://scripts/humanoid.gd")

const SOLDIER: String = "res://models/chars/soldier.glb"
const ROBOT: String = "res://models/chars/xbot.glb"

# Both models are authored at human scale (about 1.8 m) with their feet at the
# origin and facing -Z, which is Godot's forward, so they need no fitting.
const HAND_BONE: String = "mixamorig_RightHand"


static func pick(path: String = "") -> String:
	if path != "" and ResourceLoader.exists(path):
		return path
	var pool: Array = []
	if ResourceLoader.exists(SOLDIER):
		pool.append(SOLDIER)
	if ResourceLoader.exists(ROBOT):
		pool.append(ROBOT)
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]


# Instantiates the model at path. Falls back to a blocky humanoid when the
# model can't load. Returns {root, anim, hand, clip_idle, clip_walk,
# clip_run, cur, path, fallback, parts, colors, phase}.
static func build(path: String, shirt: Color, pants: Color, skin: Color, cap: Color = Color(0, 0, 0, 0), scale: float = 1.0) -> Dictionary:
	var rig := {
		"root": null,
		"anim": null,
		"hand": null,
		"clip_idle": &"",
		"clip_walk": &"",
		"clip_run": &"",
		"cur": &"",
		"path": "",
		"fallback": true,
		"parts": {},
		"colors": [shirt, pants, skin],
		"phase": 0.0,
	}
	var inst: Node3D = _instance(path)
	if inst == null:
		rig["parts"] = H.build(shirt, pants, skin, cap)
		rig["root"] = rig["parts"]["root"]
		return rig
	var holder := Node3D.new()
	if absf(scale - 1.0) > 0.001:
		holder.scale = Vector3(scale, scale, scale)
	holder.add_child(inst)
	var ap: AnimationPlayer = _anim_player(inst)
	var clips := {"idle": &"", "walk": &"", "run": &""}
	if ap != null:
		clips = _detect_clips(ap)
	rig["root"] = holder
	rig["anim"] = ap
	rig["clip_idle"] = clips["idle"]
	rig["clip_walk"] = clips["walk"]
	rig["clip_run"] = clips["run"]
	rig["path"] = path
	rig["fallback"] = false
	rig["hand"] = _hand(inst)
	return rig


static func _instance(path: String) -> Node3D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		return null
	var n: Node = ps.instantiate()
	if n is Node3D:
		return n as Node3D
	n.free()
	return null


static func _anim_player(inst: Node) -> AnimationPlayer:
	var best: AnimationPlayer = null
	var best_n: int = -1
	for n in inst.find_children("*", "AnimationPlayer", true, false):
		var ap: AnimationPlayer = n as AnimationPlayer
		if ap == null:
			continue
		var c: int = ap.get_animation_list().size()
		if c > best_n:
			best_n = c
			best = ap
	return best


# Picks idle/walk/run from the imported clip names (case-insensitive) and makes
# them loop - glTF carries no looping flag, so they would play once otherwise.
static func _detect_clips(ap: AnimationPlayer) -> Dictionary:
	var out := {"idle": &"", "walk": &"", "run": &""}
	var names: Array = ap.get_animation_list()
	for nm in names:
		var key: String = String(nm).to_lower()
		var a: Animation = ap.get_animation(nm)
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR
		if out["idle"] == &"" and (key.contains("idle") or key.contains("breath") or key.contains("stand")):
			out["idle"] = nm
		if out["walk"] == &"" and key.contains("walk"):
			out["walk"] = nm
		if out["run"] == &"" and (key.contains("run") or key.contains("jog") or key.contains("sprint")):
			out["run"] = nm
	if out["idle"] == &"" and not names.is_empty():
		out["idle"] = names[0]
	if out["walk"] == &"":
		out["walk"] = out["run"]
	if out["run"] == &"":
		out["run"] = out["walk"]
	return out


# A marker in the right hand; the player mounts its gun there and aims it.
static func _hand(inst: Node3D) -> Node3D:
	var skel: Skeleton3D = null
	for n in inst.find_children("*", "Skeleton3D", true, false):
		skel = n as Skeleton3D
		break
	if skel == null:
		return null
	var idx: int = skel.find_bone(HAND_BONE)
	if idx < 0:
		for i in range(skel.get_bone_count()):
			var bn: String = skel.get_bone_name(i).to_lower()
			if bn.contains("right") and bn.contains("hand") and not bn.contains("thumb") and not bn.contains("index") and not bn.contains("middle") and not bn.contains("ring") and not bn.contains("pinky"):
				idx = i
				break
	if idx < 0:
		return null
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = skel.get_bone_name(idx)
	return att


# Recolours a model by multiplying its albedo (used to vary pedestrians).
static func tint(rig: Dictionary, color: Color) -> void:
	if rig.get("fallback", true):
		return
	var root: Node = rig.get("root", null)
	if root == null:
		return
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var src: Material = mi.mesh.surface_get_material(i)
			if src is StandardMaterial3D:
				var mat: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
				mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
				mi.set_surface_override_material(i, mat)


# Picks the idle/walk/run clip for the current ground speed.
static func animate(rig: Dictionary, speed: float, aim: bool, dt: float) -> void:
	if rig.get("fallback", true):
		var parts: Dictionary = rig.get("parts", {})
		rig["phase"] = float(rig.get("phase", 0.0)) + speed * dt * 2.4
		H.animate(parts, rig["phase"], clampf(speed / 5.0, 0.25, 1.4), aim)
		return
	var ap: AnimationPlayer = rig.get("anim", null) as AnimationPlayer
	if ap == null:
		return
	var c_idle: StringName = rig["clip_idle"]
	var c_walk: StringName = rig["clip_walk"]
	var c_run: StringName = rig["clip_run"]
	var want: StringName = c_idle
	var sp: float = 1.0
	if speed < 0.3:
		want = c_idle
		sp = 1.0
	elif speed < 3.4 and c_walk != &"":
		want = c_walk
		sp = clampf(speed / 1.7, 0.7, 2.2)
	elif c_run != &"":
		want = c_run
		sp = clampf(speed / 6.0, 0.7, 1.9)
	if want == &"":
		return
	if rig["cur"] != want:
		rig["cur"] = want
		ap.play(want, 0.25)
	ap.speed_scale = sp


# Freezes the animation of a model that is far away (cheap for crowds).
static func pause(rig: Dictionary, frozen: bool) -> void:
	var ap: AnimationPlayer = rig.get("anim", null) as AnimationPlayer
	if ap != null:
		ap.speed_scale = 0.0 if frozen else 1.0


# Spawns a physical corpse: the real model frozen mid-stride inside a
# tumbling rigid body, or the jointed box ragdoll when models are missing.
static func spawn_corpse(parent: Node, rig: Dictionary, xf: Transform3D, vel: Vector3) -> void:
	if rig.get("fallback", true) or String(rig.get("path", "")) == "":
		H.spawn_ragdoll(parent, xf, rig.get("colors", H.random_colors()), vel)
		return
	var tree: SceneTree = parent.get_tree()
	if tree == null:
		return
	var old: Array = tree.get_nodes_in_group("ragdoll_root")
	while old.size() >= 6:
		var o: Node = old[0] as Node
		old.pop_front()
		if is_instance_valid(o):
			o.queue_free()
	var rag := Node3D.new()
	rag.add_to_group("ragdoll_root")
	parent.add_child(rag)
	rag.global_transform = xf
	var rb := RigidBody3D.new()
	rb.mass = 70.0
	rb.collision_layer = 8
	rb.collision_mask = 5
	rb.linear_damp = 0.2
	rb.angular_damp = 1.0
	rb.position = Vector3(0.0, 0.9, 0.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.6
	cs.shape = cap
	rb.add_child(cs)
	rag.add_child(rb)
	var corpse: Dictionary = build(String(rig["path"]), Color.WHITE, Color.WHITE, Color.WHITE)
	var vis: Node = corpse.get("root", null) as Node
	if vis != null:
		(vis as Node3D).position = Vector3(0.0, -0.9, 0.0)
		rb.add_child(vis)
	var cap_anim: AnimationPlayer = corpse.get("anim", null) as AnimationPlayer
	if cap_anim != null:
		var clip: StringName = corpse["clip_run"]
		if clip == &"":
			clip = corpse["clip_walk"]
		if clip == &"":
			clip = corpse["clip_idle"]
		if clip != &"":
			cap_anim.play(clip)
			cap_anim.seek(randf() * 0.4, true)
			cap_anim.pause()
	rb.linear_velocity = vel + Vector3(0.0, 1.2, 0.0)
	rb.angular_velocity = Vector3(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
	tree.create_timer(20.0).timeout.connect(rag.queue_free)
