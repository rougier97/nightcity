extends Node2D
## Opening cinematic: black screen → jazz piano → rain → skyline reveal and pan →
## Velvet Quarter street (jazz club, black car outside Moretti's) → Adrian Cross
## introduction → phone call from Vincent Moretti. Skippable.

var main
var params := {}
var _vw := 1280.0
var _city: Node2D
var _sky: Skyline
var _street: VelvetStreet
var _adrian: Adrian
var _cam: Camera2D
var _ui: Control
var _black: ColorRect
var _card: Label
var _sub: Label
var _namecard: Control
var _dialogue: DialogueBox
var _skip: Button
var _rain_over: Rain
var _done := false
var _cam_x := 0.0

func _ready() -> void:
	_vw = get_viewport_rect().size.x
	# ---- city (skyline pan)
	_city = Node2D.new()
	add_child(_city)
	_sky = Skyline.new()
	_sky.view_w = _vw + 40
	_sky.horizon = 690
	_sky.world_w = 5200
	_sky.seed_value = 4
	_city.add_child(_sky)
	var city_rain := Rain.new()
	city_rain.area = Rect2(0, -40, _vw, 780)
	city_rain.splashes = false
	city_rain.ground_top = 760
	_city.add_child(city_rain)
	# ---- street
	_street = VelvetStreet.new()
	_street.visible = false
	_street.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_street)
	_adrian = Adrian.new()
	_adrian.position = Vector2(1150, VelvetStreet.WALK_Y)
	_adrian.size = 0.95
	_adrian.facing = 1
	_street.add_child(_adrian)
	_street.add_foreground()
	_cam = Camera2D.new()
	_cam.position = Vector2(_vw * 0.5, 360)
	add_child(_cam)
	_cam.make_current()
	# ---- overlay
	_ui = UI.root_control(self)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_black)
	var rl := CanvasLayer.new()
	rl.layer = 11
	add_child(rl)
	_rain_over = Rain.new()
	_rain_over.area = Rect2(0, -40, _vw, 780)
	_rain_over.splashes = false
	_rain_over.ground_top = 760
	_rain_over.intensity = 0.0
	_rain_over.tint = Color(0.6, 0.65, 0.9)
	rl.add_child(_rain_over)
	var ui2 := UI.root_control(self, 12)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			bar.offset_bottom = 56
		else:
			bar.offset_top = -56
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui2.add_child(bar)
	_card = UI.label("", 64, NC.PALE_GOLD, "deco")
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.modulate.a = 0.0
	ui2.add_child(_card)
	_sub = UI.label("", 24, NC.a(NC.PALE_GOLD, 0.8), "title")
	_sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub.offset_top = 90
	_sub.modulate.a = 0.0
	ui2.add_child(_sub)
	_namecard = _make_namecard()
	ui2.add_child(_namecard)
	_dialogue = DialogueBox.new()
	ui2.add_child(_dialogue)
	_skip = UI.btn("SKIP  >>", _skip_intro, Vector2(150, 50), 20)
	_skip.position = Vector2(_vw - 180, 70)
	ui2.add_child(_skip)
	Audio.stop_ambience(0.5)
	Audio.stop_music(0.5)
	_run()

func _process(delta: float) -> void:
	if _street.visible:
		_street.set_camera(_cam.position.x, _vw)

func _alive() -> bool:
	return not _done and is_inside_tree()

func _wait(t: float) -> bool:
	await get_tree().create_timer(t).timeout
	return _alive()

func _tween_prop(obj: Object, prop: String, to, t: float, trans := Tween.TRANS_SINE) -> bool:
	var tw := create_tween()
	tw.tween_property(obj, prop, to, t).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	return _alive()

func _show_card(title: String, sub: String, hold: float) -> bool:
	_card.text = title
	_sub.text = sub
	var tw := create_tween().set_parallel()
	tw.tween_property(_card, "modulate:a", 1.0, 1.2)
	tw.tween_property(_sub, "modulate:a", 1.0, 1.6)
	await tw.finished
	if not await _wait(hold):
		return false
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(_card, "modulate:a", 0.0, 1.0)
	tw2.tween_property(_sub, "modulate:a", 0.0, 1.0)
	await tw2.finished
	return _alive()

func _run() -> void:
	if not await _wait(0.8): return
	Audio.play_music("intro", 0.0)
	if not await _wait(2.2): return
	Audio.play_ambience("rain", -8.0, 4.0)
	create_tween().tween_property(_rain_over, "intensity", 0.8, 4.0)
	if not await _show_card("NIGHTCITY", "1:14 A.M.  ·  THE RAIN HASN'T STOPPED IN NINE DAYS", 1.8): return
	# reveal the skyline while the camera pans
	var pan := create_tween()
	pan.tween_property(_sky, "scroll", 2600.0, 16.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tilt := create_tween()
	_city.position.y = 150
	tilt.tween_property(_city, "position:y", -10.0, 16.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not await _tween_prop(_black, "color:a", 0.0, 4.0): return
	create_tween().tween_property(_rain_over, "intensity", 0.35, 3.0)
	if not await _wait(5.0): return
	_sky.flash()
	get_tree().create_timer(1.0).timeout.connect(func(): Audio.sfx("thunder", -2.0))
	if not await _wait(5.5): return
	if not await _tween_prop(_black, "color:a", 1.0, 1.5): return
	# ---- street
	_city.visible = false
	_city.process_mode = Node.PROCESS_MODE_DISABLED
	_street.visible = true
	_street.process_mode = Node.PROCESS_MODE_INHERIT
	_rain_over.intensity = 0.15
	_cam.position = Vector2(420, 360)
	_street.set_camera(_cam.position.x, _vw)
	if not await _tween_prop(_black, "color:a", 0.0, 2.0): return
	Audio.play_music("menu", 4.0)
	Audio.sfx("car", -6.0)
	if not await _tween_prop(_cam, "position:x", 1120.0, 9.0): return
	# ---- Adrian Cross introduction
	if not await _wait(0.6): return
	var tw := create_tween()
	tw.tween_property(_namecard, "modulate:a", 1.0, 1.0)
	tw.parallel().tween_property(_namecard, "position:x", 70.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not await _wait(4.8): return
	if not await _tween_prop(_namecard, "modulate:a", 0.0, 0.8): return
	# ---- the call
	Audio.play_dialogue_sound("phone")
	if not await _wait(3.0): return
	Audio.play_dialogue_sound("phone")
	if not await _wait(1.6): return
	_adrian.pose = "phone"
	if not await _wait(0.6): return
	var choice := await _dialogue.play([
		{"who": "UNKNOWN NUMBER", "text": "Mr. Cross. You're a hard man to find. In my line of work, that's a compliment."},
		{"who": "ADRIAN", "text": "Whoever gave you this number made a mistake."},
		{"who": "VINCENT MORETTI", "text": "Vincent Moretti. You're standing outside my restaurant, Mr. Cross. Nobody makes mistakes on my street."},
		{"who": "VINCENT MORETTI", "text": "Eight years in military intelligence, then nothing. A man like that is either finished... or waiting for the right offer."},
		{"who": "ADRIAN", "text": "...", "choices": ["I'M LISTENING.", "WHAT'S THE JOB?"]},
	])
	if not _alive(): return
	var lines := [
		{"who": "VINCENT MORETTI", "text": "Good. The Castellanos keep their books above the laundromat on Sable Street. There's a ledger in their safe with my family's name in it."},
		{"who": "VINCENT MORETTI", "text": "I want it on my table before sunrise. Quietly. No noise, no police. Bring it here and there's three thousand in it for you."},
		{"who": "ADRIAN", "text": "And if I say no?"},
		{"who": "VINCENT MORETTI", "text": "Then enjoy the rain. It falls on everyone in Nightcity... eventually."},
	]
	if choice == 1:
		lines.push_front({"who": "VINCENT MORETTI", "text": "Straight to business. I like that."})
	await _dialogue.play(lines)
	if not _alive(): return
	Audio.play_dialogue_sound("hangup")
	_adrian.pose = "idle"
	if not await _wait(1.0): return
	await _dialogue.play([{"who": "", "text": "Every city has a heartbeat. This one plays it slow, in a minor key... and somebody always pays the band."}])
	if not _alive(): return
	_skip.visible = false
	if not await _tween_prop(_black, "color:a", 1.0, 1.4): return
	if not await _show_card("CHAPTER ONE", "THE LEDGER", 2.0): return
	_finish()

func _make_namecard() -> Control:
	var c := Control.new()
	c.position = Vector2(30, 420)
	c.modulate.a = 0.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = NC.GOLD
	line.size = Vector2(4, 150)
	c.add_child(line)
	var n := UI.label("ADRIAN CROSS", 58, NC.PALE_GOLD, "deco")
	n.position = Vector2(22, -6)
	c.add_child(n)
	var r := UI.label("FORMER MILITARY INTELLIGENCE  ·  CURRENTLY UNAFFILIATED", 20, NC.NEON_CYAN, "title")
	r.position = Vector2(24, 66)
	c.add_child(r)
	var q := UI.label("\"Quiet. Careful. Nobody's friend yet.\"", 20, NC.a(Color.WHITE, 0.75), "type")
	q.position = Vector2(24, 100)
	c.add_child(q)
	return c

func _skip_intro() -> void:
	if _done:
		return
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	GameState.set_flag("intro_seen")
	if GameState.flag("look_created"):
		main.goto("map", {}, 1.0)
	else:
		main.goto("wardrobe", {"mode": "create"}, 1.0)
