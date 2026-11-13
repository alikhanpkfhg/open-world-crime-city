extends Control
# Whole HUD + multi-touch controls, drawn in one Control.
# Touch: left side = floating stick, right side = look, round buttons = actions.

const U = preload("res://scripts/util.gd")

var fingers: Dictionary = {}
var joy_origin: Vector2 = Vector2.ZERO
var joy_pos: Vector2 = Vector2.ZERO
var joy_on: bool = false
var msgs: Array = []
var font: Font
var age: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	G.message.connect(_on_message)


func _on_message(t: String) -> void:
	msgs.append([t, 3.2])
	if msgs.size() > 3:
		msgs.pop_front()


func _process(dt: float) -> void:
	age += dt
	for m in msgs:
		m[1] = float(m[1]) - dt
	while not msgs.is_empty() and float(msgs[0][1]) <= 0.0:
		msgs.pop_front()
	queue_redraw()


func _buttons() -> Array:
	var s: Vector2 = size
	var in_car: bool = G.in_car != null
	var near: bool = G.player != null and G.player.near_car != null
	var home: String = ""
	if G.house != null and G.player != null:
		home = G.house.prompt(G.player)
	var out: Array = []
	if not in_car:
		out.append({"k": "fire", "c": Vector2(s.x - 150.0, s.y - 150.0), "r": 85.0, "t": "FIRE", "col": Color(0.9, 0.2, 0.2)})
		out.append({"k": "weapon", "c": Vector2(s.x - 305.0, s.y - 235.0), "r": 46.0, "t": "GUN", "col": Color(0.9, 0.6, 0.15)})
	var jt: String = "JUMP"
	var jcol: Color = Color(0.25, 0.6, 0.9)
	if in_car:
		jt = "BRAKE"
		jcol = Color(0.9, 0.35, 0.2)
	out.append({"k": "jump", "c": Vector2(s.x - 315.0, s.y - 100.0), "r": 58.0, "t": jt, "col": jcol})
	var ut: String = "USE"
	var ucol: Color = Color(0.5, 0.5, 0.55)
	if in_car:
		ut = "EXIT"
		ucol = Color(0.3, 0.75, 0.4)
	elif home != "":
		ut = home
		ucol = Color(0.3, 0.85, 0.45)
	elif near:
		ut = "ENTER"
		ucol = Color(0.3, 0.85, 0.45)
	out.append({"k": "use", "c": Vector2(s.x - 125.0, s.y - 335.0), "r": 62.0, "t": ut, "col": ucol})
	return out


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_press(st.index, st.position)
		else:
			_release(st.index)
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		_drag(sd.index, sd.position, sd.relative)


func _press(idx: int, pos: Vector2) -> void:
	for b in _buttons():
		var c: Vector2 = b["c"]
		if pos.distance_to(c) < float(b["r"]) * 1.2:
			var k: String = b["k"]
			fingers[idx] = k
			if k == "fire":
				G.fire_touch = true
			elif k == "jump":
				if G.in_car != null:
					G.brake_touch = true
				else:
					G.action_jump.emit()
			elif k == "use":
				G.action_interact.emit()
			elif k == "weapon":
				G.action_weapon.emit()
			return
	if pos.x < size.x * 0.45:
		fingers[idx] = "joy"
		joy_on = true
		joy_origin = pos
		joy_pos = pos
		G.touch_move = Vector2.ZERO
	else:
		fingers[idx] = "look"


func _release(idx: int) -> void:
	if not fingers.has(idx):
		return
	var k: String = fingers[idx]
	fingers.erase(idx)
	if k == "fire":
		G.fire_touch = false
	elif k == "jump":
		G.brake_touch = false
	elif k == "joy":
		joy_on = false
		G.touch_move = Vector2.ZERO


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	if not fingers.has(idx):
		return
	var k: String = fingers[idx]
	if k == "joy":
		joy_pos = pos
		var v: Vector2 = (pos - joy_origin) / 90.0
		v = v.limit_length(1.0)
		if v.length() < 0.12:
			v = Vector2.ZERO
		G.touch_move = Vector2(v.x, -v.y)
		if (pos - joy_origin).length() > 130.0:
			joy_origin = pos - (pos - joy_origin).normalized() * 130.0
	elif k == "look":
		G.look_delta += rel


func _text(p: Vector2, t: String, sz: int, col: Color) -> void:
	draw_string(font, p + Vector2(2.0, 2.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.7))
	draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _ctext(y: float, t: String, sz: int, col: Color) -> void:
	draw_string(font, Vector2(2.0, y + 2.0), t, HORIZONTAL_ALIGNMENT_CENTER, size.x, sz, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(0.0, y), t, HORIZONTAL_ALIGNMENT_CENTER, size.x, sz, col)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var a: float = -PI * 0.5 + float(i) * PI / 5.0
		var rr: float = r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2((r.size.x - 4.0) * clampf(frac, 0.0, 1.0), r.size.y - 4.0)), col)


func _draw() -> void:
	var s: Vector2 = size
	if G.player == null:
		return
	var pl = G.player
	# Health
	var hp: float = pl.health
	var hc: Color = Color(0.3, 0.85, 0.35).lerp(Color(0.9, 0.2, 0.2), 1.0 - clampf(hp / 100.0, 0.0, 1.0))
	_bar(Rect2(20, 18, 260, 24), hp / 100.0, hc)
	if G.in_car != null:
		_bar(Rect2(20, 46, 260, 14), G.in_car.hp / 100.0, Color(0.95, 0.75, 0.2))
	_text(Vector2(20, 100), "$%d" % G.money, 34, Color(0.45, 1.0, 0.5))
	for i in range(5):
		var on: bool = i < G.stars()
		var col: Color = Color(0.25, 0.25, 0.3, 0.8)
		if on:
			col = Color(1.0, 0.85, 0.2)
			if fmod(age, 0.6) < 0.3 and G.time - G.last_crime < 4.0:
				col = Color(1.0, 0.3, 0.3)
		_star(Vector2(34.0 + float(i) * 36.0, 128.0), 15.0, col)
	if G.in_car == null:
		_text(Vector2(20, 168), pl.weapon_name(), 22, Color(1, 1, 1, 0.9))
	_text(Vector2(20, 196), "Kills: %d" % G.kills, 20, Color(1, 1, 1, 0.8))
	# Objective
	var obj: String = "Steal a car: walk up to one and press ENTER"
	if G.in_car != null:
		obj = "Deliver the car to the yellow beacon"
	elif G.house != null and G.house.is_inside(pl):
		obj = "Home: press ENTER at the door to go outside"
	_ctext(36.0, obj, 22, Color(1, 0.95, 0.6))
	# Messages
	var y: float = 74.0
	for m in msgs:
		_ctext(y, str(m[0]), 26, Color(1, 1, 1, clampf(float(m[1]), 0.0, 1.0)))
		y += 30.0
	if pl.dead:
		_ctext(s.y * 0.5, "WASTED", 90, Color(0.9, 0.1, 0.1))
	if age < 14.0:
		_text(Vector2(20, s.y - 30.0), "Left: move   Right: look   FIRE: shoot   ENTER: steal car", 20, Color(1, 1, 1, 0.8))
	_minimap(s)
	if G.in_car == null and not pl.dead:
		var cc: Vector2 = s * 0.5
		draw_arc(cc, 9.0, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 2.0)
		draw_circle(cc, 2.0, Color(1, 0.3, 0.3, 0.9))
	_draw_controls()


func _minimap(s: Vector2) -> void:
	var r := Rect2(s.x - 195.0, 18.0, 170.0, 170.0)
	draw_rect(r, Color(0.08, 0.1, 0.14, 0.8))
	var ctr: Vector2 = r.get_center()
	var sc: float = 0.6
	var pp: Vector3 = G.player.global_position
	for rc in U.ROAD_C:
		var rx: float = ctr.x + (float(rc) - pp.x) * sc
		if rx > r.position.x and rx < r.end.x:
			draw_line(Vector2(rx, r.position.y), Vector2(rx, r.end.y), Color(0.42, 0.45, 0.52), 16.0 * sc)
		var ry: float = ctr.y + (float(rc) - pp.z) * sc
		if ry > r.position.y and ry < r.end.y:
			draw_line(Vector2(r.position.x, ry), Vector2(r.end.x, ry), Color(0.42, 0.45, 0.52), 16.0 * sc)
	for c in get_tree().get_nodes_in_group("cop"):
		var cp: Vector2 = ctr + Vector2(c.global_position.x - pp.x, c.global_position.z - pp.z) * sc
		if r.has_point(cp):
			var cc: Color = Color(1, 0.2, 0.2) if int(age * 4.0) % 2 == 0 else Color(0.3, 0.5, 1.0)
			draw_circle(cp, 5.0, cc)
	var hp: Vector2 = ctr + Vector2(G.house_pos.x - pp.x, G.house_pos.z - pp.z) * sc
	_home_icon(hp.clamp(r.position + Vector2(9, 9), r.end - Vector2(9, 9)), Color(0.45, 0.8, 1.0))
	var mp: Vector2 = ctr + Vector2(G.marker_pos.x - pp.x, G.marker_pos.z - pp.z) * sc
	mp = mp.clamp(r.position + Vector2(6, 6), r.end - Vector2(6, 6))
	draw_circle(mp, 6.0, Color(1.0, 0.9, 0.2))
	var yaw: float = G.cam_yaw
	var f: Vector2 = Vector2(-sin(yaw), -cos(yaw))
	var n: Vector2 = Vector2(-f.y, f.x)
	var tri := PackedVector2Array([ctr + f * 9.0, ctr - f * 6.0 + n * 6.0, ctr - f * 6.0 - n * 6.0])
	draw_colored_polygon(tri, Color(1, 1, 1))
	draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)


func _home_icon(c: Vector2, col: Color) -> void:
	draw_rect(Rect2(c + Vector2(-6.0, -1.0), Vector2(12.0, 9.0)), col)
	var roof := PackedVector2Array([c + Vector2(-8.0, -1.0), c + Vector2(8.0, -1.0), c + Vector2(0.0, -9.0)])
	draw_colored_polygon(roof, col)


func _draw_controls() -> void:
	if joy_on:
		draw_circle(joy_origin, 90.0, Color(1, 1, 1, 0.12))
		draw_arc(joy_origin, 90.0, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 3.0)
		draw_circle(joy_origin + (joy_pos - joy_origin).limit_length(90.0), 38.0, Color(1, 1, 1, 0.35))
	else:
		var base: Vector2 = Vector2(170.0, size.y - 170.0)
		draw_arc(base, 90.0, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 3.0)
		draw_circle(base, 36.0, Color(1, 1, 1, 0.15))
	for b in _buttons():
		var c: Vector2 = b["c"]
		var col: Color = b["col"]
		var held: bool = false
		for k in fingers.values():
			if k == b["k"]:
				held = true
		draw_circle(c, float(b["r"]), Color(col.r, col.g, col.b, 0.55 if held else 0.3))
		draw_arc(c, float(b["r"]), 0.0, TAU, 32, Color(1, 1, 1, 0.6), 3.0)
		var t: String = b["t"]
		var w: float = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, c + Vector2(-w * 0.5, 8.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.95))
