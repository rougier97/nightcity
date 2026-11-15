class_name Rain
extends Node2D
## Animated rainfall with three depth layers. Drops that reach the ground band
## create splashes and ripples; puddle rects get extra, larger ripples.

@export var area := Rect2(0, -40, 1600, 760)
@export var count := 320
@export var wind := 0.18          # horizontal slant (x per y)
@export var ground_top := 600.0    # drops land somewhere between ground_top and ground_bottom
@export var ground_bottom := 720.0
@export var splashes := true
@export var tint := Color(0.75, 0.82, 1.0)
@export var intensity := 1.0:
	set(v):
		intensity = clampf(v, 0.0, 1.0)

var puddles: Array[Rect2] = []
var follow: Node2D = null          # keep rain area centred on this (e.g. camera)

var _drops: Array = []   # [pos, speed, len, layer, land_y]
var _splash: Array = []  # [pos, t, size]
var _ripples: Array = [] # [pos, t, size]
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	for i in count:
		_drops.append(_new_drop(true))

func _new_drop(anywhere: bool) -> Array:
	var layer := _rng.randi() % 3
	var speed: float = [700.0, 1000.0, 1450.0][layer] * _rng.randf_range(0.9, 1.1)
	var length: float = [10.0, 18.0, 30.0][layer]
	var y := area.position.y + (_rng.randf() * area.size.y if anywhere else -_rng.randf() * 120.0)
	var x := area.position.x + _rng.randf() * (area.size.x + 300.0) - 150.0
	var land := _rng.randf_range(ground_top, ground_bottom) if layer > 0 else _rng.randf_range(ground_top - 40.0, ground_top + 30.0)
	return [Vector2(x, y), speed, length, layer, land]

func _process(delta: float) -> void:
	var off := Vector2.ZERO
	if follow:
		off = Vector2(follow.global_position.x - area.size.x * 0.5 - area.position.x, 0)
		area.position.x += off.x
	var active := int(count * intensity)
	for i in _drops.size():
		var d: Array = _drops[i]
		if i >= active:
			continue
		d[0] += Vector2(wind, 1.0) * d[1] * delta
		if d[0].y >= d[4]:
			if splashes and d[3] > 0:
				if _splash.size() < 90:
					_splash.append([Vector2(d[0].x, d[4]), 0.0, 1.0 + d[3] * 0.6])
				if _rng.randf() < 0.35 and _ripples.size() < 70:
					_ripples.append([Vector2(d[0].x, d[4]), 0.0, 6.0 + d[3] * 5.0])
			_drops[i] = _new_drop(false)
		elif d[0].x > area.end.x + 160.0 or d[0].x < area.position.x - 160.0:
			_drops[i] = _new_drop(false)
	# puddle ripples
	for p in puddles:
		if _rng.randf() < delta * 6.0 * intensity and _ripples.size() < 90:
			_ripples.append([Vector2(_rng.randf_range(p.position.x + 6, p.end.x - 6), _rng.randf_range(p.position.y + 2, p.end.y - 2)), 0.0, _rng.randf_range(8, 16)])
	for s in _splash:
		s[1] += delta
	for r in _ripples:
		r[1] += delta
	_splash = _splash.filter(func(s): return s[1] < 0.22)
	_ripples = _ripples.filter(func(r): return r[1] < 0.8)
	queue_redraw()

func _draw() -> void:
	var active := int(count * intensity)
	var l0 := PackedVector2Array()
	var l1 := PackedVector2Array()
	var l2 := PackedVector2Array()
	var dir := Vector2(wind, 1.0).normalized()
	for i in min(active, _drops.size()):
		var d: Array = _drops[i]
		var p: Vector2 = d[0]
		var tail: Vector2 = p - dir * d[2]
		match int(d[3]):
			0:
				l0.append(tail); l0.append(p)
			1:
				l1.append(tail); l1.append(p)
			_:
				l2.append(tail); l2.append(p)
	if l0.size() > 1:
		draw_multiline(l0, Color(tint.r, tint.g, tint.b, 0.18), 1.0)
	if l1.size() > 1:
		draw_multiline(l1, Color(tint.r, tint.g, tint.b, 0.3), 1.2)
	if l2.size() > 1:
		draw_multiline(l2, Color(tint.r, tint.g, tint.b, 0.5), 1.6)
	for s in _splash:
		var t: float = s[1] / 0.22
		var sz: float = s[2] * 5.0
		var c := Color(tint.r, tint.g, tint.b, 0.55 * (1.0 - t))
		var p: Vector2 = s[0]
		draw_line(p, p + Vector2(-sz, -sz * 1.4) * t, c, 1.0)
		draw_line(p, p + Vector2(sz, -sz * 1.3) * t, c, 1.0)
		draw_line(p, p + Vector2(0, -sz * 1.8) * t, c, 1.0)
	for r in _ripples:
		var t: float = r[1] / 0.8
		var rad: float = r[2] * (0.3 + t)
		NC.ellipse_line(self, r[0], rad, rad * 0.28, Color(tint.r, tint.g, tint.b, 0.45 * (1.0 - t)), 1.0, 18)
