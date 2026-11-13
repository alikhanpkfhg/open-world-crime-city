extends Node3D
# Rocket fired by the Rocket Launcher: flies straight from the muzzle and
# explodes on the first thing it touches, damaging everything nearby.

const U = preload("res://scripts/util.gd")

const SPEED: float = 42.0
const MAX_DIST: float = 95.0
const RADIUS: float = 8.5
const DMG: float = 130.0

var vel: Vector3 = Vector3.ZERO
var flown: float = 0.0
var boom: bool = false
var trail_t: float = 0.0


func _ready() -> void:
	# Body and warhead, drawn along the flight direction (-Z).
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.09
	cm.height = 0.55
	cm.radial_segments = 8
	mi.mesh = cm
	mi.rotation.x = PI * 0.5
	mi.material_override = U.unshaded(Color(1.0, 0.72, 0.3))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.09
	cone.height = 0.22
	cone.radial_segments = 8
	tip.mesh = cone
	tip.rotation.x = -PI * 0.5
	tip.position = Vector3(0.0, 0.0, -0.38)
	tip.material_override = U.unshaded(Color(0.85, 0.15, 0.1))
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tip)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.4
	light.omni_range = 7.0
	add_child(light)


func start(pos: Vector3, direction: Vector3) -> void:
	global_position = pos
	vel = direction.normalized() * SPEED
	if vel.length_squared() > 0.0:
		look_at(pos + vel, Vector3.UP)


func _physics_process(dt: float) -> void:
	var from: Vector3 = global_position
	var to: Vector3 = from + vel * dt
	# World, cars, corpses, pedestrians. The player is excluded so a rocket
	# never detonates on its own shooter in flight.
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 8 | 16)
	var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		global_position = h["position"]
		explode()
		return
	global_position = to
	flown += vel.length() * dt
	trail_t -= dt
	if trail_t <= 0.0:
		trail_t = 0.045
		U.spark(get_parent(), global_position, Color(0.75, 0.75, 0.78), 0.14)
	if flown >= MAX_DIST:
		explode()


func explode() -> void:
	if boom:
		return
	boom = true
	var pos: Vector3 = global_position
	var scene: Node = get_parent()
	U.spark(scene, pos, Color(1.0, 0.6, 0.15), 4.2)
	U.spark(scene, pos + Vector3(0.0, 1.2, 0.0), Color(1.0, 0.9, 0.4), 2.4)
	U.spark(scene, pos + Vector3(0.0, 0.4, 0.0), Color(0.35, 0.33, 0.3), 2.8)
	G.sfx("res://audio/enemy_destroy.ogg", pos, 4.0, 1.0)
	for n in scene.get_tree().get_nodes_in_group("car"):
		if n.exploded:
			continue
		var v: Vector3 = n.global_position - pos
		v.y = 0.0
		var d: float = v.length()
		if d < RADIUS and n.has_method("take_damage"):
			n.take_damage(DMG * (1.0 - d / RADIUS * 0.55), v.normalized(), true)
	for p in scene.get_tree().get_nodes_in_group("pedestrian"):
		if p.dead:
			continue
		var pv: Vector3 = p.global_position - pos
		pv.y = 0.0
		if pv.length() < RADIUS:
			p.hit_by_car(pv.normalized() * 11.0 + Vector3(0.0, 5.0, 0.0), true)
	if G.player != null and not G.player.dead:
		var pd: float = G.player.global_position.distance_to(pos)
		if pd < RADIUS:
			G.player.take_damage(DMG * 0.45 * (1.0 - pd / RADIUS), (G.player.global_position - pos).normalized(), false)
	_blast_bodies(scene, pos)
	queue_free()


# Flings nearby physics corpses (ragdoll parts and bodies).
func _blast_bodies(scene: Node, pos: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return
	var ss := SphereShape3D.new()
	ss.radius = RADIUS
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = ss
	sq.transform = Transform3D(Basis(), pos)
	sq.collision_mask = 8
	sq.collide_with_bodies = true
	for h in space.intersect_shape(sq, 24):
		var rb: Object = h.get("collider")
		if rb is RigidBody3D:
			var body: RigidBody3D = rb as RigidBody3D
			var v: Vector3 = body.global_position + Vector3(0.0, 0.4, 0.0) - pos
			var d: float = maxf(1.5, v.length())
			body.apply_impulse(v.normalized() * 2600.0 / d, Vector3.ZERO)
