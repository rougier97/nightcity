class_name Skyline
extends Node2D
## Layered parallax skyline: violet sky, moon, searchlights, three depths of
## art-deco towers with flickering amber windows and neon signs.

@export var view_w := 1600.0
@export var view_h := 720.0
@export var horizon := 560.0
@export var world_w := 4200.0
@export var seed_value := 7
@export var beams := true
@export var moon := true

var scroll := 0.0:
	set(v):
		scroll = v
		_apply_scroll()

var _sky: SkyLayer
var _beams: BeamLayer
var _layers: Array = []
const FACTORS := [0.18, 0.4, 0.7]

func _ready() -> void:
	build()

func build() -> void:
	for c in get_children():
		c.queue_free()
	_layers.clear()
	_sky = SkyLayer.new()
	_sky.size = Vector2(view_w, view_h)
	_sky.horizon = horizon
	_sky.moon = moon
	add_child(_sky)
	_beams = BeamLayer.new()
	_beams.horizon = horizon
	_beams.view_w = view_w
	_beams.visible = beams
	add_child(_beams)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 3:
		var l := BuildingLayer.new()
		l.depth = i
		l.horizon = horizon
		l.width = view_w + world_w * FACTORS[i] + 200.0
		l.generate(rng)
		add_child(l)
		_layers.append(l)
	var haze := HazeLayer.new()
	haze.horizon = horizon
	haze.view_w = view_w
	add_child(haze)
	_apply_scroll()

func _apply_scroll() -> void:
	for i in _layers.size():
		_layers[i].position.x = -scroll * FACTORS[i]

func max_scroll() -> float:
	return world_w

func flash() -> void:
	if _sky:
		_sky.flash()

# ============================================================== sky
class SkyLayer extends Node2D:
	var size := Vector2(1600, 720)
	var horizon := 560.0
	var moon := true
	var _stars := []
	var _clouds := []
	var _flash := 0.0
	var _t := 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		for i in 90:
			_stars.append([Vector2(rng.randf() * size.x, rng.randf() * horizon * 0.6), rng.randf_range(0.6, 1.6), rng.randf()])
		for i in 9:
			_clouds.append([Vector2(rng.randf() * (size.x + 400) - 200, rng.randf_range(60, horizon * 0.55)), rng.randf_range(160, 380), rng.randf_range(18, 40), rng.randf_range(4, 12)])

	func flash() -> void:
		_flash = 1.0

	func _process(delta: float) -> void:
		_t += delta
		for c in _clouds:
			var p: Vector2 = c[0]
			p.x += c[3] * delta
			if p.x - c[1] > size.x + 100:
				p.x = -c[1] - 100
			c[0] = p
		_flash = max(0.0, _flash - delta * 2.5)
		queue_redraw()

	func _draw() -> void:
		var h1 := horizon * 0.45
		NC.vgrad(self, Rect2(0, -40, size.x, h1 + 40), Color("05040e"), Color("1a1440"))
		NC.vgrad(self, Rect2(0, h1, size.x, horizon - h1), Color("1a1440"), Color("4a2a78"))
		NC.vgrad(self, Rect2(0, horizon, size.x, size.y - horizon + 40), Color("4a2a78"), Color("20123a"))
		for s in _stars:
			var tw: float = 0.4 + 0.6 * abs(sin(_t * 0.8 + s[2] * 10.0))
			draw_circle(s[0], s[1] * 0.6, Color(1, 0.95, 0.9, 0.35 * tw))
		if moon:
			var mc := Vector2(size.x * 0.78, horizon * 0.26)
			NC.glow(self, mc, 190, Color(0.75, 0.7, 1.0, 0.16))
			NC.glow(self, mc, 90, Color(0.95, 0.9, 1.0, 0.25))
			draw_circle(mc, 46, Color("e9e2f5"))
			draw_circle(mc + Vector2(-12, -8), 9, Color("d5cce6"))
			draw_circle(mc + Vector2(14, 12), 6, Color("d5cce6"))
			draw_circle(mc + Vector2(6, -18), 4, Color("d9d0ea"))
		for c in _clouds:
			var p: Vector2 = c[0]
			NC.ellipse(self, p, c[1], c[2], Color(0.07, 0.05, 0.16, 0.85))
			NC.ellipse(self, p + Vector2(c[1] * 0.3, -c[2] * 0.5), c[1] * 0.5, c[2] * 0.8, Color(0.09, 0.06, 0.19, 0.85))
			NC.ellipse(self, p + Vector2(0, c[2] * 0.55), c[1] * 0.85, c[2] * 0.3, Color(0.5, 0.25, 0.6, 0.18))
		if _flash > 0.0:
			draw_rect(Rect2(0, -40, size.x, size.y + 80), Color(0.8, 0.85, 1.0, 0.45 * _flash))

# ============================================================== beams
class BeamLayer extends Node2D:
	var horizon := 560.0
	var view_w := 1600.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var bases := [view_w * 0.18, view_w * 0.52, view_w * 0.86]
		for i in bases.size():
			var ang := -PI / 2 + sin(_t * (0.18 + i * 0.07) + i * 2.1) * 0.55
			NC.cone(self, Vector2(bases[i], horizon), ang, horizon * 1.4, 0.05, Color(0.85, 0.82, 1.0, 0.10))

# ============================================================== haze
class HazeLayer extends Node2D:
	var horizon := 560.0
	var view_w := 1600.0
	func _draw() -> void:
		NC.vgrad(self, Rect2(0, horizon - 160, view_w, 160), Color(0.55, 0.2, 0.6, 0.0), Color(0.6, 0.22, 0.55, 0.22))
		NC.vgrad(self, Rect2(0, horizon, view_w, 300), Color(0.05, 0.03, 0.1, 0.7), Color(0.02, 0.01, 0.05, 0.95))

# ============================================================== buildings
class BuildingLayer extends Node2D:
	var depth := 0
	var horizon := 560.0
	var width := 2000.0
	var buildings := []
	var _timer := 0.0
	var _blink := false
	const SIGN_WORDS := ["HOTEL", "JAZZ", "BAR", "CAFE", "LOUNGE", "OPEN", "DINER", "CLUB", "RADIO", "BAR"]

	func generate(rng: RandomNumberGenerator) -> void:
		var x := -120.0
		var wmin: float = [46.0, 70.0, 100.0][depth]
		var wmax: float = [110.0, 160.0, 210.0][depth]
		var hmin: float = [150.0, 210.0, 250.0][depth]
		var hmax: float = [360.0, 440.0, 520.0][depth]
		while x < width:
			var w := rng.randf_range(wmin, wmax)
			var h := rng.randf_range(hmin, hmax)
			if rng.randf() < 0.12:
				h *= 1.35
			var b := {
				"x": x, "w": w, "h": h,
				"top": ["flat", "stepped", "stepped", "spire", "pyramid", "antenna", "crown"][rng.randi() % 7],
				"windows": [], "bands": rng.randf() < 0.35, "sign": null,
				"rim": rng.randf() < 0.5,
			}
			var ww: float = [3.0, 5.0, 7.0][depth]
			var wh: float = [4.0, 7.0, 10.0][depth]
			var gx: float = [5.0, 8.0, 11.0][depth]
			var gy: float = [7.0, 11.0, 15.0][depth]
			var cols := int((w - gx) / (ww + gx))
			var rows := int((h - 30.0) / (wh + gy))
			var lit_p := rng.randf_range(0.18, 0.5)
			for r in rows:
				for c in cols:
					if b["bands"] and c % 3 == 1:
						continue
					var wx := x + gx + c * (ww + gx) + (w - gx - cols * (ww + gx)) * 0.5 + gx * 0.5
					var wy := horizon - h + 24.0 + r * (wh + gy)
					var kind := 0
					var roll := rng.randf()
					if roll < lit_p:
						kind = 1 if rng.randf() < 0.85 else (2 if rng.randf() < 0.6 else 3)
					b["windows"].append([Rect2(wx, wy, ww, wh), kind, rng.randf()])
			if depth >= 1 and rng.randf() < 0.32:
				var word: String = SIGN_WORDS[rng.randi() % SIGN_WORDS.size()]
				b["sign"] = {"word": word, "col": [NC.NEON_PINK, NC.NEON_CYAN, NC.NEON_RED, NC.NEON_BLUE][rng.randi() % 4],
					"y": horizon - h * rng.randf_range(0.35, 0.7), "side": rng.randf() < 0.5, "flicker": rng.randf() < 0.25}
			buildings.append(b)
			x += w + rng.randf_range(-8.0, 14.0) * (1.0 if depth > 0 else 0.4)

	func _process(delta: float) -> void:
		_timer += delta
		if _timer > 0.6:
			_timer = 0.0
			_blink = not _blink
			for i in 6:
				var b: Dictionary = buildings[randi() % buildings.size()]
				if b["windows"].size() > 0:
					var wnd: Array = b["windows"][randi() % b["windows"].size()]
					wnd[1] = 0 if wnd[1] != 0 else 1
			queue_redraw()

	func _body_color() -> Color:
		return [Color("2a2158"), Color("181338"), Color("0b0a18")][depth]

	func _draw() -> void:
		var body := _body_color()
		var unlit := body.lightened(0.06)
		for b in buildings:
			var x: float = b["x"]
			var w: float = b["w"]
			var h: float = b["h"]
			var top := horizon - h
			draw_rect(Rect2(x, top, w, h + 200), body)
			match b["top"]:
				"stepped":
					draw_rect(Rect2(x + w * 0.12, top - 22, w * 0.76, 22), body)
					draw_rect(Rect2(x + w * 0.26, top - 40, w * 0.48, 18), body)
					draw_rect(Rect2(x + w * 0.38, top - 54, w * 0.24, 14), body)
				"spire":
					draw_rect(Rect2(x + w * 0.2, top - 26, w * 0.6, 26), body)
					NC.poly(self, [Vector2(x + w * 0.3, top - 26), Vector2(x + w * 0.5, top - 26 - w * 1.1), Vector2(x + w * 0.7, top - 26)], body)
					if _blink:
						draw_circle(Vector2(x + w * 0.5, top - 26 - w * 1.1), 2.0 + depth, NC.NEON_RED)
				"pyramid":
					NC.poly(self, [Vector2(x, top), Vector2(x + w * 0.5, top - w * 0.45), Vector2(x + w, top)], body)
				"antenna":
					draw_line(Vector2(x + w * 0.5, top), Vector2(x + w * 0.5, top - 60 - depth * 10), body, 2.0 + depth)
					if not _blink:
						draw_circle(Vector2(x + w * 0.5, top - 60 - depth * 10), 2.0 + depth, NC.NEON_RED)
				"crown":
					for k in 5:
						var cx := x + w * (0.1 + k * 0.2)
						NC.poly(self, [Vector2(cx - w * 0.08, top), Vector2(cx, top - 26 - (k % 2) * 16), Vector2(cx + w * 0.08, top)], body)
			# deco pilaster lines
			if depth == 2:
				for k in 3:
					var px := x + w * (0.25 + k * 0.25)
					draw_line(Vector2(px, top + 8), Vector2(px, horizon), body.lightened(0.04), 1.0)
			# windows
			for wnd in b["windows"]:
				var r: Rect2 = wnd[0]
				var c: Color = unlit
				match int(wnd[1]):
					1: c = NC.AMBER.lerp(NC.WARM, wnd[2]) * Color(1, 1, 1, 0.55 + 0.45 * wnd[2])
					2: c = Color(0.55, 0.8, 1.0, 0.75)
					3: c = Color(1.0, 0.45, 0.85, 0.7)
				if depth == 0 and wnd[1] != 0:
					c = c.lerp(Color("9a7bd0"), 0.35)
				draw_rect(r, c)
			# rim light
			if b["rim"] and depth >= 1:
				var rc := NC.NEON_PINK if int(x) % 2 == 0 else NC.NEON_CYAN
				draw_line(Vector2(x + w - 1, top), Vector2(x + w - 1, horizon), NC.a(rc, 0.25 + 0.15 * depth), 1.5 + depth * 0.5)
			# neon sign
			if b["sign"] != null:
				var sg: Dictionary = b["sign"]
				var on := 1.0
				if sg["flicker"] and _blink and randf() < 0.5:
					on = 0.25
				var word: String = sg["word"]
				var fs: int = 12 if depth == 1 else 18
				var sx: float = x + (w - fs - 8 if sg["side"] else 4)
				var sy: float = sg["y"]
				var sh := word.length() * (fs + 1) + 8
				draw_rect(Rect2(sx - 2, sy - 4, fs + 8, sh), Color(0.02, 0.02, 0.05, 0.9))
				NC.glow(self, Vector2(sx + fs * 0.5 + 2, sy + sh * 0.5), sh * 0.7, NC.a(sg["col"], 0.18 * on), 1.0, 14)
				draw_rect(Rect2(sx - 2, sy - 4, fs + 8, sh), NC.a(sg["col"], 0.8 * on), false, 1.5)
				for i in word.length():
					NC.text(self, Vector2(sx + 2, sy + 4 + fs + i * (fs + 1) - 4), word[i], fs, sg["col"].lerp(Color.WHITE, 0.3) * Color(1, 1, 1, on), "title")
