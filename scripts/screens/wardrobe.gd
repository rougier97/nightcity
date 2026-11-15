extends Node2D
## Wardrobe / tailor / character creation.
## params.mode: "create" (first-time look), "shop" (Sartori & Sons — buy),
## "closet" (owned items only). The large Adrian preview is the real in-game
## character rig: every try-on, purchase and change is drawn on him live.

var main
var params := {}
var mode := "closet"

const TABS := [
	["LOOK", ["__look"]], ["SUITS", ["jacket"]], ["SHIRTS", ["shirt"]], ["TROUSERS", ["trousers"]],
	["WAISTCOATS", ["waistcoat"]], ["COATS", ["coat"]], ["TIES", ["tie"]], ["SHOES", ["shoes"]],
	["HATS", ["hat"]], ["EYEWEAR", ["glasses"]], ["GLOVES", ["gloves"]],
	["JEWELLERY", ["watch", "ring", "necklace", "pocket_square"]], ["PRESETS", ["__presets"]],
]

var _vw := 1280.0
var _adrian: Adrian
var _preview_eq := {}
var _ui: Control
var _tab := ""
var _tabs_box: HBoxContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _cash: Label
var _detail_name: Label
var _detail_desc: Label
var _action: Button
var _trying: Label
var _selected_id := ""
var _selected_slot := ""
var _swatches := {}

func _ready() -> void:
	mode = params.get("mode", "closet")
	_vw = get_viewport_rect().size.x
	var room := FittingRoom.new()
	room.w = _vw
	room.shop = mode == "shop"
	add_child(room)
	_adrian = Adrian.new()
	_adrian.use_game_state = false
	_adrian.position = Vector2(270, 668)
	_adrian.size = 2.1
	_adrian.light = 1.0
	_adrian.rim_back = NC.AMBER
	_adrian.rim_front = NC.NEON_CYAN
	_adrian.rim_strength = 0.45
	add_child(_adrian)
	_preview_eq = GameState.equipped.duplicate()
	_update_preview()
	_build_ui()
	_select_tab("LOOK" if mode == "create" else ("SUITS" if mode == "shop" else "SUITS"))
	Audio.play_music("velvet" if mode == "shop" else "menu", 2.0)
	Audio.play_ambience("rain_inside", -14.0, 2.0)
	GameState.cash_changed.connect(_on_cash)

func _update_preview() -> void:
	_adrian.set_look(GameState.appearance, _preview_eq)
	if _trying:
		var diff := false
		for k in _preview_eq:
			if _preview_eq[k] != GameState.equipped.get(k, ""):
				diff = true
		_trying.visible = diff

func _on_cash(_v: int) -> void:
	_cash.text = "$" + GameState.format_money(GameState.cash)

# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	_ui = UI.root_control(self)
	var title = {"create": "CREATE YOUR LOOK", "shop": "SARTORI & SONS", "closet": "WARDROBE"}[mode]
	var sub = {"create": "Decide who Adrian Cross is. You can change it later at your wardrobe.",
		"shop": "Bespoke tailoring since 1922. Tap an item to try it on.",
		"closet": "Your clothes. Tap to try on, WEAR to keep it on."}[mode]
	# preview controls
	var turn := UI.btn("TURN", func(): _adrian.facing = -_adrian.facing, Vector2(120, 52), 20)
	turn.position = Vector2(80, 650)
	_ui.add_child(turn)
	var reset := UI.btn("RESET", func():
		_preview_eq = GameState.equipped.duplicate()
		_update_preview()
		_refresh_tab(), Vector2(120, 52), 20)
	reset.position = Vector2(330, 650)
	_ui.add_child(reset)
	_trying = UI.label("TRYING ON — NOT YET WORN", 16, NC.NEON_CYAN, "title")
	_trying.position = Vector2(150, 618)
	_trying.visible = false
	_ui.add_child(_trying)

	var panel := PanelContainer.new()
	var sb := UI.box(Color(0.03, 0.02, 0.06, 0.9), NC.GOLD.darkened(0.3), 1)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(540, 14)
	panel.size = Vector2(_vw - 556, 692)
	_ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	head.add_child(tv)
	tv.add_child(UI.label(title, 36, NC.GOLD, "deco"))
	tv.add_child(UI.label(sub, 15, NC.a(Color.WHITE, 0.65)))
	_cash = UI.label("$" + GameState.format_money(GameState.cash), 34, NC.GOLD, "title")
	head.add_child(_cash)

	var ts := ScrollContainer.new()
	ts.custom_minimum_size = Vector2(0, 66)
	ts.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(ts)
	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 6)
	ts.add_child(_tabs_box)
	for t in TABS:
		if t[0] == "LOOK" and mode == "shop":
			continue
		var tname: String = t[0]
		var b := UI.btn(tname, func(): _select_tab(tname), Vector2(118, 54), 19)
		b.name = "Tab_" + tname
		_tabs_box.add_child(b)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_scroll.add_child(_content)

	var detail := HBoxContainer.new()
	detail.custom_minimum_size = Vector2(0, 76)
	detail.add_theme_constant_override("separation", 12)
	v.add_child(detail)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", 0)
	detail.add_child(dv)
	_detail_name = UI.label("", 22, NC.PALE_GOLD, "title")
	dv.add_child(_detail_name)
	_detail_desc = UI.label("", 16, NC.a(Color.WHITE, 0.7))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.custom_minimum_size = Vector2(300, 0)
	dv.add_child(_detail_desc)
	_action = UI.btn("", _do_action, Vector2(210, 62), 22)
	_action.name = "Action"
	_action.visible = false
	detail.add_child(_action)
	var done := UI.btn("DONE" if mode == "create" else "BACK", _leave, Vector2(150, 62), 22)
	done.name = "Done"
	detail.add_child(done)

func _select_tab(tname: String) -> void:
	_tab = tname
	for b in _tabs_box.get_children():
		var on: bool = b.name == "Tab_" + tname
		b.add_theme_color_override("font_color", NC.NEON_PINK if on else NC.PALE_GOLD)
		b.add_theme_stylebox_override("normal", UI.box(Color(0.12, 0.04, 0.1, 0.95) if on else Color(0.04, 0.03, 0.08, 0.86), NC.NEON_PINK if on else NC.GOLD.darkened(0.15), 2))
	_selected_id = ""
	_selected_slot = ""
	_refresh_tab()
	_scroll.scroll_vertical = 0

func _refresh_tab() -> void:
	for c in _content.get_children():
		c.queue_free()
	var slots: Array = []
	for t in TABS:
		if t[0] == _tab:
			slots = t[1]
	if slots.has("__look"):
		_build_look()
		_show_detail("", "")
		return
	if slots.has("__presets"):
		_build_presets()
		_show_detail("", "")
		return
	var grid := GridContainer.new()
	grid.columns = 2 if _vw - 556 < 900 else 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	for slot in slots:
		if Catalog.OPTIONAL_SLOTS.has(slot):
			grid.add_child(_card("", slot))
		for id in Catalog.items_for_slot(slot):
			if mode != "shop" and not GameState.owns_clothing(id):
				continue
			grid.add_child(_card(id, slot))
	if mode != "shop" and grid.get_child_count() <= (1 if Catalog.OPTIONAL_SLOTS.has(slots[0]) else 0):
		var l := UI.label("Nothing here yet. Visit Sartori & Sons in the Velvet Quarter.", 18, NC.a(Color.WHITE, 0.6))
		_content.add_child(l)
	_update_detail()

func _swatch(c: Color) -> ImageTexture:
	var key := c.to_html()
	if _swatches.has(key):
		return _swatches[key]
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	img.fill(NC.GOLD.darkened(0.3))
	img.fill_rect(Rect2i(2, 2, 36, 36), c)
	img.fill_rect(Rect2i(2, 2, 36, 6), c.lightened(0.2))
	var tex := ImageTexture.create_from_image(img)
	_swatches[key] = tex
	return tex

func _card(id: String, slot: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(250, 78)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 18)
	b.clip_text = true
	var status := ""
	if id == "":
		b.text = "None\n" + ("WEARING" if GameState.equipped.get(slot, "") == "" else "Remove " + Catalog.SLOT_NAMES[slot].to_lower())
		b.icon = _swatch(Color(0.05, 0.04, 0.08))
	else:
		var it: Dictionary = Catalog.clothing(id)
		if GameState.equipped.get(slot, "") == id:
			status = "WEARING"
		elif GameState.owns_clothing(id):
			status = "OWNED"
		else:
			status = "$" + GameState.format_money(int(it["price"]))
		b.text = "%s\n%s" % [it["name"], status]
		b.icon = _swatch(it["color"])
	b.name = "Card_" + (id if id != "" else "none_" + slot)
	var selected := _selected_id == id and _selected_slot == slot
	var previewing: bool = _preview_eq.get(slot, "") == id
	var border := NC.NEON_PINK if selected else (NC.NEON_CYAN if previewing else NC.GOLD.darkened(0.4))
	b.add_theme_stylebox_override("normal", UI.box(Color(0.06, 0.04, 0.1, 0.9), border, 2 if (selected or previewing) else 1))
	b.add_theme_color_override("font_color", Color.WHITE if status == "WEARING" else NC.PALE_GOLD)
	b.pressed.connect(func(): _pick(id, slot))
	return b

func _pick(id: String, slot: String) -> void:
	Audio.sfx("ui", -8.0)
	_selected_id = id
	_selected_slot = slot
	if id == "" and not Catalog.OPTIONAL_SLOTS.has(slot):
		return
	_preview_eq[slot] = id
	var it: Dictionary = Catalog.clothing(id)
	for g in it.get("grants", []):
		var gi: Dictionary = Catalog.clothing(g)
		if gi.get("slot", "") == "trousers":
			_preview_eq["trousers"] = g
	_update_preview()
	_refresh_tab()

func _update_detail() -> void:
	if _selected_slot == "":
		_show_detail("Tap an item to try it on.", "")
		return
	if _selected_id == "":
		_show_detail("No " + Catalog.SLOT_NAMES[_selected_slot].to_lower(), "")
		if GameState.equipped.get(_selected_slot, "") != "":
			_set_action("REMOVE", true)
		return
	var it: Dictionary = Catalog.clothing(_selected_id)
	var desc: String = it.get("desc", "")
	if it.has("grants") and not it["grants"].is_empty():
		desc += "  Includes matching trousers."
	_show_detail(it["name"], desc)
	if not GameState.owns_clothing(_selected_id):
		if mode == "shop":
			_set_action("BUY  $" + GameState.format_money(int(it["price"])), true)
	elif GameState.equipped.get(it["slot"], "") == _selected_id:
		_set_action("WEARING", false)
	else:
		_set_action("WEAR", true)

func _show_detail(n: String, d: String) -> void:
	_detail_name.text = n
	_detail_desc.text = d
	_action.visible = false

func _set_action(t: String, enabled: bool) -> void:
	_action.text = t
	_action.disabled = not enabled
	_action.visible = true

func _do_action() -> void:
	if _selected_slot == "":
		return
	if _selected_id == "":
		GameState.unequip(_selected_slot)
		_after_change("Removed.")
		return
	var it: Dictionary = Catalog.clothing(_selected_id)
	if not GameState.owns_clothing(_selected_id):
		var r := GameState.buy_clothing(_selected_id)
		match r:
			"ok":
				Audio.sfx("cash")
				# keep any other try-ons, wear the new piece
				GameState.equip(_selected_id)
				_after_change("Purchased: " + it["name"])
			"funds":
				Audio.sfx("deny")
				UI.toast(_ui, "Not enough cash. Vincent pays well for quiet work.", NC.NEON_RED)
		return
	GameState.equip(_selected_id)
	_after_change("Wearing: " + it["name"])

func _after_change(msg: String) -> void:
	# Pieces that are tried on but not owned stay as a preview; owned ones sync.
	var np: Dictionary = GameState.equipped.duplicate()
	for k in _preview_eq:
		var pid: String = _preview_eq[k]
		if pid != "" and not GameState.owns_clothing(pid) and k != _selected_slot:
			np[k] = pid
	_preview_eq = np
	_update_preview()
	_refresh_tab()
	UI.toast(_ui, msg, NC.PALE_GOLD, 1.4)
	GameState.save_game()

# ---------------------------------------------------------------- LOOK tab
func _build_look() -> void:
	var rows := [
		["SKIN TONE", "skin", Catalog.SKIN_TONES.size()],
		["HAIRSTYLE", "hair_style", Catalog.HAIR_STYLES],
		["HAIR COLOUR", "hair_colour", Catalog.HAIR_COLOURS.size()],
		["FACIAL HAIR", "facial_hair", Catalog.FACIAL_HAIR],
		["EYES", "eye_colour", Catalog.EYE_COLOURS.size()],
		["SCARS", "scar", Catalog.SCARS],
		["BUILD", "body", Catalog.BODY_TYPES],
	]
	for r in rows:
		var key: String = r[1]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.name = "Look_" + key
		_content.add_child(h)
		var l := UI.label(r[0], 22, NC.PALE_GOLD, "title")
		l.custom_minimum_size = Vector2(170, 0)
		h.add_child(l)
		var val := UI.label(_look_value(key), 20)
		val.custom_minimum_size = Vector2(230, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(36, 36)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.color = _look_colour(key)
		sw.visible = sw.color.a > 0.0
		var opts = r[2]
		h.add_child(UI.btn("<", func():
			_cycle(key, opts, -1)
			val.text = _look_value(key)
			sw.color = _look_colour(key), Vector2(64, 56), 26))
		h.add_child(val)
		h.add_child(UI.btn(">", func():
			_cycle(key, opts, 1)
			val.text = _look_value(key)
			sw.color = _look_colour(key), Vector2(64, 56), 26))
		h.add_child(sw)

func _cycle(key: String, opts, d: int) -> void:
	if opts is Array:
		var i: int = opts.find(GameState.appearance.get(key, opts[0]))
		GameState.set_appearance(key, opts[(i + d + opts.size()) % opts.size()])
	else:
		var n: int = opts
		GameState.set_appearance(key, (int(GameState.appearance.get(key, 0)) + d + n) % n)
	_update_preview()
	GameState.save_game()

func _look_value(key: String) -> String:
	var v = GameState.appearance.get(key)
	match key:
		"skin": return "Tone %d" % (int(v) + 1)
		"hair_style": return Catalog.HAIR_STYLE_NAMES.get(v, str(v))
		"hair_colour": return Catalog.HAIR_COLOUR_NAMES[int(v)]
		"facial_hair": return Catalog.FACIAL_HAIR_NAMES.get(v, str(v))
		"eye_colour": return Catalog.EYE_COLOUR_NAMES[int(v)]
		"scar": return Catalog.SCAR_NAMES.get(v, str(v))
		"body": return Catalog.BODY_TYPE_NAMES.get(v, str(v))
	return str(v)

func _look_colour(key: String) -> Color:
	var v = GameState.appearance.get(key)
	match key:
		"skin": return Catalog.SKIN_TONES[int(v)]
		"hair_colour": return Catalog.HAIR_COLOURS[int(v)]
		"eye_colour": return Catalog.EYE_COLOURS[int(v)]
	return Color(0, 0, 0, 0)

# ---------------------------------------------------------------- PRESETS tab
func _build_presets() -> void:
	_content.add_child(UI.label("Save what Adrian is wearing now, then switch outfits in one tap.", 17, NC.a(Color.WHITE, 0.7)))
	for i in 3:
		var idx := i
		var p: Dictionary = GameState.presets[i]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.name = "Preset_%d" % i
		_content.add_child(h)
		var l := UI.label("OUTFIT %d   %s" % [i + 1, p.get("name", "— empty —")], 20, NC.PALE_GOLD if not p.is_empty() else NC.a(Color.WHITE, 0.5))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		h.add_child(l)
		var save := UI.btn("SAVE", func():
			GameState.save_preset(idx, _outfit_name())
			GameState.save_game()
			UI.toast(_ui, "Outfit %d saved." % (idx + 1), NC.PALE_GOLD, 1.2)
			_refresh_tab(), Vector2(110, 56), 20)
		save.name = "Save"
		h.add_child(save)
		var wear := UI.btn("WEAR", func():
			if GameState.apply_preset(idx):
				_preview_eq = GameState.equipped.duplicate()
				_update_preview()
				GameState.save_game()
				UI.toast(_ui, "Wearing outfit %d." % (idx + 1), NC.PALE_GOLD, 1.2), Vector2(110, 56), 20)
		wear.name = "Wear"
		wear.disabled = p.is_empty()
		h.add_child(wear)

func _outfit_name() -> String:
	var parts := []
	for s in ["coat", "jacket", "hat"]:
		var id: String = GameState.equipped.get(s, "")
		if id != "":
			parts.append(Catalog.clothing(id)["name"])
	return " + ".join(parts.slice(0, 2)) if parts.size() > 0 else "Shirt sleeves"

# ---------------------------------------------------------------- exit
func _leave() -> void:
	GameState.save_game()
	match mode:
		"create":
			GameState.set_flag("look_created")
			GameState.save_game()
			main.goto("map")
		"shop":
			main.goto("district", {"x": 1930.0})
		_:
			var ret: String = params.get("return", "district")
			main.goto(ret, params.get("return_params", {}))

# ================================================================= room art
class FittingRoom extends Node2D:
	var w := 1280.0
	var shop := false
	var _t := 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		NC.vgrad(self, Rect2(0, 0, w, 660), Color("1c0f14"), Color("0b0609"))
		for x in range(0, int(w), 120):
			draw_line(Vector2(x, 0), Vector2(x, 660), Color(0, 0, 0, 0.35), 2)
			draw_line(Vector2(x + 3, 0), Vector2(x + 3, 660), NC.a(NC.GOLD, 0.06), 1)
		draw_rect(Rect2(0, 470, w, 6), NC.a(NC.GOLD, 0.25))
		# arched mirror
		var c := Vector2(270, 360)
		var mw := 170.0
		var pts := []
		for i in 21:
			var a := PI + PI * float(i) / 20.0
			pts.append(Vector2(c.x + cos(a) * mw, 170 + sin(a) * mw))
		pts.append(Vector2(c.x + mw, 650))
		pts.append(Vector2(c.x - mw, 650))
		draw_colored_polygon(PackedVector2Array(pts), Color("0e0c18"))
		NC.vgrad(self, Rect2(c.x - mw + 10, 120, mw * 2 - 20, 520), Color(0.25, 0.2, 0.4, 0.15), Color(0.05, 0.03, 0.1, 0.1))
		var outline := PackedVector2Array(pts)
		outline.append(pts[0])
		draw_polyline(outline, NC.GOLD, 5, true)
		draw_polyline(outline, NC.a(NC.PALE_GOLD, 0.4), 1.5, true)
		for k in 3:
			draw_line(Vector2(c.x - mw + 40 + k * 30, 200 + k * 40), Vector2(c.x - mw + 90 + k * 30, 140 + k * 40), Color(1, 1, 1, 0.05), 6)
		# spotlight
		NC.cone(self, Vector2(270, -20), PI / 2, 720, 0.3, Color(1.0, 0.82, 0.5, 0.10))
		NC.glow(self, Vector2(270, 668), 220, Color(1.0, 0.8, 0.45, 0.18), 0.18)
		# floor
		NC.vgrad(self, Rect2(0, 650, w, 70), Color("1a0e0c"), Color("080404"))
		NC.ellipse(self, Vector2(270, 676), 230, 26, Color("3a0f1a"))
		NC.ellipse_line(self, Vector2(270, 676), 214, 22, NC.a(NC.GOLD, 0.5), 2)
		# rail of suits on the left wall (shop)
		if shop:
			draw_line(Vector2(470, 160), Vector2(530, 160), NC.GOLD.darkened(0.3), 4)
