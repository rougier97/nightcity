extends Node2D
## CONTRACT 1 — "The Ledger". Side-scrolling stealth infiltration of the
## Castellano bookkeeping office above the Sable Street laundromat.
## Hide in cover, avoid guard sight, crack the safe, escape by the fire escape.

var main
var params := {}

const WORLD_W := 2700.0
const FLOOR := 600.0
const WALLS := [700.0, 1600.0, 2300.0]
const COVERS := [
	{"x": 430.0, "w": 120.0, "name": "crates"},
	{"x": 1010.0, "w": 90.0, "name": "filing cabinets"},
	{"x": 1390.0, "w": 70.0, "name": "coat stand"},
	{"x": 1760.0, "w": 80.0, "name": "curtain"},
	{"x": 2440.0, "w": 110.0, "name": "storage boxes"},
]
const LIT := [[400.0, 650.0], [1150.0, 1350.0], [1960.0, 2140.0]]
const SAFE_X := 2180.0
const ENVELOPE_X := 1250.0
const EXIT_X := 2630.0

var player: Adrian
var cam: Camera2D
var level: Level
var touch: TouchControls
var dialogue: DialogueBox
var hud: HUD
var _ui: Control
var _meter: Meter
var _vw := 1280.0
var guards: Array = []      # dicts {node, min, max, speed, wait, dir, mode, range, sus, turn_t}
var is_hidden := false
var suspicion := 0.0
var max_suspicion := 0.0
var strikes := 0
const MAX_STRIKES := 3
var takedowns := 0
var _takedown_target := {}
var has_ledger := false
var envelope_taken := false
var frozen := false
var ended := false
var _time := 0.0
var _near := ""
var _step_t := 0.0
const SPEED := 200.0

func _ready() -> void:
	_vw = get_viewport_rect().size.x
	level = Level.new()
	level.mission = self
	add_child(level)
	_add_guard(320.0, 260.0, 660.0, 70.0, 1.6, "patrol", 300.0)
	_add_guard(1300.0, 820.0, 1520.0, 80.0, 2.0, "patrol", 320.0)
	_add_guard(1950.0, 1950.0, 1950.0, 0.0, 0.0, "turner", 280.0)
	player = Adrian.new()
	player.size = 0.95
	player.position = Vector2(110, FLOOR)
	player.rim_back = NC.AMBER
	player.rim_front = NC.NEON_CYAN
	player.light = 0.58
	add_child(player)
	var covers := CoverLayer.new()
	covers.level = level
	add_child(covers)
	var fg := Foreground.new()
	fg.mission = self
	add_child(fg)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(WORLD_W)
	cam.limit_top = 0
	cam.limit_bottom = 720
	cam.position_smoothing_enabled = true
	add_child(cam)
	cam.position = Vector2(player.position.x, 360)
	cam.make_current()
	cam.reset_smoothing()
	_ui = UI.root_control(self)
	hud = HUD.new()
	_ui.add_child(hud)
	hud.setup("Contract: The Ledger", false)
	hud.pause_pressed.connect(_pause)
	_meter = Meter.new()
	_meter.mission = self
	_meter.position = Vector2(_vw * 0.5 - 140, 86)
	_ui.add_child(_meter)
	touch = TouchControls.new()
	touch.show_hide = true
	add_child(touch)
	var dl := UI.root_control(self, 30)
	dialogue = DialogueBox.new()
	dl.add_child(dialogue)
	_objective()
	Audio.play_music("tension", 2.0)
	Audio.play_ambience("rain_inside", -8.0, 2.0)
	_intro()

func _intro() -> void:
	frozen = true
	await dialogue.play([
		{"who": "", "text": "Second floor. Laundry steam in the stairwell, a radio playing somewhere. Three Castellano men between me and the safe."},
		{"who": "", "text": "Stay out of their torchlight. Press HIDE next to crates, cabinets or curtains. Get behind a guard — or ambush him from cover — and press TAKEDOWN."},
		{"who": "", "text": "Every time they spot me is a strike. Three strikes and the job's blown."},
	])
	frozen = false

func _add_guard(x: float, mn: float, mx: float, spd: float, wait: float, gmode: String, rng: float) -> void:
	var p := Pedestrian.new()
	p.umbrella = false
	p.torch = true
	p.coat_color = Color("2a1218")
	p.rim = NC.AMBER
	p.speed = spd
	p.wrap_min = 0
	p.wrap_max = 0
	p.position = Vector2(x, FLOOR)
	p.scale = Vector2(0.95, 0.95)
	p.walking = spd > 0.0
	add_child(p)
	guards.append({"node": p, "min": mn, "max": mx, "speed": spd, "wait": wait, "dir": 1, "mode": gmode,
		"range": rng, "sus": 0.0, "pause": 0.0, "turn_t": 3.5, "down": false})

func _objective() -> void:
	if not envelope_taken and not has_ledger:
		hud.set_objective("Find the Castellano safe (far end of the office). Stay unseen.")
	if has_ledger:
		hud.set_objective("You have the ledger. Escape through the fire-escape window (east).")
	elif envelope_taken:
		hud.set_objective("Find the Castellano safe (far end of the office). Stay unseen.")

func _pause() -> void:
	if ended:
		return
	main.open_pause([["RESTART CONTRACT", func(): main.goto("mission")]])

# ---------------------------------------------------------------- update
func _process(delta: float) -> void:
	if ended:
		return
	if not frozen:
		_time += delta
		_update_player(delta)
		_update_guards(delta)
		_update_detection(delta)
	if not frozen or dialogue.visible:
		touch.visible = not dialogue.visible
	cam.position = Vector2(player.position.x, 360)
	level.cam_x = cam.get_screen_center_position().x
	_update_prompts()

func _update_player(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if dialogue.visible:
		dir = 0.0
	if is_hidden and absf(dir) > 0.1:
		_set_hidden(false)
	player.walking = absf(dir) > 0.1 and not is_hidden
	if player.walking:
		player.facing = 1 if dir > 0 else -1
		player.position.x = clampf(player.position.x + dir * SPEED * delta, 60, WORLD_W - 50)
		_step_t -= delta
		if _step_t <= 0:
			_step_t = 0.46
			Audio.sfx("step", -20.0, randf_range(0.85, 1.0))

func _update_guards(delta: float) -> void:
	for g in guards:
		var n: Pedestrian = g["node"]
		if g["down"]:
			n.walking = false
			n.down = minf(1.0, n.down + delta * 3.0)
			continue
		if g["mode"] == "turner":
			g["turn_t"] -= delta
			if g["turn_t"] <= 0:
				g["dir"] = -g["dir"]
				g["turn_t"] = 4.0 if g["dir"] < 0 else 2.6
			n.dir = g["dir"]
			n.walking = false
			continue
		if g["pause"] > 0.0:
			g["pause"] -= delta
			n.walking = false
			n.dir = g["dir"]
			continue
		n.walking = true
		n.dir = g["dir"]
		n.speed = 0.0   # we move it here instead of inside Pedestrian
		n.position.x += g["speed"] * g["dir"] * delta
		n._phase += delta * 6.0 * (g["speed"] / 60.0)
		if n.position.x >= g["max"] and g["dir"] > 0:
			n.position.x = g["max"]
			g["dir"] = -1
			g["pause"] = g["wait"]
		elif n.position.x <= g["min"] and g["dir"] < 0:
			n.position.x = g["min"]
			g["dir"] = 1
			g["pause"] = g["wait"]

func _wall_between(a: float, b: float) -> bool:
	for w in WALLS:
		if (a < w and b > w) or (b < w and a > w):
			return true
	return false

func _in_light(x: float) -> bool:
	for r in LIT:
		if x >= r[0] and x <= r[1]:
			return true
	return level.flash > 0.4

func guard_sees(g: Dictionary) -> bool:
	if is_hidden or g["down"]:
		return false
	var n: Pedestrian = g["node"]
	var dx := player.position.x - n.position.x
	if absf(dx) < 46.0:
		return true
	if signf(dx) != float(g["dir"]):
		return false
	if absf(dx) > g["range"]:
		return false
	return not _wall_between(n.position.x, player.position.x)

func _update_detection(delta: float) -> void:
	var any := false
	for g in guards:
		var n: Pedestrian = g["node"]
		if guard_sees(g):
			any = true
			var dist := absf(player.position.x - n.position.x)
			var rate: float = 0.5 + 1.1 * (1.0 - dist / g["range"])
			if _in_light(player.position.x):
				rate *= 1.6
			if dist < 46.0:
				rate = 3.0
			g["sus"] = minf(1.0, g["sus"] + rate * delta)
		else:
			g["sus"] = maxf(0.0, g["sus"] - 0.3 * delta)
	suspicion = 0.0
	for g in guards:
		suspicion = maxf(suspicion, g["sus"])
	max_suspicion = maxf(max_suspicion, suspicion)
	if suspicion >= 1.0:
		for g in guards:
			if g["sus"] >= 1.0:
				_strike(g)
				break

## A guard Adrian can take down: close, standing, and either facing away
## or ambushed from cover.
func takedown_target() -> Dictionary:
	for g in guards:
		if g["down"]:
			continue
		var n: Pedestrian = g["node"]
		var dx := player.position.x - n.position.x
		if absf(dx) > 74.0 or _wall_between(n.position.x, player.position.x):
			continue
		var behind := signf(dx) != float(g["dir"])
		if behind or is_hidden:
			return g
	return {}

func _update_prompts() -> void:
	_near = ""
	var x := player.position.x
	_takedown_target = takedown_target() if not frozen else {}
	if not _takedown_target.is_empty():
		_near = "takedown"
	elif not envelope_taken and absf(x - ENVELOPE_X) < 60:
		_near = "envelope"
	elif not has_ledger and absf(x - SAFE_X) < 60:
		_near = "safe"
	elif absf(x - EXIT_X) < 70:
		_near = "exit"
	touch.interact_enabled = _near != "" and not frozen
	touch.interact_label = {"envelope": "TAKE", "safe": "CRACK", "exit": "ESCAPE", "takedown": "TAKEDOWN", "": "ACTION"}[_near]
	var c := _cover_near()
	touch.hide_label = "LEAVE" if is_hidden else "HIDE"
	if touch._vis.has("hide"):
		touch._vis["hide"].enabled = is_hidden or not c.is_empty()

func _cover_near() -> Dictionary:
	for c in COVERS:
		if absf(player.position.x - c["x"]) < c["w"] * 0.5 + 34:
			return c
	return {}

func _unhandled_input(event: InputEvent) -> void:
	if ended or frozen or dialogue.visible:
		return
	if event.is_action_pressed("hide"):
		get_viewport().set_input_as_handled()
		if is_hidden:
			_set_hidden(false)
		else:
			var c := _cover_near()
			if not c.is_empty():
				player.position.x = c["x"]
				_set_hidden(true)
	elif event.is_action_pressed("interact") and _near != "":
		get_viewport().set_input_as_handled()
		_interact(_near)
	elif event.is_action_pressed("pause"):
		_pause()

func _set_hidden(v: bool) -> void:
	is_hidden = v
	player.pose = "crouch" if v else "idle"
	player.modulate = Color(0.55, 0.55, 0.7, 1.0) if v else Color.WHITE
	Audio.sfx("step", -16.0, 0.7)

func _interact(what: String) -> void:
	match what:
		"takedown":
			_takedown(_takedown_target)
		"envelope":
			envelope_taken = true
			GameState.add_cash(250)
			Audio.sfx("cash", -2.0)
			UI.toast(_ui, "+$250  ·  Envelope of cash from the desk", NC.GOLD)
		"safe":
			frozen = true
			touch.visible = false
			var sc := SafeCrack.new()
			sc.mission = self
			_ui.add_child(sc)
		"exit":
			if not has_ledger:
				frozen = true
				await dialogue.play([{"who": "", "text": "Not without the ledger. Vincent doesn't pay for sightseeing."}])
				frozen = false
			else:
				_complete()
	_objective()

func _takedown(g: Dictionary) -> void:
	if g.is_empty() or g["down"]:
		return
	var n: Pedestrian = g["node"]
	if is_hidden:
		_set_hidden(false)
	player.facing = 1 if n.position.x > player.position.x else -1
	g["down"] = true
	g["sus"] = 0.0
	n.torch = false
	n.walking = false
	takedowns += 1
	Audio.sfx("takedown")
	UI.toast(_ui, "TAKEDOWN  ·  %d guard%s down" % [takedowns, "" if takedowns == 1 else "s"], NC.NEON_RED, 1.2)

## Spotted: lose a strike. Three strikes and the contract fails.
func _strike(g: Dictionary) -> void:
	strikes += 1
	for other in guards:
		other["sus"] = 0.0
	if strikes >= MAX_STRIKES:
		_caught()
		return
	Audio.sfx("alert", -4.0)
	g["pause"] = 1.6
	g["dir"] = -g["dir"]
	frozen = true
	player.walking = false
	var banner := UI.label("SPOTTED  ·  STRIKE %d OF %d" % [strikes, MAX_STRIKES], 46, NC.NEON_RED, "deco")
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 10)
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ui.add_child(banner)
	var sub := UI.label("Get out of sight — or take him down from behind.", 22, Color.WHITE)
	sub.add_theme_color_override("font_outline_color", Color.BLACK)
	sub.add_theme_constant_override("outline_size", 6)
	sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.offset_top = 90
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ui.add_child(sub)
	await get_tree().create_timer(1.3).timeout
	if not is_inside_tree():
		return
	banner.queue_free()
	sub.queue_free()
	if not ended:
		frozen = false

func safe_done(success: bool) -> void:
	frozen = false
	touch.visible = true
	if success:
		has_ledger = true
		GameState.add_item("ledger")
		Audio.sfx("safe_open")
		UI.toast(_ui, "Got it: Castellano Ledger", NC.GOLD)
		level.safe_open = true
		_objective()

# ---------------------------------------------------------------- endings
func _caught() -> void:
	if ended:
		return
	ended = true
	player.walking = false
	Audio.sfx("alert")
	Audio.play_music("tension", 0.5)
	GameState.add_heat(1)
	if GameState.has_item("ledger"):
		GameState.remove_item("ledger")
	var v := _panel("SPOTTED", NC.NEON_RED)
	var t := UI.label("Three strikes. The Castellanos raised the alarm and somebody called the NCPD.\nPolice heat +1. The ledger stays where it is — for now.", 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var retry := UI.btn("RETRY", func(): main.goto("mission"), Vector2(220, 64))
	retry.name = "Retry"
	h.add_child(retry)
	h.add_child(UI.btn("WALK AWAY", func():
		GameState.save_game()
		main.goto("district", {"x": 3180.0}), Vector2(220, 64)))

func _complete() -> void:
	ended = true
	player.walking = false
	GameState.complete_mission("m01_ledger")
	GameState.district_x = 3180.0
	GameState.location = "district"
	GameState.save_game()
	Audio.sfx("success")
	Audio.play_music("velvet", 3.0)
	var v := _panel("CONTRACT COMPLETE", NC.GOLD)
	var rating := "CLOSE CALL"
	if strikes == 0 and takedowns == 0 and max_suspicion < 0.35:
		rating = "GHOST"
	elif strikes == 0 and takedowns > 0:
		rating = "SILENT ASSASSIN"
	elif strikes <= 1:
		rating = "PROFESSIONAL"
	var t := UI.label("THE LEDGER\n\nTime  %d:%02d      Rating  %s\nStrikes  %d / %d      Takedowns  %d      Cash found  $%d\n\nDeliver the ledger to Vincent Moretti at his restaurant for $3,000." % [
		int(_time) / 60, int(_time) % 60, rating, strikes, MAX_STRIKES, takedowns, 250 if envelope_taken else 0], 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var c := UI.btn("CONTINUE", func(): main.goto("district", {"x": 3180.0}), Vector2(260, 64))
	c.name = "Continue"
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(c)

func _panel(title: String, col: Color) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(cc)
	var p := PanelContainer.new()
	var sb := UI.box(Color(0.03, 0.02, 0.06, 0.97), col, 2)
	sb.content_margin_left = 50
	sb.content_margin_right = 50
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	p.add_theme_stylebox_override("panel", sb)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	var l := UI.label(title, 52, col, "deco")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	touch.visible = false
	return v

# ================================================================= level art
class Level extends Node2D:
	var mission
	var cam_x := 640.0
	var flash := 0.0
	var safe_open := false
	var _t := 0.0
	var _flash_timer := 7.0

	func _process(delta: float) -> void:
		_t += delta
		_flash_timer -= delta
		if _flash_timer <= 0:
			_flash_timer = randf_range(9.0, 16.0)
			flash = 1.0
			get_tree().create_timer(0.8).timeout.connect(func(): Audio.sfx("thunder", -8.0))
		flash = maxf(0.0, flash - delta * 2.2)
		queue_redraw()

	func _window(r: Rect2) -> void:
		NC.vgrad(self, r, Color("0a0c24"), Color("2a1848"))
		# distant lit windows
		for i in 12:
			var wx := r.position.x + fmod(i * 37.0, r.size.x - 10)
			var wy := r.position.y + r.size.y * 0.45 + fmod(i * 23.0, r.size.y * 0.5)
			draw_rect(Rect2(wx, wy, 4, 5), NC.a(NC.AMBER, 0.7))
		# rain running down the glass
		for i in 16:
			var x := r.position.x + 6 + fmod(i * 29.0, r.size.x - 12)
			var y := r.position.y + fmod(_t * (90 + i * 13) + i * 40, r.size.y)
			draw_line(Vector2(x, y), Vector2(x, minf(y + 14, r.end.y)), Color(0.7, 0.8, 1.0, 0.35), 1.0)
			draw_circle(Vector2(x + 3, r.position.y + fmod(i * 47.0, r.size.y)), 1.6, Color(0.7, 0.8, 1.0, 0.25))
		if flash > 0:
			draw_rect(r, Color(0.85, 0.9, 1.0, 0.7 * flash))
		draw_rect(r.grow(6), Color("0b0808"), false, 10)
		draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color("0b0808"), 5)
		draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color("0b0808"), 5)

	func _draw() -> void:
		var F: float = mission.FLOOR
		# room walls
		NC.vgrad(self, Rect2(0, 80, 700, F - 80), Color("1d2629"), Color("0f1416"))
		NC.vgrad(self, Rect2(700, 80, 900, F - 80), Color("2e151b"), Color("140a0d"))
		for x in range(700, 1600, 40):
			draw_line(Vector2(x, 100), Vector2(x, F - 120), Color(0.6, 0.3, 0.2, 0.06), 2)
		NC.vgrad(self, Rect2(1600, 80, 700, F - 80), Color("13221b"), Color("08110d"))
		draw_rect(Rect2(1600, F - 150, 700, 150), Color("1a120c"))
		draw_line(Vector2(1600, F - 150), Vector2(2300, F - 150), NC.a(NC.GOLD, 0.3), 2)
		NC.vgrad(self, Rect2(2300, 80, 400, F - 80), Color("1a1820"), Color("0a090e"))
		# ceiling + floor
		draw_rect(Rect2(0, 0, 2700, 90), Color("07060a"))
		for x in range(0, 2700, 160):
			draw_rect(Rect2(x, 70, 30, 24), Color("0d0b10"))
		NC.vgrad(self, Rect2(0, F, 2700, 120), Color("2a1a12"), Color("0c0705"))
		for x in range(0, 2700, 70):
			draw_line(Vector2(x, F), Vector2(x - 20, 720), Color(0, 0, 0, 0.3), 1)
		# pipes (room A)
		draw_line(Vector2(0, 130), Vector2(700, 130), Color("2a3236"), 8)
		draw_line(Vector2(0, 150), Vector2(700, 150), Color("1e2428"), 5)
		# windows
		_window(Rect2(120, 200, 120, 160))
		_window(Rect2(1080, 190, 150, 170))
		_window(Rect2(1830, 170, 240, 220))
		_window(Rect2(2560, 230, 120, 200))
		# shelves (room A)
		for k in 3:
			draw_rect(Rect2(260, 260 + k * 90, 120, 6), Color("2a2a2a"))
			for b in 4:
				draw_rect(Rect2(266 + b * 28, 230 + k * 90, 22, 30), [Color("d8d0c0"), Color("3a6a8a"), Color("a83a3a"), Color("d8c040")][(b + k) % 4].darkened(0.4))
		# partition walls with doorways
		for w in mission.WALLS:
			draw_rect(Rect2(w - 22, 80, 44, 250), Color("060508"))
			draw_rect(Rect2(w - 22, 80, 6, F - 80), Color("060508"))
			draw_rect(Rect2(w + 16, 80, 6, F - 80), Color("060508"))
			draw_rect(Rect2(w - 30, 322, 60, 10), Color("1a1410"))
		# desk + envelope (room B)
		draw_rect(Rect2(1180, F - 70, 150, 12), Color("3a2414"))
		draw_rect(Rect2(1190, F - 58, 12, 58), Color("2a1a0e"))
		draw_rect(Rect2(1308, F - 58, 12, 58), Color("2a1a0e"))
		if not mission.envelope_taken:
			draw_rect(Rect2(1236, F - 80, 30, 10), Color("e0d4b0"))
			NC.glow(self, Vector2(1251, F - 76), 24, Color(1, 0.9, 0.5, 0.3 + 0.2 * sin(_t * 4)))
		# office desk + banker's lamp (room C)
		draw_rect(Rect2(1990, F - 80, 170, 14), Color("3a1e10"))
		draw_rect(Rect2(2000, F - 66, 150, 66), Color("2a140a"))
		draw_rect(Rect2(2030, F - 112, 50, 14), Color("1a5a3a"))
		draw_line(Vector2(2055, F - 98), Vector2(2055, F - 80), NC.GOLD, 3)
		draw_rect(Rect2(2090, F - 90, 40, 10), Color("e8e0cc"))
		# safe
		var sx: float = mission.SAFE_X
		draw_rect(Rect2(sx - 50, 330, 110, 140), Color("3a2a1a"))
		draw_rect(Rect2(sx - 44, 336, 98, 128), Color("6a4a2a"))
		draw_rect(Rect2(sx - 34, F - 150, 70, 150), Color("1c2024"))
		draw_rect(Rect2(sx - 34, F - 150, 70, 150), Color("4a525a"), false, 2)
		if safe_open:
			draw_rect(Rect2(sx - 30, F - 146, 62, 142), Color("050506"))
			NC.poly(self, [Vector2(sx + 36, F - 150), Vector2(sx + 70, F - 140), Vector2(sx + 70, F - 10), Vector2(sx + 36, F)], Color("2a3036"))
		else:
			draw_circle(Vector2(sx + 1, F - 90), 14, Color("8a929a"))
			draw_circle(Vector2(sx + 1, F - 90), 9, Color("2a3036"))
			draw_line(Vector2(sx + 1, F - 90), Vector2(sx + 1, F - 101), Color("e8e8e8"), 2)
			draw_rect(Rect2(sx + 20, F - 60, 8, 22), Color("8a929a"))
		# exit window label
		NC.text(self, Vector2(2540, 222), "FIRE ESCAPE", 14, NC.a(NC.NEON_CYAN, 0.8), "title", HORIZONTAL_ALIGNMENT_CENTER, 160)

	func _cover_on(ci: CanvasItem, c: Dictionary) -> void:
		var F: float = mission.FLOOR
		var x: float = c["x"]
		var w: float = c["w"]
		match c["name"]:
			"crates", "storage boxes":
				for k in 2:
					ci.draw_rect(Rect2(x - w * 0.5 + k * w * 0.5, F - 100, w * 0.5 - 4, 100), Color("4a3420"))
					ci.draw_rect(Rect2(x - w * 0.5 + k * w * 0.5, F - 100, w * 0.5 - 4, 100), Color("2a1c10"), false, 3)
					ci.draw_line(Vector2(x - w * 0.5 + k * w * 0.5, F - 100), Vector2(x + k * w * 0.5 - 4, F), Color("2a1c10"), 3)
				ci.draw_rect(Rect2(x - w * 0.3, F - 160, w * 0.6, 60), Color("3e2c1a"))
			"filing cabinets":
				ci.draw_rect(Rect2(x - w * 0.5, F - 150, w, 150), Color("3a4048"))
				for k in 4:
					ci.draw_rect(Rect2(x - w * 0.5 + 6, F - 144 + k * 36, w - 12, 30), Color("2a3036"))
					ci.draw_rect(Rect2(x - 8, F - 132 + k * 36, 16, 4), Color("9aa0a8"))
			"coat stand":
				ci.draw_line(Vector2(x, F), Vector2(x, F - 200), Color("1a1008"), 6)
				NC.poly(ci, [Vector2(x - 34, F - 190), Vector2(x + 34, F - 190), Vector2(x + 40, F - 40), Vector2(x - 40, F - 40)], Color("201a2a"))
				NC.poly(ci, [Vector2(x - 20, F - 214), Vector2(x + 20, F - 214), Vector2(x + 14, F - 196), Vector2(x - 14, F - 196)], Color("100c14"))
			"curtain":
				for k in 6:
					var cx := x - w * 0.5 + k * w / 5.0
					ci.draw_rect(Rect2(cx - 8, 150, 16, F - 150), Color("5e1626").darkened(0.15 * (k % 2)))
				ci.draw_rect(Rect2(x - w * 0.6, 140, w * 1.2, 12), NC.GOLD.darkened(0.3))

## Cover objects are drawn in front of the player so hiding reads clearly.
class CoverLayer extends Node2D:
	var level
	func _draw() -> void:
		for c in level.mission.COVERS:
			level._cover_on(self, c)

## Things drawn over the player: guard cones, suspicion marks, lamp light.
class Foreground extends Node2D:
	var mission
	var _t := 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var F: float = mission.FLOOR
		# lamps
		var bx := 520.0 + sin(_t * 1.3) * 10
		draw_line(Vector2(520, 90), Vector2(bx, 250), Color("111"), 1.5)
		NC.cone(self, Vector2(bx, 256), PI / 2, 360, 0.42, Color(1, 0.85, 0.55, 0.10))
		NC.glow(self, Vector2(bx, 256), 60, Color(1, 0.85, 0.5, 0.45))
		draw_circle(Vector2(bx, 256), 6, Color(1, 0.95, 0.8))
		NC.glow(self, Vector2(1250, F - 110), 120, Color(1, 0.8, 0.45, 0.16))
		draw_rect(Rect2(1240, F - 120, 22, 40), Color("2a1a0e"))
		NC.poly(self, [Vector2(1232, F - 120), Vector2(1270, F - 120), Vector2(1262, F - 138), Vector2(1240, F - 138)], Color("6e1b2c"))
		NC.glow(self, Vector2(2055, F - 100), 110, Color(0.6, 1.0, 0.6, 0.13))
		# guards: vision cones + suspicion
		for g in mission.guards:
			var n: Pedestrian = g["node"]
			if g["down"]:
				continue
			var d: int = g["dir"]
			var eye := Vector2(n.position.x + d * 34, F - 132)
			var sus: float = g["sus"]
			var col := Color(1.0, 0.92, 0.6).lerp(NC.NEON_RED, sus)
			var reach: float = g["range"]
			for wx in mission.WALLS:
				var dw: float = (wx - n.position.x) * d
				if dw > 0.0 and dw < reach:
					reach = dw
			NC.cone(self, eye, 0.0 if d > 0 else PI, reach, 0.2, NC.a(col, 0.22 + 0.15 * sus))
			if sus > 0.05:
				var top := Vector2(n.position.x, F - 245)
				var mark := "?" if sus < 0.7 else "!"
				draw_circle(top, 16, Color(0, 0, 0, 0.6))
				draw_arc(top, 16, -PI / 2, -PI / 2 + TAU * sus, 24, col, 3)
				NC.text(self, top + Vector2(-10, 10), mark, 28, col, "title", HORIZONTAL_ALIGNMENT_CENTER, 20)

## Top-centre detection meter.
class Meter extends Control:
	var mission
	func _init() -> void:
		custom_minimum_size = Vector2(440, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var s: float = mission.suspicion
		var col := NC.PALE_GOLD.lerp(NC.NEON_RED, s)
		var label := "HIDDEN" if mission.is_hidden else ("UNSEEN" if s < 0.05 else ("SUSPICIOUS" if s < 0.7 else "ALMOST SPOTTED"))
		draw_rect(Rect2(0, 0, 280, 10), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(0, 0, 280 * s, 10), col)
		draw_rect(Rect2(0, 0, 280, 10), NC.a(NC.GOLD, 0.6), false, 1)
		draw_string(NC.font("title"), Vector2(0, 32), label, HORIZONTAL_ALIGNMENT_CENTER, 280, 20, NC.NEON_CYAN if mission.is_hidden else col)
		draw_string(NC.font("title"), Vector2(296, 14), "STRIKES", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, NC.a(NC.PALE_GOLD, 0.7))
		for i in mission.MAX_STRIKES:
			var c := Vector2(366 + i * 22, 8)
			var on: bool = i < mission.strikes
			var xc := NC.NEON_RED if on else NC.a(NC.PALE_GOLD, 0.35)
			draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), xc, 3.0 if on else 1.5)
			draw_line(c + Vector2(6, -6), c + Vector2(-6, 6), xc, 3.0 if on else 1.5)

## Safe-cracking mini-game: tap CRACK when the needle is inside the gold zone, three times.
class SafeCrack extends Control:
	var mission
	var angle := 0.0
	var speed := 2.4
	var target := 1.0
	var width := 0.5
	var pins := 0
	var misses := 0
	var _center := Vector2.ZERO
	var _msg := "Tap CRACK when the needle is in the gold zone."

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		target = randf() * TAU
		var crack := UI.btn("CRACK", _crack, Vector2(260, 80), 34)
		crack.name = "Crack"
		crack.position = Vector2(get_viewport_rect().size.x - 340, 520)
		add_child(crack)
		var away := UI.btn("STEP AWAY", func():
			mission.safe_done(false)
			queue_free(), Vector2(200, 60), 20)
		away.position = Vector2(get_viewport_rect().size.x - 310, 620)
		add_child(away)

	func _process(delta: float) -> void:
		angle = fmod(angle + speed * delta, TAU)
		queue_redraw()

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			_crack()

	func in_zone() -> bool:
		return absf(angle_difference(angle, target)) < width * 0.5

	func _crack() -> void:
		if in_zone():
			pins += 1
			Audio.sfx("safe_tick", 0.0, 1.0 + pins * 0.1)
			if pins >= 3:
				mission.safe_done(true)
				queue_free()
				return
			target = fmod(target + randf_range(1.5, 4.5), TAU)
			speed *= -1.18
			_msg = "Tumbler %d of 3 set." % pins
		else:
			misses += 1
			Audio.sfx("deny", -4.0)
			_msg = "Missed. Steady hands."
			if misses >= 3:
				pins = 0
				misses = 0
				_msg = "The dial slipped. Start again."

	func _draw() -> void:
		var vs := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.72))
		_center = Vector2(vs.x * 0.42, 380)
		var r := 190.0
		draw_circle(_center, r + 18, Color("1c2024"))
		draw_circle(_center, r, Color("2a3036"))
		draw_arc(_center, r + 18, 0, TAU, 64, Color("8a929a"), 4)
		var steps := 24
		for i in steps:
			var a0 := target - width * 0.5 + width * i / steps
			var a1 := target - width * 0.5 + width * (i + 1) / steps
			draw_colored_polygon(PackedVector2Array([_center, _center + Vector2(cos(a0), sin(a0)) * r, _center + Vector2(cos(a1), sin(a1)) * r]), NC.a(NC.GOLD, 0.55))
		for i in 60:
			var a := TAU * i / 60.0
			var l := 18.0 if i % 5 == 0 else 8.0
			draw_line(_center + Vector2(cos(a), sin(a)) * (r - l), _center + Vector2(cos(a), sin(a)) * r, Color("c8ccd4"), 2)
		draw_circle(_center, 46, Color("8a929a"))
		draw_circle(_center, 30, Color("1c2024"))
		var tip := _center + Vector2(cos(angle), sin(angle)) * (r - 10)
		draw_line(_center, tip, NC.NEON_RED if not in_zone() else NC.NEON_CYAN, 5)
		draw_circle(tip, 6, NC.NEON_RED if not in_zone() else NC.NEON_CYAN)
		for i in 3:
			var p := Vector2(vs.x - 300 + i * 70, 300)
			draw_circle(p, 22, Color("1c2024"))
			draw_circle(p, 16, NC.GOLD if i < pins else Color("3a3a40"))
		draw_string(NC.font("deco"), Vector2(vs.x - 330, 220), "SAFE", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, NC.GOLD)
		draw_multiline_string(NC.font("sans"), Vector2(vs.x - 340, 380), _msg, HORIZONTAL_ALIGNMENT_LEFT, 300, 20, -1, Color.WHITE)
