class_name VelvetStreet
extends Node2D
## The Velvet Quarter — first district street. Layered environment:
## parallax skyline → building facades → sidewalk → wet reflective road,
## with neon, lamps, rain, puddles, traffic, pedestrians and lightning.

const WORLD_W := 3600.0
const SIDEWALK_TOP := 560.0
const WALK_Y := 600.0
const CURB := 612.0
const VIEW_H := 720.0

var cam_x := 640.0                # camera centre, set by owner every frame
var view_w := 1280.0
var skyline: Skyline
var facades: Facades
var lights: Lights
var rain: Rain
var parked_car: Car
var traffic: Array = []
var peds: Array = []
var _sky_holder: Node2D
var _lightning_timer := 6.0

## interactable doors: id, x, label
var doors := [
	{"id": "velvet_hour", "x": 570.0, "label": "The Velvet Hour"},
	{"id": "morettis", "x": 1280.0, "label": "Moretti's Ristorante"},
	{"id": "tailor", "x": 1930.0, "label": "Sartori & Sons"},
	{"id": "calloway", "x": 2410.0, "label": "Calloway Building"},
	{"id": "suds", "x": 3180.0, "label": "Sable St. Offices"},
	{"id": "barrier", "x": 3440.0, "label": "Road to Sable Docks"},
]

func _ready() -> void:
	_sky_holder = Node2D.new()
	add_child(_sky_holder)
	skyline = Skyline.new()
	skyline.view_w = 1700
	skyline.horizon = 430
	skyline.world_w = 1400
	skyline.seed_value = 31
	_sky_holder.add_child(skyline)

	facades = Facades.new()
	add_child(facades)
	lights = Lights.new()
	lights.street = self
	add_child(lights)

	for i in 3:
		var p := Pedestrian.new()
		p.position = Vector2(400 + i * 1100, 578)
		p.scale = Vector2(0.78, 0.78)
		p.speed = randf_range(35, 55)
		p.dir = 1 if i % 2 == 0 else -1
		p.umbrella = i != 1
		p.rim = [NC.NEON_CYAN, NC.NEON_PINK, NC.AMBER][i]
		p.wrap_min = -150
		p.wrap_max = WORLD_W + 150
		add_child(p)
		peds.append(p)

func add_foreground() -> void:
	## Call after the player is added so cars & rain draw in front of him.
	parked_car = Car.new()
	parked_car.position = Vector2(1180, 742)
	parked_car.scale = Vector2(1.3, 1.3)
	parked_car.length = 380
	parked_car.lights_on = true
	add_child(parked_car)
	var t := Car.new()
	t.position = Vector2(-300, 706)
	t.scale = Vector2(1.12, 1.12)
	t.length = 360
	t.speed = 260.0
	t.body_color = Color("1a0f18")
	t.wrap_min = -800
	t.wrap_max = WORLD_W + 900
	add_child(t)
	traffic.append(t)
	rain = Rain.new()
	rain.area = Rect2(0, -60, 1700, 800)
	rain.ground_top = 600
	rain.ground_bottom = 720
	rain.count = 340
	for pr in facades.puddles:
		rain.puddles.append(pr)
	add_child(rain)

func set_camera(x: float, vw: float) -> void:
	cam_x = x
	view_w = vw
	_sky_holder.position.x = x - vw * 0.5 - 200
	skyline.scroll = x * 0.35
	if rain:
		rain.area.position.x = x - 850
	lights.queue_redraw()

func refresh() -> void:
	facades.queue_redraw()

func _process(delta: float) -> void:
	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = randf_range(14.0, 26.0)
		lightning()

func lightning() -> void:
	skyline.flash()
	lights.flash = 1.0
	get_tree().create_timer(randf_range(0.6, 1.4)).timeout.connect(func(): Audio.sfx("thunder", -4.0))

func nearest_door(x: float, reach: float = 70.0) -> Dictionary:
	var best := {}
	var bd := reach
	for d in doors:
		var dist: float = absf(d["x"] - x)
		if dist < bd:
			bd = dist
			best = d
	return best

# ============================================================== facades (static)
class Facades extends Node2D:
	var puddles: Array[Rect2] = [Rect2(700, 572, 120, 14), Rect2(1640, 588, 90, 10), Rect2(2560, 576, 140, 16),
		Rect2(400, 650, 180, 18), Rect2(1900, 690, 220, 20), Rect2(2950, 660, 160, 16), Rect2(3350, 590, 80, 10)]

	func _draw() -> void:
		var W := VelvetStreet.WORLD_W
		var ST := VelvetStreet.SIDEWALK_TOP
		_alley(0, 300)
		_velvet_hour(300, 820)
		_tenement(820, 1000)
		_morettis(1000, 1560)
		_gap(1560, 1700)
		_tailor(1700, 2160)
		_calloway(2160, 2660)
		_newsstand(2660, 2800)
		_suds(2800, 3300)
		_barrier(3300, W)
		# lamp posts (behind the walking line)
		for lx in VelvetStreet.LAMPS:
			draw_rect(Rect2(lx - 3, 300, 6, ST + 6 - 300), Color("0a0910"))
			draw_rect(Rect2(lx - 8, ST - 4, 16, 10), Color("0a0910"))
			NC.poly(self, [Vector2(lx - 14, 300), Vector2(lx + 14, 300), Vector2(lx + 8, 286), Vector2(lx - 8, 286)], Color("0a0910"))
			draw_line(Vector2(lx - 3, 300), Vector2(lx - 3, ST), NC.a(NC.NEON_PINK, 0.3), 1.0)
		# sidewalk
		NC.vgrad(self, Rect2(-200, ST, W + 400, VelvetStreet.CURB - ST), Color("1c1830"), Color("120f22"))
		for x in range(-200, int(W) + 200, 90):
			draw_line(Vector2(x, ST), Vector2(x - 14, VelvetStreet.CURB), Color(0, 0, 0, 0.35), 1.0)
		draw_line(Vector2(-200, ST + 1), Vector2(W + 200, ST + 1), Color(1, 1, 1, 0.06), 2.0)
		# curb + road
		draw_rect(Rect2(-200, VelvetStreet.CURB, W + 400, 6), Color("2a2540"))
		NC.vgrad(self, Rect2(-200, VelvetStreet.CURB + 6, W + 400, 110), Color("0c0a16"), Color("05040a"))
		for x in range(-200, int(W) + 200, 160):
			draw_rect(Rect2(x, 686, 70, 3), Color(0.9, 0.8, 0.5, 0.12))
		# puddles
		for p in puddles:
			NC.ellipse(self, p.get_center(), p.size.x * 0.5, p.size.y * 0.5, Color(0.03, 0.02, 0.07, 0.9))
			NC.ellipse_line(self, p.get_center(), p.size.x * 0.5, p.size.y * 0.5, Color(0.6, 0.5, 0.9, 0.25), 1.0)

	# ------------------------------------------------ helpers
	func _bricks(r: Rect2, col: Color) -> void:
		draw_rect(r, col)
		var row := 0
		var y := r.position.y
		while y < r.end.y:
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), col.darkened(0.35), 1.0)
			var off := 0.0 if row % 2 == 0 else 14.0
			var x := r.position.x + off
			while x < r.end.x:
				draw_line(Vector2(x, y), Vector2(x, minf(y + 9, r.end.y)), col.darkened(0.3), 1.0)
				x += 28
			y += 9
			row += 1

	func _window(r: Rect2, lit: int, frame := Color("0a0910")) -> void:
		draw_rect(r.grow(3), frame)
		match lit:
			0:
				NC.vgrad(self, r, Color("141026"), Color("0a0816"))
				draw_line(r.position + Vector2(4, 4), r.position + Vector2(r.size.x * 0.4, r.size.y * 0.5), Color(0.6, 0.5, 1.0, 0.12), 2.0)
			1:
				NC.vgrad(self, r, NC.WARM, NC.AMBER.darkened(0.3))
				for k in int(r.size.y / 8):
					draw_line(Vector2(r.position.x, r.position.y + k * 8 + 4), Vector2(r.end.x, r.position.y + k * 8 + 4), Color(0.4, 0.2, 0.05, 0.35), 1.0)
			2:
				NC.vgrad(self, r, Color("8ad8ff"), Color("3a5ab0"))
		draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), frame, 2.0)

	func _cornice(x0: float, x1: float, y: float, col: Color) -> void:
		draw_rect(Rect2(x0 - 6, y - 10, x1 - x0 + 12, 10), col.lightened(0.05))
		draw_rect(Rect2(x0 - 2, y, x1 - x0 + 4, 5), col.darkened(0.3))

	# ------------------------------------------------ buildings
	func _alley(x0: float, x1: float) -> void:
		var ST := VelvetStreet.SIDEWALK_TOP
		_bricks(Rect2(x0, 90, x1 - x0, ST - 90), Color("1a1222"))
		NC.vgrad(self, Rect2(x0, 90, x1 - x0, ST - 90), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.1))
		# fire escape
		for k in 4:
			var y := 160.0 + k * 90
			draw_rect(Rect2(x0 + 40, y, 180, 4), Color("06050a"))
			for b in 10:
				draw_line(Vector2(x0 + 40 + b * 20, y), Vector2(x0 + 40 + b * 20, y - 26), Color("06050a"), 1.5)
			draw_line(Vector2(x0 + 40, y - 26), Vector2(x0 + 220, y - 26), Color("06050a"), 2.0)
			draw_line(Vector2(x0 + 60, y + 4), Vector2(x0 + 190, y + 86), Color("06050a"), 3.0)
		_window(Rect2(x0 + 90, 200, 50, 60), 1)
		_window(Rect2(x0 + 90, 380, 50, 60), 0)
		# dumpster
		NC.poly(self, [Vector2(x0 + 60, ST + 2), Vector2(x0 + 60, ST - 70), Vector2(x0 + 190, ST - 78), Vector2(x0 + 190, ST + 2)], Color("16302a"))
		draw_line(Vector2(x0 + 60, ST - 70), Vector2(x0 + 190, ST - 78), NC.a(NC.NEON_CYAN, 0.4), 2.0)

	func _velvet_hour(x0: float, x1: float) -> void:
		var ST := VelvetStreet.SIDEWALK_TOP
		var top := 150.0
		draw_rect(Rect2(x0, top, x1 - x0, ST - top), Color("0c0a12"))
		# gold deco fins
		for k in 7:
			var fx := x0 + 20 + k * (x1 - x0 - 40) / 6.0
			draw_rect(Rect2(fx - 4, top + 10, 8, 170), Color("3a2c14"))
			draw_line(Vector2(fx - 4, top + 10), Vector2(fx - 4, top + 180), NC.a(NC.GOLD, 0.6), 1.0)
		NC.poly(self, [Vector2(x0 + 140, top), Vector2((x0 + x1) * 0.5, top - 70), Vector2(x1 - 140, top)], Color("0c0a12"))
		NC.poly(self, [Vector2(x0 + 190, top), Vector2((x0 + x1) * 0.5, top - 46), Vector2(x1 - 190, top)], Color("2a2010"))
		draw_circle(Vector2((x0 + x1) * 0.5, top - 22), 12, NC.GOLD.darkened(0.3))
		for k in 3:
			_window(Rect2(x0 + 70 + k * 140, 220, 80, 70), 1 if k != 1 else 0)
		# entrance
		var dx := 520.0
		draw_rect(Rect2(dx - 10, 380, 120, ST - 380), Color("1e1408"))
		draw_rect(Rect2(dx, 400, 100, ST - 400), Color("2a1a0c"))
		draw_line(Vector2(dx + 50, 400), Vector2(dx + 50, ST), Color("120a04"), 2.0)
		for k in 2:
			draw_circle(Vector2(dx + 25 + k * 50, 450), 13, NC.WARM)
			draw_arc(Vector2(dx + 25 + k * 50, 450), 13, 0, TAU, 16, NC.GOLD, 2.0)
		# posters
		for px in [x0 + 50, x1 - 150]:
			draw_rect(Rect2(px, 410, 90, 120), NC.GOLD.darkened(0.4))
			NC.vgrad(self, Rect2(px + 5, 415, 80, 110), Color("6e1b2c"), Color("1b0a10"))
			draw_circle(Vector2(px + 45, 450), 9, Color("0a0508"))
			NC.poly(self, [Vector2(px + 30, 520), Vector2(px + 36, 462), Vector2(px + 54, 462), Vector2(px + 60, 520)], Color("0a0508"))
			draw_line(Vector2(px + 52, 470), Vector2(px + 68, 500), NC.GOLD, 3.0)
			NC.text(self, Vector2(px + 8, 432), "LIVE", 14, NC.PALE_GOLD, "title")
		# marquee base (lights drawn dynamically)
		draw_rect(Rect2(x0 + 90, 330, x1 - x0 - 180, 52), Color("120a14"))
		draw_rect(Rect2(x0 + 90, 330, x1 - x0 - 180, 52), NC.GOLD.darkened(0.2), false, 2.0)

	func _tenement(x0: float, x1: float) -> void:
		var ST := VelvetStreet.SIDEWALK_TOP
		_bricks(Rect2(x0, 110, x1 - x0, ST - 110), Color("2a1620"))
		_cornice(x0, x1, 110, Color("1a0e14"))
		for r in 4:
			for c in 2:
				_window(Rect2(x0 + 30 + c * 80, 150 + r * 100, 46, 64), [1, 0, 0, 1, 0, 1, 1, 0][r * 2 + c])
		draw_rect(Rect2(x0 + 60, 470, 60, ST - 470), Color("0a0608"))

	func _morettis(x0: float, x1: float) -> void:
		var ST := VelvetStreet.SIDEWALK_TOP
		var top := 170.0
		draw_rect(Rect2(x0, top, x1 - x0, ST - top), Color("2a1c20"))
		for k in int((ST - top) / 22):
			draw_line(Vector2(x0, top + k * 22), Vector2(x1, top + k * 22), Color(0, 0, 0, 0.25), 1.0)
		_cornice(x0, x1, top, Color("3a262a"))
		for k in 4:
			var wx := x0 + 40 + k * 125
			draw_rect(Rect2(wx - 4, 200, 78, 110), Color("1a1012"))
			draw_arc(Vector2(wx + 35, 214), 39, PI, TAU, 16, Color("1a1012"), 8)
			_window(Rect2(wx, 214, 70, 92), 1 if k % 2 == 0 else 0)
		# big dining windows with diners
		for wr in [Rect2(x0 + 40, 410, 200, 130), Rect2(x0 + 320, 410, 200, 130)]:
			draw_rect(wr.grow(6), Color("120a0c"))
			NC.vgrad(self, wr, Color("ffcf7a"), Color("b0602a"))
			NC.glow(self, wr.get_center() + Vector2(0, 10), 90, Color(1.0, 0.85, 0.5, 0.35))
			for d in 3:
				var dxp = wr.position.x + 30 + d * 70
				NC.ellipse(self, Vector2(dxp, wr.position.y + 62), 10, 12, Color("2a1208"))
				NC.poly(self, [Vector2(dxp - 18, wr.end.y), Vector2(dxp - 14, wr.position.y + 76), Vector2(dxp + 14, wr.position.y + 76), Vector2(dxp + 18, wr.end.y)], Color("2a1208"))
			draw_rect(Rect2(wr.position.x, wr.end.y - 26, wr.size.x, 26), Color("3a1a10"))
			for d in 2:
				NC.glow(self, Vector2(wr.position.x + 65 + d * 70, wr.end.y - 32), 14, Color(1, 0.9, 0.6, 0.9))
			NC.text(self, wr.position + Vector2(16, 26), "Ristorante · Est. 1931", 13, Color("5a2a10"), "deco")
		# door
		draw_rect(Rect2(1250, 420, 60, ST - 420), Color("1a0c08"))
		draw_rect(Rect2(1256, 430, 48, 60), NC.AMBER.darkened(0.2))
		draw_circle(Vector2(1300, 500), 3, NC.GOLD)
		# awning
		var ay := 360.0
		var stripes := 14
		var aw := (x1 - x0 - 40) / stripes
		for k in stripes:
			var col := NC.BURGUNDY if k % 2 == 0 else NC.BURGUNDY.darkened(0.35)
			NC.poly(self, [Vector2(x0 + 20 + k * aw, ay), Vector2(x0 + 20 + (k + 1) * aw, ay), Vector2(x0 + 10 + (k + 1) * aw * 1.0, ay + 40), Vector2(x0 + 10 + k * aw, ay + 40)], col)
		for k in stripes:
			draw_arc(Vector2(x0 + 10 + k * aw + aw * 0.5, ay + 40), aw * 0.5, 0, PI, 8, NC.BURGUNDY.darkened(0.2), 4)
		NC.text(self, Vector2(x0 + 20, ay + 30), "MORETTI'S", 30, NC.GOLD, "deco", HORIZONTAL_ALIGNMENT_CENTER, x1 - x0 - 40)
		# planters
		for px in [x0 + 20, x1 - 50]:
			draw_rect(Rect2(px, ST - 40, 30, 40), Color("1a1010"))
			NC.ellipse(self, Vector2(px + 15, ST - 52), 22, 20, Color("0c1a10"))

	func _gap(x0: float, x1: float) -> void:
		var ST := VelvetStreet.SIDEWALK_TOP
		NC.vgrad(self, Rect2(x0, 300, x1 - x0, ST - 300), Color(0.05, 0.03, 0.1, 0.0), Color(0.03, 0.02, 0.06, 0.95))
		_bricks(Rect2(x0 + 20, 420, x1 - x0 - 40, ST - 420), Color("120c18"))
		NC.vgrad(self, Rect2(x0 + 20, 420, x1 - x0 - 40, ST - 420), Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.3))

	func _tailor(x0: float, x1: float) -> void:
		var ST := VelvetStreet.SIDEWALK_TOP
		var top := 190.0
		draw_rect(Rect2(x0, top, x1 - x0, ST - top), Color("0f1916"))
		_cornice(x0, x1, top, Color("15231f"))
		for k in 4:
			_window(Rect2(x0 + 30 + k * 108, 220, 70, 60), 1 if k == 2 else 0)
		draw_rect(Rect2(x0 + 20, 300, x1 - x0 - 40, 46), Color("06100c"))
		draw_rect(Rect2(x0 + 20, 300, x1 - x0 - 40, 46), NC.GOLD, false, 2)
		NC.text(self, Vector2(x0 + 20, 336), "SARTORI & SONS", 30, NC.GOLD, "deco", HORIZONTAL_ALIGNMENT_CENTER, x1 - x0 - 40)
		NC.text(self, Vector2(x0 + 20, 362), "BESPOKE TAILORING · SINCE 1922", 12, NC.PALE_GOLD, "sans", HORIZONTAL_ALIGNMENT_CENTER, x1 - x0 - 40)
		for wr in [Rect2(x0 + 30, 380, 150, 170), Rect2(x1 - 180, 380, 150, 170)]:
			draw_rect(wr.grow(5), Color("06100c"))
			NC.vgrad(self, wr, Color("f3e6c8"), Color("9a7c50"))
			NC.glow(self, wr.get_center(), 90, Color(1, 0.95, 0.8, 0.35))
			for m in 2:
				var mx = wr.position.x + 45 + m * 60
				var cols := [Color("1b2550"), Color("5e1626"), Color("3a3a44"), Color("121118")]
				var col: Color = cols[(int(wr.position.x) / 10 + m) % 4]
				NC.poly(self, [Vector2(mx - 24, wr.position.y + 50), Vector2(mx + 24, wr.position.y + 50), Vector2(mx + 18, wr.position.y + 130), Vector2(mx - 18, wr.position.y + 130)], col)
				NC.poly(self, [Vector2(mx - 6, wr.position.y + 50), Vector2(mx + 6, wr.position.y + 50), Vector2(mx, wr.position.y + 84)], Color("e9e6df"))
				draw_line(Vector2(mx, wr.position.y + 54), Vector2(mx, wr.position.y + 80), Color("6e1b2c"), 3)
				draw_line(Vector2(mx, wr.position.y + 130), Vector2(mx, wr.end.y - 4), Color("3a2a1a"), 3)
				draw_circle(Vector2(mx, wr.position.y + 40), 8, Color("d9cdb0"))
		draw_rect(Rect2(x0 + 200, 400, 60, ST - 400), Color("06100c"))
		draw_rect(Rect2(x0 + 208, 410, 44, 70), NC.WARM.darkened(0.2))

	func _calloway(x0: float, x1: float) -> void:
		var ST := VelvetStreet.SIDEWALK_TOP
		var top := 30.0
		draw_rect(Rect2(x0, top, x1 - x0, ST - top), Color("1c1830"))
		draw_rect(Rect2(x0 + 60, top - 30, x1 - x0 - 120, 30), Color("1c1830"))
		draw_rect(Rect2(x0 + 140, top - 50, x1 - x0 - 280, 20), Color("1c1830"))
		for k in 5:
			draw_rect(Rect2(x0 + 30 + k * 100, top, 6, ST - top), Color("26213e"))
		var owned := GameState.owns_property("calloway_4b")
		for r in 4:
			for c in 4:
				var lit = [0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1][r * 4 + c]
				if r == 1 and c == 2:
					lit = 1 if owned else 0
				_window(Rect2(x0 + 60 + c * 105, 70 + r * 72, 60, 46), lit)
		# apt 4B marker
		var b4 := Rect2(x0 + 60 + 2 * 105, 70 + 72, 60, 46)
		if owned:
			NC.glow(self, b4.get_center(), 50, Color(1, 0.8, 0.4, 0.3))
		draw_rect(Rect2(x0 + 180, 380, 140, 26), Color("2a1a0c"))
		draw_rect(Rect2(x0 + 180, 380, 140, 26), NC.GOLD, false, 2)
		NC.text(self, Vector2(x0 + 180, 400), "CALLOWAY", 18, NC.GOLD, "deco", HORIZONTAL_ALIGNMENT_CENTER, 140)
		draw_rect(Rect2(x0 + 210, 410, 80, ST - 410), Color("120e1a"))
		draw_rect(Rect2(x0 + 220, 420, 60, ST - 420), NC.AMBER.darkened(0.45))
		draw_line(Vector2(x0 + 250, 420), Vector2(x0 + 250, ST), Color("120e1a"), 2)
		# lobby window with sale sign
		var sw := Rect2(x0 + 340, 420, 120, 100)
		_window(sw, 1)
		draw_rect(Rect2(sw.position.x + 10, sw.position.y + 20, 100, 60), Color("f2ead8"))
		if owned:
			NC.text(self, Vector2(sw.position.x + 10, sw.position.y + 46), "APT 4B", 16, Color("1a1410"), "title", HORIZONTAL_ALIGNMENT_CENTER, 100)
			NC.text(self, Vector2(sw.position.x + 10, sw.position.y + 70), "SOLD", 22, NC.BURGUNDY, "title", HORIZONTAL_ALIGNMENT_CENTER, 100)
		else:
			NC.text(self, Vector2(sw.position.x + 10, sw.position.y + 42), "FOR SALE", 16, NC.BURGUNDY, "title", HORIZONTAL_ALIGNMENT_CENTER, 100)
			NC.text(self, Vector2(sw.position.x + 10, sw.position.y + 58), "APT 4B", 13, Color("1a1410"), "title", HORIZONTAL_ALIGNMENT_CENTER, 100)
			NC.text(self, Vector2(sw.position.x + 10, sw.position.y + 74), "$2,000", 14, Color("1a1410"), "title", HORIZONTAL_ALIGNMENT_CENTER, 100)
		_window(Rect2(x0 + 40, 420, 120, 100), 0)

	func _newsstand(x0: float, x1: float) -> void:
		var ST := VelvetStreet.SIDEWALK_TOP
		_bricks(Rect2(x0, 260, x1 - x0, ST - 260), Color("1a1424"))
		draw_rect(Rect2(x0 + 20, 440, x1 - x0 - 40, ST - 440), Color("2a2010"))
		NC.poly(self, [Vector2(x0 + 10, 440), Vector2(x1 - 10, 440), Vector2(x1, 420), Vector2(x0, 420)], Color("3a1a14"))
		for k in 4:
			draw_rect(Rect2(x0 + 28 + k * 24, 460, 20, 28), Color("e8e0cc"))
			draw_rect(Rect2(x0 + 30 + k * 24, 464, 16, 4), Color("1a1410"))
		NC.text(self, Vector2(x0 + 10, 436), "HERALD", 14, NC.PALE_GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, x1 - x0 - 20)

	func _suds(x0: float, x1: float) -> void:
		var ST := VelvetStreet.SIDEWALK_TOP
		var top := 230.0
		_bricks(Rect2(x0, top, x1 - x0, ST - top), Color("16202a"))
		_cornice(x0, x1, top, Color("1a2630"))
		# upstairs office (the Castellano books)
		for k in 3:
			var r := Rect2(x0 + 40 + k * 140, 260, 100, 80)
			_window(r, 1 if k == 2 else 0)
			if k == 2:
				for b in 8:
					draw_line(Vector2(r.position.x, r.position.y + b * 10 + 4), Vector2(r.end.x, r.position.y + b * 10 + 4), Color(0.3, 0.15, 0.05, 0.6), 2.0)
				NC.ellipse(self, Vector2(r.position.x + 40, r.position.y + 36), 9, 11, Color(0.1, 0.05, 0.02, 0.8))
				NC.poly(self, [Vector2(r.position.x + 22, r.end.y), Vector2(r.position.x + 28, r.position.y + 48), Vector2(r.position.x + 52, r.position.y + 48), Vector2(r.position.x + 58, r.end.y)], Color(0.1, 0.05, 0.02, 0.8))
		# laundromat window
		var lw := Rect2(x0 + 30, 400, 300, 150)
		draw_rect(lw.grow(5), Color("0a1016"))
		NC.vgrad(self, lw, Color("bff3ff"), Color("4a8aa8"))
		for k in 4:
			var c := Vector2(lw.position.x + 40 + k * 72, lw.position.y + 100)
			draw_rect(Rect2(c - Vector2(30, 40), Vector2(60, 80)), Color("dfe8ea"))
			draw_circle(c, 22, Color("1a2a34"))
			draw_circle(c, 17, Color("4a7a9a"))
			draw_arc(c, 22, 0, TAU, 18, Color("9aa8b0"), 3)
		# office side door
		draw_rect(Rect2(3150, 410, 64, ST - 410), Color("0a0c10"))
		draw_rect(Rect2(3156, 420, 52, 40), Color("2a3238"))
		NC.text(self, Vector2(3150, 404), "OFFICES · 2F", 11, Color("9ab0c0"), "sans", HORIZONTAL_ALIGNMENT_CENTER, 64)

	func _barrier(x0: float, x1: float) -> void:
		var ST := VelvetStreet.SIDEWALK_TOP
		_bricks(Rect2(x0, 200, x1 - x0, ST - 200), Color("141020"))
		NC.vgrad(self, Rect2(x0, 200, x1 - x0, ST - 200), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.2))
		for k in 3:
			var bx := x0 + 60 + k * 70
			draw_rect(Rect2(bx, ST - 50, 60, 10), Color("d8a020"))
			for s in 4:
				draw_rect(Rect2(bx + s * 16, ST - 50, 8, 10), Color("101010"))
			draw_line(Vector2(bx + 6, ST - 40), Vector2(bx, ST + 2), Color("2a2a2a"), 3)
			draw_line(Vector2(bx + 54, ST - 40), Vector2(bx + 60, ST + 2), Color("2a2a2a"), 3)
		draw_rect(Rect2(x0 + 70, 400, 180, 70), Color("1a1a1a"))
		draw_rect(Rect2(x0 + 70, 400, 180, 70), Color("d8a020"), false, 3)
		NC.text(self, Vector2(x0 + 70, 428), "ROAD CLOSED", 22, Color("d8a020"), "title", HORIZONTAL_ALIGNMENT_CENTER, 180)
		NC.text(self, Vector2(x0 + 70, 456), "SABLE DOCKS — NCPD", 13, Color("e0e0e0"), "sans", HORIZONTAL_ALIGNMENT_CENTER, 180)

# ============================================================== dynamic lights
const LAMPS := [250.0, 980.0, 1630.0, 2300.0, 2740.0, 3260.0]

class Lights extends Node2D:
	var street: VelvetStreet
	var flash := 0.0
	var _t := 0.0
	var _steam := []

	func _ready() -> void:
		for i in 14:
			_steam.append([randf() * 3.0, randf_range(-20, 20)])

	func _process(delta: float) -> void:
		_t += delta
		flash = maxf(0.0, flash - delta * 2.5)
		queue_redraw()

	func _visible(x: float, margin: float = 300.0) -> bool:
		return absf(x - street.cam_x) < street.view_w * 0.5 + margin

	func _neon_flicker(seed_v: float) -> float:
		var n := sin(_t * 23.0 + seed_v * 7.0) * sin(_t * 3.1 + seed_v)
		return 0.35 if n > 0.93 else 1.0

	func _reflect(x: float, col: Color, w: float, strength: float = 0.25) -> void:
		var top := VelvetStreet.CURB + 6
		for k in 9:
			var y := top + k * 12.0
			var off := sin(_t * 1.7 + k * 0.9 + x * 0.013) * 5.0
			var ww := w * (1.0 - k * 0.07) * (0.7 + 0.3 * sin(_t * 2.3 + k * 1.3 + x))
			draw_line(Vector2(x - ww * 0.5 + off, y), Vector2(x + ww * 0.5 + off, y), NC.a(col, strength * (1.0 - k * 0.09)), 3.0)

	func _draw() -> void:
		# street lamps
		for lx in VelvetStreet.LAMPS:
			if not _visible(lx):
				continue
			NC.cone(self, Vector2(lx, 296), PI / 2, 280, 0.32, Color(1.0, 0.82, 0.5, 0.13))
			NC.glow(self, Vector2(lx, 296), 70, Color(1.0, 0.8, 0.45, 0.28))
			draw_circle(Vector2(lx, 294), 5, Color(1, 0.95, 0.8))
			NC.ellipse(self, Vector2(lx, VelvetStreet.SIDEWALK_TOP + 26), 120, 14, Color(1.0, 0.8, 0.45, 0.07))
			_reflect(lx, NC.AMBER, 30)
		# Velvet Hour marquee + vertical JAZZ sign
		if _visible(560):
			var x0 := 390.0
			var x1 := 730.0
			var f := _neon_flicker(1.0)
			NC.glow(self, Vector2(560, 356), 220, Color(1.0, 0.2, 0.8, 0.12 * f), 0.35)
			NC.neon_text(self, Vector2(x0, 366), "THE VELVET HOUR", 26, NC.NEON_PINK, "deco", HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, f)
			var n := 28
			for i in n:
				var on := int(_t * 8.0 + i) % 3 != 0
				var bx := x0 + (x1 - x0) * float(i) / (n - 1)
				draw_circle(Vector2(bx, 333), 2.5, NC.WARM if on else Color("4a3010"))
				draw_circle(Vector2(bx, 379), 2.5, NC.WARM if not on else Color("4a3010"))
			var jf := _neon_flicker(3.3)
			draw_rect(Rect2(770, 160, 36, 150), Color("08060e"))
			draw_rect(Rect2(770, 160, 36, 150), NC.a(NC.NEON_CYAN, 0.8 * jf), false, 2)
			NC.glow(self, Vector2(788, 235), 90, NC.a(NC.NEON_CYAN, 0.14 * jf))
			for i in 4:
				NC.neon_text(self, Vector2(770, 196 + i * 34), "JAZZ"[i], 30, NC.NEON_CYAN, "title", HORIZONTAL_ALIGNMENT_CENTER, 36, jf)
			_reflect(560, NC.NEON_PINK, 120, 0.22)
			_reflect(788, NC.NEON_CYAN, 30, 0.3)
			NC.text(self, Vector2(x0, 398), "TONIGHT · THE MIDNIGHT QUARTET", 12, NC.PALE_GOLD, "sans", HORIZONTAL_ALIGNMENT_CENTER, x1 - x0)
		# Moretti's warm windows reflected
		if _visible(1280):
			_reflect(1140, NC.AMBER, 120, 0.16)
			_reflect(1420, NC.AMBER, 120, 0.16)
			NC.glow(self, Vector2(1280, 470), 60, Color(1, 0.7, 0.3, 0.12))
		# Tailor shop glow
		if _visible(1930):
			_reflect(1805, NC.WARM, 100, 0.14)
			_reflect(2055, NC.WARM, 100, 0.14)
		# Calloway lamps
		if _visible(2410):
			for lx in [2370.0, 2450.0]:
				NC.glow(self, Vector2(lx, 430), 24, Color(1, 0.85, 0.5, 0.5))
				draw_circle(Vector2(lx, 430), 4, NC.WARM)
		# Laundromat neon
		if _visible(3050):
			var sf := _neon_flicker(5.5)
			NC.glow(self, Vector2(3000, 380), 160, NC.a(NC.NEON_CYAN, 0.12 * sf), 0.4)
			NC.neon_text(self, Vector2(2830, 392), "SUDS  24HR  LAUNDRY", 26, NC.NEON_CYAN, "title", HORIZONTAL_ALIGNMENT_CENTER, 300, sf)
			_reflect(2980, NC.NEON_CYAN, 160, 0.2)
		# barrier hazard blinker
		if _visible(3450):
			var on := int(_t * 2.0) % 2 == 0
			for k in 3:
				var bx := 3360.0 + k * 70 + 30
				if on:
					NC.glow(self, Vector2(bx, VelvetStreet.SIDEWALK_TOP - 58), 22, Color(1, 0.65, 0.1, 0.7))
				draw_circle(Vector2(bx, VelvetStreet.SIDEWALK_TOP - 58), 4, Color(1, 0.7, 0.2) if on else Color("3a2a10"))
			if on:
				_reflect(3430, Color(1, 0.65, 0.1), 60, 0.2)
		# alley steam
		if _visible(1630):
			for s in _steam:
				var life := fmod(_t * 0.35 + s[0], 3.0) / 3.0
				var p := Vector2(1630 + s[1] + sin(_t + s[0]) * 14 * life, VelvetStreet.SIDEWALK_TOP + 10 - life * 260)
				NC.glow(self, p, 30 + life * 60, Color(0.75, 0.7, 0.95, 0.10 * (1.0 - life)))
		# lightning wash
		if flash > 0.0:
			draw_rect(Rect2(street.cam_x - 1000, -100, 2000, 900), Color(0.8, 0.85, 1.0, 0.22 * flash))
