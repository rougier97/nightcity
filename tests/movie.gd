extends Node
## Records footage via Godot's movie maker:
##   godot --path . --write-movie out.avi --fixed-fps 30 -- --test=movie --part=intro|play
var main
func _w(t): await get_tree().create_timer(t).timeout
func _f(n):
	for i in n: await get_tree().process_frame

func autotalk(db: DialogueBox) -> void:
	await _f(2)
	while is_instance_valid(db) and db.visible:
		if db._typing:
			await _f(1); continue
		await _w(1.8)
		if not is_instance_valid(db): return
		var b = db._choices.get_children()
		if b.size() > 0: b[0].pressed.emit()
		else: db._on_tap()
		await _f(2)

func run(m) -> void:
	main = m
	var part := "intro"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="): part = a.substr(7)
	GameState.delete_save(); GameState.new_game()
	if part == "intro":
		main.goto("menu", {}, 0.0); await _w(5.0)
		main.current._new_game()
		while main.current_name != "wardrobe":
			if main.current_name == "intro" and main.current._dialogue.visible:
				await autotalk(main.current._dialogue)
			await _f(1)
		await _w(1.5)
		var w = main.current
		for k in [["skin", 4, 1], ["hair_style", Catalog.HAIR_STYLES, 1], ["facial_hair", Catalog.FACIAL_HAIR, 1]]:
			w._cycle(k[0], k[1] if k[1] is Array else Catalog.SKIN_TONES.size(), 1); await _w(0.9)
		await _w(1.5)
	else:
		GameState.set_flag("look_created"); GameState.add_cash(4000)
		main.goto("district", {"x": 700.0}, 0.0); await _w(1.0)
		Input.action_press("move_right"); await _w(5.5); Input.action_release("move_right"); await _w(1.0)
		main.goto("wardrobe", {"mode": "shop"}); await _w(1.5)
		var w = main.current
		for p in [["suit_midnight","jacket"],["coat_trench_black","coat"],["hat_fedora_black","hat"],["glasses_round","glasses"],["suit_burgundy","jacket"],["coat_over_camel","coat"],["hat_trilby","hat"]]:
			w._select_tab({"jacket":"SUITS","coat":"COATS","hat":"HATS","glasses":"EYEWEAR"}[p[1]]); w._pick(p[0], p[1]); await _w(1.1)
		w._do_action(); await _w(1.5)
		main.goto("mission"); await _w(1.0)
		var ms = main.current
		await autotalk(ms.dialogue)
		ms.guards[0]["node"].position.x = 640; ms.guards[0]["dir"] = -1; ms.guards[0]["pause"] = 0.0
		Input.action_press("move_right")
		while ms.player.position.x < 425: await _f(1)
		Input.action_release("move_right")
		var ev := InputEventAction.new(); ev.action = "hide"; ev.pressed = true; Input.parse_input_event(ev)
		await _w(5.5)
		Input.action_press("move_right"); await _w(1.2); Input.action_release("move_right")
		await _w(1.5)
	get_tree().quit()
