class_name Car
extends Node2D
## Black luxury sedan — long deco hood, chrome trim, rain beads, lights and a
## wet-road reflection. Origin = ground under the middle of the car.

@export var body_color := Color("0d0c14")
@export var length := 330.0
@export var lights_on := true
@export var speed := 0.0            # px/s, moves along x when non-zero
@export var reflect := true
@export var wrap_min := -400.0
@export var wrap_max := 4000.0
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	if speed != 0.0:
		position.x += speed * delta
		if speed > 0 and position.x > wrap_max:
			position.x = wrap_min
		elif speed < 0 and position.x < wrap_min:
			position.x = wrap_max
		scale.x = absf(scale.x) * (1 if speed > 0 else -1)
		queue_redraw()

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if reflect:
		draw_set_transform(Vector2(0, 4), 0, Vector2(1, -0.55))
		_body(0.16)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_body(1.0)

func _c(c: Color, k: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * k)

func _body(k: float) -> void:
	var L := length
	var hl := L * 0.5
	var bc := body_color
	var chrome := Color("c8cbd6")
	# headlight beam + glow (front = +x)
	if lights_on and k >= 1.0:
		NC.cone(self, Vector2(hl - 6, -34), 0.04, 320, 0.16, Color(1.0, 0.92, 0.7, 0.22))
		NC.glow(self, Vector2(hl - 4, -34), 26, Color(1.0, 0.9, 0.65, 0.55))
		NC.glow(self, Vector2(-hl + 6, -36), 18, Color(1.0, 0.15, 0.2, 0.55))
	# lower body
	var body := [Vector2(-hl, -26), Vector2(-hl + 6, -50), Vector2(-hl * 0.55, -56), Vector2(-hl * 0.38, -58),
		Vector2(-hl * 0.22, -88), Vector2(hl * 0.12, -90), Vector2(hl * 0.26, -60), Vector2(hl * 0.82, -54),
		Vector2(hl, -44), Vector2(hl + 2, -24), Vector2(hl - 8, -14), Vector2(-hl + 6, -14)]
	draw_colored_polygon(PackedVector2Array(body), _c(bc, k))
	# fenders
	NC.ellipse(self, Vector2(-hl * 0.62, -30), 44, 26, _c(bc.lightened(0.04), k))
	NC.ellipse(self, Vector2(hl * 0.6, -30), 44, 26, _c(bc.lightened(0.04), k))
	# windows with neon reflection
	var win := [Vector2(-hl * 0.33, -60), Vector2(-hl * 0.2, -84), Vector2(hl * 0.1, -86), Vector2(hl * 0.22, -60)]
	draw_polygon(PackedVector2Array(win), PackedColorArray([_c(Color("2a1f4a"), k), _c(Color("6a2a7a"), k), _c(Color("2a6a8a"), k), _c(Color("1a1838"), k)]))
	draw_line(Vector2(-hl * 0.04, -86), Vector2(-hl * 0.03, -60), _c(bc, k), 4.0)
	draw_polyline(PackedVector2Array(win + [win[0]]), _c(chrome, 0.7 * k), 1.5, true)
	# roof highlight & rain beads
	draw_line(Vector2(-hl * 0.2, -89), Vector2(hl * 0.1, -91), _c(Color(0.8, 0.6, 1.0), 0.5 * k), 2.0)
	if k >= 1.0:
		for i in 14:
			var x := -hl * 0.8 + i * L * 0.12 + sin(i * 7.3) * 6
			var y := -56.0 - absf(sin(i * 3.1)) * 2
			if x > -hl * 0.38 and x < hl * 0.26:
				y = -60
			draw_circle(Vector2(x, y), 1.2, Color(0.8, 0.85, 1.0, 0.5))
	# chrome strip, grille, bumpers
	draw_line(Vector2(-hl + 8, -38), Vector2(hl - 4, -38), _c(chrome, 0.85 * k), 2.0)
	draw_rect(Rect2(hl - 6, -46, 6, 22), _c(chrome, 0.8 * k))
	for i in 4:
		draw_line(Vector2(hl - 5, -44 + i * 5), Vector2(hl - 1, -44 + i * 5), _c(Color("2a2a30"), k), 1.0)
	draw_line(Vector2(hl - 10, -18), Vector2(hl + 3, -20), _c(chrome, 0.9 * k), 3.0)
	draw_line(Vector2(-hl + 2, -18), Vector2(-hl + 14, -18), _c(chrome, 0.9 * k), 3.0)
	# lights
	draw_circle(Vector2(hl - 4, -34), 5, _c(Color(1.0, 0.95, 0.8) if lights_on else Color("555"), k))
	draw_rect(Rect2(-hl + 1, -40, 5, 9), _c(Color(1.0, 0.2, 0.25) if lights_on else Color("411"), k))
	# door line + handle
	draw_line(Vector2(-hl * 0.05, -58), Vector2(-hl * 0.05, -18), _c(Color("000000"), 0.6 * k), 1.0)
	draw_line(Vector2(hl * 0.02, -46), Vector2(hl * 0.1, -46), _c(chrome, k), 2.0)
	# wheels
	for wx in [-hl * 0.62, hl * 0.6]:
		draw_circle(Vector2(wx, -14), 17, _c(Color("050508"), k))
		draw_circle(Vector2(wx, -14), 9, _c(chrome.darkened(0.2), k))
		draw_circle(Vector2(wx, -14), 4, _c(Color("2a2a30"), k))
		if speed != 0.0 and k >= 1.0:
			var a := _t * speed * 0.06
			draw_line(Vector2(wx, -14), Vector2(wx, -14) + Vector2(cos(a), sin(a)) * 8, Color("2a2a30"), 1.5)
	# rim light from street neon
	if k >= 1.0:
		draw_polyline(PackedVector2Array([Vector2(-hl, -26), Vector2(-hl + 6, -50), Vector2(-hl * 0.55, -56), Vector2(-hl * 0.38, -58), Vector2(-hl * 0.22, -88), Vector2(hl * 0.12, -90)]), Color(1.0, 0.17, 0.84, 0.55), 1.5, true)
