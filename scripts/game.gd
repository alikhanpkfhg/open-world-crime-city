extends Node
# Autoload "G": shared input state, money, wanted level and helpers.

signal action_jump
signal action_interact
signal action_weapon
signal message(text: String)
signal ped_died

var touch_move: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO
var fire_touch: bool = false
var brake_touch: bool = false

var cam_yaw: float = 0.0
var aim_origin: Vector3 = Vector3.ZERO
var aim_dir: Vector3 = Vector3(0.0, 0.0, -1.0)

var money: int = 0
var wanted: float = 0.0
var kills: int = 0
var time: float = 0.0
var last_crime: float = -100.0

var objective: String = ""
var marker_pos: Vector3 = Vector3.ZERO

# Untyped on purpose: these are duck-typed scripts (player.gd / car.gd).
var player = null
var in_car = null
# Set by main.gd: the player's house (house.gd) and where it sits on the map.
var house = null
var house_pos: Vector3 = Vector3.ZERO


func get_move() -> Vector2:
	var v: Vector2 = touch_move
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		v.y -= 1.0
	return v.limit_length(1.0)


func fire_held() -> bool:
	return fire_touch or Input.is_physical_key_pressed(KEY_F)


func brake_held() -> bool:
	return brake_touch or Input.is_physical_key_pressed(KEY_SHIFT)


func stars() -> int:
	if wanted <= 0.01:
		return 0
	return clampi(ceili(wanted), 1, 5)


func add_wanted(a: float) -> void:
	var before: int = stars()
	wanted = minf(5.0, wanted + a)
	last_crime = time
	if stars() > before:
		message.emit("Wanted level up!")


func add_money(n: int) -> void:
	money += n


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and not k.echo:
			if k.physical_keycode == KEY_SPACE:
				action_jump.emit()
			elif k.physical_keycode == KEY_E:
				action_interact.emit()
			elif k.physical_keycode == KEY_Q:
				action_weapon.emit()


func _process(dt: float) -> void:
	time += dt
	if wanted > 0.0 and time - last_crime > 14.0:
		wanted = maxf(0.0, wanted - 0.1 * dt)


# One-shot positional sound.
func sfx(path: String, pos: Vector3, vol: float = 0.0, pitch: float = 1.0) -> void:
	var s: AudioStream = load(path)
	if s == null:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = pitch
	p.max_distance = 90.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
