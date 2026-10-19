extends Node
## Platzhalter-Sounds, die beim Start im Code erzeugt werden (keine Audiodateien).
## Benutzung: Sfx.play("shoot")

const MIX_RATE := 22050
const POOL_SIZE := 16

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = -6.0
		add_child(player)
		_players.append(player)

	_streams["shoot"] = _synth(1100.0, 450.0, 0.07, "square", 0.22, 0.0)
	_streams["shoot_heavy"] = _synth(500.0, 90.0, 0.22, "saw", 0.35, 0.3)
	_streams["jump"] = _synth(280.0, 620.0, 0.12, "sine", 0.35, 0.0)
	_streams["dash"] = _synth(700.0, 150.0, 0.16, "saw", 0.2, 0.7)
	_streams["hit"] = _synth(260.0, 120.0, 0.07, "square", 0.25, 0.4)
	_streams["kill"] = _synth(300.0, 40.0, 0.35, "saw", 0.4, 0.6)


## Spielt einen Sound ab. Gleiche Sounds werden leicht gedrosselt, damit
## Salven nicht zu einem Rauschen werden.
func play(sound: String, pitch_variation := 0.1) -> void:
	if not _streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 30:
		return
	_last_played[sound] = now
	var player := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _streams[sound]
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func _synth(freq_start: float, freq_end: float, duration: float, wave: String, volume: float, noise: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var freq := lerpf(freq_start, freq_end, t)
		phase += freq / MIX_RATE
		var cycle := fposmod(phase, 1.0)
		var sample := 0.0
		match wave:
			"square":
				sample = 1.0 if cycle < 0.5 else -1.0
			"saw":
				sample = cycle * 2.0 - 1.0
			_:
				sample = sin(cycle * TAU)
		sample = lerpf(sample, randf_range(-1.0, 1.0), noise)
		var envelope := pow(1.0 - t, 2.0)
		data.encode_s16(i * 2, int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
