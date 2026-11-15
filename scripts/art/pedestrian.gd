class_name Pedestrian
extends Node2D
## Background figure: ink silhouette in coat and hat, often under an umbrella,
## lit by neon rim light. Also used for guards (with a torch) in missions.

@export var speed := 50.0
@export var umbrella := true
@export var coat_color := Color("121020")
@export var umbrella_color := Color("17142a")
@export var rim := NC.NEON_CYAN
@export var hat := true
@export var wrap_min := -200.0
@export var wrap_max := 3800.0
@export var torch := false
var dir := 1
var down := 0.0          # 0 standing → 1 lying on the floor (takedown)
var walking := true
var _phase := randf() * TAU

func _process(delta: float) -> void:
	if walking and speed != 0.0:
		_phase += delta * 6.0 * (speed / 60.0)
		position.x += speed * dir * delta
		if wrap_max > wrap_min:
			if position.x > wrap_max:
				position.x = wrap_min
			elif position.x < wrap_min:
				position.x = wrap_max
	scale.x = absf(scale.x) * dir
	if down > 0.0:
		modulate = Color.WHITE.lerp(Color(1.25, 1.1, 1.2, 1.0), down)
	queue_redraw()

func _draw() -> void:
	if down > 0.0:
		draw_set_transform(Vector2(-20.0 * down, -26.0 * down), -PI * 0.5 * down, Vector2.ONE)
	var w := 1.0 if walking else 0.0
	var s := sin(_phase) * w
	var c := coat_color
	var ink := Color("05040a")
	# legs
	for side in [-1, 1]:
		var a: float = s * 0.4 * side
		var hip := Vector2(side * 6, -100)
		var foot := hip + Vector2(sin(a), cos(a)) * 98
		NC.limb(self, hip, foot, 14, 11, c.darkened(0.3 if side < 0 else 0.1))
		NC.poly(self, [foot + Vector2(-6, -4), foot + Vector2(14, -2), foot + Vector2(14, 4), foot + Vector2(-6, 4)], ink)
	# coat
	NC.poly(self, [Vector2(-24, -172), Vector2(24, -172), Vector2(26, -60), Vector2(-26, -60)], c)
	draw_circle(Vector2(-22, -166), 8, c)
	draw_circle(Vector2(22, -166), 8, c)
	draw_line(Vector2(-25, -168), Vector2(-27, -62), NC.a(rim, 0.55), 1.5)
	# arm
	if umbrella:
		NC.limb(self, Vector2(20, -166), Vector2(24, -130), 13, 11, c)
		NC.limb(self, Vector2(24, -130), Vector2(14, -150), 11, 10, c)
	else:
		NC.limb(self, Vector2(20, -166), Vector2(22 + s * 10, -96), 13, 11, c)
	# head
	NC.limb(self, Vector2(0, -172), Vector2(1, -182), 10, 10, c.darkened(0.2))
	NC.ellipse(self, Vector2(2, -194), 11, 14, Color("2a1e22"))
	if hat:
		NC.poly(self, [Vector2(-19, -202), Vector2(21, -202), Vector2(18, -198), Vector2(-16, -198)], ink)
		NC.poly(self, [Vector2(-11, -202), Vector2(-9, -218), Vector2(11, -218), Vector2(13, -202)], ink)
	if umbrella:
		draw_line(Vector2(14, -150), Vector2(14, -250), Color("2a2a30"), 2)
		var top := Vector2(14, -262)
		var pts := [top]
		for i in 9:
			var t := float(i) / 8.0
			pts.append(Vector2(14 - 58 + t * 116, -232 + sin(t * PI * 4) * 3))
		NC.poly(self, pts, umbrella_color)
		draw_polyline(PackedVector2Array(pts.slice(1)), NC.a(rim, 0.7), 1.5, true)
		draw_line(top, Vector2(-44, -232), NC.a(rim, 0.25), 1.0)
	if torch:
		NC.limb(self, Vector2(20, -166), Vector2(36, -134), 12, 10, c)
		draw_rect(Rect2(34, -140, 14, 6), Color("2a2a30"))
		NC.glow(self, Vector2(50, -137), 14, Color(1, 0.95, 0.7, 0.8))
