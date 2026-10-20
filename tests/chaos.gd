extends Node
## Entwickler-Werkzeug (nicht Teil der Testsuite): Zufallseingaben fuer beide Spieler bei
## unverwundbaren Robotern. Sucht Abstuerze, NaN-Positionen und Spieler, die aus der Arena fallen.
## Ausfuehren: CHAOS_CLASSES=roomba,hexapod CHAOS_SECONDS=120 CHAOS_BOSS=1 godot --headless --path . res://tests/chaos.tscn

const ACTIONS := ["left", "right", "up", "down", "jump", "dash", "fire", "ability", "hook", "weapon", "interact"]

var main: Node
var seconds := 120.0
var _elapsed := 0.0
var _next_change := [0.0, 0.0]
var _held: Array = [[], []]
var _problems := {}
var _last_wave := 0
var _trail: Array = []
var _trail_timer := 0.0
var _trail_printed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var classes := OS.get_environment("CHAOS_CLASSES")
	Engine.set_meta("classes", classes.split(",") if classes != "" else ["roomba", "hexapod"])
	if OS.get_environment("CHAOS_SECONDS") != "":
		seconds = float(OS.get_environment("CHAOS_SECONDS"))
	main = load("res://scenes/main.tscn").instantiate()
	main.test_loadout = OS.get_environment("CHAOS_BOSS") != ""
	add_child(main)
	if OS.get_environment("CHAOS_BOSS") != "":
		_boss.call_deferred()
	print("Chaos: ", Engine.get_meta("classes"), " ", seconds, " s")


func _boss() -> void:
	for i in 20:
		await get_tree().physics_frame
	main.wave = main.max_waves
	main._start_boss()


func _note(key: String) -> void:
	if not _trail_printed and key.begins_with("ausserhalb"):
		_trail_printed = true
		print("SPUR vor dem Absturz:")
		for line in _trail:
			print("  ", line)
	if not _problems.has(key):
		_problems[key] = 0
		print("PROBLEM ", key, " bei ", snappedf(_elapsed, 0.1), " s")
	_problems[key] += 1


func _physics_process(delta: float) -> void:
	Engine.time_scale = 6.0
	_elapsed += delta
	if _elapsed > seconds or main.game_over or main.phase == main.Phase.VICTORY:
		print("Ende nach ", snappedf(_elapsed, 0.1), " s, Welle ", main.wave, ", Phase ", main.phase, ", Probleme: ", _problems)
		get_tree().quit(1 if not _problems.is_empty() else 0)
		return
	if main.levelup_menu.is_open:
		var menu: LevelUpMenu = main.levelup_menu
		menu._finish(menu.perk_ids[randi() % menu.perk_ids.size()])
		return
	if main.contract_menu.is_open:
		var contracts: ContractMenu = main.contract_menu
		contracts._finish(contracts.perk_ids[randi() % contracts.perk_ids.size()])
		return
	if main.shop_menu.is_open:
		main.shop_menu._finish()
		return
	# Spur der letzten Sekunden, damit ein Absturz nachvollziehbar ist.
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.25 * Engine.time_scale
		var stage_id: String = String(main.stage_layout.get("id", "-")) if not main.stage_layout.is_empty() else "-"
		_trail.append("t=%d %s w%d ph%d P1 %d,%d v%d,%d fl%s cl%s ro%s | P2 %d,%d" % [_elapsed, stage_id, main.wave, main.phase,
			main.players[0].global_position.x, main.players[0].global_position.y, main.players[0].velocity.x, main.players[0].velocity.y,
			str(main.players[0].is_on_floor())[0], str(main.players[0].is_clinging())[0], str(main.players[0].on_rope)[0],
			main.players[1].global_position.x, main.players[1].global_position.y])
		if _trail.size() > 40:
			_trail.pop_front()
	if main.wave != _last_wave:
		_last_wave = main.wave
		print("Welle ", main.wave, " Zeit ", snappedf(_elapsed, 1.0))
	for i in 2:
		var player: Player = main.players[i]
		if not is_finite(player.global_position.x) or not is_finite(player.global_position.y) or not is_finite(player.velocity.x):
			_note("NaN P%d" % (i + 1))
		var p := player.global_position
		if p.x < -60.0 or p.x > main.arena_size.x + 60.0 or p.y < -200.0 or p.y > main.arena_size.y + 200.0:
			_note("ausserhalb P%d bei %d,%d" % [i + 1, p.x, p.y])
		if main.phase != main.Phase.BOSS or OS.get_environment("CHAOS_GOD") != "":
			player.hp = player.max_health()
		_next_change[i] -= delta
		if _next_change[i] <= 0.0:
			_next_change[i] = randf_range(0.1, 0.6)
			for action in _held[i]:
				Input.action_release("p%d_%s" % [i + 1, action])
			_held[i] = []
			for action in ACTIONS:
				if randf() < (0.5 if action in ["fire", "left", "right"] else 0.18):
					_held[i].append(action)
					Input.action_press("p%d_%s" % [i + 1, action])
			var aim := Vector2.from_angle(randf() * TAU)
			Input.action_press("p%d_aim_right" % (i + 1), maxf(aim.x, 0.0))
			Input.action_press("p%d_aim_left" % (i + 1), maxf(-aim.x, 0.0))
			Input.action_press("p%d_aim_down" % (i + 1), maxf(aim.y, 0.0))
			Input.action_press("p%d_aim_up" % (i + 1), maxf(-aim.y, 0.0))
