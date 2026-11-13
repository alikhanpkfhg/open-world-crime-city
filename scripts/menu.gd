extends CanvasLayer
# Main menu: a title screen over the paused city. The world is built and then
# the tree is paused; a tap anywhere (after a short beat, so the intro tap
# can't skip it) unpauses. Touch is handled in _input like the in-game HUD,
# not with a Button - Button GUI is unreliable for raw touches on Android.

var age: float = 0.0
var started: bool = false
var ui: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_menu)
	add_child(ui)


func _process(dt: float) -> void:
	age += dt
	ui.queue_redraw()


func _input(event: InputEvent) -> void:
	if started:
		return
	var tapped: bool = false
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tapped = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		tapped = true
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k: InputEventKey = event as InputEventKey
		tapped = (k.physical_keycode == KEY_SPACE or k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER)
	if tapped and age > 0.5:
		_start()


func _start() -> void:
	if started:
		return
	started = true
	get_tree().paused = false
	queue_free()


func _draw_menu() -> void:
	var f: Font = ThemeDB.fallback_font
	var s: Vector2 = ui.size
	ui.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.05, 0.09, 0.8))
	ui.draw_string(f, Vector2(0.0, s.y * 0.34), "CRIME CITY", HORIZONTAL_ALIGNMENT_CENTER, s.x, 72, Color(1.0, 0.85, 0.2))
	ui.draw_string(f, Vector2(0.0, s.y * 0.34 + 42.0), "Steal cars. Outrun the cops. Mind the pedestrians.", HORIZONTAL_ALIGNMENT_CENTER, s.x, 22, Color(1, 1, 1, 0.85))
	var pulse: float = 0.55 + 0.45 * sin(age * 3.5)
	ui.draw_string(f, Vector2(0.0, s.y * 0.56), "TAP TO PLAY", HORIZONTAL_ALIGNMENT_CENTER, s.x, 46, Color(1, 1, 1, pulse))
	ui.draw_string(f, Vector2(0.0, s.y * 0.56 + 40.0), "Left half: move   Right half: look", HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, Color(1, 1, 1, 0.7))
	ui.draw_string(f, Vector2(0.0, s.y * 0.56 + 66.0), "FIRE shoot   GUN switch   JUMP   ENTER steal cars / doors", HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, Color(1, 1, 1, 0.7))
