extends Node2D
## Calloway Apt 4B — first safehouse. Rain on the windows, the skyline outside,
## a record player. Save the game, change clothes, check the bag.

var main
var params := {}
var _vw := 1280.0
var _ui: Control
var _adrian: Adrian
var dialogue: DialogueBox

func _ready() -> void:
	_vw = get_viewport_rect().size.x
	GameState.location = "safehouse"
	var sky := Skyline.new()
	sky.view_w = _vw
	sky.horizon = 520
	sky.world_w = 800
	sky.seed_value = 77
	sky.beams = true
	add_child(sky)
	sky.scroll = 300
	var rain := Rain.new()
	rain.area = Rect2(0, -40, _vw, 600)
	rain.splashes = false
	rain.ground_top = 560
	rain.intensity = 0.7
	add_child(rain)
	var room := Room.new()
	room.w = _vw
	add_child(room)
	_adrian = Adrian.new()
	_adrian.position = Vector2(_vw * 0.36, 650)
	_adrian.size = 1.25
	_adrian.light = 0.8
	_adrian.rim_back = NC.AMBER
	_adrian.rim_front = Color(0.55, 0.65, 1.0)
	_adrian.rim_strength = 0.6
	_adrian.facing = 1
	add_child(_adrian)
	_ui = UI.root_control(self)
	var t := UI.label("APT 4B", 44, NC.GOLD, "deco")
	t.position = Vector2(50, 30)
	_ui.add_child(t)
	var s := UI.label("CALLOWAY BUILDING  ·  THE VELVET QUARTER  ·  SAFEHOUSE", 16, NC.a(NC.PALE_GOLD, 0.7), "title")
	s.position = Vector2(52, 84)
	_ui.add_child(s)
	var cash := UI.label("$" + GameState.format_money(GameState.cash), 34, NC.GOLD, "title")
	cash.position = Vector2(_vw - 220, 30)
	_ui.add_child(cash)
	var v := VBoxContainer.new()
	v.position = Vector2(_vw - 330, 150)
	v.add_theme_constant_override("separation", 12)
	_ui.add_child(v)
	var save := UI.btn("SAVE GAME", _save, Vector2(280, 62))
	save.name = "Save"
	v.add_child(save)
	v.add_child(UI.btn("WARDROBE", func(): main.goto("wardrobe", {"mode": "closet", "return": "safehouse"}), Vector2(280, 62)))
	v.add_child(UI.btn("BAG", func(): main.goto("inventory", {"return": "safehouse"}), Vector2(280, 62)))
	v.add_child(UI.btn("CITY MAP", func(): main.goto("map"), Vector2(280, 62)))
	v.add_child(UI.btn("LEAVE", func():
		GameState.location = "district"
		main.goto("district", {"x": 2410.0}), Vector2(280, 62)))
	v.add_child(UI.btn("SETTINGS", func(): main.open_settings(), Vector2(280, 62)))
	var dl := UI.root_control(self, 30)
	dialogue = DialogueBox.new()
	dl.add_child(dialogue)
	Audio.play_music("safehouse", 2.5)
	Audio.play_ambience("rain_inside", -6.0, 2.0)
	GameState.save_game()
	if params.get("first", false) or not GameState.flag("safehouse_seen"):
		GameState.set_flag("safehouse_seen")
		GameState.save_game()
		_first_visit()

func _first_visit() -> void:
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return
	await dialogue.play([
		{"who": "ADRIAN", "text": "Four rooms, a radiator that knocks, and a view of the whole rotten city.", "thought": true},
		{"who": "ADRIAN", "text": "Somewhere to keep the suits dry. Somewhere to think. Home — for now.", "thought": true},
	])

func _save() -> void:
	GameState.location = "safehouse"
	var ok := GameState.save_game()
	Audio.sfx("ui")
	UI.toast(_ui, "Game saved." if ok else "Save failed.", NC.PALE_GOLD)

class Room extends Node2D:
	var w := 1280.0
	var _t := 0.0
	var _drops := []

	func _ready() -> void:
		for i in 46:
			_drops.append([randf_range(70, w - 70), randf_range(80, 520), randf_range(10, 40), randf_range(1.5, 3.2)])

	func _process(d: float) -> void:
		_t += d
		for dr in _drops:
			dr[1] += dr[2] * d * (1.0 + sin(_t * 3.0 + dr[0]) * 0.8)
			if dr[1] > 530:
				dr[1] = 80
				dr[0] = randf_range(70, w - 70)
		queue_redraw()

	func _draw() -> void:
		# rain drops sliding down the glass
		for dr in _drops:
			draw_line(Vector2(dr[0], dr[1] - 22), Vector2(dr[0], dr[1]), Color(0.75, 0.82, 1.0, 0.14), dr[3] * 0.6)
			draw_circle(Vector2(dr[0], dr[1]), dr[3], Color(0.8, 0.86, 1.0, 0.42))
		# window frames
		var frame := Color("0c0806")
		draw_rect(Rect2(0, 0, w, 60), frame)
		draw_rect(Rect2(0, 540, w, 180), Color("120a08"))
		draw_rect(Rect2(0, 0, 50, 720), frame)
		draw_rect(Rect2(w - 50, 0, 50, 720), frame)
		for k in 3:
			var x := 50.0 + (w - 100) * (k + 1) / 4.0
			draw_rect(Rect2(x - 10, 60, 20, 480), frame)
		draw_rect(Rect2(50, 290, w - 100, 12), frame)
		draw_rect(Rect2(40, 530, w - 80, 18), Color("2a1a10"))
		draw_line(Vector2(40, 530), Vector2(w - 40, 530), NC.a(NC.AMBER, 0.3), 2)
		# floor
		NC.vgrad(self, Rect2(0, 600, w, 120), Color("1a0f0a"), Color("070403"))
		NC.ellipse(self, Vector2(w * 0.45, 670), 360, 34, Color("2a0c14"))
		# warm lamp glow
		var lx := w * 0.12
		NC.glow(self, Vector2(lx, 420), 360, Color(1.0, 0.72, 0.38, 0.22))
		draw_rect(Rect2(lx - 50, 520, 100, 100), Color("1a0e08"))
		draw_line(Vector2(lx, 520), Vector2(lx, 440), Color("2a1a0e"), 4)
		NC.poly(self, [Vector2(lx - 36, 440), Vector2(lx + 36, 440), Vector2(lx + 24, 400), Vector2(lx - 24, 400)], Color("e8b060"))
		NC.glow(self, Vector2(lx, 430), 60, Color(1, 0.85, 0.5, 0.6))
		# sofa
		var sx := w * 0.52
		NC.poly(self, [Vector2(sx - 200, 640), Vector2(sx - 200, 540), Vector2(sx + 200, 540), Vector2(sx + 200, 640)], Color("121018"))
		for k in 3:
			NC.ellipse(self, Vector2(sx - 130 + k * 130, 560), 62, 30, Color("1c1828"))
		draw_rect(Rect2(sx - 220, 560, 40, 80), Color("0e0c14"))
		draw_rect(Rect2(sx + 180, 560, 40, 80), Color("0e0c14"))
		draw_line(Vector2(sx - 200, 541), Vector2(sx + 200, 541), NC.a(NC.AMBER, 0.25), 2)
		# record player
		var rx := w * 0.82
		draw_rect(Rect2(rx - 70, 560, 140, 70), Color("2a160c"))
		draw_rect(Rect2(rx - 64, 548, 128, 14), Color("1a0e08"))
		NC.ellipse(self, Vector2(rx - 8, 548), 46, 9, Color("060406"))
		var a := _t * 3.5
		draw_line(Vector2(rx - 8, 548) + Vector2(cos(a), sin(a) * 0.2) * 40, Vector2(rx - 8, 548), Color(0.6, 0.6, 0.8, 0.4), 1)
		NC.ellipse(self, Vector2(rx - 8, 548), 10, 2, NC.BURGUNDY)
		draw_line(Vector2(rx + 50, 546), Vector2(rx + 18, 540), Color("b8bec8"), 2)
		# plant
		var px := w * 0.25
		draw_rect(Rect2(px - 18, 600, 36, 36), Color("4a2a18"))
		for k in 7:
			var ang := -PI / 2 + (k - 3) * 0.32
			draw_line(Vector2(px, 600), Vector2(px, 600) + Vector2(cos(ang), sin(ang)) * 48, Color("1a3a24"), 6)
