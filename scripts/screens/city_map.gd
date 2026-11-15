extends Node2D
## Interactive Nightcity map. Six districts (one unlocked), tap a district to see
## its owner and locations; GO travels there.

var main
var params := {}
var _vw := 1280.0
var _map: MapArt
var _ui: Control
var _panel: VBoxContainer
var _selected := "velvet"

const POLYS := {
	"crown": [Vector2(380, 130), Vector2(640, 110), Vector2(600, 270), Vector2(390, 300), Vector2(330, 210)],
	"neonmile": [Vector2(640, 110), Vector2(850, 140), Vector2(800, 270), Vector2(600, 270)],
	"velvet": [Vector2(390, 300), Vector2(600, 270), Vector2(640, 450), Vector2(450, 490), Vector2(360, 410)],
	"palermo": [Vector2(600, 270), Vector2(800, 270), Vector2(830, 440), Vector2(640, 450)],
	"docks": [Vector2(150, 440), Vector2(360, 410), Vector2(450, 490), Vector2(400, 640), Vector2(170, 630)],
	"ashgate": [Vector2(450, 490), Vector2(640, 450), Vector2(830, 440), Vector2(870, 610), Vector2(620, 650), Vector2(400, 640)],
}

func _ready() -> void:
	_vw = get_viewport_rect().size.x
	_map = MapArt.new()
	_map.screen = self
	add_child(_map)
	var rain := Rain.new()
	rain.area = Rect2(0, -40, _vw, 760)
	rain.splashes = false
	rain.intensity = 0.45
	rain.ground_top = 760
	add_child(rain)
	_ui = UI.root_control(self)
	var hud := HUD.new()
	_ui.add_child(hud)
	hud.setup("Nightcity", false)
	hud.set_objective("Tap a district")
	hud.pause_pressed.connect(func(): main.open_pause([]))
	# district hit area: point-in-polygon on tap
	var hit := Control.new()
	hit.name = "MapHit"
	hit.position = Vector2.ZERO
	hit.size = Vector2(_vw - 430, 720)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var id := district_at(ev.position)
			if id != "":
				_select(id))
	_ui.add_child(hit)
	_ui.move_child(hit, 0)
	var pc := PanelContainer.new()
	var sb := UI.box(Color(0.03, 0.02, 0.07, 0.92), NC.GOLD.darkened(0.3), 1)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	pc.add_theme_stylebox_override("panel", sb)
	pc.position = Vector2(_vw - 420, 100)
	pc.size = Vector2(400, 600)
	_ui.add_child(pc)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 10)
	pc.add_child(_panel)
	_select("velvet")
	Audio.play_music("velvet", 2.0)
	Audio.play_ambience("rain", -16.0, 2.0)

func district_at(pos: Vector2) -> String:
	for id in POLYS:
		if Geometry2D.is_point_in_polygon(pos, PackedVector2Array(POLYS[id])):
			return id
	return ""

func _select(id: String) -> void:
	_selected = id
	_map.selected = id
	Audio.sfx("ui", -8.0)
	for c in _panel.get_children():
		c.queue_free()
	var d: Dictionary = Catalog.district(id)
	var unlocked := GameState.unlocked_districts.has(id)
	_panel.add_child(UI.label(d["name"].to_upper(), 30, NC.GOLD, "deco"))
	_panel.add_child(UI.label(d["family"], 17, NC.NEON_CYAN, "title"))
	var desc := UI.label(d["desc"], 18, NC.a(Color.WHITE, 0.75))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(350, 0)
	_panel.add_child(desc)
	if not unlocked:
		var l := UI.label("LOCKED\nEarn the Moretti family's trust to open this district.", 20, NC.NEON_RED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(350, 0)
		_panel.add_child(l)
		return
	var rows := [
		["WALK THE QUARTER", {"x": GameState.district_x}, "district"],
		["MORETTI'S RISTORANTE", {"x": 1280.0}, "district"],
	]
	if not GameState.mission_done("m01_ledger"):
		rows.append(["CONTRACT: THE LEDGER", {"x": 3180.0}, "district"])
	rows.append(["SARTORI & SONS  (TAILOR)", {"x": 1930.0}, "district"])
	if GameState.owns_property("calloway_4b"):
		rows.append(["SAFEHOUSE  ·  APT 4B", {}, "safehouse"])
	else:
		rows.append(["APT 4B FOR SALE  ·  $2,000", {"x": 2410.0}, "district"])
	rows.append(["THE VELVET HOUR  (JAZZ)", {"x": 570.0}, "district"])
	for r in rows:
		var p: Dictionary = r[1]
		var scr: String = r[2]
		var b := UI.btn(r[0], func(): main.goto(scr, p), Vector2(350, 56), 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.name = "Go_" + str(r[0]).split(" ")[0]
		_panel.add_child(b)

class MapArt extends Node2D:
	var screen
	var selected := "velvet":
		set(v):
			selected = v
			queue_redraw()
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var w: float = screen._vw
		NC.vgrad(self, Rect2(0, 0, w, 720), Color("070a1c"), Color("02030a"))
		# grid
		for x in range(0, int(w), 40):
			draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.3, 0.4, 0.8, 0.05), 1)
		for y in range(0, 720, 40):
			draw_line(Vector2(0, y), Vector2(w, y), Color(0.3, 0.4, 0.8, 0.05), 1)
		# water
		var water := [Vector2(0, 360), Vector2(140, 420), Vector2(160, 640), Vector2(400, 660), Vector2(880, 640), Vector2(960, 720), Vector2(0, 720)]
		NC.poly(self, water, Color("0a1838"))
		for i in 10:
			var y := 470.0 + i * 24
			var x := 20.0 + fmod(_t * 12 + i * 40, 80)
			draw_line(Vector2(x, y), Vector2(x + 40, y), Color(0.4, 0.6, 1.0, 0.15), 1)
		# land mass
		NC.poly(self, [Vector2(150, 440), Vector2(330, 210), Vector2(380, 130), Vector2(640, 110), Vector2(850, 140), Vector2(800, 270), Vector2(830, 440), Vector2(870, 610), Vector2(620, 650), Vector2(400, 640), Vector2(170, 630)], Color("0d0b1a"))
		var fills := {"crown": Color("1a1a3a"), "neonmile": Color("2a0f2e"), "velvet": Color("2a1420"), "palermo": Color("241a10"), "docks": Color("10202a"), "ashgate": Color("1a1a1a")}
		var neon := {"crown": NC.NEON_BLUE, "neonmile": NC.NEON_PINK, "velvet": NC.AMBER, "palermo": NC.GOLD, "docks": NC.NEON_CYAN, "ashgate": Color("c8c8d0")}
		for id in screen.POLYS:
			var pts: Array = screen.POLYS[id]
			var unlocked: bool = GameState.unlocked_districts.has(id)
			var col: Color = fills[id]
			if not unlocked:
				col = col.darkened(0.45)
			NC.poly(self, pts, col)
			# streets
			var c := Vector2.ZERO
			for p in pts:
				c += p
			c /= pts.size()
			for k in 5:
				draw_line(c + Vector2(-70, -40 + k * 20), c + Vector2(70, -46 + k * 20), Color(1, 1, 1, 0.05 if unlocked else 0.02), 1)
			var outline := PackedVector2Array(pts)
			outline.append(pts[0])
			var nc: Color = neon[id]
			var sel: bool = id == selected
			var pulse := 0.6 + 0.4 * sin(_t * 3.0)
			draw_polyline(outline, NC.a(nc, (0.9 * pulse if sel else 0.5) if unlocked else 0.18), 4.0 if sel else 2.0, true)
			var d: Dictionary = Catalog.district(id)
			var name: String = d["name"].replace("The ", "").to_upper()
			NC.text(self, c + Vector2(-110, 6), name, 20, NC.a(nc.lerp(Color.WHITE, 0.3), 1.0 if unlocked else 0.35), "title", HORIZONTAL_ALIGNMENT_CENTER, 220)
			if not unlocked:
				_lock(c + Vector2(0, 34))
		# velvet location pins
		var pins := [[Vector2(420, 360), NC.NEON_PINK], [Vector2(470, 340), NC.AMBER], [Vector2(520, 330), NC.GOLD], [Vector2(560, 350), NC.PALE_GOLD], [Vector2(590, 400), NC.NEON_CYAN]]
		for i in pins.size():
			var p: Vector2 = pins[i][0]
			if i == 4 and GameState.mission_done("m01_ledger"):
				continue
			NC.glow(self, p, 16, NC.a(pins[i][1], 0.5))
			draw_circle(p, 5, pins[i][1])
		if not GameState.mission_done("m01_ledger"):
			var p := Vector2(590, 400)
			draw_arc(p, 12 + 6 * fmod(_t * 1.5, 1.0), 0, TAU, 20, NC.a(NC.NEON_RED, 1.0 - fmod(_t * 1.5, 1.0)), 2)
		# title
		NC.neon_text(self, Vector2(40, 690), "NIGHTCITY", 44, NC.NEON_PINK, "deco")
		NC.text(self, Vector2(300, 688), "SIX DISTRICTS  ·  FIVE FAMILIES  ·  ONE CITY", 16, NC.a(NC.PALE_GOLD, 0.6), "title")

	func _lock(c: Vector2) -> void:
		draw_arc(c + Vector2(0, -8), 8, PI, TAU, 10, Color(0.8, 0.8, 0.85, 0.6), 3)
		draw_rect(Rect2(c + Vector2(-11, -8), Vector2(22, 18)), Color(0.8, 0.8, 0.85, 0.6))
		draw_circle(c + Vector2(0, 0), 3, Color("0d0b1a"))
