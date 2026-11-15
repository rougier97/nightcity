extends Node
## Music (crossfading, per-district), ambience, SFX and dialogue on separate buses
## so each has its own volume control.

const BUSES := ["Music", "SFX", "Dialogue"]
const MUSIC_DIR := "res://audio/music_%s.ogg"
const SFX_DIR := "res://audio/sfx_%s.ogg"

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _dialogue: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _cache := {}
var current_track := ""
var current_ambience := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_active_music = _music_a
	_ambience = _make_player("SFX")
	_dialogue = _make_player("Dialogue")
	for i in 8:
		_sfx_pool.append(_make_player("SFX"))
	apply_settings()

func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func _load(path: String, loop: bool) -> AudioStream:
	var key := path + str(loop)
	if _cache.has(key):
		return _cache[key]
	if not ResourceLoader.exists(path):
		push_warning("Missing audio: " + path)
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		s = s.duplicate()
		s.loop = loop
	_cache[key] = s
	return s

# ---------------------------------------------------------------- volume
func apply_settings() -> void:
	set_bus_volume("Music", GameState.settings["music"])
	set_bus_volume("SFX", GameState.settings["sfx"])
	set_bus_volume("Dialogue", GameState.settings["dialogue"])

func set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(linear, 0.001)))

# ---------------------------------------------------------------- music
## Crossfade to a track: "menu", "intro", "velvet", "tension", "safehouse"
func play_music(track: String, fade: float = 2.0) -> void:
	if track == current_track and _active_music.playing:
		return
	var stream := _load(MUSIC_DIR % track, true)
	if stream == null:
		return
	current_track = track
	var old := _active_music
	var new := _music_b if _active_music == _music_a else _music_a
	_active_music = new
	new.stream = stream
	new.volume_db = -40.0 if fade > 0.0 else 0.0
	new.play()
	if fade > 0.0:
		create_tween().tween_property(new, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE)
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, max(fade, 0.05))
		tw.tween_callback(old.stop)

func stop_music(fade: float = 1.5) -> void:
	current_track = ""
	var p := _active_music
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -40.0, max(fade, 0.05))
	tw.tween_callback(p.stop)

func music_for_district(id: String) -> String:
	var d: Dictionary = Catalog.district(id)
	return d.get("music", "velvet")

# ---------------------------------------------------------------- ambience
func play_ambience(name: String, volume_db: float = -6.0, fade: float = 2.0) -> void:
	if name == current_ambience and _ambience.playing:
		create_tween().tween_property(_ambience, "volume_db", volume_db, fade)
		return
	var s := _load(SFX_DIR % name, true)
	if s == null:
		return
	current_ambience = name
	_ambience.stream = s
	_ambience.volume_db = -40.0
	_ambience.play()
	create_tween().tween_property(_ambience, "volume_db", volume_db, fade)

func stop_ambience(fade: float = 1.5) -> void:
	current_ambience = ""
	var tw := create_tween()
	tw.tween_property(_ambience, "volume_db", -40.0, fade)
	tw.tween_callback(_ambience.stop)

# ---------------------------------------------------------------- sfx
func sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := _load(SFX_DIR % name, false)
	if s == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	_sfx_pool[0].stream = s
	_sfx_pool[0].play()

## Short typewriter blip used by dialogue boxes (Dialogue bus).
func dialogue_blip(pitch: float = 1.0) -> void:
	var s := _load(SFX_DIR % "blip", false)
	if s == null:
		return
	_dialogue.stream = s
	_dialogue.pitch_scale = pitch
	_dialogue.volume_db = -8.0
	_dialogue.play()

func play_dialogue_sound(name: String) -> void:
	var s := _load(SFX_DIR % name, false)
	if s == null:
		return
	_dialogue.stream = s
	_dialogue.pitch_scale = 1.0
	_dialogue.volume_db = 0.0
	_dialogue.play()
