extends Node
## Platzhalter-Sounds, die beim Start im Code erzeugt werden (keine Audiodateien).
## Benutzung: Sfx.play("shoot")

const MIX_RATE := 22050
const POOL_SIZE := 16
const BASE_DB := -6.0

## Lautstaerke einzelner Sounds (1.0 = unveraendert). Schuesse sind bewusst leiser,
## weil sie staendig vorkommen.
const GAIN := {
	"shoot": 0.4, "shoot_rapid": 0.3, "shoot_heavy": 0.55, "shotgun": 0.55, "rocket": 0.6, "beam": 0.35, "sniper": 0.6,
	"turret": 0.45, "turret_over": 0.45, "can_throw": 0.55, "enemy_shoot": 0.45, "drone": 0.3, "drone_shot": 0.3,
	"hit": 0.55, "kill": 0.7, "shake": 0.6, "pop": 0.6,
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = BASE_DB
		add_child(player)
		_players.append(player)

	_streams["shoot"] = _synth(1100.0, 450.0, 0.07, "square", 0.22, 0.0)
	_streams["shoot_rapid"] = _synth(1700.0, 1000.0, 0.035, "square", 0.18, 0.1)
	_streams["shoot_heavy"] = _synth(500.0, 90.0, 0.22, "saw", 0.35, 0.3)
	_streams["jump"] = _synth(280.0, 620.0, 0.12, "sine", 0.35, 0.0)
	_streams["dash"] = _synth(700.0, 150.0, 0.16, "saw", 0.2, 0.7)
	_streams["hit"] = _synth(260.0, 120.0, 0.07, "square", 0.25, 0.4)
	_streams["shotgun"] = _synth(320.0, 60.0, 0.2, "saw", 0.4, 0.8)
	_streams["rocket"] = _synth(220.0, 80.0, 0.28, "saw", 0.35, 0.5)
	_streams["explosion"] = _synth(130.0, 30.0, 0.5, "saw", 0.5, 0.9)
	_streams["beam"] = _synth(800.0, 720.0, 0.05, "square", 0.12, 0.1)
	_streams["sniper"] = _synth(1500.0, 90.0, 0.28, "saw", 0.4, 0.3)
	_streams["switch"] = _synth(600.0, 900.0, 0.05, "square", 0.2, 0.0)
	_streams["hurt"] = _synth(220.0, 70.0, 0.22, "saw", 0.45, 0.5)
	_streams["revive"] = _synth(300.0, 900.0, 0.3, "sine", 0.4, 0.0)
	_streams["pickup"] = _synth(700.0, 1200.0, 0.06, "sine", 0.18, 0.0)
	_streams["scrap"] = _synth(1500.0, 2100.0, 0.05, "sine", 0.12, 0.1)
	_streams["coin"] = _synth(1100.0, 1700.0, 0.08, "square", 0.15, 0.0)
	_streams["levelup"] = _synth(400.0, 1000.0, 0.4, "square", 0.3, 0.0)
	_streams["telegraph"] = _synth(500.0, 500.0, 0.05, "sine", 0.15, 0.0)
	_streams["enemy_shoot"] = _synth(600.0, 250.0, 0.12, "square", 0.2, 0.2)
	_streams["slam"] = _synth(200.0, 50.0, 0.3, "saw", 0.5, 0.7)
	_streams["steam"] = _synth(900.0, 300.0, 0.3, "saw", 0.3, 0.95)
	_streams["freeze"] = _synth(1600.0, 800.0, 0.2, "sine", 0.3, 0.2)
	_streams["zap"] = _synth(1400.0, 300.0, 0.15, "square", 0.25, 0.5)
	_streams["shake"] = _synth(380.0, 260.0, 0.04, "square", 0.14, 0.7)
	_streams["can_throw"] = _synth(220.0, 520.0, 0.14, "sine", 0.35, 0.1)
	_streams["pop"] = _synth(500.0, 120.0, 0.1, "square", 0.3, 0.5)
	_streams["turret"] = _synth(950.0, 220.0, 0.11, "saw", 0.3, 0.35)
	_streams["turret_over"] = _synth(1250.0, 300.0, 0.08, "saw", 0.3, 0.35)
	_streams["land_heavy"] = _synth(110.0, 38.0, 0.22, "saw", 0.45, 0.6)
	_streams["tread"] = _synth(120.0, 70.0, 0.05, "square", 0.1, 0.7)
	_streams["deploy"] = _synth(320.0, 110.0, 0.09, "saw", 0.28, 0.5)
	_streams["step"] = _synth(1000.0, 520.0, 0.03, "square", 0.07, 0.5)
	_streams["glide"] = _synth(260.0, 200.0, 0.05, "sine", 0.08, 0.6)
	_streams["land"] = _synth(170.0, 60.0, 0.09, "sine", 0.3, 0.3)
	_streams["ability"] = _synth(200.0, 700.0, 0.3, "saw", 0.35, 0.3)
	_streams["ready"] = _synth(900.0, 1300.0, 0.08, "sine", 0.2, 0.0)
	_streams["suck"] = _synth(150.0, 420.0, 0.25, "sine", 0.3, 0.4)
	_streams["drone_shot"] = _synth(1000.0, 600.0, 0.05, "sine", 0.25, 0.1)
	_streams["drone"] = _synth(1300.0, 700.0, 0.07, "square", 0.14, 0.2)
	_streams["kill"] = _synth(300.0, 40.0, 0.35, "saw", 0.4, 0.6)
	_make_event_sounds()


## Klaenge fuer Ereignisse der Karte und der Menues (mehrschichtig, jeweils mit eigenem Charakter).
func _make_event_sounds() -> void:
	# Kiste auf: kurzer Klick, dann drei aufsteigende Glockentoene.
	_streams["chest_open"] = _layers([
		[900.0, 300.0, 0.04, "square", 0.2, 0.8, 0.0],
		[660.0, 660.0, 0.16, "sine", 0.28, 0.0, 0.03], [880.0, 880.0, 0.16, "sine", 0.28, 0.0, 0.09], [1320.0, 1320.0, 0.3, "sine", 0.3, 0.0, 0.15],
	])
	# Abgelehnt (zu wenig Gold, nicht moeglich): zwei tiefe, kurze Brummer.
	_streams["deny"] = _layers([[190.0, 160.0, 0.08, "square", 0.22, 0.1, 0.0], [170.0, 140.0, 0.1, "square", 0.22, 0.1, 0.1]])
	# Blutaltar: zwei dumpfe Herzschlaege und ein tiefes Grollen.
	_streams["altar_blood"] = _layers([
		[110.0, 45.0, 0.14, "sine", 0.55, 0.1, 0.0], [100.0, 40.0, 0.18, "sine", 0.55, 0.1, 0.17],
		[140.0, 60.0, 0.45, "saw", 0.22, 0.4, 0.0],
	])
	# Gluecksaltar: schnelles Klingeln wie ein Spielautomat.
	_streams["altar_chance"] = _layers([[1000.0, 1000.0, 0.05, "square", 0.14, 0.0, 0.0], [1250.0, 1250.0, 0.05, "square", 0.14, 0.0, 0.06], [1500.0, 1500.0, 0.05, "square", 0.14, 0.0, 0.12], [1800.0, 1800.0, 0.12, "square", 0.14, 0.0, 0.18]])
	# Niete: absteigendes Wah-Wah.
	_streams["altar_lose"] = _layers([[420.0, 260.0, 0.2, "saw", 0.28, 0.1, 0.0], [330.0, 150.0, 0.34, "saw", 0.28, 0.1, 0.2]])
	# Item erhalten: kurzes Funkeln nach oben.
	_streams["item"] = _layers([[1300.0, 1300.0, 0.07, "sine", 0.2, 0.0, 0.0], [1650.0, 1650.0, 0.07, "sine", 0.2, 0.0, 0.05], [2000.0, 2000.0, 0.07, "sine", 0.2, 0.0, 0.1], [2600.0, 2600.0, 0.22, "sine", 0.2, 0.0, 0.15]])
	# Waechter erscheint: tiefes Horn mit Grollen, schwillt an.
	_streams["guardian"] = _layers([
		[98.0, 92.0, 1.0, "saw", 0.34, 0.05, 0.0, "swell"], [147.0, 138.0, 1.0, "saw", 0.2, 0.05, 0.0, "swell"],
		[60.0, 45.0, 1.0, "square", 0.2, 0.5, 0.0, "swell"],
	])
	# Medic heilt: weiches Doppelsignal nach oben.
	_streams["heal"] = _layers([[520.0, 780.0, 0.14, "sine", 0.26, 0.0, 0.0], [780.0, 1040.0, 0.2, "sine", 0.24, 0.0, 0.1]])
	# Sprengi zuendet: schnelle Pieptoene.
	_streams["fuse"] = _layers([[1900.0, 1900.0, 0.035, "square", 0.16, 0.0, 0.0], [1900.0, 1900.0, 0.035, "square", 0.16, 0.0, 0.08], [2200.0, 2200.0, 0.035, "square", 0.16, 0.0, 0.16], [2500.0, 2500.0, 0.05, "square", 0.16, 0.0, 0.22]])
	# Vertrag besiegelt: dumpfer Stempel und metallisches Klacken.
	_streams["contract"] = _layers([[140.0, 50.0, 0.16, "sine", 0.55, 0.2, 0.0], [1500.0, 900.0, 0.05, "square", 0.2, 0.4, 0.1], [700.0, 300.0, 0.18, "saw", 0.18, 0.5, 0.1]])
	# Tore: Rumpeln, das anschwillt (der Aufprall kommt als land_heavy).
	_streams["gate"] = _layers([[90.0, 60.0, 0.7, "saw", 0.3, 0.6, 0.0, "swell"], [220.0, 110.0, 0.7, "saw", 0.12, 0.8, 0.0, "swell"]])
	# Wellenstart: Zaehlton und Startsignal.
	_streams["count"] = _layers([[660.0, 660.0, 0.1, "sine", 0.3, 0.0, 0.0]])
	_streams["go"] = _layers([[880.0, 880.0, 0.1, "square", 0.22, 0.0, 0.0], [1320.0, 1320.0, 0.28, "square", 0.24, 0.0, 0.1]])
	# Welle geschafft: kurze Fanfare.
	_streams["fanfare"] = _layers([
		[523.0, 523.0, 0.12, "square", 0.2, 0.0, 0.0], [659.0, 659.0, 0.12, "square", 0.2, 0.0, 0.11], [784.0, 784.0, 0.12, "square", 0.2, 0.0, 0.22],
		[1046.0, 1046.0, 0.4, "square", 0.22, 0.0, 0.33], [523.0, 523.0, 0.4, "sine", 0.2, 0.0, 0.33],
	])


## Spielt einen Sound ab. Gleiche Sounds werden leicht gedrosselt, damit
## Salven nicht zu einem Rauschen werden.
func play(sound: String, pitch_variation := 0.1) -> void:
	if not _streams.has(sound):
		return
	var gain := SaveData.gain_db("sfx")
	if gain <= -79.0:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 30:
		return
	_last_played[sound] = now
	var player := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.volume_db = BASE_DB + gain
	player.stream = _streams[sound]
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


## Ein einzelner Ton (Frequenz gleitet von freq_start nach freq_end, abklingende Huellkurve).
func _synth(freq_start: float, freq_end: float, duration: float, wave: String, volume: float, noise: float) -> AudioStreamWAV:
	return _layers([[freq_start, freq_end, duration, wave, volume, noise, 0.0]])


## Mehrere Toene, die zeitversetzt in einen Klang gemischt werden. Jeder Ton:
## [freq_start, freq_end, duration, wave, volume, noise, start_delay, envelope]
## envelope: "decay" (Standard, klingt aus), "swell" (schwillt an und ab, fuer Hoerner und Rumpeln).
func _layers(parts: Array) -> AudioStreamWAV:
	var total := 0.0
	for part in parts:
		total = maxf(total, float(part[6]) + float(part[2]))
	var count := int(MIX_RATE * total)
	var mix := PackedFloat32Array()
	mix.resize(count)
	for part in parts:
		var begin := int(MIX_RATE * float(part[6]))
		var length := int(MIX_RATE * float(part[2]))
		var wave: String = part[3]
		var envelope_kind: String = part[7] if part.size() > 7 else "decay"
		var phase := 0.0
		for i in length:
			var t := float(i) / length
			phase += lerpf(float(part[0]), float(part[1]), t) / MIX_RATE
			var cycle := fposmod(phase, 1.0)
			var sample := 0.0
			match wave:
				"square":
					sample = 1.0 if cycle < 0.5 else -1.0
				"saw":
					sample = cycle * 2.0 - 1.0
				_:
					sample = sin(cycle * TAU)
			sample = lerpf(sample, randf_range(-1.0, 1.0), float(part[5]))
			var envelope := sin(t * PI) if envelope_kind == "swell" else pow(1.0 - t, 2.0)
			if begin + i < count:
				mix[begin + i] += sample * envelope * float(part[4])
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
