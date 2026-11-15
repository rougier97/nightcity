class_name DialogueBox
extends Control
## Cinematic dialogue panel with typewriter text, speaker name, tap-to-advance
## and optional choices. Use: `var choice = await box.play(lines)`.
## A line is {who, text, [choices]} — `who` may be "" for narration.

signal finished(choice: int)
signal _advance

const SPEAKERS := {
	"VINCENT MORETTI": {"color": NC.AMBER, "pitch": 0.75},
	"ADRIAN": {"color": NC.NEON_CYAN, "pitch": 1.0},
	"UNKNOWN NUMBER": {"color": NC.AMBER, "pitch": 0.75},
	"SAL": {"color": Color("e09a7a"), "pitch": 0.85},
	"TAILOR": {"color": NC.PALE_GOLD, "pitch": 1.1},
	"GUARD": {"color": NC.NEON_RED, "pitch": 0.9},
}

var _panel: PanelContainer
var _name: Label
var _text: RichTextLabel
var _hint: Label
var _choices: HBoxContainer
var _typing := false
var _choice := -1
var cps := 48.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_panel = PanelContainer.new()
	var sb := UI.box(Color(0.02, 0.015, 0.05, 0.9), NC.GOLD.darkened(0.2), 0)
	sb.border_width_top = 2
	sb.content_margin_left = 60
	sb.content_margin_right = 60
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -200
	_panel.offset_bottom = 0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_name = UI.label("", 26, NC.AMBER, "deco")
	v.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(0, 90)
	_text.add_theme_font_override("normal_font", NC.font("sans"))
	_text.add_theme_font_size_override("normal_font_size", 26)
	_text.add_theme_color_override("default_color", Color("efe9f5"))
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	_choices = HBoxContainer.new()
	_choices.add_theme_constant_override("separation", 16)
	v.add_child(_choices)
	_hint = UI.label("TAP TO CONTINUE", 16, NC.a(NC.PALE_GOLD, 0.7), "title")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_hint)

func _gui_input(event: InputEvent) -> void:
	var tapped = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		accept_event()
		_on_tap()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_on_tap()

func _on_tap() -> void:
	if _choices.get_child_count() > 0:
		return
	if _typing:
		_typing = false
		_text.visible_ratio = 1.0
	else:
		_advance.emit()

func play(lines: Array) -> int:
	visible = true
	_choice = -1
	for line in lines:
		await _show_line(line)
	visible = false
	finished.emit(_choice)
	return _choice

func _show_line(line: Dictionary) -> void:
	var who: String = line.get("who", "")
	var info: Dictionary = SPEAKERS.get(who, {"color": NC.PALE_GOLD, "pitch": 1.0})
	_name.text = who
	_name.add_theme_color_override("font_color", info["color"])
	var italic: bool = who == "" or line.get("thought", false)
	_text.text = ("[i]%s[/i]" % line["text"]) if italic else line["text"]
	_text.visible_characters = 0
	_hint.visible = false
	for c in _choices.get_children():
		c.queue_free()
	_typing = true
	var total := _text.get_total_character_count()
	var shown := 0.0
	var blip_every := 3
	while _typing and _text.visible_characters < total:
		await get_tree().process_frame
		shown += get_process_delta_time() * cps
		var n := int(shown)
		if n != _text.visible_characters:
			if n / blip_every != _text.visible_characters / blip_every:
				Audio.dialogue_blip(info["pitch"] * randf_range(0.95, 1.05))
			_text.visible_characters = mini(n, total)
	_typing = false
	_text.visible_ratio = 1.0
	var opts: Array = line.get("choices", [])
	if opts.size() > 0:
		for i in opts.size():
			var idx := i
			_choices.add_child(UI.btn(opts[i], func():
				_choice = idx
				for c in _choices.get_children():
					c.queue_free()
				_advance.emit(), Vector2(220, 56), 22))
		await _advance
		return
	_hint.visible = true
	if line.get("auto", 0.0) > 0.0:
		await get_tree().create_timer(line["auto"]).timeout
		return
	await _advance
