extends Node
## Functional playthrough test. Run:
##   godot --path . -- --test=logic
## Prints PASS/FAIL lines and a summary; exit code 1 on failure.

var main
var fails := 0
var passes := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("PASS  ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Tap through a dialogue box, picking `choice` whenever choices appear.
func talk(db: DialogueBox, choice: int = 0, max_steps: int = 60) -> void:
	await _frames(2)
	var steps := 0
	while db.visible and steps < max_steps:
		steps += 1
		var btns := db._choices.get_children()
		if btns.size() > 0:
			await _frames(1)
			(btns[choice] as Button).pressed.emit()
		else:
			db._on_tap()
		await _frames(3)

func screen():
	return main.current

func wait_screen(name: String, timeout: float = 5.0) -> bool:
	var t := 0.0
	while t < timeout:
		if main.current_name == name and not main.is_busy():
			await _frames(3)
			return true
		await _w(0.1)
		t += 0.1
	return false

func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)

func run(m) -> void:
	main = m
	await _frames(2)
	# ---------------------------------------------------------- economy / wardrobe rules
	GameState.delete_save()
	GameState.new_game()
	check(GameState.cash == 750, "new game starts with $750")
	check(GameState.buy_clothing("coat_trench_black") == "funds", "cannot buy $1,100 trench with $750")
	check(GameState.cash == 750, "failed purchase does not charge")
	check(GameState.buy_clothing("tie_gold") == "ok" and GameState.cash == 600, "buy gold tie -> $600 left")
	check(GameState.buy_clothing("tie_gold") == "owned", "cannot buy the same item twice")
	check(GameState.equip("tie_gold") and GameState.equipped["tie"] == "tie_gold", "equip owned tie")
	check(not GameState.equip("hat_fedora_black"), "cannot equip an unowned hat")
	check(GameState.unequip("tie") and GameState.equipped["tie"] == "", "remove tie")
	check(not GameState.unequip("shirt"), "shirt slot cannot be emptied")
	GameState.add_cash(1000)
	GameState.buy_clothing("suit_midnight")
	check(GameState.owns_clothing("trousers_midnight"), "suit purchase grants matching trousers")
	GameState.equip("suit_midnight")
	check(GameState.equipped["trousers"] == "trousers_midnight", "wearing suit jacket also wears its trousers")
	GameState.set_appearance("hair_style", "pompadour")
	GameState.set_appearance("facial_hair", "full_beard")
	GameState.save_preset(0, "Test outfit")
	GameState.set_appearance("hair_style", "bald")
	GameState.equip("suit_black")
	check(GameState.apply_preset(0) and GameState.appearance["hair_style"] == "pompadour" and GameState.equipped["jacket"] == "suit_midnight", "outfit preset restores look and clothes")
	# appearance really changes the drawn character
	var a1 := Adrian.new()
	a1.use_game_state = false
	add_child(a1)
	a1.set_look(GameState.default_appearance(), GameState.default_equipped())
	var eq2 := GameState.default_equipped()
	eq2["coat"] = "coat_over_camel"
	check(a1.equipped != eq2, "character rig receives a different outfit dictionary")
	a1.queue_free()

	# ---------------------------------------------------------- save / load
	GameState.add_item("matchbook")
	GameState.add_heat(2)
	var before: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	check(GameState.save_game(), "save game writes file")
	GameState.new_game()
	check(GameState.cash == 750, "new_game resets state before load")
	check(GameState.load_game(), "load game reads file")
	var after: Dictionary = GameState.to_dict()
	for k in ["cash", "appearance", "equipped", "owned_clothes", "inventory", "owned_properties", "heat", "presets"]:
		check(JSON.stringify(after[k]) == JSON.stringify(before[k]), "save/load round-trip keeps " + k)
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check(not GameState.load_game(), "corrupt save is rejected without crashing")

	# ---------------------------------------------------------- full playthrough
	GameState.delete_save()
	GameState.new_game()
	GameState.set_flag("look_created")
	main.goto("district", {"x": 3180.0}, 0.0)
	check(await wait_screen("district"), "district screen loads")
	var d = screen()
	await _frames(5)
	check(d._door.get("id", "") == "suds", "standing at the Sable St. Offices door")
	check(d.touch.interact_enabled and d.touch.interact_label == "BREAK IN", "ACTION button offers BREAK IN")
	# multi-touch: hold LEFT with finger 0 and confirm movement
	var vs := get_viewport().get_visible_rect().size
	var x0: float = d.player.position.x
	touch(0, Vector2(110, vs.y - 100), true)
	await _w(0.5)
	check(d.player.position.x < x0 - 40, "touch LEFT moves Adrian (%.0f -> %.0f)" % [x0, d.player.position.x])
	# second finger while first still held
	touch(1, Vector2(262, vs.y - 100), true)
	await _frames(3)
	check(Input.is_action_pressed("move_left") and Input.is_action_pressed("move_right"), "two touch buttons can be held at once (multi-touch)")
	touch(1, Vector2(262, vs.y - 100), false)
	touch(0, Vector2(110, vs.y - 100), false)
	await _frames(3)
	d.player.position.x = 3180.0
	await _frames(3)
	d._interact("suds")
	await talk(d.dialogue, 0)
	check(await wait_screen("mission"), "BEGIN CONTRACT starts the mission")

	# mission: get spotted
	var ms = screen()
	await talk(ms.dialogue)
	await _frames(3)
	check(not ms.frozen, "mission intro dialogue finishes and play begins")
	var g0: Dictionary = ms.guards[0]
	g0["pause"] = 99.0
	g0["dir"] = 1
	ms.player.position.x = g0["node"].position.x + 140
	var heat0 := GameState.heat
	await _w(2.5)
	check(ms.ended, "standing in a guard's sight gets Adrian spotted")
	check(GameState.heat == heat0 + 1, "being spotted raises police heat")
	main.goto("mission", {}, 0.0)
	check(await wait_screen("mission"), "retry reloads the mission")
	ms = screen()
	await talk(ms.dialogue)
	# mission: hide in cover
	g0 = ms.guards[0]
	ms.player.position.x = 430.0
	var ev := InputEventAction.new()
	ev.action = "hide"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var ev2 := InputEventAction.new()
	ev2.action = "hide"
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await _frames(2)
	check(ms.is_hidden and ms.player.pose == "crouch", "HIDE at the crates puts Adrian in cover")
	g0["pause"] = 99.0
	g0["dir"] = 1
	g0["node"].position.x = 330.0
	await _w(1.5)
	check(not ms.ended and g0["sus"] < 0.05, "a guard looking straight at hidden Adrian does not see him")
	# walls block sight
	ms._set_hidden(false)
	ms.player.position.x = 760.0
	g0["node"].position.x = 600.0
	check(not ms.guard_sees(g0), "walls block a guard's line of sight")
	g0["node"].position.x = 260.0
	g0["dir"] = -1
	# envelope (cash pickup)
	for g in ms.guards:
		g["pause"] = 999.0
		g["dir"] = -1
		g["turn_t"] = 999.0
		g["node"].position.x = g["min"]
	ms.guards[2]["dir"] = -1
	var cash0 := GameState.cash
	ms.player.position.x = ms.ENVELOPE_X
	await _frames(3)
	check(ms._near == "envelope", "TAKE prompt at the desk envelope")
	ms._interact("envelope")
	check(GameState.cash == cash0 + 250, "envelope adds $250")
	# exit before ledger is refused
	ms.player.position.x = ms.EXIT_X
	await _frames(3)
	ms._interact("exit")
	await talk(ms.dialogue)
	check(not ms.ended, "cannot escape without the ledger")
	# safe cracking
	ms.player.position.x = ms.SAFE_X
	await _frames(3)
	check(ms._near == "safe", "CRACK prompt at the safe")
	ms._interact("safe")
	await _frames(3)
	var sc = null
	for c in ms._ui.get_children():
		if c.get_script() != null and c.has_method("_crack"):
			sc = c
	check(sc != null, "safe-cracking mini-game opens")
	check(not ms.touch.visible, "touch controls hide during safe-cracking")
	sc.angle = sc.target + PI
	sc._crack()
	check(sc.pins == 0 and sc.misses == 1, "pressing outside the gold zone misses")
	for i in 3:
		sc.angle = sc.target
		sc._crack()
	await _frames(3)
	check(ms.has_ledger and GameState.has_item("ledger"), "three hits open the safe and give the ledger")
	ms.player.position.x = ms.EXIT_X
	await _frames(3)
	ms._interact("exit")
	await _frames(3)
	check(ms.ended and GameState.mission_done("m01_ledger"), "escaping completes the contract")
	check(GameState.has_save(), "contract completion autosaves")
	main.goto("district", {"x": 1280.0}, 0.0)
	check(await wait_screen("district"), "back to the district")
	d = screen()
	await _frames(5)
	check(d._door.get("id", "") == "morettis", "at Moretti's door")
	var cash1 := GameState.cash
	d._interact("morettis")
	await talk(d.dialogue)
	await _frames(3)
	check(GameState.cash == cash1 + 3000, "delivering the ledger pays $3,000 (cash %d -> %d)" % [cash1, GameState.cash])
	check(not GameState.has_item("ledger") and GameState.flag("ledger_delivered"), "ledger handed over")
	# safehouse purchase
	d.player.position.x = 2410.0
	await _frames(3)
	var cash2 := GameState.cash
	d._interact("calloway")
	await talk(d.dialogue, 0)
	check(GameState.owns_property("calloway_4b") and GameState.cash == cash2 - 2000, "Apt 4B purchased for $2,000")
	check(GameState.has_item("key_calloway"), "safehouse key added to bag")
	check(await wait_screen("safehouse", 8.0), "purchase leads into the safehouse")
	var sh = screen()
	await talk(sh.dialogue)
	# wardrobe purchase through the shop UI
	main.goto("wardrobe", {"mode": "shop"}, 0.0)
	check(await wait_screen("wardrobe"), "tailor shop opens")
	var w = screen()
	var cash3 := GameState.cash
	w._select_tab("COATS")
	w._pick("coat_over_camel", "coat")
	check(w._adrian.equipped.get("coat", "") == "coat_over_camel", "trying on puts the coat on the preview character")
	check(GameState.equipped.get("coat", "") == "", "trying on does not equip it for real")
	w._do_action()
	check(GameState.owns_clothing("coat_over_camel") and GameState.cash == cash3 - 1350, "BUY charges $1,350 and adds the coat")
	check(GameState.equipped["coat"] == "coat_over_camel", "bought coat is worn")
	w._select_tab("HATS")
	w._pick("hat_fedora_grey", "hat")
	w._select_tab("SUITS")
	check(w._adrian.equipped.get("hat", "") == "hat_fedora_grey", "try-ons persist across tabs until RESET")
	w._leave()
	check(await wait_screen("district"), "leaving the tailor returns to the street")
	check(screen().player.equipped.get("coat", "") == "coat_over_camel", "new coat is drawn on Adrian in the district")
	check(screen().player.equipped.get("hat", "") == "", "unpurchased try-on hat is not carried into the game")
	# settings / volume buses
	main.open_settings()
	await _frames(3)
	var slider: HSlider = main.overlay.find_child("Slider_music", true, false)
	check(slider != null, "settings has a music slider")
	slider.value = 0.25
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.25)) < 0.1, "music slider sets the Music bus volume")
	var s2: HSlider = main.overlay.find_child("Slider_dialogue", true, false)
	s2.value = 0.5
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Dialogue")) - linear_to_db(0.5)) < 0.1, "dialogue slider sets the Dialogue bus independently")
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) - linear_to_db(GameState.settings["sfx"])) < 0.1, "SFX bus unaffected by other sliders")
	main.close_overlays()
	# pause
	screen()._pause()
	await _frames(2)
	check(get_tree().paused, "pause menu pauses the game")
	main.close_overlays()
	get_tree().paused = false
	# continue from menu
	screen()._store_pos()
	GameState.location = "safehouse"
	GameState.save_game()
	var saved_cash := GameState.cash
	GameState.new_game()
	main.goto("menu", {}, 0.0)
	check(await wait_screen("menu"), "menu loads")
	var cont: Button = screen()._ui.find_child("Continue", true, false)
	check(cont != null, "CONTINUE shown when a save exists")
	cont.pressed.emit()
	check(await wait_screen("safehouse", 6.0), "CONTINUE resumes in the safehouse")
	check(GameState.cash == saved_cash and GameState.equipped["coat"] == "coat_over_camel", "continued game keeps cash and outfit")
	print("\nRESULT: %d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)
