class_name Adrian
extends Node2D
## Adrian Cross — a layered, fully procedural 2D character rig.
## Every appearance option and clothing item is drawn as its own layer, so any
## combination is visibly represented on the character (not just in a menu).
## Origin = between the feet on the ground. Faces +x when facing = 1.

@export var size := 1.0:
	set(v):
		size = v
		_update_scale()
@export var facing := 1:
	set(v):
		facing = 1 if v >= 0 else -1
		_update_scale()
@export var light := 0.62           # 1 = fully lit (wardrobe), lower = moody noir shading
@export var rim_back := NC.NEON_PINK
@export var rim_front := NC.NEON_CYAN
@export var rim_strength := 0.8
@export var ink_outline := true
@export var ground_shadow := true
@export var use_game_state := true

var walking := false
var walk_speed := 1.0
var pose := "idle"                  # "idle" | "phone" | "crouch"
var phase := 0.0
var _t := 0.0
var appearance: Dictionary = {}
var equipped: Dictionary = {}
var bw := 1.0                       # body width factor

const SHADOW := Color("0a0816")
const INKC := Color("06050b")

func _ready() -> void:
	_update_scale()
	if use_game_state:
		GameState.appearance_changed.connect(refresh)
	refresh()

func _update_scale() -> void:
	scale = Vector2(size * facing, size)

func refresh() -> void:
	if use_game_state:
		appearance = GameState.appearance.duplicate()
		equipped = GameState.equipped.duplicate()
	queue_redraw()

func set_look(app: Dictionary, eq: Dictionary) -> void:
	use_game_state = false
	appearance = app.duplicate()
	equipped = eq.duplicate()
	queue_redraw()

func sync_from(other: Adrian) -> void:
	phase = other.phase
	walking = other.walking
	pose = other.pose
	_t = other._t
	facing = other.facing
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if walking:
		phase += delta * 7.5 * walk_speed
	queue_redraw()

# ---------------------------------------------------------------- helpers
func L(c: Color, extra_dark: float = 0.0) -> Color:
	var k := clampf(light - extra_dark, 0.0, 1.0)
	return SHADOW.lerp(c, k)

func _item(slot: String) -> Dictionary:
	var id: String = equipped.get(slot, "")
	if id == "":
		return {}
	return Catalog.clothing(id)

func _ol(pts: Array, col: Color, w: float = 1.4) -> void:
	var pv := PackedVector2Array(pts)
	draw_colored_polygon(pv, col)
	if ink_outline:
		pv.append(pts[0])
		draw_polyline(pv, INKC, w, true)

func _skin() -> Color:
	var i: int = int(appearance.get("skin", 2))
	return Catalog.SKIN_TONES[clampi(i, 0, Catalog.SKIN_TONES.size() - 1)]

func _hair_col() -> Color:
	var i: int = int(appearance.get("hair_colour", 0))
	return Catalog.HAIR_COLOURS[clampi(i, 0, Catalog.HAIR_COLOURS.size() - 1)]

# ---------------------------------------------------------------- draw
func _draw() -> void:
	bw = {"lean": 0.9, "standard": 1.0, "broad": 1.13}.get(appearance.get("body", "standard"), 1.0)
	var crouch := pose == "crouch"
	var walk_amt := 1.0 if walking else 0.0
	var s := sin(phase)
	var bob := -absf(sin(phase)) * 3.0 * walk_amt + sin(_t * 2.0) * 0.7 * (1.0 - walk_amt)
	if crouch:
		bob = 34.0
	var oy := bob

	var coat := _item("coat")
	var jacket := _item("jacket")
	var shirt := _item("shirt")
	var trousers := _item("trousers")
	var shoes := _item("shoes")
	var waist := _item("waistcoat")
	var tie := _item("tie")
	var gloves := _item("gloves")

	var trouser_col: Color = trousers.get("color", Color("15141c"))
	var shirt_col: Color = shirt.get("color", Color("e9e6df"))
	var sleeve_col: Color = shirt_col
	if not jacket.is_empty():
		sleeve_col = jacket["color"]
	if not coat.is_empty():
		sleeve_col = coat["color"]
	var short_sleeve: bool = shirt.get("style", "") == "tee" and jacket.is_empty() and coat.is_empty()
	var hand_col: Color = gloves["color"] if not gloves.is_empty() else _skin()

	if ground_shadow:
		NC.ellipse(self, Vector2(2, 2), 34 * bw, 6, Color(0, 0, 0, 0.45))

	# ---------------- coat back
	if not coat.is_empty():
		var cb := L(coat["color"], 0.18)
		var sway := s * 3.0 * walk_amt
		_ol([Vector2(-25 * bw, -150 + oy), Vector2(25 * bw, -150 + oy), Vector2(29 * bw + sway, -48 + oy * 0.5), Vector2(-31 * bw + sway, -48 + oy * 0.5)], cb)

	# ---------------- legs
	var leg_swing := 0.42 * walk_amt
	var hipy := -112.0 + oy
	var legs := []
	for side in [-1, 1]:
		var a: float = s * leg_swing * side
		var bend: float = maxf(0.0, -sin(phase * 1.0 + (0.0 if side > 0 else PI) + 0.7)) * 0.7 * walk_amt
		var hip := Vector2(side * 8.0 * bw, hipy)
		var knee: Vector2
		var ankle: Vector2
		if crouch:
			knee = hip + Vector2(22 + side * 4, 8)
			ankle = knee + Vector2(-4, 34 - oy * 0.0 + 6)
			ankle.y = -6.0
		else:
			knee = hip + Vector2(sin(a), cos(a)) * 52.0
			ankle = knee + Vector2(sin(a - bend), cos(a - bend)) * 54.0
		legs.append([side, hip, knee, ankle])
	# back leg first (side -1), darker
	for lg in legs:
		var dark: float = 0.16 if lg[0] < 0 else 0.0
		var tc := L(trouser_col, dark)
		NC.limb(self, lg[1], lg[2], 19, 16, tc)
		NC.limb(self, lg[2], lg[3], 16, 13, tc)
		if ink_outline:
			var n: Vector2 = (lg[3] - lg[1]).normalized().orthogonal()
			draw_line(lg[1] + n * 9, lg[2] + n * 8, INKC, 1.2)
			draw_line(lg[2] + n * 8, lg[3] + n * 6.5, INKC, 1.2)
		if trousers.get("style", "") == "jeans":
			draw_line(lg[2] + Vector2(2, 0), lg[3] + Vector2(2, -4), L(trouser_col.lightened(0.25), dark), 1.0)
		else:
			draw_line(lg[1] + Vector2(1, 6), lg[3] + Vector2(1, -6), L(trouser_col.lightened(0.12), dark), 1.0)
		_draw_shoe(lg[3], shoes, dark)

	# hip block
	_ol([Vector2(-19 * bw, -126 + oy), Vector2(19 * bw, -126 + oy), Vector2(18 * bw, -104 + oy), Vector2(-18 * bw, -104 + oy)], L(trouser_col))

	# ---------------- back arm
	var arm_swing := 0.32 * walk_amt
	_draw_arm(-1, -s * arm_swing, oy, sleeve_col, hand_col, short_sleeve, 0.2, false)

	# ---------------- neck
	NC.limb(self, Vector2(2, -184 + oy), Vector2(3, -200 + oy), 13, 12, L(_skin(), 0.1))

	# ---------------- shirt / torso
	var torso := [Vector2(-30 * bw, -182 + oy), Vector2(-12, -188 + oy), Vector2(12, -188 + oy), Vector2(30 * bw, -182 + oy),
		Vector2(28 * bw, -160 + oy), Vector2(19 * bw, -122 + oy), Vector2(18 * bw, -106 + oy),
		Vector2(-18 * bw, -106 + oy), Vector2(-19 * bw, -122 + oy), Vector2(-28 * bw, -160 + oy)]
	_ol(torso, L(shirt_col))
	draw_circle(Vector2(-29 * bw, -177 + oy), 8, L(shirt_col))
	draw_circle(Vector2(29 * bw, -177 + oy), 8, L(shirt_col))
	_draw_collar(shirt, oy, shirt_col)

	# necklace (visible with open collars)
	var neck_item := _item("necklace")
	if not neck_item.is_empty():
		var nc: Color = L(neck_item["color"].lightened(0.1))
		var pts := NC.bezier(Vector2(-8, -188 + oy), Vector2(-6, -172 + oy), Vector2(6, -172 + oy), Vector2(8, -188 + oy), 10)
		draw_polyline(PackedVector2Array(pts), nc, 1.6, true)
		draw_circle(pts[5], 2.2, nc)

	# tie
	if not tie.is_empty() and shirt.get("style", "dress") == "dress":
		_draw_tie(tie, oy)

	# waistcoat
	if not waist.is_empty():
		var wc := L(waist["color"])
		_ol([Vector2(-27 * bw, -178 + oy), Vector2(-9, -182 + oy), Vector2(0, -150 + oy), Vector2(9, -182 + oy), Vector2(27 * bw, -178 + oy),
			Vector2(26 * bw, -160 + oy), Vector2(19 * bw, -122 + oy), Vector2(14 * bw, -108 + oy), Vector2(0, -102 + oy),
			Vector2(-14 * bw, -108 + oy), Vector2(-19 * bw, -122 + oy), Vector2(-26 * bw, -160 + oy)], wc)
		if waist.has("accent"):
			for k in 6:
				draw_circle(Vector2(-12 + (k % 3) * 12, -160 + oy + int(k / 3) * 26), 3, L(waist["accent"]) * Color(1, 1, 1, 0.5))
		for k in 4:
			draw_circle(Vector2(0, -144 + oy + k * 10), 1.6, L(NC.PALE_GOLD))
		draw_line(Vector2(0, -150 + oy), Vector2(0, -103 + oy), INKC, 1.0)

	# jacket
	if not jacket.is_empty():
		_draw_jacket(jacket, oy)

	# coat front
	if not coat.is_empty():
		_draw_coat(coat, oy, s * 3.0 * walk_amt)

	# cel shading on the back side of the body
	var bottom := -96.0 if coat.is_empty() else -48.0
	var bx := 22.0 if coat.is_empty() else 30.0
	NC.poly(self, [Vector2(-31 * bw, -183 + oy), Vector2(-16, -186 + oy), Vector2(-14, bottom + oy * 0.5),
		Vector2(-bx * bw, bottom + oy * 0.5), Vector2(-21 * bw, -122 + oy), Vector2(-29 * bw, -160 + oy)], Color(0.02, 0.0, 0.08, 0.28))

	# ---------------- head
	_draw_head(Vector2(3, -217 + oy))

	# ---------------- front arm
	if pose == "phone":
		_draw_phone_arm(oy, sleeve_col, hand_col, short_sleeve)
	else:
		_draw_arm(1, s * arm_swing, oy, sleeve_col, hand_col, short_sleeve, 0.0, true)

	# ---------------- rim light
	if rim_strength > 0.0:
		var rb := NC.a(rim_back, rim_strength)
		var rf := NC.a(rim_front, rim_strength * 0.7)
		var hc := Vector2(3, -217 + oy)
		draw_polyline(PackedVector2Array([hc + Vector2(-1, -22), hc + Vector2(-11, -20), hc + Vector2(-16, -10), hc + Vector2(-14, 2), hc + Vector2(-10, 12)]), rb, 1.4, true)
		var back_edge_bottom := Vector2(-21 * bw, -96 + oy) if coat.is_empty() else Vector2(-31 * bw, -48 + oy * 0.5)
		draw_polyline(PackedVector2Array([Vector2(-14, -190 + oy), Vector2(-33 * bw, -181 + oy), Vector2(-30 * bw, -160 + oy), Vector2(-22 * bw, -122 + oy), back_edge_bottom]), NC.a(rim_back, rim_strength * 0.75), 1.5, true)
		draw_polyline(PackedVector2Array([Vector2(30 * bw, -186 + oy), Vector2(36 * bw, -176 + oy)]), rf, 1.6, true)
		for lg in legs:
			if lg[0] < 0:
				var n: Vector2 = -(lg[3] - lg[1]).normalized().orthogonal()
				draw_line(lg[2] + n * 8, lg[3] + n * 6.5, NC.a(rim_back, rim_strength * 0.5), 1.3)

# ---------------------------------------------------------------- parts
func _draw_shoe(ankle: Vector2, shoes: Dictionary, dark: float) -> void:
	var c := L(shoes.get("color", Color("0d0c10")), dark)
	var style: String = shoes.get("style", "oxford")
	var p := ankle
	match style:
		"boot":
			_ol([p + Vector2(-8, -14), p + Vector2(7, -14), p + Vector2(10, -3), p + Vector2(21, 2), p + Vector2(21, 8), p + Vector2(-9, 8)], c)
			draw_line(p + Vector2(-9, 7), p + Vector2(21, 7), L(Color("2a2626"), dark), 2.0)
		"sneaker":
			_ol([p + Vector2(-8, -6), p + Vector2(7, -6), p + Vector2(20, 1), p + Vector2(21, 8), p + Vector2(-9, 8)], c)
			draw_line(p + Vector2(-9, 7), p + Vector2(21, 7), L(Color("bdb8b0"), dark), 3.0)
			draw_line(p + Vector2(0, -3), p + Vector2(10, 0), L(Color("8a8680"), dark), 1.0)
		"loafer":
			_ol([p + Vector2(-8, -3), p + Vector2(8, -2), p + Vector2(20, 3), p + Vector2(20, 7), p + Vector2(-8, 7)], c)
			draw_line(p + Vector2(5, 0), p + Vector2(13, 2), L(NC.GOLD, dark), 1.2)
		_:
			_ol([p + Vector2(-8, -5), p + Vector2(8, -3), p + Vector2(21, 3), p + Vector2(21, 7), p + Vector2(-8, 7)], c)
			draw_line(p + Vector2(12, 1), p + Vector2(19, 3), L(Color(1, 1, 1, 0.5), dark), 1.0)

func _draw_collar(shirt: Dictionary, oy: float, col: Color) -> void:
	var style: String = shirt.get("style", "dress")
	var c := L(col.lightened(0.05))
	match style:
		"turtleneck":
			_ol([Vector2(-9, -186 + oy), Vector2(-8, -199 + oy), Vector2(11, -199 + oy), Vector2(12, -186 + oy)], L(col))
			for k in 3:
				draw_line(Vector2(-8, -190 + oy - k * 3), Vector2(11, -190 + oy - k * 3), L(col.lightened(0.12)), 1.0)
		"tee":
			draw_arc(Vector2(2, -190 + oy), 9, 0.1, PI - 0.1, 10, L(col.darkened(0.2)), 2.0)
		_:
			_ol([Vector2(-10, -190 + oy), Vector2(1, -182 + oy), Vector2(-5, -175 + oy)], c, 1.0)
			_ol([Vector2(13, -190 + oy), Vector2(2, -182 + oy), Vector2(9, -175 + oy)], c, 1.0)
			draw_line(Vector2(1.5, -180 + oy), Vector2(1.5, -106 + oy), L(col.darkened(0.15)), 1.0)
			for k in 5:
				draw_circle(Vector2(3.5, -168 + oy + k * 14), 1.1, L(col.darkened(0.3)))

func _draw_tie(tie: Dictionary, oy: float) -> void:
	var c := L(tie["color"])
	match tie.get("style", "tie"):
		"bow":
			_ol([Vector2(1.5, -183 + oy), Vector2(-9, -188 + oy), Vector2(-9, -178 + oy)], c, 1.0)
			_ol([Vector2(1.5, -183 + oy), Vector2(12, -188 + oy), Vector2(12, -178 + oy)], c, 1.0)
			draw_circle(Vector2(1.5, -183 + oy), 2.5, c)
		"skinny":
			_ol([Vector2(-1, -184 + oy), Vector2(4, -184 + oy), Vector2(4, -132 + oy), Vector2(1.5, -127 + oy), Vector2(-1, -132 + oy)], c, 1.0)
			NC.glow(self, Vector2(1.5, -150 + oy), 12, NC.a(tie["color"], 0.25 * light))
		_:
			_ol([Vector2(-2, -184 + oy), Vector2(5, -184 + oy), Vector2(3.5, -178 + oy), Vector2(-0.5, -178 + oy)], c, 1.0)
			_ol([Vector2(-0.5, -178 + oy), Vector2(3.5, -178 + oy), Vector2(7, -134 + oy), Vector2(1.5, -126 + oy), Vector2(-4, -134 + oy)], c, 1.0)
			draw_line(Vector2(1.5, -176 + oy), Vector2(1.5, -130 + oy), c.lightened(0.15) * Color(1, 1, 1, 0.5), 1.0)

func _draw_jacket(j: Dictionary, oy: float) -> void:
	var c := L(j["color"])
	var style: String = j.get("style", "suit")
	if style == "leather" or style == "bomber":
		var hem := -110.0
		var lp := [Vector2(-31 * bw, -184 + oy), Vector2(-9, -190 + oy), Vector2(-5, -160 + oy), Vector2(-3, hem + oy), Vector2(-21 * bw, hem + oy), Vector2(-21 * bw, -124 + oy), Vector2(-29 * bw, -160 + oy)]
		var rp := [Vector2(31 * bw, -184 + oy), Vector2(12, -190 + oy), Vector2(8, -160 + oy), Vector2(6, hem + oy), Vector2(21 * bw, hem + oy), Vector2(21 * bw, -124 + oy), Vector2(29 * bw, -160 + oy)]
		_ol(lp, c)
		_ol(rp, c)
		draw_circle(Vector2(-29 * bw, -177 + oy), 9, c)
		draw_circle(Vector2(29 * bw, -177 + oy), 9, c)
		if style == "leather":
			_ol([Vector2(-9, -190 + oy), Vector2(-20, -184 + oy), Vector2(-8, -166 + oy)], L(j["color"].lightened(0.1)), 1.0)
			_ol([Vector2(12, -190 + oy), Vector2(23, -184 + oy), Vector2(10, -166 + oy)], L(j["color"].lightened(0.1)), 1.0)
			draw_line(Vector2(-4, -158 + oy), Vector2(-3, hem + oy), L(Color("9aa0aa")), 1.2)
			draw_line(Vector2(-20 * bw, -150 + oy), Vector2(-10, -140 + oy), L(Color(1, 1, 1, 0.25)), 2.0)
		else:
			draw_rect(Rect2(-21 * bw, hem - 6 + oy, 42 * bw, 6), L(j["color"].darkened(0.3)))
			for k in 8:
				draw_line(Vector2(-20 * bw + k * 5.5 * bw, hem - 6 + oy), Vector2(-20 * bw + k * 5.5 * bw, hem + oy), INKC, 0.8)
			draw_arc(Vector2(1.5, -188 + oy), 11, 0.0, PI, 10, L(j["color"].darkened(0.3)), 3.0)
		return
	var hem := -94.0
	var lp := [Vector2(-31 * bw, -184 + oy), Vector2(-11, -189 + oy), Vector2(-1, -138 + oy), Vector2(0, -112 + oy), Vector2(-3, hem + 2 + oy),
		Vector2(-22 * bw, hem + oy), Vector2(-21 * bw, -122 + oy), Vector2(-29 * bw, -160 + oy)]
	var rp := [Vector2(31 * bw, -184 + oy), Vector2(14, -189 + oy), Vector2(4, -138 + oy), Vector2(3, -112 + oy), Vector2(7, hem + 2 + oy),
		Vector2(22 * bw, hem + oy), Vector2(21 * bw, -122 + oy), Vector2(29 * bw, -160 + oy)]
	_ol(lp, c)
	_ol(rp, c)
	draw_circle(Vector2(-29 * bw, -177 + oy), 9.5, c)
	draw_circle(Vector2(29 * bw, -177 + oy), 9.5, c)
	if j.has("accent"):
		for k in 6:
			var x := -24.0 * bw + k * 9.0 * bw
			if absf(x) > 6:
				draw_line(Vector2(x, -176 + oy), Vector2(x * 0.85, hem + 4 + oy), L(j["accent"]) * Color(1, 1, 1, 0.35), 1.0)
	var lapel_col := L(Color("0b0a0f")) if style == "dinner" else L(j["color"].lightened(0.09))
	_ol([Vector2(-11, -189 + oy), Vector2(-21, -174 + oy), Vector2(-16, -170 + oy), Vector2(-1, -138 + oy), Vector2(-6, -162 + oy)], lapel_col, 1.0)
	_ol([Vector2(14, -189 + oy), Vector2(24, -174 + oy), Vector2(19, -170 + oy), Vector2(4, -138 + oy), Vector2(9, -162 + oy)], lapel_col, 1.0)
	draw_circle(Vector2(1.5, -126 + oy), 1.8, L(Color("2a2a30")))
	draw_circle(Vector2(1.5, -113 + oy), 1.8, L(Color("2a2a30")))
	draw_line(Vector2(-19 * bw, -114 + oy), Vector2(-9, -114 + oy), INKC, 1.0)
	draw_line(Vector2(19 * bw, -114 + oy), Vector2(9, -114 + oy), INKC, 1.0)
	var sq := _item("pocket_square")
	if not sq.is_empty():
		var qc := L(sq["color"])
		_ol([Vector2(12 * bw, -160 + oy), Vector2(15 * bw, -167 + oy), Vector2(18 * bw, -162 + oy), Vector2(21 * bw, -166 + oy), Vector2(23 * bw, -160 + oy)], qc, 0.8)
	draw_line(Vector2(11 * bw, -160 + oy), Vector2(24 * bw, -160 + oy), INKC, 1.0)

func _draw_coat(c: Dictionary, oy: float, sway: float) -> void:
	var col := L(c["color"])
	var hem := -48.0 + oy * 0.5
	var trench: bool = c.get("style", "") == "trench"
	var lp := [Vector2(-33 * bw, -185 + oy), Vector2(-13, -191 + oy), Vector2(-8, -140 + oy), Vector2(-9 + sway, hem),
		Vector2(-31 * bw + sway, hem), Vector2(-25 * bw, -120 + oy), Vector2(-31 * bw, -160 + oy)]
	var rp := [Vector2(33 * bw, -185 + oy), Vector2(16, -191 + oy), Vector2(11, -140 + oy), Vector2(13 + sway, hem),
		Vector2(31 * bw + sway, hem), Vector2(25 * bw, -120 + oy), Vector2(31 * bw, -160 + oy)]
	_ol(lp, col)
	_ol(rp, col)
	draw_circle(Vector2(-30 * bw, -178 + oy), 10.5, col)
	draw_circle(Vector2(30 * bw, -178 + oy), 10.5, col)
	var lap := L(c["color"].lightened(0.08))
	_ol([Vector2(-13, -191 + oy), Vector2(-27, -172 + oy), Vector2(-20, -166 + oy), Vector2(-8, -138 + oy)], lap, 1.0)
	_ol([Vector2(16, -191 + oy), Vector2(30, -172 + oy), Vector2(23, -166 + oy), Vector2(11, -138 + oy)], lap, 1.0)
	# popped collar
	_ol([Vector2(-13, -191 + oy), Vector2(-15, -204 + oy), Vector2(-6, -198 + oy)], lap, 1.0)
	_ol([Vector2(16, -191 + oy), Vector2(19, -204 + oy), Vector2(9, -198 + oy)], lap, 1.0)
	if trench:
		draw_rect(Rect2(-25 * bw, -126 + oy, 50 * bw, 7), L(c["color"].darkened(0.25)))
		draw_rect(Rect2(-5, -127 + oy, 9, 9), L(NC.GOLD), false, 1.5)
		for k in 3:
			draw_circle(Vector2(-14, -156 + oy + k * 13), 2.0, L(Color("2a2420")))
			draw_circle(Vector2(18, -156 + oy + k * 13), 2.0, L(Color("2a2420")))
		draw_line(Vector2(-34 * bw, -183 + oy), Vector2(-22 * bw, -186 + oy), L(c["color"].lightened(0.15)), 3.0)
	else:
		for k in 3:
			draw_circle(Vector2(-10, -130 + oy + k * 22), 2.0, L(Color("2a2420")))
	draw_line(Vector2(-27 * bw, -100 + oy * 0.8), Vector2(-14, -98 + oy * 0.8), INKC, 1.0)

func _arm_points(side: int, swing: float, oy: float) -> Array:
	var sh := Vector2(side * 31.0 * bw, -178 + oy)
	var el := sh + Vector2(sin(swing), cos(swing)) * 46.0
	var fore := swing + (0.25 if side > 0 else 0.15) + absf(swing) * 0.4
	var hand := el + Vector2(sin(fore), cos(fore)) * 42.0
	if pose == "crouch":
		el = sh + Vector2(14, 34)
		hand = el + Vector2(20, -6)
	return [sh, el, hand]

func _draw_arm(side: int, swing: float, oy: float, sleeve: Color, hand_col: Color, short_sleeve: bool, dark: float, front: bool) -> void:
	var p := _arm_points(side, swing, oy)
	var sc := L(sleeve, dark)
	NC.limb(self, p[0], p[1], 17, 15, sc)
	if short_sleeve:
		var mid: Vector2 = p[0].lerp(p[1], 0.55)
		NC.limb(self, p[0], mid, 17, 16, sc)
		NC.limb(self, mid, p[1], 11, 11, L(_skin(), dark))
		NC.limb(self, p[1], p[2], 11, 10, L(_skin(), dark))
	else:
		NC.limb(self, p[1], p[2], 15, 13, sc)
		if ink_outline:
			var n: Vector2 = (p[2] - p[0]).normalized().orthogonal() * float(side)
			draw_line(p[0] + n * 8, p[1] + n * 7.5, INKC, 1.2)
			draw_line(p[1] + n * 7.5, p[2] + n * 6.5, INKC, 1.2)
		var shirt_c: Color = _item("shirt").get("color", Color("e9e6df"))
		var cuff: Vector2 = p[1].lerp(p[2], 0.9)
		draw_circle(cuff, 5.5, L(shirt_c, dark))
	_draw_hand(p[2], p[1], hand_col, dark, front)

func _draw_hand(hand: Vector2, elbow: Vector2, col: Color, dark: float, front: bool) -> void:
	if front:
		var w := _item("watch")
		if not w.is_empty():
			var wp: Vector2 = elbow.lerp(hand, 0.82)
			draw_circle(wp, 4.0, L(w["color"], dark))
			draw_circle(wp, 2.0, L(Color("f4f0e6"), dark))
	var hc := L(col, dark)
	draw_circle(hand + Vector2(0, 2), 6.0, hc)
	draw_circle(hand + Vector2(4, 0), 2.6, hc)
	if ink_outline:
		draw_arc(hand + Vector2(0, 2), 6.0, 0.0, TAU, 14, INKC, 1.0)
	if front:
		var r := _item("ring")
		if not r.is_empty():
			draw_circle(hand + Vector2(2, 6), 1.8, L(r["color"].lightened(0.2)))

func _draw_phone_arm(oy: float, sleeve: Color, hand_col: Color, short_sleeve: bool) -> void:
	var sh := Vector2(31.0 * bw, -178 + oy)
	var el := sh + Vector2(6, 40)
	var hand := Vector2(16, -212 + oy)
	var sc := L(sleeve)
	NC.limb(self, sh, el, 17, 15, sc)
	NC.limb(self, el, hand, 15, 13, sc if not short_sleeve else L(_skin()))
	var shirt_c: Color = _item("shirt").get("color", Color("e9e6df"))
	draw_circle(el.lerp(hand, 0.88), 5.5, L(shirt_c))
	# phone with screen glow
	_ol([hand + Vector2(-3, -12), hand + Vector2(4, -12), hand + Vector2(4, 8), hand + Vector2(-3, 8)], L(Color("101014")), 1.0)
	NC.glow(self, hand + Vector2(4, -2), 26, Color(0.4, 0.8, 1.0, 0.35))
	_draw_hand(hand + Vector2(0, 2), el, hand_col, 0.0, true)

func _draw_head(hc: Vector2) -> void:
	var skin := L(_skin())
	var skin_dark := L(_skin(), 0.22)
	var face := [Vector2(-2, -21), Vector2(10, -17), Vector2(14, -6), Vector2(17, 1), Vector2(14, 4), Vector2(13, 8),
		Vector2(12, 15), Vector2(5, 19), Vector2(-9, 12), Vector2(-13, 2), Vector2(-15, -10), Vector2(-10, -19)]
	var pts := []
	for p in face:
		pts.append(hc + p)
	_ol(pts, skin)
	# shadow side
	NC.poly(self, [hc + Vector2(-2, -21), hc + Vector2(-10, -19), hc + Vector2(-15, -10), hc + Vector2(-13, 2), hc + Vector2(-9, 12), hc + Vector2(-2, 15), hc + Vector2(-3, 0)], NC.a(skin_dark, 0.7))
	# ear
	NC.ellipse(self, hc + Vector2(-5, 0), 3.5, 5.5, skin_dark)
	draw_arc(hc + Vector2(-5, 0), 3.5, -1.2, 1.6, 6, INKC, 1.0)
	# features
	var eye_c: Color = Catalog.EYE_COLOURS[clampi(int(appearance.get("eye_colour", 1)), 0, Catalog.EYE_COLOURS.size() - 1)]
	NC.ellipse(self, hc + Vector2(8.5, -4), 3.2, 1.7, L(Color("ece6dc")), 10)
	draw_circle(hc + Vector2(9.5, -4), 1.5, L(eye_c))
	draw_circle(hc + Vector2(9.8, -4), 0.6, INKC)
	draw_line(hc + Vector2(4, -8.5), hc + Vector2(13, -8), L(_hair_col().darkened(0.2)), 2.2)
	draw_line(hc + Vector2(14, -5), hc + Vector2(16.5, 1.5), skin_dark, 1.2)
	draw_line(hc + Vector2(9, 9), hc + Vector2(13, 8.5), L(Color("5a2f2a")), 1.4)
	draw_line(hc + Vector2(2, 2), hc + Vector2(6, 9), NC.a(skin_dark, 0.8), 1.0)
	match appearance.get("scar", "none"):
		"cheek": draw_line(hc + Vector2(3, 2), hc + Vector2(9, 9), L(Color("e6b8b0")), 1.4)
		"brow": draw_line(hc + Vector2(8, -12), hc + Vector2(10.5, -2), L(Color("e6b8b0")), 1.4)
		"lip": draw_line(hc + Vector2(11, 5), hc + Vector2(12.5, 12), L(Color("e6b8b0")), 1.4)
	_draw_facial_hair(hc)
	var hat := _item("hat")
	_draw_hair(hc, not hat.is_empty())
	if not hat.is_empty():
		_draw_hat(hc, hat)
	var gl := _item("glasses")
	if not gl.is_empty():
		_draw_glasses(hc, gl)

func _draw_facial_hair(hc: Vector2) -> void:
	var c := L(_hair_col())
	var f: String = appearance.get("facial_hair", "none")
	var P := func(arr: Array) -> Array:
		var out := []
		for p in arr:
			out.append(hc + p)
		return out
	match f:
		"stubble":
			NC.poly(self, P.call([Vector2(-8, 7), Vector2(2, 5), Vector2(12, 6), Vector2(13, 12), Vector2(11, 16), Vector2(5, 19), Vector2(-9, 12)]), NC.a(c, 0.32))
		"pencil":
			draw_line(hc + Vector2(9.5, 5.5), hc + Vector2(15, 4.5), c, 1.3)
		"moustache":
			NC.poly(self, P.call([Vector2(8, 5), Vector2(15, 3.5), Vector2(14.5, 7), Vector2(9, 8)]), c)
		"goatee":
			NC.poly(self, P.call([Vector2(8, 5), Vector2(15, 3.5), Vector2(14.5, 7), Vector2(9, 8)]), c)
			NC.poly(self, P.call([Vector2(8, 11), Vector2(12.5, 12), Vector2(11.5, 16), Vector2(6, 19.5), Vector2(5, 15)]), c)
		"full_beard":
			NC.poly(self, P.call([Vector2(-10, -2), Vector2(-6, 4), Vector2(2, 6), Vector2(9, 4.5), Vector2(15, 3.5), Vector2(14.5, 8),
				Vector2(13, 12), Vector2(11.5, 17), Vector2(5, 21.5), Vector2(-3, 18), Vector2(-10, 12)]), c)
			draw_line(hc + Vector2(9, 9.5), hc + Vector2(13, 9), L(Color("5a2f2a")), 1.4)

func _draw_hair(hc: Vector2, under_hat: bool) -> void:
	var c := L(_hair_col())
	var sheen := L(_hair_col().lightened(0.3)) * Color(1, 1, 1, 0.6)
	var style: String = appearance.get("hair_style", "slick_back")
	var P := func(arr: Array) -> Array:
		var out := []
		for p in arr:
			out.append(hc + p)
		return out
	if under_hat:
		if style == "bald":
			return
		if style == "long_swept":
			_ol(P.call([Vector2(-16, 10), Vector2(-16, -12), Vector2(-9, -14), Vector2(-10, -2), Vector2(-10, 8)]), c, 1.0)
		elif style != "buzz":
			_ol(P.call([Vector2(-15, -10), Vector2(-14, -15), Vector2(-7, -15), Vector2(-10, -4), Vector2(-13, -1)]), c, 1.0)
		return
	match style:
		"slick_back":
			_ol(P.call([Vector2(-15, -9), Vector2(-14, -18), Vector2(-6, -23), Vector2(6, -23), Vector2(12, -19), Vector2(14, -12),
				Vector2(11, -14), Vector2(4, -17), Vector2(-4, -15), Vector2(-10, -9), Vector2(-12, -3)]), c, 1.0)
			draw_polyline(PackedVector2Array(P.call([Vector2(-8, -19), Vector2(0, -21), Vector2(8, -20)])), sheen, 1.5, true)
		"side_part":
			_ol(P.call([Vector2(-15, -8), Vector2(-15, -18), Vector2(-7, -24), Vector2(5, -25), Vector2(13, -21), Vector2(15, -13),
				Vector2(13, -11), Vector2(10, -16), Vector2(2, -18), Vector2(-6, -16), Vector2(-11, -9), Vector2(-12, -3)]), c, 1.0)
			draw_line(hc + Vector2(-1, -24), hc + Vector2(-6, -17), L(_hair_col().darkened(0.5)), 1.4)
			draw_polyline(PackedVector2Array(P.call([Vector2(0, -22), Vector2(8, -21), Vector2(12, -17)])), sheen, 1.3, true)
		"crew_cut":
			_ol(P.call([Vector2(-14, -8), Vector2(-14, -18), Vector2(-6, -22), Vector2(6, -22), Vector2(12, -18), Vector2(13, -13),
				Vector2(4, -16), Vector2(-6, -14), Vector2(-11, -6)]), c, 1.0)
		"pompadour":
			_ol(P.call([Vector2(-15, -8), Vector2(-14, -19), Vector2(-6, -25), Vector2(4, -31), Vector2(14, -29), Vector2(18, -22),
				Vector2(15, -16), Vector2(10, -17), Vector2(2, -18), Vector2(-6, -15), Vector2(-11, -7)]), c, 1.0)
			draw_polyline(PackedVector2Array(P.call([Vector2(-4, -24), Vector2(6, -29), Vector2(15, -26)])), sheen, 1.5, true)
		"long_swept":
			_ol(P.call([Vector2(-16, 10), Vector2(-17, -8), Vector2(-14, -20), Vector2(-5, -25), Vector2(7, -25), Vector2(14, -19),
				Vector2(15, -11), Vector2(10, -16), Vector2(1, -17), Vector2(-8, -12), Vector2(-10, -2), Vector2(-10, 8)]), c, 1.0)
			draw_polyline(PackedVector2Array(P.call([Vector2(-12, -14), Vector2(-2, -21), Vector2(9, -20)])), sheen, 1.3, true)
		"curly_top":
			_ol(P.call([Vector2(-14, -8), Vector2(-14, -18), Vector2(-6, -22), Vector2(6, -22), Vector2(12, -18), Vector2(13, -13),
				Vector2(4, -16), Vector2(-6, -14), Vector2(-11, -6)]), c, 1.0)
			for p in [Vector2(-12, -15), Vector2(-7, -21), Vector2(0, -23), Vector2(7, -21), Vector2(11, -16), Vector2(-13, -8), Vector2(-3, -18), Vector2(4, -18)]:
				draw_circle(hc + p, 5.0, c)
				draw_arc(hc + p, 5.0, PI, TAU, 6, INKC, 0.8)
		"buzz":
			NC.poly(self, P.call([Vector2(-14, -8), Vector2(-14, -18), Vector2(-6, -22), Vector2(6, -22), Vector2(12, -18), Vector2(13, -13),
				Vector2(4, -16), Vector2(-6, -14), Vector2(-11, -6)]), NC.a(c, 0.55))
		"bald":
			draw_arc(hc + Vector2(0, -8), 12, -2.4, -1.2, 8, L(Color(1, 1, 1, 0.35)), 2.0)

func _draw_hat(hc: Vector2, h: Dictionary) -> void:
	var c := L(h["color"])
	var acc := L(h.get("accent", Color("15141c")))
	var style: String = h.get("style", "fedora")
	var P := func(arr: Array) -> Array:
		var out := []
		for p in arr:
			out.append(hc + p)
		return out
	# eyes in the shadow of the brim — the noir look
	NC.poly(self, P.call([Vector2(-14, -18), Vector2(16, -18), Vector2(17, -4), Vector2(-14, -6)]), Color(0.02, 0.0, 0.06, 0.45))
	match style:
		"flatcap":
			_ol(P.call([Vector2(-16, -14), Vector2(-14, -24), Vector2(0, -28), Vector2(14, -24), Vector2(24, -16), Vector2(14, -15)]), c, 1.2)
			draw_line(hc + Vector2(-2, -27), hc + Vector2(12, -18), L(h["color"].lightened(0.15)), 1.0)
		"trilby":
			_ol(P.call([Vector2(-19, -18), Vector2(-4, -22), Vector2(14, -22), Vector2(22, -17), Vector2(14, -15), Vector2(-4, -16)]), c, 1.2)
			_ol(P.call([Vector2(-12, -20), Vector2(-10, -33), Vector2(1, -36), Vector2(11, -33), Vector2(13, -20)]), c, 1.2)
			draw_rect(Rect2(hc + Vector2(-12, -25), Vector2(25, 4)), acc)
		_:
			_ol(P.call([Vector2(-24, -17), Vector2(-8, -23), Vector2(14, -23), Vector2(27, -16), Vector2(22, -13), Vector2(8, -16), Vector2(-10, -15)]), c, 1.2)
			_ol(P.call([Vector2(-14, -21), Vector2(-12, -34), Vector2(-5, -38), Vector2(2, -35), Vector2(9, -38), Vector2(14, -33), Vector2(15, -21)]), c, 1.2)
			draw_rect(Rect2(hc + Vector2(-14, -26), Vector2(29, 5)), acc)
			draw_line(hc + Vector2(-5, -37), hc + Vector2(1, -30), L(h["color"].lightened(0.12)), 1.2)

func _draw_glasses(hc: Vector2, g: Dictionary) -> void:
	var frame := L(g["color"].lightened(0.1))
	var lens := Color(0.05, 0.04, 0.1, 0.92)
	match g.get("style", "wayfarer"):
		"aviator":
			NC.poly(self, [hc + Vector2(4, -7), hc + Vector2(14, -7), hc + Vector2(14, -2), hc + Vector2(10, 1), hc + Vector2(6, 0)], lens)
			draw_polyline(PackedVector2Array([hc + Vector2(4, -7), hc + Vector2(14, -7), hc + Vector2(14, -2), hc + Vector2(10, 1), hc + Vector2(6, 0), hc + Vector2(4, -7)]), frame, 1.0, true)
		"round":
			draw_circle(hc + Vector2(9, -4), 4.2, lens)
			draw_arc(hc + Vector2(9, -4), 4.2, 0.0, TAU, 12, frame, 1.0)
		_:
			NC.poly(self, [hc + Vector2(3, -8), hc + Vector2(15, -8), hc + Vector2(14, -2), hc + Vector2(5, -1)], lens)
			draw_line(hc + Vector2(3, -8), hc + Vector2(15, -8), frame, 2.0)
	draw_line(hc + Vector2(4, -6), hc + Vector2(-4, -3), frame, 1.0)
	draw_line(hc + Vector2(6, -6), hc + Vector2(11, -3), Color(1.0, 0.3, 0.85, 0.7), 1.0)
	draw_line(hc + Vector2(9, -6), hc + Vector2(12, -4), Color(0.3, 0.9, 1.0, 0.6), 1.0)
