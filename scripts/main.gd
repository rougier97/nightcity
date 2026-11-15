extends Node
## Root of the game: switches screens with a fade, hosts overlays (settings,
## pause) and exposes test hooks:  godot --path . -- --test=<name>

const SCREENS := {
	"menu": "res://scripts/screens/menu.gd",
	"intro": "res://scripts/screens/intro.gd",
	"map": "res://scripts/screens/city_map.gd",
	"district": "res://scripts/screens/district.gd",
	"mission": "res://scripts/screens/mission.gd",
	"wardrobe": "res://scripts/screens/wardrobe.gd",
	"inventory": "res://scripts/screens/inventory.gd",
	"safehouse": "res://scripts/screens/safehouse.gd",
}

var current: Node
var current_name := ""
var overlay: Control
var _fade: ColorRect
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fl := CanvasLayer.new()
	fl.layer = 100
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(_fade)
	overlay = UI.root_control(self, 50)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.get_parent().process_mode = Node.PROCESS_MODE_ALWAYS

	_rotate_hint()
	var test := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test="):
			test = a.substr(7)
	if test != "":
		var t: Node = load("res://tests/%s.gd" % test).new()
		add_child(t)
		t.call("run", self)
		return
	goto("menu", {}, 0.0)

## Portrait phones (e.g. in a mobile browser) get a "rotate" overlay.
func _rotate_hint() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 200
	add_child(cl)
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	cl.add_child(r)
	var l := UI.label("ROTATE YOUR PHONE\n\nHITMAN: NIGHTCITY plays in landscape.", 34, NC.PALE_GOLD, "deco")
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(l)
	var upd := func():
		var s := DisplayServer.window_get_size()
		cl.visible = s.x < s.y
	get_tree().root.size_changed.connect(upd)
	upd.call()

func goto(name: String, params: Dictionary = {}, fade: float = 0.45) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if fade > 0.0:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, fade)
		await tw.finished
	else:
		_fade.color.a = 1.0
	get_tree().paused = false
	for c in overlay.get_children():
		c.queue_free()
	if current:
		current.queue_free()
		current = null
	var s: Node = load(SCREENS[name]).new()
	s.set("main", self)
	s.set("params", params)
	s.process_mode = Node.PROCESS_MODE_PAUSABLE
	current = s
	current_name = name
	add_child(s)
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, maxf(fade, 0.25))
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func is_busy() -> bool:
	return _busy

# ---------------------------------------------------------------- overlays
func _modal(title: String) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var p := PanelContainer.new()
	var sb := UI.box(Color(0.03, 0.02, 0.07, 0.97), NC.GOLD, 2)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 24
	sb.content_margin_bottom = 28
	p.add_theme_stylebox_override("panel", sb)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var t := UI.label(title, 40, NC.GOLD, "deco")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.set_meta("shade", shade)
	return v

func close_overlays() -> void:
	for c in overlay.get_children():
		c.queue_free()

func open_settings(on_close: Callable = Callable()) -> void:
	var v := _modal("SETTINGS")
	var shade: Control = v.get_meta("shade")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 18)
	v.add_child(grid)
	for row in [["music", "MUSIC", "Music"], ["sfx", "SOUND EFFECTS", "SFX"], ["dialogue", "DIALOGUE", "Dialogue"]]:
		var key: String = row[0]
		grid.add_child(UI.label(row[1], 22, NC.PALE_GOLD, "title"))
		var s := HSlider.new()
		s.name = "Slider_" + key
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = GameState.settings[key]
		s.custom_minimum_size = Vector2(340, 44)
		var pct := UI.label("%d%%" % int(s.value * 100), 22)
		pct.custom_minimum_size = Vector2(70, 0)
		s.value_changed.connect(func(val: float):
			GameState.settings[key] = val
			Audio.set_bus_volume(row[2], val)
			pct.text = "%d%%" % int(val * 100))
		s.drag_ended.connect(func(_c):
			if key == "sfx":
				Audio.sfx("cash", -6)
			elif key == "dialogue":
				Audio.dialogue_blip())
		grid.add_child(s)
		grid.add_child(pct)
	var note := UI.label("Music, sound effects and dialogue each have their own channel.", 16, NC.a(Color.WHITE, 0.6))
	v.add_child(note)
	var close := UI.btn("CLOSE", func():
		GameState.save_settings()
		shade.queue_free()
		if on_close.is_valid():
			on_close.call(), Vector2(220, 60))
	close.name = "CloseSettings"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)

## options: Array of [label, Callable]
func open_pause(options: Array) -> void:
	get_tree().paused = true
	var v := _modal("PAUSED")
	var shade: Control = v.get_meta("shade")
	var resume := func():
		shade.queue_free()
		get_tree().paused = false
	v.add_child(UI.btn("RESUME", resume, Vector2(320, 62)))
	for o in options:
		var cb: Callable = o[1]
		v.add_child(UI.btn(o[0], func():
			shade.queue_free()
			cb.call(), Vector2(320, 62)))
	v.add_child(UI.btn("SETTINGS", func():
		shade.queue_free()
		open_settings(func(): open_pause(options)), Vector2(320, 62)))
	v.add_child(UI.btn("QUIT TO MENU", func():
		shade.queue_free()
		get_tree().paused = false
		goto("menu"), Vector2(320, 62)))

## Screenshot helper for tests.
func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
