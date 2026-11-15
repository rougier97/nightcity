class_name NC
## Nightcity art kit: palette, fonts and drawing helpers shared by every scene.
## Style: "Neon Deco Noir" — flat ink silhouettes, deco skyscrapers with warm
## amber windows against violet skies, magenta/cyan neon rim light, rain.

# ---------------------------------------------------------------- palette
const INK := Color("07060c")
const NIGHT := Color("0b0a14")
const CHARCOAL := Color("1c1b24")
const MIDNIGHT := Color("121a3d")
const INDIGO := Color("262a6b")
const VIOLET := Color("3b2b78")
const DEEP_PURPLE := Color("1d1336")
const BURGUNDY := Color("6e1b2c")
const AMBER := Color("ffb347")
const WARM := Color("f7c66b")
const GOLD := Color("c9a24a")
const PALE_GOLD := Color("e8d29a")
const NEON_PINK := Color("ff2bd6")
const NEON_CYAN := Color("2de2ff")
const NEON_RED := Color("ff3355")
const NEON_BLUE := Color("3b7bff")
const RAIN := Color("b9c8ff")

# ---------------------------------------------------------------- fonts
static var _fonts := {}

static func font(name: String) -> Font:
	if _fonts.has(name):
		return _fonts[name]
	var path := {
		"deco": "res://fonts/Limelight-Regular.ttf",
		"sans": "res://fonts/JosefinSans.ttf",
		"title": "res://fonts/BebasNeue-Regular.ttf",
		"type": "res://fonts/SpecialElite-Regular.ttf",
	}.get(name, "")
	var f: Font = ThemeDB.fallback_font
	if path != "" and ResourceLoader.exists(path):
		f = load(path)
	if name == "sans" and f is FontFile:
		var v := FontVariation.new()
		v.base_font = f
		v.variation_opentype = {"wght": 600}
		f = v
	_fonts[name] = f
	return f

# ---------------------------------------------------------------- drawing
static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

static func hgrad(ci: CanvasItem, r: Rect2, left: Color, right: Color) -> void:
	ci.draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([left, right, right, left]))

## Soft radial glow: opaque-ish centre fading to transparent edge.
static func glow(ci: CanvasItem, c: Vector2, radius: float, col: Color, sy: float = 1.0, segs: int = 24) -> void:
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([col])
	var edge := Color(col.r, col.g, col.b, 0.0)
	for i in segs + 1:
		var a := TAU * float(i) / segs
		pts.append(c + Vector2(cos(a) * radius, sin(a) * radius * sy))
		cols.append(edge)
	# triangle fan
	for i in range(1, segs + 1):
		ci.draw_polygon(PackedVector2Array([pts[0], pts[i], pts[i + 1]]),
			PackedColorArray([cols[0], cols[i], cols[i + 1]]))

## Light cone: apex to a far edge, fading out.
static func cone(ci: CanvasItem, apex: Vector2, dir: float, length: float, half_angle: float, col: Color) -> void:
	var a := apex
	var b := apex + Vector2(cos(dir - half_angle), sin(dir - half_angle)) * length
	var c := apex + Vector2(cos(dir + half_angle), sin(dir + half_angle)) * length
	var edge := Color(col.r, col.g, col.b, 0.0)
	ci.draw_polygon(PackedVector2Array([a, b, c]), PackedColorArray([col, edge, edge]))

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, segs: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var a := TAU * float(i) / segs
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)

static func ellipse_line(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, width: float = 1.0, segs: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in segs + 1:
		var a := TAU * float(i) / segs
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_polyline(pts, col, width, true)

## A tapered limb segment from a (width wa) to b (width wb) with rounded joint.
static func limb(ci: CanvasItem, a: Vector2, b: Vector2, wa: float, wb: float, col: Color) -> void:
	var d := (b - a)
	if d.length() < 0.01:
		return
	var n := d.normalized().orthogonal()
	ci.draw_colored_polygon(PackedVector2Array([a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5]), col)
	ci.draw_circle(b, wb * 0.5, col)

static func poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)

static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, fname: String = "sans", align := HORIZONTAL_ALIGNMENT_LEFT, width: float = -1) -> void:
	ci.draw_string(font(fname), pos, s, align, width, size, col)

## Neon text: soft glow passes then a bright core.
static func neon_text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, fname: String = "deco", align := HORIZONTAL_ALIGNMENT_LEFT, width: float = -1, flicker: float = 1.0) -> void:
	var f := font(fname)
	var g := Color(col.r, col.g, col.b, 0.18 * flicker)
	for o in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(-2, -2), Vector2(2, 2)]:
		ci.draw_string(f, pos + o, s, align, width, size, g)
	ci.draw_string(f, pos, s, align, width, size, col.lerp(Color.WHITE, 0.35 * flicker) * Color(1, 1, 1, 0.4 + 0.6 * flicker))

static func shade(c: Color, amount: float) -> Color:
	return c.darkened(amount)

static func lift(c: Color, amount: float) -> Color:
	return c.lightened(amount)

static func a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, alpha)

## Sample a cubic bezier into points.
static func bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int = 10) -> Array:
	var out := []
	for i in steps + 1:
		var t := float(i) / steps
		var u := 1.0 - t
		out.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return out
