class_name HUD
extends Control
## In-game heads-up display: cash, heat, location, objective and quick buttons.

signal map_pressed
signal bag_pressed
signal wardrobe_pressed
signal pause_pressed

var _cash: Label
var _heat: HeatMeter
var _obj: Label
var _loc: Label
var _shown_cash := 0.0

func setup(location: String, show_map: bool = true) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 16
	top.add_theme_constant_override("separation", 18)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 0)
	top.add_child(left)
	_cash = UI.label("$0", 34, NC.GOLD, "title")
	left.add_child(_cash)
	_heat = HeatMeter.new()
	left.add_child(_heat)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.custom_minimum_size = Vector2(120, 0)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(mid)
	_loc = UI.label(location.to_upper(), 18, NC.a(NC.PALE_GOLD, 0.8), "deco")
	_loc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_loc)
	_obj = UI.label("", 17, Color("e8e2f0"))
	_obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_obj.offset_left = -330
	_obj.offset_right = 330
	_obj.offset_top = 128
	_obj.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_obj.add_theme_constant_override("outline_size", 6)
	add_child(_obj)
	if show_map:
		top.add_child(UI.btn("MAP", func(): map_pressed.emit(), Vector2(96, 58), 22))
		top.add_child(UI.btn("BAG", func(): bag_pressed.emit(), Vector2(96, 58), 22))
		top.add_child(UI.btn("WARDROBE", func(): wardrobe_pressed.emit(), Vector2(150, 58), 22))
	top.add_child(UI.btn("II", func(): pause_pressed.emit(), Vector2(64, 58), 24))
	_shown_cash = GameState.cash
	GameState.cash_changed.connect(_on_cash)
	GameState.heat_changed.connect(func(_h): _update_heat())
	_update_cash()
	_update_heat()

func set_objective(t: String) -> void:
	_obj.text = t

func _on_cash(_v: int) -> void:
	var tw := create_tween()
	tw.tween_method(func(x: float):
		_shown_cash = x
		_update_cash(), _shown_cash, float(GameState.cash), 0.8)

func _update_cash() -> void:
	_cash.text = "$" + GameState.format_money(int(round(_shown_cash)))

func _update_heat() -> void:
	_heat.queue_redraw()

class HeatMeter extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(190, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var h := GameState.heat
		var col := NC.NEON_RED if h > 0 else NC.a(NC.PALE_GOLD, 0.5)
		draw_string(NC.font("title"), Vector2(0, 16), "POLICE HEAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		for i in 5:
			var c := Vector2(100 + i * 18, 9)
			var pts := PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)])
			if i < h:
				draw_colored_polygon(pts, NC.NEON_RED)
			else:
				pts.append(pts[0])
				draw_polyline(pts, NC.a(NC.PALE_GOLD, 0.5), 1.2)
