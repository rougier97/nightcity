extends Node2D
## Playable Velvet Quarter street. Walk with touch arrows, ACTION at doors.
## Doors: jazz club, Moretti's (mission giver / payout), tailor (shop),
## Calloway Building (buy / enter safehouse), Sable St. Offices (mission start).

var main
var params := {}
var street: VelvetStreet
var player: Adrian
var reflection: Adrian
var cam: Camera2D
var hud: HUD
var touch: TouchControls
var dialogue: DialogueBox
var _ui: Control
var _vw := 1280.0
var _busy := false
var _step_t := 0.0
var _door := {}
const SPEED := 240.0

func _ready() -> void:
	_vw = get_viewport_rect().size.x
	GameState.location = "district"
	street = VelvetStreet.new()
	add_child(street)
	reflection = Adrian.new()
	reflection.modulate = Color(1, 1, 1, 0.16)
	reflection.ground_shadow = false
	reflection.rim_strength = 0.0
	street.add_child(reflection)
	player = Adrian.new()
	player.size = 0.95
	street.add_child(player)
	street.add_foreground()
	var x: float = params.get("x", GameState.district_x)
	player.position = Vector2(clampf(x, 80, VelvetStreet.WORLD_W - 80), VelvetStreet.WALK_Y)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(VelvetStreet.WORLD_W)
	cam.limit_top = 0
	cam.limit_bottom = 720
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)
	cam.position = Vector2(player.position.x, 360)
	cam.make_current()
	cam.reset_smoothing()

	_ui = UI.root_control(self)
	hud = HUD.new()
	_ui.add_child(hud)
	hud.setup("The Velvet Quarter")
	hud.map_pressed.connect(func(): _leave_to("map"))
	hud.bag_pressed.connect(func(): _leave_to("inventory", {"return": "district"}))
	hud.wardrobe_pressed.connect(func(): _leave_to("wardrobe", {"mode": "closet", "return": "district"}))
	hud.pause_pressed.connect(_pause)
	touch = TouchControls.new()
	add_child(touch)
	dialogue = DialogueBox.new()
	var dl := UI.root_control(self, 30)
	dl.add_child(dialogue)
	_update_objective()
	Audio.play_music("velvet", 2.5)
	Audio.play_ambience("rain", -9.0, 2.0)

func _update_objective() -> void:
	var t := ""
	if not GameState.mission_done("m01_ledger") and not GameState.has_item("ledger"):
		t = "CONTRACT: Steal the Castellano ledger  ·  Sable St. Offices (east, past the laundromat)"
	elif GameState.has_item("ledger"):
		t = "Deliver the ledger to Vincent Moretti  ·  Moretti's Ristorante"
	elif not GameState.owns_property("calloway_4b"):
		t = "Buy a safehouse  ·  Calloway Building, Apt 4B  ($2,000)"
	else:
		t = "Explore the Velvet Quarter. Vincent will call with more work."
	hud.set_objective(t)

func _process(delta: float) -> void:
	var dir := 0.0
	if not _busy and not dialogue.visible:
		dir = Input.get_axis("move_left", "move_right")
	player.walking = absf(dir) > 0.1
	if player.walking:
		player.facing = 1 if dir > 0 else -1
		player.position.x = clampf(player.position.x + dir * SPEED * delta, 60, VelvetStreet.WORLD_W - 60)
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.42
			Audio.sfx("step", -14.0, randf_range(0.9, 1.1))
	reflection.position = Vector2(player.position.x, VelvetStreet.WALK_Y + 4)
	reflection.size = 0.95
	reflection.sync_from(player)
	reflection.scale = Vector2(0.95 * player.facing, -0.95)
	cam.position = Vector2(player.position.x, 360)
	var cx := clampf(cam.get_screen_center_position().x, _vw * 0.5, VelvetStreet.WORLD_W - _vw * 0.5)
	street.set_camera(cx, _vw)
	touch.visible = not dialogue.visible
	# doors
	_door = street.nearest_door(player.position.x, 80.0)
	touch.interact_enabled = not _door.is_empty() and not _busy
	if not _door.is_empty():
		touch.interact_label = _verb(_door["id"])
	else:
		touch.interact_label = "ACTION"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not _busy and not dialogue.visible and not _door.is_empty():
		get_viewport().set_input_as_handled()
		_interact(_door["id"])
	elif event.is_action_pressed("pause") and not _busy:
		_pause()

func _verb(id: String) -> String:
	match id:
		"morettis": return "TALK"
		"tailor": return "SHOP"
		"calloway": return "ENTER" if GameState.owns_property("calloway_4b") else "BUY"
		"suds": return "BREAK IN" if not GameState.mission_done("m01_ledger") else "LOOK"
		"barrier": return "LOOK"
	return "ENTER"

func _pause() -> void:
	main.open_pause([["SAVE GAME", func():
		_store_pos()
		var ok := GameState.save_game()
		UI.toast(_ui, "Game saved." if ok else "Save failed.", NC.PALE_GOLD)]])

func _store_pos() -> void:
	GameState.district_x = player.position.x
	GameState.location = "district"

func _leave_to(screen: String, p: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	_store_pos()
	GameState.save_game()
	main.goto(screen, p)

# ---------------------------------------------------------------- doors
func _interact(id: String) -> void:
	_busy = true
	player.walking = false
	match id:
		"velvet_hour":
			if not GameState.flag("matchbook"):
				await dialogue.play([
					{"who": "", "text": "Smoke, low light and a saxophone taking its time. The Midnight Quartet is between sets."},
					{"who": "", "text": "Someone left a matchbook on the bar. A phone number is written inside in red ink."},
				])
				GameState.set_flag("matchbook")
				GameState.add_item("matchbook")
				GameState.save_game()
				UI.toast(_ui, "Added to bag: Velvet Hour Matchbook")
			else:
				await dialogue.play([{"who": "", "text": "The doorman shakes his head. Private booking tonight. Come back another night."}])
		"morettis":
			await _morettis()
		"tailor":
			Audio.sfx("door", -6.0)
			_store_pos()
			GameState.save_game()
			main.goto("wardrobe", {"mode": "shop"})
			return
		"calloway":
			await _calloway()
		"suds":
			if GameState.mission_done("m01_ledger"):
				await dialogue.play([{"who": "", "text": "The office upstairs is dark now. The Castellanos have cleared out — for tonight."}])
			else:
				var c := await dialogue.play([{"who": "", "text": "A side door, a cheap lock, and the Castellano books one floor up. Two men on the stairs, maybe three.", "choices": ["BEGIN CONTRACT", "NOT YET"]}])
				if c == 0:
					Audio.sfx("door", -4.0)
					_store_pos()
					GameState.district_x = 3180.0
					GameState.save_game()
					main.goto("mission", {}, 0.8)
					return
		"barrier":
			await dialogue.play([{"who": "", "text": "NCPD sawhorses and a sign: SABLE DOCKS — ROAD CLOSED. The Volkov Syndicate's territory will have to wait until the Morettis trust you."}])
	_busy = false
	_update_objective()

func _morettis() -> void:
	if GameState.has_item("ledger"):
		await dialogue.play([
			{"who": "SAL", "text": "He's expecting you. Back booth."},
			{"who": "VINCENT MORETTI", "text": "Page forty-one. My father's name, in Castellano handwriting. You didn't read the rest, did you, Mr. Cross?"},
			{"who": "ADRIAN", "text": "I was paid to carry it, not to read it."},
			{"who": "VINCENT MORETTI", "text": "Good answer. Three thousand, as promised. Buy yourself a coat — and somewhere to sleep that isn't a bus shelter. The Calloway Building has a flat going."},
		])
		GameState.remove_item("ledger")
		GameState.add_cash(Catalog.MISSIONS["m01_ledger"]["reward"])
		GameState.set_flag("ledger_delivered")
		GameState.save_game()
		Audio.sfx("cash")
		UI.toast(_ui, "+$3,000  ·  Contract paid by Vincent Moretti", NC.GOLD, 2.6)
	elif GameState.flag("ledger_delivered"):
		await dialogue.play([{"who": "SAL", "text": "Mr. Moretti says you did good work. He'll call when there's more. Until then — the tiramisu's on the house."}])
	else:
		await dialogue.play([{"who": "SAL", "text": "Sable Street. Second floor, above the laundromat. Mr. Moretti doesn't like waiting, and neither do I."}])

func _calloway() -> void:
	if GameState.owns_property("calloway_4b"):
		Audio.sfx("door", -6.0)
		_store_pos()
		GameState.save_game()
		main.goto("safehouse")
		await get_tree().process_frame
		return
	var price: int = Catalog.PROPERTIES["calloway_4b"]["price"]
	var c := await dialogue.play([{"who": "", "text": "Calloway Building, Apt 4B. Fourth floor, skyline view, radiator that knocks. The super wants $%s, cash." % GameState.format_money(price), "choices": ["BUY  $" + GameState.format_money(price), "LEAVE IT"]}])
	if c != 0:
		return
	var r := GameState.buy_property("calloway_4b")
	if r == "ok":
		Audio.sfx("cash")
		street.refresh()
		GameState.save_game()
		UI.toast(_ui, "SAFEHOUSE PURCHASED  ·  Calloway Apt 4B", NC.GOLD, 2.4)
		await get_tree().create_timer(1.2).timeout
		_store_pos()
		GameState.save_game()
		main.goto("safehouse", {"first": true})
	else:
		Audio.sfx("deny")
		await dialogue.play([{"who": "", "text": "You're $%s short. Vincent Moretti pays well for quiet work." % GameState.format_money(price - GameState.cash)}])
