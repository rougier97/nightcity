extends Node
## Visual tour: loads each screen, waits, saves a screenshot to /tmp/shots.
var main
func _w(t): await get_tree().create_timer(t).timeout
func snap(n): await main.shot("/tmp/shots/%s.png" % n); print("SHOT ", n)

func run(m) -> void:
	main = m
	GameState.delete_save()
	GameState.new_game()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.substr(7)
	if only == "" or only == "menu":
		main.goto("menu", {}, 0.0); await _w(2.0); await snap("01_menu")
	if only == "" or only == "intro":
		main.goto("intro", {}, 0.0)
		await _w(5.0); await snap("02_intro_card")
		await _w(2.5)
		await _w(9.0); await snap("03_intro_skyline")
		await _w(14.0); await snap("04_intro_street")
		await _w(6.0); await snap("05_intro_namecard")
		await _w(9.0); await snap("06_intro_call")
	if only == "" or only == "wardrobe":
		main.goto("wardrobe", {"mode": "create"}, 0.0); await _w(1.5); await snap("07_create_look")
		GameState.add_cash(5000)
		main.goto("wardrobe", {"mode": "shop"}, 0.0); await _w(1.0)
		var w = main.current
		w._pick("suit_midnight", "jacket"); w._pick("coat_trench_black", "coat"); w._pick("hat_fedora_black", "hat")
		await _w(0.8); await snap("08_shop_tryon")
		w._select_tab("HATS"); await _w(0.5); await snap("08b_shop_hats")
	if only == "" or only == "map":
		main.goto("map", {}, 0.0); await _w(1.5); await snap("09_map")
		main.current._select("docks"); await _w(0.5); await snap("09b_map_locked")
	if only == "" or only == "district":
		for x in [600.0, 1250.0, 1950.0, 2450.0, 3150.0]:
			main.goto("district", {"x": x}, 0.0); await _w(1.6); await snap("10_district_%d" % int(x))
		main.current.player.walking = true
		Input.action_press("move_right"); await _w(0.6); await snap("11_walking"); Input.action_release("move_right")
	if only == "" or only == "mission":
		main.goto("mission", {}, 0.0); await _w(1.0)
		var ms = main.current
		ms.dialogue._advance.emit(); await _w(0.1); ms.dialogue._on_tap(); ms.dialogue._advance.emit()
		ms.dialogue.visible = false; ms.frozen = false
		await _w(1.0); await snap("12_mission_start")
		ms.player.position.x = 430; ms._set_hidden(true); await _w(1.0); await snap("13_mission_hidden")
		ms._set_hidden(false); ms.player.position.x = 1100; await _w(1.5); await snap("14_mission_roomB")
		ms.player.position.x = 2180; ms.guards[2]["dir"] = -1; ms.guards[2]["turn_t"] = 99.0
		await _w(0.6); ms._interact("safe"); await _w(0.8); await snap("15_safecrack")
	if only == "" or only == "inventory":
		GameState.add_item("ledger"); GameState.add_item("matchbook")
		main.goto("inventory", {}, 0.0); await _w(1.0); await snap("16_inventory")
	if only == "" or only == "safehouse":
		GameState.buy_property("calloway_4b"); GameState.set_flag("safehouse_seen")
		main.goto("safehouse", {}, 0.0); await _w(1.5); await snap("17_safehouse")
		main.open_settings(); await _w(0.5); await snap("18_settings")
	if only == "dialogue":
		GameState.set_flag("look_created")
		main.goto("district", {"x": 1280.0}, 0.0); await _w(1.0)
		main.current._interact("morettis"); await _w(2.5); await snap("19_dialogue")
		main.goto("intro", {}, 0.0); await _w(1.0); await snap("20_intro_skip")
		main.goto("district", {"x": 2410.0}, 0.0); await _w(1.0)
		main.current._interact("calloway"); await _w(3.5); await snap("21_dialogue_choice")
	if only == "strike":
		main.goto("mission", {}, 0.0); await _w(0.8)
		var ms = main.current
		ms.dialogue.visible = false; ms.frozen = false
		var g = ms.guards[0]; g["pause"] = 99.0; g["dir"] = 1; g["node"].position.x = 300
		ms.player.position.x = 450; await _w(1.6); await snap("22_strike")
		await _w(1.6)
		g["dir"] = 1; ms.player.position.x = 250; await _w(0.3); await snap("23_takedown_prompt")
		ms._interact("takedown"); ms.player.position.x = 120; await _w(1.0)
		print("DBG down=", g["node"].down, " pos=", g["node"].position, " mod=", g["node"].modulate, " vis=", g["node"].visible, " gdown=", g["down"])
		await snap("24_guard_down")
	print("SHOTS DONE")
	get_tree().quit()
