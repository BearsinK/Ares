extends Node
## Hintergrundmusik, komplett im Code erzeugt: ein dunkler Industrie-Loop in a-Moll
## (Bass, Kick, Snare, Hi-Hat) plus eine zweite Ebene mit Arpeggio, die mit der
## Spannung (Welle, Boss) lauter wird. Die Ebenen werden beim Start Stueck fuer
## Stueck berechnet, damit das Spiel nicht haengt.

const RATE := 22050
const STEP := 3000
const STEPS := 128
const TOTAL := STEP * STEPS
const BASE_DB := -17.0
const EVENTS_PER_FRAME := 14

const ROOTS := [55.0, 55.0, 43.65, 49.0, 55.0, 55.0, 43.65, 41.2]
const TRIADS := [
	[440.0, 523.25, 659.25], [440.0, 523.25, 659.25], [349.23, 440.0, 523.25], [392.0, 493.88, 587.33],
	[440.0, 523.25, 659.25], [440.0, 523.25, 659.25], [349.23, 440.0, 523.25], [329.63, 415.3, 493.88],
]
const BASS_STEPS := [0, 3, 6, 8, 11, 14]

var ready_to_play := false
var layer_level := 0.3

var _base_player: AudioStreamPlayer
var _layer_player: AudioStreamPlayer
var _base := PackedFloat32Array()
var _layer := PackedFloat32Array()
var _events: Array = []
var _cursor := 0
var _noise_seed := 12345
## Tonhoehe der Musik je nach Karte und Kampf (1 = normal), wird weich ueberblendet.
var mood := 1.0
var _mood_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_base_player = AudioStreamPlayer.new()
	_layer_player = AudioStreamPlayer.new()
	add_child(_base_player)
	add_child(_layer_player)
	_base.resize(TOTAL)
	_layer.resize(TOTAL)
	_plan_events()


## Berechnet beide Ebenen sofort (fuer Werkzeuge und Tests, ohne Audio-Ausgabe).
func render_all() -> void:
	_base.resize(TOTAL)
	_layer.resize(TOTAL)
	_plan_events()
	for event in _events:
		_render(event)
	_normalize(_base)
	_normalize(_layer)


func save_wav(path: String, mixed := true) -> void:
	var data := PackedFloat32Array()
	data.resize(TOTAL)
	for i in TOTAL:
		data[i] = _base[i] * 0.7 + (_layer[i] * 0.4 if mixed else 0.0)
	var stream := _make_stream(data)
	stream.save_to_wav(path)


## Stimmung: leicht tiefer und langsamer (unter 1) oder schneller und heller (ueber 1), blendet ueber zwei Sekunden.
func set_mood(pitch: float) -> void:
	pitch = clampf(pitch, 0.8, 1.2)
	if is_equal_approx(pitch, mood):
		return
	mood = pitch
	if _base_player == null:
		return
	if _mood_tween != null:
		_mood_tween.kill()
	_mood_tween = create_tween().set_parallel(true)
	_mood_tween.set_ignore_time_scale(true)
	_mood_tween.tween_property(_base_player, "pitch_scale", pitch, 2.0)
	_mood_tween.tween_property(_layer_player, "pitch_scale", pitch, 2.0)


## Uebernimmt die gespeicherte Lautstaerke (nach Aenderung in den Optionen).
func apply_settings() -> void:
	_apply_volume()


## Spannung 0..1: laesst die zweite Ebene lauter werden.
func set_layer_level(level: float) -> void:
	var clamped := clampf(level, 0.0, 1.0)
	if is_equal_approx(clamped, layer_level):
		return
	layer_level = clamped
	_apply_volume()


func _apply_volume() -> void:
	if _base_player == null:
		return
	var gain := SaveData.gain_db("music")
	var audible := gain > -79.0
	_base_player.volume_db = BASE_DB + gain if audible else -80.0
	_layer_player.volume_db = (BASE_DB + gain - 14.0 * (1.0 - layer_level)) if audible and layer_level > 0.02 else -80.0


# ---------------------------------------------------------------- Berechnung

func _plan_events() -> void:
	_events.clear()
	for step in STEPS:
		var bar := step / 16
		var in_bar := step % 16
		if in_bar % 4 == 0:
			_events.append(["kick", step, 0.0])
		if in_bar == 4 or in_bar == 12:
			_events.append(["snare", step, 0.0])
		if in_bar % 2 == 0:
			_events.append(["hat", step, 0.0])
		elif in_bar % 4 == 3:
			_events.append(["hat", step, 0.0])
		if in_bar in BASS_STEPS:
			var octave := 2.0 if in_bar == 8 or in_bar == 14 else 1.0
			_events.append(["bass", step, float(ROOTS[bar]) * octave])
		var triad: Array = TRIADS[bar]
		var tone := float(triad[[0, 1, 2, 1][in_bar % 4]])
		if in_bar % 8 >= 6:
			tone *= 2.0
		_events.append(["arp", step, tone])
		if in_bar == 0:
			_events.append(["bell", step, float(triad[0]) * 2.0])


func _process(_delta: float) -> void:
	if ready_to_play:
		return
	var done := 0
	while done < EVENTS_PER_FRAME and _cursor < _events.size():
		_render(_events[_cursor])
		_cursor += 1
		done += 1
	if _cursor >= _events.size():
		_finish()


func _finish() -> void:
	_normalize(_base)
	_normalize(_layer)
	_base_player.stream = _make_stream(_base)
	_layer_player.stream = _make_stream(_layer)
	ready_to_play = true
	_apply_volume()
	_base_player.play()
	_layer_player.play()
	set_process(false)


func _normalize(buffer: PackedFloat32Array) -> void:
	var peak := 0.001
	for i in buffer.size():
		peak = maxf(peak, absf(buffer[i]))
	var gain := 0.85 / peak
	for i in buffer.size():
		buffer[i] *= gain


func _make_stream(buffer: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buffer.size() * 2)
	for i in buffer.size():
		bytes.encode_s16(i * 2, int(clampf(buffer[i], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = buffer.size()
	return stream


func _noise() -> float:
	_noise_seed = (_noise_seed * 1103515245 + 12345) & 0x7fffffff
	return float(_noise_seed) / 1073741823.5 - 1.0


## Addiert eine Stimme ab dem Schritt in den Puffer (laeuft am Ende zum Anfang weiter).
func _render(event: Array) -> void:
	var kind: String = event[0]
	var start: int = int(event[1]) * STEP
	var freq: float = event[2]
	var length := 0
	match kind:
		"kick":
			length = 4000
		"snare":
			length = 3200
		"hat":
			length = 1200
		"bass":
			length = 5500
		"arp":
			length = 4200
		"bell":
			length = 12000
	var phase := 0.0
	var previous := 0.0
	for n in length:
		var t := float(n) / RATE
		var value := 0.0
		match kind:
			"kick":
				phase += TAU * (45.0 + 110.0 * exp(-t * 35.0)) / RATE
				value = sin(phase) * exp(-t * 14.0) * 0.9
			"snare":
				value = (_noise() * 0.55 + sin(TAU * 185.0 * t) * 0.35) * exp(-t * 22.0)
			"hat":
				var noise := _noise()
				value = (noise - previous) * 0.5 * exp(-t * 90.0) * 0.5
				previous = noise
			"bass":
				phase += TAU * freq / RATE
				var envelope := minf(t * 400.0, 1.0) * exp(-t * 5.0)
				value = (sin(phase) + 0.5 * sin(phase * 2.0) + 0.28 * sin(phase * 3.0)) * envelope * 0.4
			"arp":
				phase += TAU * freq / RATE
				value = asin(sin(phase)) * (2.0 / PI) * exp(-t * 9.0) * 0.5
			"bell":
				phase += TAU * freq / RATE
				value = (sin(phase) + 0.4 * sin(phase * 2.01)) * exp(-t * 3.5) * 0.4
		var index := (start + n) % TOTAL
		if kind == "arp" or kind == "bell":
			_layer[index] += value
		else:
			_base[index] += value
