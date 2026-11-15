extends Node2D
## Main menu: rooftop over Nightcity in the rain. New Game / Continue / Settings.

var main
var params := {}
var _sky: Skyline
var _ui: Control
var _vw := 1280.0
var _scroll := 0.0

func _ready() -> void:
	_vw = get_viewport_rect().size.x
	_sky = Skyline.new()
	_sky.view_w = _vw + 40
	_sky.horizon = 600
	_sky.world_w = 6000
	_sky.seed_value = 12
	add_child(_sky)
	var roof := Rooftop.new()
	roof.w = _vw
	add_child(roof)
	var adrian := Adrian.new()
	adrian.use_game_state = false
	var eq := GameState.default_equipped()
	eq["coat"] = "coat_trench_black"
	eq["hat"] = "hat_fedora_black"
	adrian.set_look(GameState.default_appearance(), eq)
	adrian.position = Vector2(_vw * 0.78, 628)
	adrian.size = 1.75
	adrian.facing = -1
	adrian.light = 0.16
	adrian.rim_strength = 1.0
	adrian.ground_shadow = false
	add_child(adrian)
	var rain := Rain.new()
	rain.area = Rect2(0, -40, _vw, 760)
	rain.ground_top = 628
	rain.ground_bottom = 720
	add_child(rain)
	var title := Title.new()
	title.position = Vector2(70, 96)
	add_child(title)
	_build_ui()
	Audio.play_music("menu", 2.5)
	Audio.play_ambience("rain", -12.0, 3.0)

func _process(delta: float) -> void:
	_scroll += delta * 14.0
	_sky.scroll = fmod(_scroll, 5000.0)

func _build_ui() -> void:
	_ui = UI.root_control(self)
	var v := VBoxContainer.new()
	v.position = Vector2(80, 330)
	v.add_theme_constant_override("separation", 14)
	_ui.add_child(v)
	if GameState.has_save():
		var c := UI.btn("CONTINUE", _continue, Vector2(340, 66), 28)
		c.name = "Continue"
		v.add_child(c)
		var sum := UI.label(GameState.save_summary(), 16, NC.a(NC.PALE_GOLD, 0.75))
		v.add_child(sum)
	var n := UI.btn("NEW GAME", _new_game, Vector2(340, 66), 28)
	n.name = "NewGame"
	v.add_child(n)
	v.add_child(UI.btn("SETTINGS", func(): main.open_settings(), Vector2(340, 66), 28))
	var foot := UI.label("STAGE 1 DEVELOPMENT BUILD  ·  ORIGINAL SCORE  ·  RATED 13+", 14, NC.a(NC.PALE_GOLD, 0.5), "title")
	foot.position = Vector2(80, 680)
	_ui.add_child(foot)

func _continue() -> void:
	if GameState.load_game():
		main.goto("safehouse" if GameState.location == "safehouse" and GameState.owns_property("calloway_4b") else "district")
	else:
		UI.toast(_ui, "Save file could not be read.", NC.NEON_RED)

func _new_game() -> void:
	if GameState.has_save():
		UI.confirm(_ui, "NEW GAME", "Starting over will replace your saved game.", ["CANCEL", "START OVER"], func(i):
			if i == 1:
				_start())
	else:
		_start()

func _start() -> void:
	GameState.new_game()
	main.goto("intro", {}, 1.2)

class Rooftop extends Node2D:
	var w := 1280.0
	func _draw() -> void:
		NC.vgrad(self, Rect2(0, 628, w, 92), Color("0a0814"), Color("040309"))
		draw_rect(Rect2(0, 612, w, 18), Color("0d0b18"))
		draw_line(Vector2(0, 612), Vector2(w, 612), NC.a(NC.NEON_PINK, 0.35), 2)
		for x in range(0, int(w), 64):
			draw_rect(Rect2(x + 4, 596, 40, 16), Color("0d0b18"))
			draw_line(Vector2(x + 4, 596), Vector2(x + 44, 596), NC.a(NC.NEON_CYAN, 0.2), 1)
		# water tower silhouette
		var tx := w * 0.58
		draw_rect(Rect2(tx, 470, 90, 90), Color("06050c"))
		NC.poly(self, [Vector2(tx - 6, 470), Vector2(tx + 45, 438), Vector2(tx + 96, 470)], Color("06050c"))
		for k in 3:
			draw_line(Vector2(tx + 10 + k * 35, 560), Vector2(tx + 10 + k * 35, 612), Color("06050c"), 4)
		draw_line(Vector2(tx, 470), Vector2(tx, 560), NC.a(NC.NEON_PINK, 0.3), 1.5)

class Title extends Node2D:
	var _t := 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var f := 1.0 if sin(_t * 17.0) * sin(_t * 2.3) < 0.94 else 0.4
		NC.neon_text(self, Vector2(0, 80), "HITMAN", 104, NC.NEON_PINK, "deco", HORIZONTAL_ALIGNMENT_LEFT, -1, f)
		NC.neon_text(self, Vector2(8, 150), "N I G H T C I T Y", 48, NC.NEON_CYAN, "title")
		draw_rect(Rect2(400, 112, 66, 40), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(400, 112, 66, 40), NC.GOLD, false, 2)
		NC.text(self, Vector2(400, 145), "13+", 32, NC.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, 66)
		draw_line(Vector2(8, 172), Vector2(470, 172), NC.a(NC.GOLD, 0.6), 1.5)
		NC.text(self, Vector2(8, 198), "A CITY THAT NEVER STOPS RAINING", 18, NC.a(NC.PALE_GOLD, 0.8), "title")
