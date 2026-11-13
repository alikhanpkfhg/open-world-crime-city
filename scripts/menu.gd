extends CanvasLayer
# Main menu: a title screen over the paused city. The world is built and then
# the tree is paused; PLAY unpauses, so the city is already loaded behind it.

var font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	font = ThemeDB.fallback_font

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.09, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	add_child(box)

	var title := Label.new()
	title.text = "CRIME CITY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Steal cars. Outrun the cops. Mind the pedestrians."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 16.0)
	box.add_child(spacer)

	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(280.0, 70.0)
	play.add_theme_font_size_override("font_size", 38)
	play.pressed.connect(_start)
	box.add_child(play)

	var hint := Label.new()
	hint.text = "Left half: move   Right half: look   FIRE / GUN / JUMP / ENTER"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	box.add_child(hint)


func _start() -> void:
	get_tree().paused = false
	queue_free()
