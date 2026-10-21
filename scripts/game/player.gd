class_name Player
extends CharacterBody2D
## Ein Spieler-Roboter. Steuerung ueber die Aktionen p1_* oder p2_*
## (siehe input_setup.gd). Die Darstellung ist ein Platzhalter aus Formen:
## Koerperform und Farbe zeigen die Klasse, der Rand zeigt den Spieler.

signal fired(player: Player, weapon_id: String, origin: Vector2, direction: Vector2, charge: float)
signal hurt(player: Player, amount: float)
signal went_down(player: Player)
signal revived(player: Player)
## Der Partner hat diesen Spieler per Interagieren wiederbelebt (nicht durch Waechter-Reparatur).
signal rescued(player: Player)
signal slam_landed(player: Player, position: Vector2)
signal heavy_landed(player: Player, strength: float)

const GRAVITY := 2000.0
const FALL_GRAVITY_MULT := 1.35
const JUMP_CUT_GRAVITY_MULT := 2.2
const MAX_FALL_SPEED := 1400.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.1
const DASH_TIME := 0.16
const DASH_SPEED := 1000.0
const DASH_END_MOMENTUM := 1.35
const DASH_IFRAMES := 0.22
const AIM_MEMORY := 0.25
const AIM_THRESHOLD := 0.3
const MOUSE_AIM_TIMEOUT := 3.0
const HIT_IFRAMES := 0.8
const REVIVE_TIME := 3.0
const REVIVE_RANGE := 90.0
const WALL_SLIDE_SPEED := 140.0
const GLIDE_SPEED := 160.0
## Jet Boots: Steiggeschwindigkeit, Beschleunigung und Tankdauer in Sekunden.
const JET_SPEED := 400.0
const JET_ACCEL := 3600.0
const JET_TIME := 0.9
const WALL_JUMP_PUSH := 520.0
const WALL_LOCK_TIME := 0.18
const SLAM_SPEED := 1600.0
const HOOK_RANGE := 650.0
const HOOK_SPEED := 1400.0
const HOOK_COOLDOWN := 0.8
const HOOK_MAX_TIME := 0.7
const DROP_TIME := 0.25
const CLIMB_SPEED := 300.0
## Wie lange die Schiesshaltung nach dem letzten Feuerdruck bleibt (Hexapod: langsamer beim Schiessen).
const STANCE_HOLD := 0.12
## Staerkste Neigung der Zeichnung auf schraegem Boden (rad, etwa 49 Grad).
const SLOPE_MAX := 0.85
# Ebene 8: unsichtbare Waende, die nur Spieler aufhalten (z.B. vor dem Boss), Geschosse fliegen durch.
## Welt, Stege, unsichtbare Begrenzung und die Kisten des Endbosses (Ebene 9, nur Spieler stossen daran).
const WORLD_MASK := (1 << 0) | (1 << 5) | (1 << 7) | (1 << 8)

var player_index := 1
## Wie oft dieser Spieler gedasht hat (fuer den Dash-Hinweis nach dem ersten Treffer).
var dash_count := 0
var class_id := "roomba"
var stats: Dictionary = {}
var aim_dir := Vector2.RIGHT
var facing := 1.0
var iframes := 0.0
var dash_charges := 0
var weapons: Array[String] = []
var weapon_index := 0
# Elementmodul pro Waffe (gleicher Index wie weapons), "" = kein Modul.
var modules: Array[String] = []
var hp := 100.0
var gold := 0
## Summe des verursachten Schadens (nur echter Lebensverlust der Ziele), fuer die Ergebnisanzeige.
var damage_dealt := 0.0
var downed := false
var revive_progress := 0.0
var partner: Player = null
# Bewegungs-Firmware: id -> Anzahl Stapel (siehe Firmware).
var firmware: Dictionary = {}
var hook_active := false
## Sandbox: keine Treffer.
var invulnerable := false
## Seil: Spieler haengt gerade an einem Kletterseil der Karte.
var on_rope := false
var _rope_x := 0.0
var _rope_rect := Rect2()
var _rope_lock := 0.0
const ROPE_SPEED := 270.0
var hook_anchor := Vector2.ZERO
## Schuettel-Aufladung der Dose (0 bis 1), solange Schiessen gehalten wird.
var shake_charge := 0.0
## Zug eines Laufbands in px/s (negativ = nach links), wirkt nur am Boden.
var belt_push := 0.0
## Solange > 0, ist der Spieler verlangsamt (Frostwache).
var slow_time := 0.0
## Anzahl Shop-Kaeufe in diesem Lauf (macht weitere Kaeufe teurer).
var purchases := 0
# Dauerhafte Boni aus Perks und Items (Anteile, ausser max_hp als fester Wert).
var mods := {"damage": 0.0, "fire_rate": 0.0, "speed": 0.0, "max_hp": 0.0, "dmg_taken": 0.0,
	"dash_cd": 0.0, "pickup": 0.0, "gold": 0.0, "ability_cd": 0.0, "crit": 0.0, "kill_heal": 0.0,
	"pierce": 0.0, "death_blast": 0.0, "link": 0.0, "frenzy": 0.0, "arc": 0.0, "dash_blast": 0.0, "thorns": 0.0,
	"rage": 0.0, "shield": 0.0, "recycle": 0.0, "execute": 0.0, "close": 0.0, "far": 0.0,
	# Waffen-Upgrades: Magazin, Nachladen, Projektile, Tempo, Reichweite, Praezision, Explosion, Crit-Schaden, Rueckstoss, Abpraller, Zielsuche, Munitionsersparnis.
	"mag": 0.0, "reload": 0.0, "proj": 0.0, "proj_speed": 0.0, "range": 0.0, "accuracy": 0.0, "blast": 0.0,
	"crit_dmg": 0.0, "knock": 0.0, "bounce": 0.0, "seek": 0.0, "ammo_save": 0.0}
## Persoenliche Items (Shop, Kisten): Perk-Id -> Anzahl. Team-Perks vom Level-Up stehen nicht hier.
var items := {}
## Schild aus Shield Cell: schluckt Schaden, laedt nach einer Weile ohne Treffer wieder auf.
var shield := 0.0
var frenzy_stacks := 0
var _frenzy_time := 0.0
var _since_hit := 99.0
## Munition im Magazin je Waffenplatz (gleicher Index wie weapons). Wird ueber _sync_ammo abgeglichen,
## damit Tests und Shop die Waffenliste frei aendern koennen.
var ammo: Array[int] = []
var _ammo_ids: Array[String] = []
var _ammo_max: Array[int] = []
## Restzeit des laufenden Nachladens je Platz (0 = laedt nicht) und die Gesamtdauer fuer die Anzeige.
var _reload_left: Array[float] = []
var _reload_span: Array[float] = []
var _since_shot := 99.0
var _dry_cooldown := 0.0
var _reload_flash := 0.0
var _burst_left := 0
var _burst_timer := 0.0
## Ein Nachladen im Lauf gilt nur fuer den Spieler, der gerade nicht feuert.
const IDLE_RELOAD := 0.9

var _prefix := "p1_"
var _coyote := 0.0
var _jump_buffer := 0.0
var _air_jumps_left := 0
var _dash_time_left := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_recharge := 0.0
## Jet Boots: Tankfuellung (0 bis 1), ob der Schub gerade laeuft, und Gegner, die der Blade Dash schon getroffen hat.
var _jet_fuel := 1.0
var jet_active := false
var _blade_hit: Array[Node2D] = []
var _jet_timer := 0.0
var _fire_cooldown := 0.0
var _switch_cooldown := 0.0
var _aim_memory := 0.0
var _mouse_timer := 0.0
var _trail_timer := 0.0
var _shine_timer := 0.0
var _channel := 0.0
var _laser_length := 600.0
const LASER_RANGE := 640.0
const LASER_COLORS: Array[Color] = [Color(0.3, 0.95, 1.0), Color(0.65, 1.0, 0.3)]
var _shine_last := Vector2.ZERO
var _wall_lock := 0.0
var _slamming := false
var _hook_time := 0.0
var _hook_cooldown := 0.0
var _drop_time := 0.0
var _lob_charging := false
var _clinging := false
var _cling_dir := 0.0
var _stance_timer := 0.0
var _shake_tick := 0.0
var _art_time := 0.0
var _walk_phase := 0.0
var _fire_flash := 0.0
var _hurt_timer := 0.0
var _happy_timer := 0.0
var _arm_deploy := 0.0
# Animationszustand (siehe _update_juice): Landestauchung, Rueckstoss, Hitze, Aufstellen, Klettern.
var _land_squash := 0.0
var _was_grounded := true
var _fall_speed := 0.0
var _recoil := 0.0
var _heat := 0.0
var _deploy_amount := 0.0
var _deployed_flag := false
var _climb_phase := 0.0
var _step_acc := 0.0
var _cling_amount := 0.0
var _ceiling := false
var _ceiling_amount := 0.0
var _ceiling_cooldown := 0.0
var _coin_flash := 0.0
var _down_amount := 0.0
## Neigung des Koerpers auf schraegem Boden (rad, weich nachgefuehrt) und die Verschiebung, mit der die Fuesse auf der Flaeche bleiben.
var _slope_tilt := 0.0
var _slope_shift := Vector2.ZERO
## Auto-Druck (Printbot): Sekunden bis der naechste Printling fertig ist, und Nachleuchten der Druckkammer nach dem Start eines Dieners.
var _print_timer := 0.0
var _launch_flash := 0.0
var _summon_serial := 0

var ability: Ability


func setup(index: int, new_class_id: String) -> void:
	player_index = index
	class_id = new_class_id
	stats = RobotClasses.get_stats(class_id)
	_prefix = "p%d_" % index
	dash_charges = stats.dash_charges
	hp = stats.max_hp
	mods.pickup = float(stats.get("pickup_bonus", 0.0))
	for weapon_id in stats.weapons:
		weapons.append(weapon_id)
		modules.append("")


func is_clinging() -> bool:
	return _clinging


func fw(firmware_id: String) -> int:
	return int(firmware.get(firmware_id, 0))


func firmware_count() -> int:
	var total := 0
	for id in firmware:
		total += int(firmware[id])
	return total


func add_firmware(firmware_id: String) -> void:
	firmware[firmware_id] = fw(firmware_id) + 1


func dash_max() -> int:
	return int(stats.dash_charges) + fw("dash_charge")


## Absprunggeschwindigkeit mit Spring Legs.
func jump_speed() -> float:
	return float(stats.jump_speed) * (1.0 + Firmware.SPRING_BONUS * float(fw("spring")))


## Dauer eines Dashs in Sekunden (Long Dash verlaengert ihn).
func dash_time() -> float:
	return DASH_TIME * (1.0 + Firmware.LONG_DASH_BONUS * float(fw("long_dash")))


func max_health() -> float:
	return float(stats.max_hp) + float(mods.max_hp)


func move_speed() -> float:
	var slowed := 1.0
	# Dauerstrahl haelt den Schuetzen fest (langsamer, solange er feuert).
	if _channel > 0.05:
		slowed *= float(Weapons.get_weapon(current_weapon_id()).get("slow", 1.0))
	return base_speed() * slowed * fire_move_factor()


## Tempo ohne die Bremse durchs Schiessen (Dash-Schwung, Walze, Eis).
func base_speed() -> float:
	var rolling := 1.7 if ability != null and ability.is_active("roll") else 1.0
	var slowed := 0.6 if slow_time > 0.0 else 1.0
	var rage := Perks.RAGE_SPEED * float(mods.rage) if low_health() else 0.0
	return float(stats.speed) * (1.0 + float(mods.speed) + rage + Firmware.SPRINT_BONUS * float(fw("sprint"))) * rolling * slowed


## Hexapod: beim Schiessen mit der Klassenwaffe nur halbes Tempo (am Boden, an der Wand, an der Decke).
## Overwatch hebt das auf. Weich ueber die Stellung eingeblendet.
func fire_move_factor() -> float:
	var fire_slow := float(stats.get("fire_slow", 1.0))
	if fire_slow >= 1.0 or (ability != null and ability.is_active("overwatch")):
		return 1.0
	return 1.0 - (1.0 - fire_slow) * clampf(_deploy_amount, 0.0, 1.0)


## Feuerrate-Faktor aus Perks und Overwatch.
func fire_rate_mult() -> float:
	var boost := 2.0 if ability != null and ability.is_active("overwatch") else 1.0
	return (1.0 + float(mods.fire_rate) + float(mods.frenzy) * float(frenzy_stacks)) * boost


## Kabelbaum: aktiv, solange der Partner steht und nah genug ist.
func link_active() -> bool:
	return float(mods.link) > 0.0 and not downed and partner != null and not partner.downed \
		and partner.global_position.distance_to(global_position) <= 450.0


func damage_mult() -> float:
	var link := 0.15 * float(mods.link) if link_active() else 0.0
	var rage := Perks.RAGE_DAMAGE * float(mods.rage) if low_health() else 0.0
	return float(stats.damage_mult) * (1.0 + float(mods.damage) + link + rage)


func add_mods(new_mods: Dictionary) -> void:
	for key in new_mods:
		mods[key] = float(mods[key]) + float(new_mods[key])
	if new_mods.has("max_hp") and not downed:
		hp += float(new_mods.max_hp)
	if new_mods.has("shield"):
		shield += float(new_mods.shield)
	if new_mods.has("mag"):
		_sync_ammo()


## Perk als persoenliches Item aufnehmen (Shop, Kiste): Werte der Klassenvariante, mit Zaehler fuers HUD.
func add_item(perk_id: String) -> void:
	add_mods(Perks.mods_for(perk_id, class_id))
	items[perk_id] = int(items.get(perk_id, 0)) + 1


func max_shield() -> float:
	return float(mods.shield)


func low_health() -> bool:
	return float(mods.rage) > 0.0 and not downed and hp <= max_health() * Perks.RAGE_THRESHOLD


## Ein Kill im Team: Frenzy stapelt sich.
func register_kill() -> void:
	if float(mods.frenzy) > 0.0 and not downed:
		frenzy_stacks = mini(Perks.FRENZY_STACKS, frenzy_stacks + 1)
		_frenzy_time = Perks.FRENZY_TIME


## Schadensfaktor eines Treffers auf einen Gegner: Executioner, Close Quarters, Long Shot.
func hit_multiplier(target: Node2D) -> float:
	var factor := 1.0
	if float(mods.execute) > 0.0 and "hp" in target and "max_hp" in target and float(target.hp) < float(target.max_hp) * Perks.EXECUTE_THRESHOLD:
		factor += float(mods.execute)
	var distance := global_position.distance_to(target.global_position)
	if float(mods.close) > 0.0 and distance < Perks.CLOSE_RANGE:
		factor += float(mods.close)
	if float(mods.far) > 0.0 and distance > Perks.FAR_RANGE:
		factor += float(mods.far)
	return factor


## Explosion rund um den Spieler (Dash Blast, Thorns), ueber die Hauptszene.
func _burst(radius: float, damage: float, color: Color) -> void:
	var main := get_parent()
	if main != null and main.has_method("_explode"):
		main._explode(global_position, radius, damage * damage_mult(), self, color, "", 4.0)


## Gibt true zurueck, wenn der Treffer ankam (nicht unverwundbar oder am Boden).
func take_hit(amount: float, from: Vector2) -> bool:
	if downed or iframes > 0.0 or invulnerable:
		return false
	var final_amount := amount * maxf(0.1, 1.0 - float(mods.dmg_taken))
	if ability != null and ability.is_active("roll"):
		final_amount *= 0.5
	# Stellung: Ein schiessender Hexapod steckt Treffer besser weg.
	if float(stats.get("fire_slow", 1.0)) < 1.0 and _deploy_amount > 0.8:
		final_amount *= 0.8
	_since_hit = 0.0
	if shield > 0.0:
		var absorbed := minf(shield, final_amount)
		shield -= absorbed
		final_amount -= absorbed
		if final_amount <= 0.0:
			# Der Schild hat alles geschluckt: kurze Schutzzeit, kein Treffer-Effekt am Koerper.
			iframes = HIT_IFRAMES * 0.6
			Sfx.play("freeze", 0.05)
			if Fx.instance:
				Fx.instance.ring(global_position, maxf(stats.size.x, stats.size.y) * 0.5 + 14.0, Color(0.5, 0.85, 1.0))
			return true
	hp -= final_amount
	iframes = HIT_IFRAMES
	_hurt_timer = 0.45
	var away := (global_position - from).normalized()
	var push := 1.0 - float(stats.get("knockback_resist", 0.0))
	velocity += Vector2(away.x * 320.0, -260.0) * push
	Sfx.play("hurt")
	InputSetup.rumble(player_index, 0.3, clampf(0.3 + final_amount / 40.0, 0.3, 1.0), 0.25)
	hurt.emit(self, final_amount)
	if float(mods.thorns) > 0.0 and hp > 0.0:
		_burst(Perks.THORNS_RADIUS, Perks.THORNS_DAMAGE * float(mods.thorns), Color(1.0, 0.5, 0.35))
	if hp <= 0.0:
		hp = 0.0
		downed = true
		_ceiling = false
		_clinging = false
		on_rope = false
		_dash_time_left = 0.0
		_slamming = false
		if hook_active:
			_release_hook()
		revive_progress = 0.0
		shake_charge = 0.0
		_lob_charging = false
		_burst_left = 0
		velocity = Vector2(velocity.x * 0.3, velocity.y)
		InputSetup.rumble(player_index, 0.6, 1.0, 0.6)
		went_down.emit(self)
	return true


## Setzt den Spieler an einen neuen Ort (Kartenwechsel) und beendet alles, was ihn gerade bewegt.
func teleport(pos: Vector2) -> void:
	_burst_left = 0
	global_position = pos
	velocity = Vector2.ZERO
	if hook_active:
		_release_hook()
	_dash_time_left = 0.0
	on_rope = false
	_clinging = false
	_ceiling = false
	_slamming = false


## Freiwilliger Preis in Leben (Blutaltar): kein Treffer, kein Iframe, aber das Panel blitzt kurz rot auf. Laesst mindestens 1 Leben.
func pay_health(amount: float) -> void:
	hp = maxf(1.0, hp - amount)
	_hurt_timer = 0.3


func revive(health_fraction := 0.5) -> void:
	downed = false
	revive_progress = 0.0
	hp = max_health() * health_fraction
	iframes = 1.5
	_happy_timer = 1.5
	Sfx.play("revive")
	revived.emit(self)


func _process_downed(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	move_and_slide()
	# Der Partner belebt durch Halten von Interagieren in der Naehe.
	var reviving := false
	if partner != null and not partner.downed:
		var close := partner.global_position.distance_to(global_position) <= REVIVE_RANGE
		reviving = close and Input.is_action_pressed(partner._prefix + "interact")
	if reviving:
		revive_progress += delta / REVIVE_TIME
		if revive_progress >= 1.0:
			revive()
			rescued.emit(self)
	else:
		revive_progress = maxf(0.0, revive_progress - delta * 0.5)


func _ready() -> void:
	collision_layer = 1 << 1
	# Spieler kollidieren nur mit der Welt, nicht mit Gegnern oder dem Partner.
	collision_mask = WORLD_MASK
	floor_snap_length = 8.0
	ability = Ability.new()
	add_child(ability)
	ability.setup(self)
	if bool(stats.get("summoner", false)):
		_print_timer = float(Minions.AUTO_PRINT.interval)
		_start_minions.call_deferred()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = stats.size
	shape.shape = rect
	add_child(shape)


func _input(event: InputEvent) -> void:
	# Nur Spieler 1 kann mit der Maus zielen.
	if player_index == 1 and event is InputEventMouseMotion:
		_mouse_timer = MOUSE_AIM_TIMEOUT


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	if downed:
		_process_downed(delta)
		_update_juice(delta)
		queue_redraw()
		return
	_update_aim(delta)
	_update_laser()

	var move := Input.get_axis(_prefix + "left", _prefix + "right")
	if absf(move) > 0.1:
		facing = signf(move)

	if Input.is_action_just_pressed(_prefix + "jump"):
		_jump_buffer = JUMP_BUFFER_TIME
	if Input.is_action_just_pressed(_prefix + "dash"):
		_try_dash()
	if Input.is_action_just_pressed(_prefix + "ability"):
		ability.try_use()
	if Input.is_action_just_pressed(_prefix + "hook"):
		if hook_active:
			_release_hook()
		else:
			_try_hook()

	if hook_active:
		_process_hook(delta)
	elif _dash_time_left > 0.0:
		_process_dash(delta)
	else:
		_process_movement(delta, move)

	move_and_slide()
	if belt_push != 0.0 and is_on_floor():
		move_and_collide(Vector2(belt_push * delta, 0.0))
	_update_juice(delta)
	_handle_fire(delta)
	queue_redraw()


## Kurzes Aufleuchten (Muenzschlitz des Automaten) beim Einsammeln von Gold.
## 1 direkt nach einem Treffer, faellt auf 0 ab (fuer Roboter und HUD-Anzeige).
func hurt_amount() -> float:
	return clampf(_hurt_timer / 0.45, 0.0, 1.0)


func gold_flash() -> void:
	_coin_flash = 1.0


## Schiesshaltung des Hexapods: er schiesst gerade mit dem Geschuetz (Beine spreizen sich, er geht langsamer).
func is_deployed() -> bool:
	return float(stats.get("fire_slow", 1.0)) < 1.0 and _stance_timer > 0.0 and not downed


## Staub am Boden unter dem Spieler.
func _puff(offset: Vector2, count: int, speed := 110.0) -> void:
	if Fx.instance:
		Fx.instance.spark(global_position + offset, Color(0.75, 0.77, 0.82, 0.75), count, speed)


## Auf schraegem Boden stellt sich der Koerper parallel zur Flaeche. Die Kollisionsbox bleibt gerade und liegt mit einer
## Ecke auf, deshalb wird die Zeichnung um die Differenz zur Flaeche hin verschoben.
func _update_slope(grounded: bool, delta: float) -> void:
	var tilt_target := 0.0
	var shift_target := Vector2.ZERO
	if grounded and not _clinging and not _ceiling and not on_rope and not downed and not _slamming:
		var normal := get_floor_normal()
		tilt_target = clampf(atan2(normal.x, -normal.y), -SLOPE_MAX, SLOPE_MAX)
		var half: Vector2 = Vector2(stats.size) * 0.5
		var lift := half.y * cos(tilt_target) + half.x * absf(sin(tilt_target)) - half.y
		shift_target = -normal * lift
	var follow := 1.0 - exp(-14.0 * delta)
	_slope_tilt = lerpf(_slope_tilt, tilt_target, follow)
	_slope_shift = _slope_shift.lerp(shift_target, follow)
	if absf(_slope_tilt) < 0.002 and tilt_target == 0.0:
		_slope_tilt = 0.0
		_slope_shift = Vector2.ZERO


## Rein optische Zustaende: Landen, Aufstellen, Rueckstoss, Hitze, Klettern, Schritte.
func _update_juice(delta: float) -> void:
	var grounded := is_on_floor()
	if not grounded:
		_fall_speed = maxf(_fall_speed, velocity.y)
	elif not _was_grounded and _fall_speed > 260.0 and not _clinging:
		_land_squash = clampf(_fall_speed / 900.0, 0.25, 1.0)
		_puff(Vector2(0.0, float(stats.size.y) * 0.5), 4 + int(4.0 * _land_squash), 140.0)
		if bool(stats.get("heavy", false)) and _fall_speed > 550.0:
			# Schwere Klassen lassen beim harten Aufprall den Boden beben.
			_puff(Vector2(-22.0, float(stats.size.y) * 0.5), 4, 170.0)
			_puff(Vector2(22.0, float(stats.size.y) * 0.5), 4, 170.0)
			Sfx.play("land_heavy", 0.1)
			heavy_landed.emit(self, _land_squash)
		else:
			Sfx.play("land", 0.15)
	if grounded:
		_fall_speed = 0.0
	_was_grounded = grounded
	_update_slope(grounded, delta)
	_land_squash = move_toward(_land_squash, 0.0, delta * 5.0)
	_recoil = maxf(0.0, _recoil - delta * 9.0)
	_coin_flash = maxf(0.0, _coin_flash - delta * 2.0)
	_heat = maxf(0.0, _heat - delta * 0.45)

	var planted := is_deployed()
	_deploy_amount = move_toward(_deploy_amount, 1.0 if planted else 0.0, delta * (8.0 if planted else 5.0))
	if planted and not _deployed_flag:
		_deployed_flag = true
		if grounded:
			_puff(Vector2(-18.0, float(stats.size.y) * 0.5), 2, 80.0)
			_puff(Vector2(18.0, float(stats.size.y) * 0.5), 2, 80.0)
	elif not planted and _deployed_flag:
		_deployed_flag = false

	_cling_amount = move_toward(_cling_amount, 1.0 if _clinging else 0.0, delta * 7.0)
	_ceiling_amount = move_toward(_ceiling_amount, 1.0 if _ceiling else 0.0, delta * 8.0)
	_down_amount = move_toward(_down_amount, 1.0 if downed else 0.0, delta * (3.0 if downed else 2.2))
	if _clinging:
		_climb_phase += velocity.y * delta * 0.045
	# Roomba: hinter ihm bleibt ein blanker, funkelnder Streifen, weil er sauber macht.
	if bool(stats.get("vacuum", false)) and grounded and not downed and absf(velocity.x) > 50.0:
		_shine_timer -= delta
		var feet := global_position + Vector2(-float(facing) * 30.0, float(stats.size.y) * 0.5)
		if _shine_timer <= 0.0 and Fx.instance:
			_shine_timer = 0.07
			if _shine_last != Vector2.ZERO and _shine_last.distance_to(feet) < 120.0:
				Fx.instance.shine(_shine_last, feet)
			_shine_last = feet
			if randf() < 0.8:
				Fx.instance.glint(feet + Vector2(randf_range(-30.0, 30.0), randf_range(-14.0, -2.0)), randf_range(9.0, 16.0))
	else:
		_shine_last = Vector2.ZERO
	if grounded and not _clinging and absf(velocity.x) > 70.0 and stats.get("step", "") != "":
		_step_acc += absf(velocity.x) * delta
		if _step_acc >= 52.0:
			_step_acc = 0.0
			Sfx.play(String(stats.step), 0.2)
			_puff(Vector2(-facing * 10.0, float(stats.size.y) * 0.5), 1, 60.0)


func _update_timers(delta: float) -> void:
	_update_ammo(delta)
	iframes = maxf(0.0, iframes - delta)
	_since_hit += delta
	if frenzy_stacks > 0:
		_frenzy_time -= delta
		if _frenzy_time <= 0.0:
			frenzy_stacks = 0
	if shield < max_shield() and _since_hit >= Perks.SHIELD_DELAY:
		shield = minf(max_shield(), shield + Perks.SHIELD_RATE * delta)
	slow_time = maxf(0.0, slow_time - delta)
	if link_active() and hp < max_health():
		hp = minf(max_health(), hp + float(mods.link) * delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_mouse_timer = maxf(0.0, _mouse_timer - delta)
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_wall_lock = maxf(0.0, _wall_lock - delta)
	_hook_cooldown = maxf(0.0, _hook_cooldown - delta)
	_drop_time = maxf(0.0, _drop_time - delta)
	collision_mask = ((1 << 0) | (1 << 7) | (1 << 8)) if _drop_time > 0.0 else WORLD_MASK
	_switch_cooldown = maxf(0.0, _switch_cooldown - delta)
	_art_time += delta
	_fire_flash = maxf(0.0, _fire_flash - delta * 6.0)
	_reload_flash = maxf(0.0, _reload_flash - delta * 4.0)
	_update_auto_print(delta)
	if is_on_floor() or on_rope or _clinging or _ceiling:
		_jet_fuel = minf(1.0, _jet_fuel + delta * 2.5)
	# Der Schub endet, sobald etwas anderes die Bewegung uebernimmt (Seil, Wand, Dash, Haken, Ausfall).
	if downed or on_rope or _clinging or _ceiling or _dash_time_left > 0.0 or hook_active:
		jet_active = false
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_happy_timer = maxf(0.0, _happy_timer - delta)
	var arm_target := 1.0 if (Input.is_action_pressed(_prefix + "fire") or _fire_flash > 0.05) and not downed else 0.0
	_arm_deploy = move_toward(_arm_deploy, arm_target, delta * 8.0)
	_walk_phase += velocity.x * facing * delta * 0.12 if is_on_floor() or _clinging or _ceiling else 0.0

	if dash_charges < dash_max():
		_dash_recharge += delta
		if _dash_recharge >= float(stats.dash_cooldown) * (1.0 - float(mods.dash_cd)):
			_dash_recharge = 0.0
			dash_charges += 1
	else:
		_dash_recharge = 0.0



func _update_aim(delta: float) -> void:
	var stick := Input.get_vector(
		_prefix + "aim_left", _prefix + "aim_right",
		_prefix + "aim_up", _prefix + "aim_down")
	if stick.length() > AIM_THRESHOLD:
		aim_dir = stick.normalized()
		_aim_memory = AIM_MEMORY
	elif _aim_memory > 0.0:
		# Aim-Gedaechtnis: Zielrichtung bleibt kurz erhalten, falls der Daumen
		# fuer eine andere Taste den Stick verlaesst.
		_aim_memory -= delta
	elif _mouse_timer > 0.0:
		aim_dir = (get_global_mouse_position() - global_position).normalized()
	else:
		aim_dir = Vector2(facing, 0.0)

	if absf(aim_dir.x) > 0.2:
		facing = signf(aim_dir.x)


func _process_movement(delta: float, move: float) -> void:
	var on_floor := is_on_floor()
	var down := Input.get_axis(_prefix + "up", _prefix + "down")
	var accel: float = stats.accel if on_floor else stats.air_accel

	if _process_rope(delta, move, down):
		return
	if stats.get("wall_climb", false) and _process_ceiling(delta, move, down):
		return
	if stats.get("wall_climb", false) and _process_climb(move, down):
		return
	if _slamming:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
		velocity.y = SLAM_SPEED
		if on_floor:
			_slamming = false
			slam_landed.emit(self, global_position + Vector2(0.0, float(stats.size.y) * 0.5))
		return
	if _wall_lock <= 0.0:
		velocity.x = move_toward(velocity.x, move * move_speed(), accel * delta)

	var solid_normal := _solid_wall_normal()
	var on_wall := is_on_wall_only() and not on_floor and solid_normal != Vector2.ZERO
	var wall_normal := solid_normal if on_wall else Vector2.ZERO
	var pushing_wall := on_wall and move != 0.0 and signf(move) == -signf(wall_normal.x)
	var jump_held := Input.is_action_pressed(_prefix + "jump")

	var gravity := GRAVITY
	if velocity.y > 0.0:
		gravity *= FALL_GRAVITY_MULT
	elif velocity.y < 0.0 and not jump_held:
		gravity *= JUMP_CUT_GRAVITY_MULT
	velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)

	# Wandrutschen und Gleiten bremsen den Fall.
	if velocity.y > 0.0:
		if fw("wall_jump") > 0 and pushing_wall:
			velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
			if randf() < 0.25:
				_puff(Vector2(-wall_normal.x * float(stats.size.x) * 0.5, float(stats.size.y) * 0.3), 1, 50.0)
		elif fw("glide") > 0 and jump_held and not on_floor:
			velocity.y = minf(velocity.y, GLIDE_SPEED)

	# Jet Boots: in der Luft Sprung halten (erst nach dem Scheitelpunkt des Sprungs) schiebt nach oben, solange der Tank reicht.
	var jetting := fw("jet") > 0 and jump_held and not on_floor and (jet_active or velocity.y > -120.0) and _jet_fuel > 0.0
	if jetting:
		velocity.y = move_toward(velocity.y, -JET_SPEED, JET_ACCEL * delta)
		_jet_fuel = maxf(0.0, _jet_fuel - delta / JET_TIME)
		if not jet_active:
			Sfx.play("dash", 0.15)
		_jet_puff(delta)
	jet_active = jetting

	if on_floor:
		_coyote = COYOTE_TIME
		_air_jumps_left = fw("double_jump")
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if _jump_buffer <= 0.0:
		return
	if on_floor and down > 0.6 and _is_on_one_way():
		# Nach unten durch eine Plattform fallen.
		_drop_time = DROP_TIME
		_jump_buffer = 0.0
	elif not on_floor and down > 0.6 and fw("slam") > 0:
		_slamming = true
		_jump_buffer = 0.0
		Sfx.play("slam")
	elif _coyote > 0.0:
		velocity.y = -jump_speed()
		_jump_buffer = 0.0
		_coyote = 0.0
		Sfx.play("jump")
		_puff(Vector2(0.0, float(stats.size.y) * 0.5), 4, 110.0)
	elif on_wall and fw("wall_jump") > 0:
		velocity = Vector2(wall_normal.x * WALL_JUMP_PUSH, -jump_speed() * 0.95)
		facing = signf(wall_normal.x)
		_wall_lock = WALL_LOCK_TIME
		_jump_buffer = 0.0
		Sfx.play("jump")
		_puff(Vector2(-wall_normal.x * float(stats.size.x) * 0.5, 0.0), 5, 130.0)
	elif _air_jumps_left > 0:
		velocity.y = -jump_speed()
		_jump_buffer = 0.0
		_air_jumps_left -= 1
		Sfx.play("jump")
		if Fx.instance:
			Fx.instance.ring(global_position + Vector2(0.0, float(stats.size.y) * 0.5), 34.0, Color(0.8, 0.9, 1.0))


## Wandklettern (Hexapod): Gegen die Wand druecken haelt ihn fest, hoch/runter klettert.
## Gibt true zurueck, wenn die Bewegung dieses Frames damit erledigt ist.
## Unterseite einer Plattform oder der Decke direkt ueber dem Kopf (leer, wenn keine in Reichweite).
func _ceiling_above() -> Dictionary:
	var size: Vector2 = stats.size
	var head_y: float = global_position.y - size.y * 0.5
	for body in get_tree().get_nodes_in_group("ceilings"):
		var rect: Rect2 = body.get_meta("rect")
		var bottom := rect.end.y
		if global_position.x < rect.position.x + 6.0 or global_position.x > rect.end.x - 6.0:
			continue
		# Der Spieler muss unter der Platte sein (Mitte darunter) und der Kopf nahe an der Unterseite.
		if global_position.y > bottom and absf(head_y - bottom) < 24.0:
			return {"y": bottom, "rect": rect}
	return {}


## Deckenklettern (Hexapod): Hoch gedrueckt haelt er sich an der Unterseite fest, laeuft dort
## kopfueber entlang und laesst sich mit Runter oder Sprung fallen.
func _process_ceiling(delta: float, move: float, vertical: float) -> bool:
	_ceiling_cooldown = maxf(0.0, _ceiling_cooldown - delta)
	var info := _ceiling_above()
	if _ceiling:
		if info.is_empty() or vertical > 0.3 or _jump_buffer > 0.0 or _dash_time_left > 0.0:
			_ceiling = false
			_ceiling_cooldown = 0.3
			if _jump_buffer > 0.0:
				_jump_buffer = 0.0
			velocity = Vector2(velocity.x * 0.5, 140.0)
			return false
	elif vertical < -0.4 and _ceiling_cooldown <= 0.0 and not info.is_empty() and velocity.y < 400.0 and _dash_time_left <= 0.0:
		_ceiling = true
		_clinging = false
		_air_jumps_left = fw("double_jump")
		Sfx.play("deploy", 0.05)
		_puff(Vector2(0.0, -float(stats.size.y) * 0.5), 3, 80.0)
	else:
		return false
	global_position.y = float(info.y) + float(stats.size.y) * 0.5 + 1.0
	velocity.y = 0.0
	if _wall_lock <= 0.0:
		velocity.x = move_toward(velocity.x, move * move_speed() * 0.85, float(stats.accel) * delta)
	return true


## Seile der Karte (Gruppe "ropes"): Hoch oder Runter in der Naehe greift zu, dann klettert man mit hoch und runter.
## Sprung loest sich mit Schwung zur Seite, oben angekommen hopst man auf den Rand.
func _process_rope(delta: float, move: float, vertical: float) -> bool:
	_rope_lock = maxf(0.0, _rope_lock - delta)
	var half := float(stats.size.y) * 0.5
	if on_rope:
		var inside := global_position.y - half < _rope_rect.end.y + 4.0 and global_position.y + half > _rope_rect.position.y - 30.0
		if downed or not inside or _dash_time_left > 0.0 or hook_active:
			_release_rope(0.3)
			return false
		if _jump_buffer > 0.0:
			_jump_buffer = 0.0
			velocity = Vector2(move * 340.0, -jump_speed() * 0.7)
			_wall_lock = 0.18 if move != 0.0 else 0.0
			if move != 0.0:
				facing = signf(move)
			Sfx.play("jump")
			_release_rope(0.35)
			return true
		var feet := global_position.y + half
		if vertical < -0.3 and feet <= _rope_rect.position.y + 26.0:
			# Oben angekommen: auf den Rand hopsen, ohne Eingabe zur Seite, wo oben ein Rand liegt.
			var side := signf(move) if move != 0.0 else _rope_ledge_side()
			velocity = Vector2(side * 230.0, -520.0)
			_wall_lock = 0.3
			facing = side
			Sfx.play("jump")
			_release_rope(0.35)
			return true
		if vertical > 0.3 and feet >= _rope_rect.end.y + 2.0:
			_release_rope(0.2)
			return false
		velocity = Vector2(0.0, vertical * ROPE_SPEED)
		global_position.x = move_toward(global_position.x, _rope_x, 700.0 * delta)
		return true
	if _rope_lock > 0.0 or _slamming or hook_active or downed or absf(vertical) < 0.5 or _dash_time_left > 0.0:
		return false
	for rope in get_tree().get_nodes_in_group("ropes"):
		var rect: Rect2 = rope.get_meta("rect")
		var center_x := rect.get_center().x
		if absf(global_position.x - center_x) > 36.0:
			continue
		var feet := global_position.y + half
		# Nach oben greift man auf Hoehe des Seils, nach unten schon etwas ueber dem Seilanfang.
		var top_limit := rect.position.y + 20.0 if vertical < 0.0 else rect.position.y - 110.0
		if feet < top_limit or global_position.y - half > rect.end.y:
			continue
		if vertical > 0.5 and feet >= rect.end.y - 4.0:
			continue
		on_rope = true
		_rope_x = center_x
		_rope_rect = rect
		_clinging = false
		_ceiling = false
		velocity = Vector2.ZERO
		_air_jumps_left = fw("double_jump")
		Sfx.play("deploy", 0.05)
		return true
	return false


## Seite (-1 oder 1), auf der neben dem Seilende ein Rand zum Draufhopsen liegt; sonst die Blickrichtung.
func _rope_ledge_side() -> float:
	var space := get_world_2d().direct_space_state
	var top := _rope_rect.position.y
	var best := float(facing)
	var best_distance := INF
	for side in [-1.0, 1.0]:
		for reach in [70.0, 130.0]:
			var from := Vector2(_rope_x + side * reach, top - 60.0)
			var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 120.0), (1 << 0) | (1 << 5))
			var hit := space.intersect_ray(query)
			if not hit.is_empty() and absf(float(hit.position.y) - top) < 50.0 and reach < best_distance:
				best = side
				best_distance = reach
	return best


func _release_rope(lock: float) -> void:
	on_rope = false
	_rope_lock = lock


func _process_climb(move: float, vertical: float) -> bool:
	if _wall_lock > 0.0 or _slamming:
		_clinging = false
		return false
	var wall_normal := _solid_wall_normal()
	var touching := wall_normal != Vector2.ZERO
	var wall_dir := -signf(wall_normal.x) if touching else 0.0
	var pushing := touching and move != 0.0 and signf(move) == wall_dir
	var on_floor := is_on_floor()

	if _clinging and not touching:
		# Oberkante erreicht: kleiner Hopser auf den Rand.
		_clinging = false
		if vertical < -0.3 and signf(move) == _cling_dir:
			velocity = Vector2(_cling_dir * 240.0, -430.0)
			Sfx.play("jump")
			return true
		return false
	if _clinging and on_floor and vertical >= 0.0:
		_clinging = false
		return false

	var start := pushing and (not on_floor or vertical < -0.4)
	# Einmal festgehalten bleibt er auch ohne Richtungseingabe haengen (nur Wegdruecken, Sprung oder Runter loest ihn).
	if not (start or (_clinging and (pushing or move == 0.0))):
		_clinging = false
		return false

	_clinging = true
	_cling_dir = wall_dir
	velocity.x = wall_dir * 80.0
	velocity.y = vertical * CLIMB_SPEED * fire_move_factor()
	_air_jumps_left = fw("double_jump")
	if _jump_buffer > 0.0:
		# Von der Wand abspringen.
		velocity = Vector2(-wall_dir * WALL_JUMP_PUSH, -jump_speed() * 0.95)
		facing = -wall_dir
		_wall_lock = WALL_LOCK_TIME
		_jump_buffer = 0.0
		_clinging = false
		Sfx.play("jump")
	return true


## Normale einer echten Wand, an der man klettern oder abspringen darf (sichtbare Waende der Ebene 1), sonst Null.
## Unsichtbare Begrenzungen (Ebene 8, z.B. vor dem Boss) zaehlen nicht: man kann sie nicht beklettern.
func _solid_wall_normal() -> Vector2:
	if not is_on_wall():
		return Vector2.ZERO
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var collider := hit.get_collider()
		if absf(hit.get_normal().x) > 0.7 and collider is CollisionObject2D and (collider.collision_layer & 1) != 0:
			return hit.get_normal()
	return Vector2.ZERO


## True, wenn der Spieler auf einer durchlaessigen Plattform steht.
func _is_on_one_way() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is CollisionObject2D and (collider.collision_layer & (1 << 5)) != 0:
			return true
	return false


func _try_hook() -> void:
	if fw("hook") <= 0 or _hook_cooldown > 0.0 or _dash_time_left > 0.0:
		return
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + aim_dir * HOOK_RANGE, WORLD_MASK)
	query.exclude = [get_rid()]
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		_hook_cooldown = 0.3
		Sfx.play("switch")
		return
	hook_active = true
	hook_anchor = result.position
	_hook_time = HOOK_MAX_TIME
	_slamming = false
	Sfx.play("dash")


func _process_hook(delta: float) -> void:
	_hook_time -= delta
	var to_anchor := hook_anchor - global_position
	if to_anchor.length() < 36.0 or _hook_time <= 0.0 or _jump_buffer > 0.0:
		_release_hook()
		return
	velocity = to_anchor.normalized() * HOOK_SPEED


func _release_hook() -> void:
	hook_active = false
	_hook_cooldown = HOOK_COOLDOWN
	velocity *= 0.65


func _try_dash() -> void:
	if dash_charges <= 0 or _dash_time_left > 0.0 or hook_active or downed:
		return
	var stick := Input.get_vector(
		_prefix + "left", _prefix + "right", _prefix + "up", _prefix + "down")
	var dir := stick
	if dir.length() < AIM_THRESHOLD:
		dir = Vector2(facing, 0.0)
	_dash_dir = dir.normalized()
	_ceiling = false
	_ceiling_cooldown = 0.3
	_dash_time_left = dash_time()
	_blade_hit.clear()
	dash_charges -= 1
	dash_count += 1
	iframes = maxf(iframes, DASH_IFRAMES)
	Sfx.play("dash")
	_puff(Vector2(-_dash_dir.x * 20.0, float(stats.size.y) * 0.5 if is_on_floor() else 0.0), 6, 170.0)
	if float(mods.dash_blast) > 0.0:
		_burst(Perks.DASH_BLAST_RADIUS, Perks.DASH_BLAST_DAMAGE * float(mods.dash_blast), Color(0.5, 0.9, 1.0))


func _spawn_ghost() -> void:
	var ghost := DashGhost.new()
	ghost.class_id = class_id
	ghost.state = _art_state()
	ghost.state.squash = Vector2.ONE
	ghost.tint = RobotClasses.PLAYER_COLORS[player_index - 1]
	get_parent().add_child(ghost)
	ghost.global_position = global_position


## Windlinien hinter dem Roboter, gegen die Dash-Richtung.
func _draw_speed_lines() -> void:
	var back := -_dash_dir
	var side := back.orthogonal()
	for i in 5:
		var offset := side * (float(i) - 2.0) * 9.0 + back * float(i % 2) * 8.0
		var start := offset + back * 26.0
		draw_line(start, start + back * (34.0 + 10.0 * (i % 3)), Color(1, 1, 1, 0.35), 2.0, true)


## Jet Boots: Flammen unter den Fuessen, Tankanzeige als kleiner Balken, solange er nicht voll ist.
func _draw_jet(size: Vector2) -> void:
	var base := Vector2(0.0, size.y * 0.5)
	for side in [-1.0, 1.0]:
		var flicker := 0.7 + 0.3 * sin(_art_time * 60.0 + side * 2.0)
		var length := 26.0 * flicker
		var top := base + Vector2(side * size.x * 0.22, 0.0)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-5.0, 0.0), top + Vector2(5.0, 0.0), top + Vector2(0.0, length)]), Color(1.0, 0.55, 0.15, 0.85))
		draw_colored_polygon(PackedVector2Array([top + Vector2(-2.5, 0.0), top + Vector2(2.5, 0.0), top + Vector2(0.0, length * 0.6)]), Color(1.0, 0.95, 0.6, 0.95))


## Fallstreifen beim Bodenschlag.
func _draw_slam_streaks(size: Vector2) -> void:
	for i in 4:
		var x := (float(i) - 1.5) * size.x * 0.3
		draw_line(Vector2(x, -size.y * 0.5 - 10.0), Vector2(x, -size.y * 0.5 - 52.0 - 14.0 * (i % 2)), Color(0.9, 0.93, 1.0, 0.45), 2.5, true)


## Haken: gespannte Leine mit leichtem Schwingen, Greifkralle am Ziel und Einschlagring.
func _draw_hook() -> void:
	var end := to_local(hook_anchor)
	var length := end.length()
	var dir := end / maxf(length, 1.0)
	var side := dir.orthogonal()
	var points := PackedVector2Array()
	var segments := 14
	for i in segments + 1:
		var f := float(i) / segments
		var wobble := sin(f * PI) * sin(_art_time * 40.0 + f * 9.0) * 3.0 * minf(1.0, length / 300.0)
		points.append(dir * length * f + side * wobble)
	draw_polyline(points, Color(0.1, 0.1, 0.14), 4.0, true)
	draw_polyline(points, Color(0.9, 0.86, 0.55), 2.0, true)
	# Kralle: drei Zinken, die in die Flaeche greifen.
	for k in 3:
		var angle := (float(k) - 1.0) * 0.8
		var tine := end - dir.rotated(angle) * 12.0
		draw_line(end, tine, Color(0.1, 0.1, 0.14), 4.0, true)
		draw_line(end, tine, Color(0.85, 0.87, 0.95), 2.0, true)
	draw_circle(end, 4.0, Color(0.95, 0.9, 0.5))
	draw_arc(end, 9.0 + 3.0 * sin(_art_time * 14.0), 0.0, TAU, 14, Color(1, 1, 1, 0.5), 1.5, true)


func _process_dash(delta: float) -> void:
	_dash_time_left -= delta
	velocity = _dash_dir * DASH_SPEED
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.03
		_spawn_ghost()
	if fw("blade") > 0:
		_dash_blade()
	if _dash_time_left <= 0.0:
		# Momentum: nach dem Dash bleibt etwas Schwung erhalten.
		velocity = _dash_dir * base_speed() * DASH_END_MOMENTUM
		velocity.y = minf(velocity.y, 0.0)
		if float(mods.dash_blast) > 0.0:
			_burst(Perks.DASH_BLAST_RADIUS, Perks.DASH_BLAST_DAMAGE * float(mods.dash_blast), Color(0.5, 0.9, 1.0))


## Flammenstoss unter den Fuessen und Funken beim Jet-Schub.
func _jet_puff(delta: float) -> void:
	_jet_timer -= delta
	if _jet_timer > 0.0 or Fx.instance == null:
		return
	_jet_timer = 0.04
	Fx.instance.spark(global_position + Vector2(randf_range(-8.0, 8.0), float(stats.size.y) * 0.5), Color(1.0, 0.7, 0.25), 2, 120.0)


## Blade Dash: Gegner auf dem Weg des Dashs werden je Dash einmal getroffen.
func _dash_blade() -> void:
	var damage := Firmware.BLADE_DAMAGE * damage_mult()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _blade_hit.has(enemy) or enemy.is_queued_for_deletion():
			continue
		var point := Targeting.point_of(enemy, global_position)
		if point.distance_to(global_position) > Firmware.BLADE_REACH + Targeting.slack_of(enemy):
			continue
		_blade_hit.append(enemy)
		enemy.take_damage(damage, self, _dash_dir * 2.5, current_module())
		if Fx.instance:
			Fx.instance.slash(point, _dash_dir, 60.0, 1.3, Color(0.6, 0.92, 1.0))
		Sfx.play("hit", 0.2)


## Gehoert die Waffe zur eigenen Klasse (Klassenwaffen loesen z.B. beim Hexapod die Schiesshaltung aus)?
func is_class_weapon(weapon_id: String) -> bool:
	return Weapons.owner_of(weapon_id) == class_id


func current_weapon_id() -> String:
	return weapons[weapon_index]


## Setzt das Elementmodul der aktiven Waffe (ersetzt ein vorhandenes).
func set_module(element: String, index := -1) -> void:
	modules[weapon_index if index < 0 or index >= modules.size() else index] = element


## Neue Waffe: freier Slot, sonst ersetzt sie die Waffe in replace_index (Standard: die aktive), inklusive Modul.
func add_weapon(weapon_id: String, replace_index := -1) -> void:
	if weapons.size() < 3:
		weapons.append(weapon_id)
		modules.append("")
		weapon_index = weapons.size() - 1
	else:
		var index := weapon_index if replace_index < 0 or replace_index >= weapons.size() else replace_index
		weapons[index] = weapon_id
		modules[index] = ""
		weapon_index = index
	_sync_ammo()


func current_module() -> String:
	return modules[weapon_index] if weapon_index < modules.size() else ""


## Faktor auf die Wurfgeschwindigkeit der Dose aus Projektiltempo und Reichweite (Reichweite zaehlt halb).
func lob_speed_factor() -> float:
	return (1.0 + float(mods.proj_speed)) * (1.0 + 0.5 * float(mods.range))


## Magazingroesse einer Waffe mit allen Upgrades (mindestens +1 pro Magazin-Upgrade, auch bei kleinen Magazinen).
func mag_size_of(weapon_id: String) -> int:
	var base := int(Weapons.get_weapon(weapon_id).get("mag", 30))
	var bonus := float(mods.mag)
	if bonus <= 0.0:
		return base
	return maxi(base + 1, roundi(float(base) * (1.0 + bonus)))


## Nachladezeit einer Waffe in Sekunden mit allen Upgrades.
func reload_time_of(weapon_id: String) -> float:
	return float(Weapons.get_weapon(weapon_id).get("reload", 1.5)) / (1.0 + float(mods.reload))


func ammo_of(index: int) -> int:
	_sync_ammo()
	return ammo[index] if index >= 0 and index < ammo.size() else 0


func ammo_max_of(index: int) -> int:
	_sync_ammo()
	return _ammo_max[index] if index >= 0 and index < _ammo_max.size() else 0


## Laedt die Waffe auf diesem Platz gerade nach? Ohne Angabe: die aktive Waffe.
func is_reloading(index := -1) -> bool:
	_sync_ammo()
	var slot := weapon_index if index < 0 else index
	return slot < _reload_left.size() and _reload_left[slot] > 0.0


## 0 bis 1: Fortschritt des Nachladens (0, wenn die Waffe nicht nachlaedt).
func reload_ratio(index := -1) -> float:
	_sync_ammo()
	var slot := weapon_index if index < 0 else index
	if slot >= _reload_left.size() or _reload_left[slot] <= 0.0:
		return 0.0
	return clampf(1.0 - _reload_left[slot] / maxf(_reload_span[slot], 0.01), 0.0, 1.0)


## Fuellt alle Magazine sofort (Wellenstart, Tests).
func refill_ammo() -> void:
	_sync_ammo()
	for i in ammo.size():
		ammo[i] = _ammo_max[i]
		_reload_left[i] = 0.0


## Wie viele Minen, Tuerme oder Diener dieser Art von diesem Spieler gerade in der Welt sind.
func deployed_count(entity: String) -> int:
	if Minions.DATA.has(entity):
		return Minion.count_of(self, entity)
	var count := 0
	for node in get_tree().get_nodes_in_group("deployables"):
		if node.owner_player == self and node.kind == entity and not node.is_queued_for_deletion():
			count += 1
	return count


## Hoechstzahl gleichzeitiger Diener einer Art (Split Barrel erhoeht sie).
func minion_cap(kind: String) -> int:
	return int(Minions.DATA[kind].cap) + int(mods.proj)


## Druckt einen Diener am Druckkopf (oder an at). damage ist der fertige Schaden je Schuss oder Biss, -1 nimmt den Grundwert.
## Ist die Hoechstzahl erreicht, verglueht der aelteste Diener der Art.
func summon_minion(kind: String, damage := -1.0, life := -1.0, at := Vector2.INF, cap := -1) -> Minion:
	var info: Dictionary = Minions.DATA[kind]
	var limit := cap if cap > 0 else minion_cap(kind)
	while Minion.count_of(self, kind) >= limit:
		var oldest := Minion.oldest_of(self, kind)
		if oldest == null:
			break
		oldest._expire()
	var minion := Minion.new()
	minion.setup(kind, self, damage if damage >= 0.0 else float(info.damage) * damage_mult(), life)
	minion.slot = _summon_serial % 6
	_summon_serial += 1
	get_parent().add_child(minion)
	minion.global_position = at if at != Vector2.INF else global_position + Vector2(-6.0 * facing, -20.0)
	_launch_flash = 0.7
	return minion


## Beim Start druckt der Printbot sofort einen Printling, den Rest druckt er nach.
func _start_minions() -> void:
	if not downed and Minion.count_of(self, String(Minions.AUTO_PRINT.kind)) == 0:
		summon_minion(String(Minions.AUTO_PRINT.kind))


## Auto-Druck: alle paar Sekunden ein Printling, solange die Hoechstzahl nicht erreicht ist.
func _update_auto_print(delta: float) -> void:
	_launch_flash = maxf(0.0, _launch_flash - delta)
	if not bool(stats.get("summoner", false)) or downed:
		return
	var kind := String(Minions.AUTO_PRINT.kind)
	var interval := float(Minions.AUTO_PRINT.interval) * maxf(0.4, 1.0 - float(mods.ability_cd))
	if Minion.count_of(self, kind) >= minion_cap(kind):
		_print_timer = interval
		return
	_print_timer -= delta
	if _print_timer <= 0.0:
		_print_timer = interval
		summon_minion(kind)


## Fortschritt des naechsten Printlings (0 bis 1) fuer die Lampen am Drucker.
func print_progress() -> float:
	var interval := float(Minions.AUTO_PRINT.interval) * maxf(0.4, 1.0 - float(mods.ability_cd))
	if Minion.count_of(self, String(Minions.AUTO_PRINT.kind)) >= minion_cap(String(Minions.AUTO_PRINT.kind)):
		return 1.0
	return clampf(1.0 - _print_timer / interval, 0.0, 1.0)


## Von Hand nachladen (Kreuz / T / B): die aktive Waffe, wenn das Magazin nicht voll ist und sie nicht gerade geworfen wird.
func reload_now() -> void:
	_sync_ammo()
	if downed or _lob_charging or weapon_index >= ammo.size():
		return
	_start_reload(weapon_index)


## Gleicht Munition und Nachladen mit der Waffenliste ab: neue oder getauschte Waffen starten voll,
## groessere Magazine fuellen sich um den Zuwachs.
func _sync_ammo() -> void:
	var count := weapons.size()
	if ammo.size() != count:
		ammo.resize(count)
		_ammo_ids.resize(count)
		_ammo_max.resize(count)
		_reload_left.resize(count)
		_reload_span.resize(count)
	for i in count:
		var size := mag_size_of(weapons[i])
		if _ammo_ids[i] != weapons[i]:
			_ammo_ids[i] = weapons[i]
			ammo[i] = size
			_ammo_max[i] = size
			_reload_left[i] = 0.0
		elif size != _ammo_max[i]:
			ammo[i] = clampi(ammo[i] + size - _ammo_max[i], 0, size)
			_ammo_max[i] = size


func _update_ammo(delta: float) -> void:
	_sync_ammo()
	_since_shot += delta
	_dry_cooldown = maxf(0.0, _dry_cooldown - delta)
	if not downed and Input.is_action_pressed(_prefix + "fire"):
		_since_shot = 0.0
	for i in weapons.size():
		if _reload_left[i] > 0.0:
			_reload_left[i] -= delta
			if _reload_left[i] <= 0.0:
				_reload_left[i] = 0.0
				ammo[i] = _ammo_max[i]
				if i == weapon_index and not downed:
					Sfx.play("reload_done", 0.05)
					_reload_flash = 1.0
		elif ammo[i] < _ammo_max[i] and (ammo[i] <= 0 or _since_shot >= IDLE_RELOAD):
			_start_reload(i)


func _start_reload(index: int) -> void:
	if _reload_left[index] > 0.0 or ammo[index] >= _ammo_max[index]:
		return
	var missing := float(_ammo_max[index] - ammo[index]) / float(_ammo_max[index])
	var span := reload_time_of(weapons[index]) * lerpf(0.5, 1.0, missing)
	_reload_left[index] = span
	_reload_span[index] = span
	if index == weapon_index and not downed:
		Sfx.play("reload_start", 0.05)


## Verbraucht Munition fuer einen Schuss. Overwatch und Effizienz-Chip sparen sie, ein leeres Magazin laedt von selbst nach.
func _spend_ammo(index: int, weapon: Dictionary) -> void:
	_since_shot = 0.0
	if ability != null and ability.is_active("overwatch"):
		return
	if float(mods.ammo_save) > 0.0 and randf() < minf(0.75, float(mods.ammo_save)):
		return
	ammo[index] = maxi(0, ammo[index] - int(weapon.get("ammo_cost", 1)))
	if ammo[index] <= 0:
		_start_reload(index)
		if index == weapon_index:
			Tips.request("reload")


## Kann die aktive Waffe feuern? Leer: trockenes Klicken beim Druecken, das Nachladen laeuft schon.
func _has_ammo(index: int) -> bool:
	if ammo[index] > 0:
		# Feuer unterbricht ein Teilnachladen.
		_reload_left[index] = 0.0
		return true
	_start_reload(index)
	if _dry_cooldown <= 0.0:
		_dry_cooldown = 0.35
		Sfx.play("dry", 0.05)
	return false


func _rotate_weapon() -> void:
	if weapons.size() <= 1:
		return
	weapon_index = (weapon_index + 1) % weapons.size()
	_burst_left = 0
	_switch_cooldown = 0.2
	shake_charge = 0.0
	_lob_charging = false
	Sfx.play("switch")


## Dosenwurf: Feuer halten schuettelt die Dose (laedt auf), Loslassen wirft sie
## im Bogen. Je laenger geschuettelt, desto weiter, schneller und explosiver.
func _handle_lob(weapon_id: String, weapon: Dictionary, delta: float) -> void:
	var held := Input.is_action_pressed(_prefix + "fire")
	if held and not _lob_charging and _fire_cooldown <= 0.0 and _switch_cooldown <= 0.0 and not _has_ammo(weapon_index):
		return
	if held and _fire_cooldown <= 0.0 and _switch_cooldown <= 0.0:
		_lob_charging = true
		shake_charge = minf(1.0, shake_charge + delta / float(weapon.shake_time))
		_shake_tick -= delta
		if _shake_tick <= 0.0:
			_shake_tick = 0.07
			Sfx.play("shake", 0.2)
	elif _lob_charging and not held:
		_lob_charging = false
		_fire_cooldown = 1.0 / (float(weapon.fire_rate) * fire_rate_mult())
		var origin := _fire_origin(float(weapon.barrel))
		velocity -= aim_dir * float(weapon.recoil) * (0.35 if is_on_floor() else 1.0)
		var thrown_charge := shake_charge
		shake_charge = 0.0
		_fire_flash = 1.0
		_recoil = 0.5 + 0.5 * thrown_charge
		if Fx.instance and thrown_charge > 0.2:
			# Schaum spritzt aus dem Ausgabefach.
			Fx.instance.spark(origin, Color(1.0, 1.0, 1.0, 0.9), 4 + int(8.0 * thrown_charge), 220.0)
		fired.emit(self, weapon_id, origin, aim_dir, thrown_charge)
		_spend_ammo(weapon_index, weapon)
	elif not held:
		shake_charge = 0.0


## 0 bis 1: wie lange ein Dauerstrahl schon gehalten wird (Schadensanstieg).
func channel_ratio() -> float:
	var ramp_time := float(Weapons.get_weapon(current_weapon_id()).get("ramp_time", 0.0))
	return clampf(_channel / ramp_time, 0.0, 1.0) if ramp_time > 0.0 else 0.0


func heat_level() -> float:
	return _heat


func _handle_fire(_delta: float) -> void:
	if Input.is_action_just_pressed(_prefix + "weapon"):
		_rotate_weapon()
	if Input.is_action_just_pressed(_prefix + "reload"):
		reload_now()
	_process_burst(_delta)
	var current := Weapons.get_weapon(current_weapon_id())
	if Input.is_action_pressed(_prefix + "fire") and not downed and is_class_weapon(current_weapon_id()):
		_stance_timer = STANCE_HOLD
	else:
		_stance_timer = maxf(0.0, _stance_timer - _delta)
	# Bremsen (Strahl, Flamme, Sog) nur, solange wirklich geschossen werden kann (nicht bei leerem Magazin oder Nachladen).
	if (current.has("ramp_time") or current.has("slow")) and Input.is_action_pressed(_prefix + "fire") and not downed \
			and ammo_of(weapon_index) > 0 and not is_reloading():
		_channel = minf(_channel + _delta, float(current.get("ramp_time", 1.0)))
	else:
		_channel = maxf(0.0, _channel - _delta * 3.0)
	if current.kind == "lob":
		_handle_lob(current_weapon_id(), current, _delta)
		return
	shake_charge = 0.0
	if not Input.is_action_pressed(_prefix + "fire"):
		return
	if _fire_cooldown > 0.0 or _switch_cooldown > 0.0:
		return
	var weapon_id := current_weapon_id()
	var weapon := Weapons.get_weapon(weapon_id)
	if weapon.kind == "lob":
		return
	if not _has_ammo(weapon_index):
		return
	_fire_cooldown = 1.0 / (float(weapon.fire_rate) * fire_rate_mult())
	_shoot(weapon_id, weapon)
	# Salve: die weiteren Schuesse folgen im festen Abstand, der Druck loest nur die erste aus.
	if weapon.has("burst"):
		_burst_left = int(weapon.burst) - 1
		_burst_timer = float(weapon.get("burst_gap", 0.06))


## Ein einzelner Schuss mit Rueckstoss, Effekten, Munition und Signal.
func _shoot(weapon_id: String, weapon: Dictionary) -> void:
	var origin := _fire_origin(float(weapon.barrel))
	# Rueckstoss: am Boden schwaecher, in der Luft staerker. Drohnenschuesse stossen den Koerper nicht.
	var kick := float(weapon.recoil) * (0.35 if is_on_floor() else 1.0)
	if not (float(stats.get("fire_slow", 1.0)) < 1.0 and is_class_weapon(weapon_id)):
		velocity -= aim_dir * kick
	_fire_flash = 1.0
	_recoil = 1.0
	_heat = minf(1.0, _heat + 0.2)
	if class_id == "hexapod":
		# Huelse fliegt seitlich aus dem Gehaeuse.
		if Fx.instance:
			Fx.instance.spark(global_position + Vector2(-5.0 * facing, -14.0), Color(1.0, 0.82, 0.4), 1, 150.0)
	fired.emit(self, weapon_id, origin, aim_dir, 0.0)
	_spend_ammo(weapon_index, weapon)


## Folgeschuesse einer Salve. Ein Waffenwechsel, Boden oder leeres Magazin brechen sie ab.
func _process_burst(delta: float) -> void:
	if _burst_left <= 0:
		return
	var weapon_id := current_weapon_id()
	var weapon := Weapons.get_weapon(weapon_id)
	if downed or not weapon.has("burst") or ammo[weapon_index] <= 0:
		_burst_left = 0
		return
	_burst_timer -= delta
	if _burst_timer > 0.0:
		return
	_burst_left -= 1
	_burst_timer = float(weapon.get("burst_gap", 0.06))
	_shoot(weapon_id, weapon)


## Zustand fuer die Zeichenfunktionen (siehe RobotArt).
func _art_state() -> Dictionary:
	var weapon_color: Color = Weapons.get_weapon(current_weapon_id()).color
	var element := current_module()
	if element != "":
		weapon_color = Elements.COLORS[element]
	var mood := "normal"
	if downed:
		mood = "dead"
	elif _hurt_timer > 0.0:
		mood = "hurt"
	elif ability.is_active("roll"):
		mood = "angry"
	elif _coin_flash > 0.3:
		mood = "happy"
	elif _fire_flash > 0.3 or shake_charge > 0.0 or _deploy_amount > 0.85:
		mood = "focus"
	elif _happy_timer > 0.0:
		mood = "happy"
	var printed := print_progress()
	var launch := (0.7 - _launch_flash) / 0.7 if _launch_flash > 0.0 else -1.0
	var squash := Vector2.ONE
	if _land_squash > 0.0:
		squash = Vector2(1.0 + 0.2 * _land_squash, 1.0 - 0.24 * _land_squash)
	elif not is_on_floor() and not _clinging:
		var stretch := clampf(absf(velocity.y) / 1600.0, 0.0, 0.14)
		squash = Vector2(1.0 - stretch * 0.6, 1.0 + stretch)
	elif _dash_time_left > 0.0:
		squash = Vector2(1.12, 0.9)
	# Neigung: Walze lehnt sich nach vorn, ausgeschaltete schwere Klassen kippen um.
	var tilt := 0.0
	if bool(stats.get("tips_over", false)):
		tilt = (0.1 if ability.is_active("roll") else 0.0) * facing
	# Kletternder Spinnenroboter dreht sich mit dem Bauch zur Wand.
	if on_rope:
		tilt += sin(_art_time * 3.0) * 0.05
	var cling_rotation := -_cling_dir * PI / 2.0 * _cling_amount if bool(stats.get("wall_climb", false)) else 0.0
	return {
		"ceiling": _ceiling_amount, "cling": _cling_amount, "rot": cling_rotation, "down": _down_amount, "vy": velocity.y,
		"squash": squash, "deploy": _deploy_amount, "recoil": _recoil, "heat": _heat, "climb": _climb_phase,
		"hurt": _hurt_timer / 0.45, "downed": downed, "overdrive": 1.0 if ability.is_active() else 0.0,
		"coin": _coin_flash, "low": clampf((0.3 - hp / max_health()) / 0.3, 0.0, 1.0) if not downed else 0.0, "tilt": tilt,
		"print": printed, "launch": launch,
		"facing": facing, "aim": aim_dir, "t": _art_time, "vx": 0.0 if downed else velocity.x,
		"walk": _walk_phase, "grounded": is_on_floor(), "clinging": _clinging, "cling_dir": _cling_dir,
		"planted": is_deployed(), "slope": _slope_tilt, "slope_shift": _slope_shift,
		"mood": mood, "firing": _fire_flash, "charge": shake_charge, "arm": _arm_deploy,
		"weapon_color": weapon_color, "accent": RobotClasses.PLAYER_COLORS[player_index - 1],
		"eye_color": stats.eye_color,
	}


func _draw() -> void:
	var size: Vector2 = stats.size
	var accent: Color = RobotClasses.PLAYER_COLORS[player_index - 1]

	ability.draw_aura(self, _art_time)
	if not downed:
		# Weicher Schein in der Spielerfarbe: man findet sich auch vor unruhigem Hintergrund.
		var halo := maxf(size.x, size.y) * 0.8
		for i in 6:
			draw_circle(Vector2.ZERO, halo * (1.0 - 0.14 * i), Color(accent, 0.035))
	if slow_time > 0.0:
		draw_arc(Vector2.ZERO, maxf(stats.size.x, stats.size.y) * 0.5 + 6.0, 0.0, TAU, 28, Color(0.75, 0.92, 1.0, 0.7), 2.5, true)

	if _dash_time_left > 0.0:
		_draw_speed_lines()
	if _slamming:
		_draw_slam_streaks(size)
	if jet_active and not downed:
		_draw_jet(size)
	if fw("jet") > 0 and _jet_fuel < 0.99 and not downed:
		var gauge := Rect2(Vector2(-14.0, size.y * 0.5 + 6.0), Vector2(28.0, 3.0))
		draw_rect(gauge, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * _jet_fuel, gauge.size.y)), Color(1.0, 0.7, 0.25))
	if hook_active:
		_draw_hook()

	if not downed:
		var body := maxf(size.x, size.y) * 0.5
		if max_shield() > 0.0 and shield > 0.0:
			var fill := shield / max_shield()
			draw_arc(Vector2.ZERO, body + 10.0, 0.0, TAU, 32, Color(0.5, 0.85, 1.0, 0.25 + 0.4 * fill), 2.5, true)
			draw_circle(Vector2.ZERO, body + 9.0, Color(0.5, 0.85, 1.0, 0.06 * fill))
		if low_health():
			var pulse := 0.5 + 0.5 * sin(_art_time * 9.0)
			draw_arc(Vector2.ZERO, body + 6.0, 0.0, TAU, 28, Color(1.0, 0.3, 0.25, 0.35 + 0.3 * pulse), 3.0, true)
		for k in frenzy_stacks:
			var px := (float(k) - (frenzy_stacks - 1) * 0.5) * 9.0
			draw_circle(Vector2(px, -size.y * 0.5 - 22.0), 3.2, Color(0.05, 0.03, 0.02, 0.8))
			draw_circle(Vector2(px, -size.y * 0.5 - 22.0), 2.4, Color(1.0, 0.6, 0.2))

	# Blinken waehrend der Unverwundbarkeit nach einem Treffer.
	var blink := iframes > 0.0 and _dash_time_left <= 0.0 and not downed and fmod(iframes, 0.12) < 0.06
	modulate = Color(1, 1, 1, 0.45) if blink else (Color(0.6, 0.6, 0.66) if downed else Color.WHITE)
	if _hurt_timer > 0.0 and not downed:
		# Treffer: Roboter leuchtet kurz rot auf.
		modulate = modulate.lerp(Color(1.0, 0.3, 0.25, modulate.a), 0.75 * hurt_amount())
		var k := hurt_amount()
		draw_circle(Vector2.ZERO, maxf(size.x, size.y) * 0.5 + 10.0, Color(1.0, 0.15, 0.1, 0.28 * k))
		draw_arc(Vector2.ZERO, maxf(size.x, size.y) * 0.5 + 12.0 + 14.0 * (1.0 - k), 0.0, TAU, 28, Color(1.0, 0.3, 0.2, 0.8 * k), 3.0, true)

	var jitter := Vector2.ZERO
	if shake_charge > 0.0:
		jitter = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_charge * 3.0
	RobotArt.draw_player(self, class_id, _art_state(), jitter)

	if downed:
		_draw_downed(size)
		return
	_draw_marker(size, accent)
	_draw_laser()
	if shake_charge > 0.0:
		_draw_lob_preview(size)
	_draw_reload(size)


## Laserpointer jedes Spielers: Zielen ist schwer, der Strahl zeigt die Richtung bis zur ersten Wand.
## P1 cyan, P2 gruen, damit man seinen eigenen erkennt und nichts mit den roten Gegner-Warnlinien verwechselt.
func laser_color() -> Color:
	return LASER_COLORS[player_index - 1]


func _draw_laser() -> void:
	var from := _muzzle_offset() + aim_dir * 18.0
	var length := _laser_length
	var color := laser_color()
	var pulse := 0.85 + 0.15 * sin(_art_time * 9.0)
	# Beim Schiessen wird der Strahl noch blasser, damit man die Schuesse sieht.
	var boost := 1.0 - 0.5 * _fire_flash
	var segments := 12
	for i in segments:
		var a := from + aim_dir * length * float(i) / float(segments)
		var b := from + aim_dir * length * float(i + 1) / float(segments)
		var fade := 1.0 - float(i) / float(segments)
		draw_line(a, b, Color(color, (0.03 + 0.12 * fade * fade) * pulse * boost), 2.0 + 0.5 * fade, true)
		draw_line(a, b, Color(1, 1, 1, (0.03 + 0.1 * fade * fade) * boost), 1.0, true)
	var end := from + aim_dir * length
	draw_circle(end, 3.0, Color(color, 0.4 * pulse * boost))
	draw_circle(end, 6.0, Color(color, 0.08))
	draw_circle(end, 1.2, Color(1, 1, 1, 0.5))


func _update_laser() -> void:
	var space := get_world_2d().direct_space_state
	var from := global_position + _muzzle_offset() + aim_dir * 18.0
	var query := PhysicsRayQueryParameters2D.create(from, from + aim_dir * LASER_RANGE, 1 << 0)
	var hit := space.intersect_ray(query)
	_laser_length = LASER_RANGE if hit.is_empty() else from.distance_to(hit.position)


func _draw_marker(size: Vector2, accent: Color) -> void:
	# Spielermarke ueber dem Kopf und Dash-Aufladungen.
	var y := -size.y * 0.5 - 20.0
	var font := ThemeDB.fallback_font
	draw_colored_polygon(PackedVector2Array([Vector2(-6, y - 6), Vector2(6, y - 6), Vector2(0, y + 3)]), accent)
	draw_polyline(PackedVector2Array([Vector2(-6, y - 6), Vector2(6, y - 6), Vector2(0, y + 3), Vector2(-6, y - 6)]), Art.OUTLINE, 1.5, true)
	draw_string(font, Vector2(-20, y - 9), "P%d" % player_index, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 12, Color(1, 1, 1, 0.9))
	var total := dash_max()
	for i in total:
		var pos := Vector2((i - (total - 1) * 0.5) * 11.0, -size.y * 0.5 - 8.0)
		var filled := i < dash_charges
		draw_circle(pos, 3.5, Color(1, 1, 1, 0.9) if filled else Color(1, 1, 1, 0.18))
		if filled:
			draw_arc(pos, 3.5, 0.0, TAU, 10, accent, 1.2, true)


func _draw_downed(size: Vector2) -> void:
	# Ausgeschaltet: Rauch steigt auf, der Wiederbelebungs-Ring fuellt sich.
	for i in 3:
		var life := fposmod(_art_time * 0.8 + i * 0.33, 1.0)
		draw_circle(Vector2(sin(_art_time * 2.0 + i) * 6.0, -size.y * 0.5 - life * 28.0), 3.0 + life * 5.0, Color(0.7, 0.7, 0.75, 0.4 * (1.0 - life)))
	var ring_radius := maxf(size.x, size.y) * 0.5 + 8.0
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, Color(1, 1, 1, 0.15), 3.0, true)
	if revive_progress > 0.0:
		draw_arc(Vector2.ZERO, ring_radius, -PI / 2.0, -PI / 2.0 + TAU * revive_progress, 40, Color(0.4, 1.0, 0.5), 5.0, true)


## Nachladen: ein warmer Ring um den Roboter fuellt sich, am Ende blitzt er kurz auf.
func _draw_reload(size: Vector2) -> void:
	var radius := maxf(size.x, size.y) * 0.5 + 18.0
	if is_reloading():
		var ratio := reload_ratio()
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(1, 1, 1, 0.1), 3.0, true)
		draw_arc(Vector2.ZERO, radius, -PI / 2.0, -PI / 2.0 + TAU * ratio, 36, Color(1.0, 0.8, 0.3, 0.9), 3.0, true)
	elif _reload_flash > 0.0:
		draw_arc(Vector2.ZERO, radius + 6.0 * (1.0 - _reload_flash), 0.0, TAU, 36, Color(0.7, 1.0, 0.6, _reload_flash), 3.0, true)


func _draw_lob_preview(size: Vector2) -> void:
	# Ladering und gepunktete Flugbahn der Dose.
	var weapon := Weapons.get_weapon(current_weapon_id())
	var ring_color := Color(0.4, 0.95, 0.55).lerp(Color(1, 1, 1), shake_charge)
	var ring_radius := maxf(size.x, size.y) * 0.5 + 10.0
	draw_arc(Vector2.ZERO, ring_radius, -PI / 2.0, -PI / 2.0 + TAU * shake_charge, 40, ring_color, 4.0, true)
	var speed := lerpf(float(weapon.speed), float(weapon.speed_max), shake_charge) * lob_speed_factor()
	var gravity: float = weapon.gravity
	var pos := _muzzle_offset() + aim_dir * float(weapon.barrel)
	var vel := aim_dir * speed
	var step := 0.06
	for i in 24:
		vel.y += gravity * step
		pos += vel * step
		if global_position.y + pos.y > 1250.0:
			break
		draw_circle(pos, 3.0, Color(ring_color, 0.55))


## Mündung des nächsten Schusses.
func _fire_origin(barrel: float) -> Vector2:
	return global_position + _muzzle_offset() + aim_dir * barrel


## Position des Waffenansatzes relativ zum Koerpermittelpunkt (beruecksichtigt die Blickrichtung).
func _muzzle_offset() -> Vector2:
	var muzzle: Vector2 = stats.muzzle
	var local := Vector2(muzzle.x * facing, muzzle.y)
	if _ceiling:
		# Kopfueber sitzt das Geschuetz unten am Koerper.
		return Vector2(muzzle.x * facing, -muzzle.y)
	if _clinging:
		return local.rotated(-_cling_dir * PI / 2.0)
	# Auf schraegem Boden dreht sich der Ansatz mit dem Koerper (nur ohne Wand und Decke).
	if _slope_tilt != 0.0:
		return local.rotated(_slope_tilt) + _slope_shift
	return local
