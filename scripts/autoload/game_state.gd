extends Node
## Persistent game state: money, appearance, wardrobe, inventory, properties,
## story progress and settings. Saved as JSON in user://.

signal cash_changed(value: int)
signal appearance_changed
signal inventory_changed
signal heat_changed(value: int)

const SAVE_PATH := "user://nightcity_save.json"
const SETTINGS_PATH := "user://nightcity_settings.json"
const SAVE_VERSION := 1
const STARTING_CASH := 750

var cash: int = 0
var appearance: Dictionary = {}
var equipped: Dictionary = {}
var owned_clothes: Array = []
var presets: Array = [{}, {}, {}]
var inventory: Dictionary = {}
var owned_properties: Array = []
var missions_done: Array = []
var flags: Dictionary = {}
var unlocked_districts: Array = ["velvet"]
var heat: int = 0
var location: String = "district"   # where Continue drops you: "district" | "safehouse"
var district_x: float = 1500.0
var playtime: float = 0.0

var settings := {"music": 0.8, "sfx": 0.9, "dialogue": 1.0}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()
	new_game()  # sane defaults until a game is started or loaded

func _process(delta: float) -> void:
	if not get_tree().paused:
		playtime += delta

func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E, KEY_SPACE, KEY_ENTER],
		"hide": [KEY_C, KEY_SHIFT],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

# ---------------------------------------------------------------- new game
func default_appearance() -> Dictionary:
	return {"skin": 2, "hair_style": "slick_back", "hair_colour": 0, "facial_hair": "stubble",
		"eye_colour": 1, "scar": "none", "body": "standard"}

func default_equipped() -> Dictionary:
	var e := {}
	for s in Catalog.SLOTS:
		e[s] = ""
	e["jacket"] = "suit_black"
	e["shirt"] = "shirt_white"
	e["trousers"] = "trousers_black"
	e["tie"] = "tie_black"
	e["shoes"] = "shoes_oxford_black"
	return e

func new_game() -> void:
	cash = STARTING_CASH
	appearance = default_appearance()
	equipped = default_equipped()
	owned_clothes = Catalog.STARTER_CLOTHES.duplicate()
	presets = [{}, {}, {}]
	inventory = {"lockpick": 1, "burner_phone": 1}
	owned_properties = []
	missions_done = []
	flags = {}
	unlocked_districts = ["velvet"]
	heat = 0
	location = "district"
	district_x = 1500.0
	playtime = 0.0
	cash_changed.emit(cash)
	appearance_changed.emit()
	inventory_changed.emit()

# ---------------------------------------------------------------- money
func add_cash(amount: int) -> void:
	cash = max(0, cash + amount)
	cash_changed.emit(cash)

func can_afford(amount: int) -> bool:
	return cash >= amount

func spend(amount: int) -> bool:
	if amount > cash:
		return false
	cash -= amount
	cash_changed.emit(cash)
	return true

# ---------------------------------------------------------------- heat
func add_heat(amount: int) -> void:
	heat = clampi(heat + amount, 0, 5)
	heat_changed.emit(heat)

# ---------------------------------------------------------------- wardrobe
func owns_clothing(id: String) -> bool:
	return owned_clothes.has(id)

## Returns "ok", "owned", "funds" or "invalid".
func buy_clothing(id: String) -> String:
	var item: Dictionary = Catalog.clothing(id)
	if item.is_empty():
		return "invalid"
	if owns_clothing(id):
		return "owned"
	if not spend(int(item["price"])):
		return "funds"
	owned_clothes.append(id)
	for g in item.get("grants", []):
		if not owned_clothes.has(g):
			owned_clothes.append(g)
	return "ok"

func equip(id: String) -> bool:
	var item: Dictionary = Catalog.clothing(id)
	if item.is_empty() or not owns_clothing(id):
		return false
	equipped[item["slot"]] = id
	# A suit jacket brings its matching trousers along, if owned.
	for g in item.get("grants", []):
		var gi: Dictionary = Catalog.clothing(g)
		if not gi.is_empty() and owns_clothing(g) and gi["slot"] == "trousers":
			equipped["trousers"] = g
	appearance_changed.emit()
	return true

func unequip(slot: String) -> bool:
	if not Catalog.OPTIONAL_SLOTS.has(slot):
		return false
	equipped[slot] = ""
	appearance_changed.emit()
	return true

func set_appearance(key: String, value) -> void:
	appearance[key] = value
	appearance_changed.emit()

func save_preset(index: int, label: String) -> void:
	presets[index] = {"name": label, "appearance": appearance.duplicate(), "equipped": equipped.duplicate()}

func apply_preset(index: int) -> bool:
	var p: Dictionary = presets[index]
	if p.is_empty():
		return false
	# Only wear pieces still owned (defensive against edited saves)
	for slot in p["equipped"]:
		var id: String = p["equipped"][slot]
		if id == "" or owns_clothing(id):
			equipped[slot] = id
	appearance = p["appearance"].duplicate()
	appearance_changed.emit()
	return true

# ---------------------------------------------------------------- inventory
func add_item(id: String, count: int = 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + count
	if inventory[id] <= 0:
		inventory.erase(id)
	inventory_changed.emit()

func has_item(id: String) -> bool:
	return int(inventory.get(id, 0)) > 0

func remove_item(id: String, count: int = 1) -> void:
	add_item(id, -count)

# ---------------------------------------------------------------- property
func owns_property(id: String) -> bool:
	return owned_properties.has(id)

## Returns "ok", "owned", "funds" or "invalid".
func buy_property(id: String) -> String:
	if not Catalog.PROPERTIES.has(id):
		return "invalid"
	if owns_property(id):
		return "owned"
	if not spend(int(Catalog.PROPERTIES[id]["price"])):
		return "funds"
	owned_properties.append(id)
	if id == "calloway_4b":
		add_item("key_calloway")
	return "ok"

# ---------------------------------------------------------------- story
func mission_done(id: String) -> bool:
	return missions_done.has(id)

func complete_mission(id: String) -> void:
	if not missions_done.has(id):
		missions_done.append(id)

func flag(key: String) -> bool:
	return bool(flags.get(key, false))

func set_flag(key: String, value: bool = true) -> void:
	flags[key] = value

# ---------------------------------------------------------------- save / load
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "cash": cash, "appearance": appearance, "equipped": equipped,
		"owned_clothes": owned_clothes, "presets": presets, "inventory": inventory,
		"owned_properties": owned_properties, "missions_done": missions_done, "flags": flags,
		"unlocked_districts": unlocked_districts, "heat": heat, "location": location,
		"district_x": district_x, "playtime": playtime,
		"saved_at": Time.get_datetime_string_from_system(),
	}

func from_dict(d: Dictionary) -> void:
	new_game()
	cash = int(d.get("cash", STARTING_CASH))
	var app: Dictionary = default_appearance()
	var src_app: Dictionary = d.get("appearance", {})
	for k in app:
		if src_app.has(k):
			app[k] = src_app[k]
	for k in ["skin", "hair_colour", "eye_colour"]:
		app[k] = int(app[k])
	app["skin"] = clampi(app["skin"], 0, Catalog.SKIN_TONES.size() - 1)
	app["hair_colour"] = clampi(app["hair_colour"], 0, Catalog.HAIR_COLOURS.size() - 1)
	app["eye_colour"] = clampi(app["eye_colour"], 0, Catalog.EYE_COLOURS.size() - 1)
	appearance = app
	owned_clothes = []
	for id in d.get("owned_clothes", Catalog.STARTER_CLOTHES):
		if Catalog.CLOTHES.has(id) and not owned_clothes.has(id):
			owned_clothes.append(id)
	for id in Catalog.STARTER_CLOTHES:
		if not owned_clothes.has(id):
			owned_clothes.append(id)
	var eq: Dictionary = default_equipped()
	var src_eq: Dictionary = d.get("equipped", {})
	for slot in eq:
		if src_eq.has(slot):
			var id: String = str(src_eq[slot])
			if id == "" and Catalog.OPTIONAL_SLOTS.has(slot):
				eq[slot] = ""
			elif owned_clothes.has(id) and Catalog.CLOTHES[id]["slot"] == slot:
				eq[slot] = id
	equipped = eq
	presets = [{}, {}, {}]
	var src_p: Array = d.get("presets", [])
	for i in range(min(3, src_p.size())):
		if src_p[i] is Dictionary:
			presets[i] = src_p[i]
	inventory = {}
	var src_inv: Dictionary = d.get("inventory", {})
	for k in src_inv:
		if Catalog.ITEMS.has(k) and int(src_inv[k]) > 0:
			inventory[k] = int(src_inv[k])
	owned_properties = Array(d.get("owned_properties", [])).filter(func(p): return Catalog.PROPERTIES.has(p))
	missions_done = Array(d.get("missions_done", []))
	flags = d.get("flags", {})
	unlocked_districts = Array(d.get("unlocked_districts", ["velvet"]))
	heat = int(d.get("heat", 0))
	location = str(d.get("location", "district"))
	district_x = float(d.get("district_x", 1500.0))
	playtime = float(d.get("playtime", 0.0))
	cash_changed.emit(cash)
	appearance_changed.emit()
	inventory_changed.emit()
	heat_changed.emit(heat)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Dictionary):
		push_error("Save file is corrupt")
		return false
	from_dict(data)
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func save_summary() -> String:
	if not has_save():
		return ""
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return ""
	var mins := int(float(data.get("playtime", 0)) / 60.0)
	return "$%s  ·  %d min played" % [format_money(int(data.get("cash", 0))), mins]

# ---------------------------------------------------------------- settings
func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		for k in settings:
			if data.has(k):
				settings[k] = clampf(float(data[k]), 0.0, 1.0)

static func format_money(v: int) -> String:
	var s := str(abs(v))
	var out := ""
	var n := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		n += 1
		if n % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if v < 0 else "") + out
