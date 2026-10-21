extends Node
## Test der Klaenge: Jeder im Code verwendete Sound-Name existiert, die Klaenge sind nicht leer
## und uebersteuern nicht.
## Ausfuehren: godot --headless --path . res://tests/sound_test.tscn

var failures := 0


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK    ", message)
	else:
		print("FEHLER ", message)
		failures += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var streams: Dictionary = Sfx._streams
	_check(streams.size() >= 50, "Klangtabelle ist gefuellt (%d Klaenge)" % streams.size())
	for name in ["chest_open", "deny", "altar_blood", "altar_chance", "altar_lose", "item", "guardian", "heal", "fuse", "contract", "gate", "count", "go", "fanfare"]:
		var stream: AudioStreamWAV = streams.get(name)
		_check(stream != null and stream.data.size() > 2000, "Klang %s ist vorhanden und nicht leer" % name)
		if stream != null:
			var peak := 0
			for i in range(0, stream.data.size(), 2):
				peak = maxi(peak, absi(stream.data.decode_s16(i)))
			_check(peak > 3000 and peak < 32767, "Klang %s ist hoerbar und uebersteuert nicht (Spitze %d)" % [name, peak])
	# Alle Sfx.play("name")-Aufrufe im Code muessen einen vorhandenen Klang meinen.
	var regex := RegEx.new()
	regex.compile("Sfx\\.play\\(\"([a-z_]+)\"")
	var missing: Array[String] = []
	var checked := 0
	for path in _scripts("res://scripts"):
		var text := FileAccess.get_file_as_string(path)
		for hit in regex.search_all(text):
			checked += 1
			var sound := hit.get_string(1)
			if not streams.has(sound) and not missing.has("%s (%s)" % [sound, path.get_file()]):
				missing.append("%s (%s)" % [sound, path.get_file()])
	_check(checked > 100, "Aufrufe im Code gefunden (%d)" % checked)
	_check(missing.is_empty(), "Alle verwendeten Klaenge existieren (fehlend: %s)" % ", ".join(missing))
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for file in dir.get_files():
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	for sub_dir in dir.get_directories():
		found.append_array(_scripts(dir_path.path_join(sub_dir)))
	return found
