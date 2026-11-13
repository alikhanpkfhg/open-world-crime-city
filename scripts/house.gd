extends Node3D
# The player's home: a small house on a city block and the furnished room
# behind its door. The door teleports between the two, so the house has a real
# interior without a second scene or a loading screen.

const U = preload("res://scripts/util.gd")

# City block kept clear of buildings for the house (index into U.BLOCK_C).
const BLOCK: Vector2i = Vector2i(2, 2)
const CITY_POS: Vector3 = Vector3(-40.0, 0.0, -40.0)
const WIDTH: float = 9.0
const DEPTH: float = 8.0
const WALL_H: float = 3.0

# The room sits in its own space straight below the house, so the minimap,
# traffic and police keep treating the player as standing at home.
const INTERIOR_ORIGIN: Vector3 = Vector3(-40.0, -20.0, -40.0)
const INTERIOR_DOOR: Vector3 = Vector3(5.0, 0.0, 0.0)
const INTERIOR_SPAWN: Vector3 = Vector3(-1.0, 0.2, 0.0)

# Street side of the door, and the door's outward facing (the camera yaw used
# when teleporting, since the front of the house points at +X).
const EXIT_POS: Vector3 = Vector3(-31.5, 0.35, -40.0)
const USE_RADIUS: float = 3.2
const YAW_OUT: float = -PI * 0.5


var city_pos: Vector3 = CITY_POS
var exit_pos: Vector3 = EXIT_POS
var interior_spawn: Vector3 = INTERIOR_ORIGIN + INTERIOR_SPAWN


func build() -> void:
	_build_exterior()
	_build_interior()


# ------------------------------------------------------------ queries

func city_door() -> Vector3:
	return Vector3(CITY_POS.x + WIDTH * 0.5, 0.0, CITY_POS.z)


func interior_door() -> Vector3:
	return INTERIOR_ORIGIN + INTERIOR_DOOR


func is_inside(pl) -> bool:
	if pl == null:
		return false
	var p: Vector3 = pl.global_position
	if p.y > INTERIOR_ORIGIN.y + 4.0:
		return false
	var d := Vector2(p.x - INTERIOR_ORIGIN.x, p.z - INTERIOR_ORIGIN.z)
	return d.length_squared() < 400.0


# "" when no door is in reach, otherwise the button label to show.
func prompt(pl) -> String:
	if pl == null:
		return ""
	if is_inside(pl):
		if _near(pl.global_position, interior_door(), USE_RADIUS):
			return "LEAVE"
		return ""
	if _near(pl.global_position, city_door(), USE_RADIUS):
		return "HOME"
	return ""


func try_use(pl) -> bool:
	if pl == null:
		return false
	if is_inside(pl):
		if not _near(pl.global_position, interior_door(), USE_RADIUS):
			return false
		G.cam_yaw = YAW_OUT
		pl.teleport(exit_pos)
		G.message.emit("Back on the street")
		return true
	if not _near(pl.global_position, city_door(), USE_RADIUS):
		return false
	G.cam_yaw = YAW_OUT
	pl.teleport(interior_spawn)
	G.message.emit("Home sweet home")
	return true


func _near(a: Vector3, b: Vector3, r: float) -> bool:
	var d := Vector2(a.x - b.x, a.z - b.z)
	return d.length_squared() < r * r


# ------------------------------------------------------------ building

func _glow(color: Color, energy: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _solid(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rough: float = 0.9) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.add_child(U.box(size, U.mat(color, rough)))
	parent.add_child(sb)
	sb.position = pos
	return sb


func _build_exterior() -> void:
	var g := Node3D.new()
	add_child(g)
	g.position = Vector3(CITY_POS.x, U.CURB, CITY_POS.z)
	var wall := Color(0.88, 0.84, 0.74)
	var wood := Color(0.45, 0.3, 0.2)
	var roof_col := Color(0.56, 0.24, 0.2)
	var face: float = WIDTH * 0.5

	# Walls (solid, so the house can't be walked through) and gabled roof.
	_solid(g, Vector3(WIDTH, WALL_H, DEPTH), Vector3(0.0, WALL_H * 0.5, 0.0), wall)
	var rise: float = 2.2
	var slope: float = sqrt(WIDTH * WIDTH * 0.25 + rise * rise) + 0.3
	var tilt: float = atan2(rise, WIDTH * 0.5)
	for s in [-1.0, 1.0]:
		var slab := U.box(Vector3(slope, 0.22, DEPTH + 0.8), U.mat(roof_col))
		slab.position = Vector3(float(s) * WIDTH * 0.25, WALL_H + rise * 0.5, 0.0)
		slab.rotation.z = -tilt * float(s)
		g.add_child(slab)

	# Front door, step and porch lamp on the +X face.
	_solid(g, Vector3(0.14, 2.2, 1.3), Vector3(face + 0.02, 1.1, 0.0), wood)
	var step := U.box(Vector3(1.0, 0.16, 1.8), U.mat(Color(0.62, 0.62, 0.62)))
	step.position = Vector3(face + 0.55, 0.08, 0.0)
	g.add_child(step)
	var lamp := U.box(Vector3(0.26, 0.3, 0.26), _glow(Color(1.0, 0.92, 0.7), 1.6))
	lamp.position = Vector3(face + 0.13, 2.4, 0.0)
	g.add_child(lamp)

	for s in [-1.0, 1.0]:
		var win := U.box(Vector3(0.1, 1.0, 1.4), _glow(Color(0.45, 0.6, 0.8), 1.2))
		win.position = Vector3(face + 0.01, 1.85, 2.4 * float(s))
		g.add_child(win)
		var hedge := U.box(Vector3(1.6, 0.8, 0.6), U.mat(Color(0.25, 0.5, 0.25)))
		hedge.position = Vector3(face + 1.6, 0.4, 2.9 * float(s))
		g.add_child(hedge)

	var chimney := U.box(Vector3(0.7, 1.6, 0.7), U.mat(Color(0.5, 0.5, 0.52)))
	chimney.position = Vector3(-1.6, WALL_H + rise + 0.3, -2.0)
	g.add_child(chimney)

	# Path from the front door to the street.
	var path := U.box(Vector3(27.0, 0.07, 1.8), U.mat(Color(0.68, 0.66, 0.62)))
	path.position = Vector3(face + 14.4, 0.05, 0.0)
	path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(path)


func _build_interior() -> void:
	var g := Node3D.new()
	add_child(g)
	g.position = INTERIOR_ORIGIN
	var floor_col := Color(0.5, 0.38, 0.29)
	var wall_col := Color(0.86, 0.84, 0.8)
	var half: float = 5.0

	# Floor, ceiling and walls; the +X wall is split around the door.
	_solid(g, Vector3(half * 2.0 + 0.4, 0.24, half * 2.0 + 0.4), Vector3(0.0, -0.12, 0.0), floor_col)
	_solid(g, Vector3(half * 2.0 + 0.4, 0.2, half * 2.0 + 0.4), Vector3(0.0, 2.9, 0.0), wall_col)
	_solid(g, Vector3(0.2, 2.8, half * 2.0 + 0.4), Vector3(-half - 0.1, 1.4, 0.0), wall_col)
	_solid(g, Vector3(half * 2.0, 2.8, 0.2), Vector3(0.0, 1.4, -half - 0.1), wall_col)
	_solid(g, Vector3(half * 2.0, 2.8, 0.2), Vector3(0.0, 1.4, half + 0.1), wall_col)
	_solid(g, Vector3(0.2, 2.8, 4.2), Vector3(half + 0.1, 1.4, -2.9), wall_col)
	_solid(g, Vector3(0.2, 2.8, 4.2), Vector3(half + 0.1, 1.4, 2.9), wall_col)
	_solid(g, Vector3(0.2, 0.7, 1.6), Vector3(half + 0.1, 2.45, 0.0), wall_col)
	_solid(g, Vector3(0.18, 2.1, 1.4), Vector3(half + 0.02, 1.05, 0.0), Color(0.42, 0.28, 0.18))

	# Bed with pillow and blanket, wardrobe.
	_solid(g, Vector3(1.5, 0.5, 2.4), Vector3(-3.6, 0.25, -3.3), Color(0.3, 0.32, 0.42))
	var pillow := U.box(Vector3(1.1, 0.16, 0.5), U.mat(Color(0.93, 0.93, 0.96)))
	pillow.position = Vector3(-3.6, 0.58, -4.2)
	g.add_child(pillow)
	var blanket := U.box(Vector3(1.56, 0.1, 1.5), U.mat(Color(0.24, 0.45, 0.6)))
	blanket.position = Vector3(-3.6, 0.53, -2.85)
	g.add_child(blanket)
	_solid(g, Vector3(0.7, 2.1, 1.8), Vector3(-4.4, 1.05, 1.4), Color(0.42, 0.3, 0.22))

	# Sofa, rug, coffee table.
	_solid(g, Vector3(2.6, 0.5, 1.0), Vector3(2.8, 0.25, -3.9), Color(0.34, 0.2, 0.22))
	var back := U.box(Vector3(2.6, 0.9, 0.24), U.mat(Color(0.4, 0.24, 0.26)))
	back.position = Vector3(2.8, 0.7, -4.4)
	g.add_child(back)
	var rug := U.box(Vector3(3.4, 0.04, 2.4), U.mat(Color(0.5, 0.2, 0.24)))
	rug.position = Vector3(2.8, 0.03, -1.6)
	g.add_child(rug)
	_solid(g, Vector3(1.6, 0.42, 0.8), Vector3(2.8, 0.21, -1.6), Color(0.46, 0.36, 0.26))

	# TV on a stand against the far wall.
	_solid(g, Vector3(1.8, 0.5, 0.5), Vector3(2.8, 0.25, 3.9), Color(0.3, 0.3, 0.32))
	var tv := U.box(Vector3(1.5, 0.9, 0.1), U.mat(Color(0.1, 0.1, 0.12)))
	tv.position = Vector3(2.8, 1.3, 3.95)
	g.add_child(tv)
	var screen := U.box(Vector3(1.34, 0.74, 0.03), _glow(Color(0.3, 0.45, 0.6), 0.8))
	screen.position = Vector3(2.8, 1.3, 3.88)
	g.add_child(screen)

	# Kitchen counter with a sink.
	_solid(g, Vector3(2.4, 0.9, 0.65), Vector3(-2.9, 0.45, 4.4), Color(0.76, 0.76, 0.79))
	var sink := U.box(Vector3(0.7, 0.06, 0.45), U.mat(Color(0.58, 0.63, 0.68)))
	sink.position = Vector3(-2.9, 0.92, 4.4)
	g.add_child(sink)

	# Window (the panel is the light coming in) and two ceiling lights.
	var win := U.box(Vector3(0.06, 1.2, 2.2), _glow(Color(0.72, 0.84, 1.0), 1.4))
	win.position = Vector3(-4.98, 1.9, 1.8)
	g.add_child(win)
	for s in [-1.0, 1.0]:
		var shade := U.box(Vector3(0.7, 0.14, 0.7), _glow(Color(1.0, 0.9, 0.7), 2.0))
		shade.position = Vector3(2.6 * float(s), 2.78, 0.0)
		g.add_child(shade)
		var omni := OmniLight3D.new()
		omni.light_color = Color(1.0, 0.88, 0.72)
		omni.light_energy = 2.0
		omni.omni_range = 15.0
		omni.position = Vector3(2.6 * float(s), 2.5, 0.0)
		g.add_child(omni)
