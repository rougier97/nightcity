extends Node2D
## Basic inventory: items laid out on a noir desk under a lamp, plus the
## player's money, properties, wardrobe and progress.

var main
var params := {}
var _vw := 1280.0
var _ui: Control
var _desc: Label

func _ready() -> void:
	_vw = get_viewport_rect().size.x
	var desk := Desk.new()
	desk.w = _vw
	add_child(desk)
	_ui = UI.root_control(self)
	var title := UI.label("THE BAG", 48, NC.GOLD, "deco")
	title.position = Vector2(60, 30)
	_ui.add_child(title)
	var back := UI.btn("BACK", _back, Vector2(150, 60))
	back.name = "Back"
	back.position = Vector2(_vw - 190, 30)
	_ui.add_child(back)
	# stats card
	var stats := VBoxContainer.new()
	stats.position = Vector2(60, 120)
	stats.add_theme_constant_override("separation", 6)
	_ui.add_child(stats)
	stats.add_child(UI.label("CASH", 18, NC.a(NC.PALE_GOLD, 0.6), "title"))
	stats.add_child(UI.label("$" + GameState.format_money(GameState.cash), 46, NC.GOLD, "title"))
	stats.add_child(UI.label("PROPERTIES", 18, NC.a(NC.PALE_GOLD, 0.6), "title"))
	var props := []
	for p in GameState.owned_properties:
		props.append(Catalog.PROPERTIES[p]["name"])
	stats.add_child(UI.label("\n".join(props) if props.size() > 0 else "None yet", 20))
	stats.add_child(UI.label("WARDROBE", 18, NC.a(NC.PALE_GOLD, 0.6), "title"))
	stats.add_child(UI.label("%d of %d pieces owned" % [GameState.owned_clothes.size(), Catalog.CLOTHES.size()], 20))
	stats.add_child(UI.label("CONTRACTS", 18, NC.a(NC.PALE_GOLD, 0.6), "title"))
	stats.add_child(UI.label("%d completed" % GameState.missions_done.size(), 20))
	stats.add_child(UI.label("WEAPONS", 18, NC.a(NC.PALE_GOLD, 0.6), "title"))
	stats.add_child(UI.label("None — arms dealer opens in Stage 2", 18, NC.a(Color.WHITE, 0.55)))
	# item grid
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(470, 130)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_ui.add_child(grid)
	for id in GameState.inventory:
		var it: Dictionary = Catalog.ITEMS[id]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(230, 150)
		b.text = ""
		b.name = "Item_" + id
		var icon := ItemIcon.new()
		icon.kind = id
		icon.position = Vector2(115, 58)
		b.add_child(icon)
		var l := UI.label(it["name"], 17, NC.PALE_GOLD, "title")
		l.position = Vector2(10, 112)
		l.size = Vector2(210, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		var cnt: int = GameState.inventory[id]
		if cnt > 1:
			var c := UI.label("x%d" % cnt, 16)
			c.position = Vector2(196, 6)
			b.add_child(c)
		b.pressed.connect(func():
			Audio.sfx("ui", -8.0)
			_desc.text = "%s  ·  %s\n%s" % [it["name"], it["kind"].to_upper(), it["desc"]])
		grid.add_child(b)
	_desc = UI.label("Tap an item to inspect it.", 20, Color("e8e2f0"))
	_desc.position = Vector2(470, 520)
	_desc.size = Vector2(_vw - 520, 120)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui.add_child(_desc)

func _back() -> void:
	main.goto(params.get("return", "district"))

class ItemIcon extends Node2D:
	var kind := ""
	func _draw() -> void:
		match kind:
			"lockpick":
				for i in 3:
					draw_line(Vector2(-40 + i * 6, 20), Vector2(30 + i * 6, -20), Color("b8bec8"), 3)
				draw_rect(Rect2(-48, 10, 26, 18), Color("3a2a1a"))
			"burner_phone":
				draw_rect(Rect2(-16, -36, 32, 66), Color("101014"))
				draw_rect(Rect2(-12, -30, 24, 30), Color(0.4, 0.8, 1.0, 0.8))
				for i in 9:
					draw_rect(Rect2(-11 + (i % 3) * 8, 6 + int(i / 3) * 7, 6, 5), Color("3a3a40"))
			"ledger":
				draw_rect(Rect2(-40, -34, 80, 64), Color("4a1a14"))
				draw_rect(Rect2(-40, -34, 8, 64), Color("2a0a08"))
				draw_rect(Rect2(-24, -14, 50, 14), NC.GOLD.darkened(0.2))
			"key_calloway":
				draw_circle(Vector2(-24, 0), 16, NC.GOLD)
				draw_circle(Vector2(-24, 0), 7, Color("1a1410"))
				draw_rect(Rect2(-10, -4, 52, 8), NC.GOLD)
				draw_rect(Rect2(30, 4, 6, 10), NC.GOLD)
				draw_rect(Rect2(20, 4, 6, 7), NC.GOLD)
			"matchbook":
				draw_rect(Rect2(-30, -24, 60, 46), Color("1a0a20"))
				NC.text(self, Vector2(-30, 2), "VH", 22, NC.NEON_PINK, "deco", HORIZONTAL_ALIGNMENT_CENTER, 60)
				draw_line(Vector2(-22, 14), Vector2(18, 14), NC.NEON_RED, 2)
			_:
				draw_circle(Vector2.ZERO, 20, NC.GOLD)

class Desk extends Node2D:
	var w := 1280.0
	func _draw() -> void:
		NC.vgrad(self, Rect2(0, 0, w, 720), Color("0a0d18"), Color("05060c"))
		NC.vgrad(self, Rect2(0, 420, w, 300), Color("2a160c"), Color("120804"))
		for k in 8:
			draw_line(Vector2(0, 430 + k * 36), Vector2(w, 426 + k * 36), Color(0, 0, 0, 0.25), 2)
		NC.cone(self, Vector2(w - 120, -40), PI * 0.62, 900, 0.42, Color(1, 0.85, 0.55, 0.08))
		NC.glow(self, Vector2(w * 0.55, 420), 520, Color(1, 0.8, 0.45, 0.10), 0.5)
