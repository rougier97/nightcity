class_name UI
## Art-deco noir UI theme and widget helpers. All touch targets ≥ 56 px.

static var _theme: Theme

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = NC.font("sans")
	t.default_font_size = 22
	# buttons
	var normal := box(Color(0.04, 0.03, 0.08, 0.86), NC.GOLD.darkened(0.15), 2)
	var hover := box(Color(0.10, 0.05, 0.14, 0.92), NC.NEON_PINK, 2)
	var pressed := box(Color(0.25, 0.06, 0.12, 0.95), NC.NEON_PINK, 2)
	var disabled := box(Color(0.04, 0.03, 0.08, 0.5), Color(0.4, 0.35, 0.3, 0.4), 1)
	var focus := box(Color(0, 0, 0, 0), NC.NEON_CYAN, 1)
	for s in [normal, hover, pressed, disabled]:
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 10
		s.content_margin_bottom = 8
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", NC.PALE_GOLD)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.55, 0.5, 0.5))
	t.set_font_size("font_size", "Button", 24)
	t.set_color("font_color", "Label", Color("e8e2f0"))
	# panels
	t.set_stylebox("panel", "PanelContainer", box(Color(0.03, 0.02, 0.07, 0.93), NC.GOLD.darkened(0.3), 1))
	t.set_stylebox("panel", "Panel", box(Color(0.03, 0.02, 0.07, 0.93), NC.GOLD.darkened(0.3), 1))
	# slider
	var track := box(Color(0.1, 0.08, 0.16, 1), Color(0.3, 0.25, 0.4), 1)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(NC.GOLD.darkened(0.2), NC.GOLD, 1)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _knob(NC.PALE_GOLD))
	t.set_icon("grabber_highlight", "HSlider", _knob(Color.WHITE))
	# scrollbars
	var sb := box(Color(0.1, 0.08, 0.16, 0.6), Color(0, 0, 0, 0), 0)
	var grab := box(NC.GOLD.darkened(0.3), Color(0, 0, 0, 0), 0)
	for k in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", k, sb)
		t.set_stylebox("grabber", k, grab)
		t.set_stylebox("grabber_highlight", k, grab)
		t.set_stylebox("grabber_pressed", k, grab)
	_theme = t
	return t

static func _knob(c: Color) -> ImageTexture:
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 28:
		for x in 28:
			var d := Vector2(x - 13.5, y - 13.5).length()
			if d < 12:
				img.set_pixel(x, y, c if d < 10 else c.darkened(0.4))
	return ImageTexture.create_from_image(img)

static func box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(2)
	s.anti_aliasing = true
	return s

static func btn(text: String, cb: Callable = Callable(), min_size := Vector2(240, 60), fsize: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", fsize)
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(func():
			Audio.sfx("ui", -6.0)
			cb.call())
	return b

static func label(text: String, size: int = 22, color: Color = Color("e8e2f0"), fname: String = "sans") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", NC.font(fname))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func root_control(parent: Node, layer: int = 10) -> Control:
	var cl := CanvasLayer.new()
	cl.layer = layer
	parent.add_child(cl)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.theme = theme()
	cl.add_child(c)
	return c

## Brief notification at the top of the screen.
static func toast(parent: Control, text: String, color: Color = NC.PALE_GOLD, seconds: float = 2.4) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(0.03, 0.02, 0.07, 0.92), color, 2))
	var l := label(text, 22, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p.position = Vector2(parent.size.x * 0.5 - 260, 90)
	p.custom_minimum_size = Vector2(520, 0)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(seconds)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

## A modal yes/no style prompt. Returns the chosen index through the callback.
static func confirm(parent: Control, title: String, body: String, options: Array, cb: Callable) -> PanelContainer:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(0.03, 0.02, 0.07, 0.96), NC.GOLD, 2))
	shade.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var t := label(title, 32, NC.GOLD, "deco")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := label(body, 22)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(560, 0)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	for i in options.size():
		var idx := i
		h.add_child(btn(options[i], func():
			shade.queue_free()
			cb.call(idx), Vector2(200, 60)))
	p.reset_size()
	p.position = (parent.size - p.size) * 0.5
	shade.resized.connect(func(): p.position = (shade.size - p.size) * 0.5)
	return p
