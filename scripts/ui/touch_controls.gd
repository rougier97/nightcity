class_name TouchControls
extends CanvasLayer
## Multi-touch on-screen controls for landscape play. Uses TouchScreenButton so
## the player can hold a direction and tap ACTION at the same time.
## Keyboard equivalents: A/D or arrows, E/Space, C/Shift.

var interact_label := "ACTION":
	set(v):
		interact_label = v
		if _vis.has("interact"):
			_vis["interact"].label = v
var interact_enabled := false:
	set(v):
		interact_enabled = v
		if _vis.has("interact"):
			_vis["interact"].enabled = v
var show_hide := false:
	set(v):
		show_hide = v
		if _btns.has("hide"):
			_btns["hide"].visible = v
var hide_label := "HIDE":
	set(v):
		hide_label = v
		if _vis.has("hide"):
			_vis["hide"].label = v

var _btns := {}
var _vis := {}

func _ready() -> void:
	layer = 20
	_make("move_left", 62, "<")
	_make("move_right", 62, ">")
	_make("interact", 74, interact_label)
	_make("hide", 54, hide_label)
	_btns["hide"].visible = show_hide
	_vis["interact"].enabled = interact_enabled
	get_viewport().size_changed.connect(_layout)
	_layout()

func _make(action: String, radius: float, text: String) -> void:
	var b := TouchScreenButton.new()
	var sh := CircleShape2D.new()
	sh.radius = radius
	b.shape = sh
	b.shape_visible = false
	b.action = action
	b.passby_press = action.begins_with("move")
	add_child(b)
	var v := Visual.new()
	v.radius = radius
	v.label = text
	v.button = b
	v.small_text = action == "interact" or action == "hide"
	b.add_child(v)
	_btns[action] = b
	_vis[action] = v

func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	_btns["move_left"].position = Vector2(110, s.y - 100)
	_btns["move_right"].position = Vector2(262, s.y - 100)
	_btns["interact"].position = Vector2(s.x - 120, s.y - 116)
	_btns["hide"].position = Vector2(s.x - 290, s.y - 84)

class Visual extends Node2D:
	var radius := 60.0
	var label := "":
		set(v):
			label = v
			queue_redraw()
	var enabled := true:
		set(v):
			enabled = v
			queue_redraw()
	var button: TouchScreenButton
	var small_text := false
	var _was := false

	func _process(_d: float) -> void:
		var p := button.is_pressed()
		if p != _was:
			_was = p
			queue_redraw()

	func _draw() -> void:
		var p := button.is_pressed()
		var a := 1.0 if enabled else 0.35
		draw_circle(Vector2.ZERO, radius, Color(0.03, 0.02, 0.07, (0.55 if not p else 0.8) * a))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, NC.a(NC.NEON_PINK if p else NC.GOLD, 0.9 * a), 2.5, true)
		draw_arc(Vector2.ZERO, radius - 7, 0, TAU, 40, NC.a(NC.GOLD, 0.25 * a), 1.0, true)
		if label == "<" or label == ">":
			var d := -1.0 if label == "<" else 1.0
			var col := NC.a(Color.WHITE if p else NC.PALE_GOLD, a)
			draw_colored_polygon(PackedVector2Array([Vector2(16 * d, 0), Vector2(-10 * d, -18), Vector2(-10 * d, 18)]), col)
			return
		var f := NC.font("title")
		var fs := 22 if small_text else 38
		if label.length() > 7:
			fs = 18
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(f, Vector2(-w * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, NC.a(Color.WHITE if p else NC.PALE_GOLD, a))
