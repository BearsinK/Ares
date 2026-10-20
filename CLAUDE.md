# Robros (Repo: Ares): Hinweise fuer Claude

Godot 4.7 (GDScript, GL Compatibility), 2D-Coop-Roguelike fuer zwei Spieler. Sprache mit dem Nutzer: Deutsch. Sichtbare Spieltexte (Strings in scripts/) mit echten Umlauten und ß, Namen kurz und gamer-cool (oft englisch: Dustgun, Vortex, Heavy Frame), UI-Woerter deutsch, Kommentare und Tests duerfen ASCII bleiben.
Kurz und direkt, keine Emojis, keine Gedankenstriche. Design: docs/DESIGN.md (Entscheidungen), README.md (Steuerung, Stand).

## Arbeitsweise
- Aenderungen immer mit den Tests pruefen (siehe unten) und per Screenshot ansehen, dann committen und pushen.
- Branch: claude/2-player-coop-game-upgrades-5s2a48. Commit-Nachrichten mit den Co-Authored-By und Claude-Session Zeilen.
- Der Nutzer testet auf Windows mit PS5-Controllern und holt Updates per update.bat.
- Alles Visuelle wird im Code gezeichnet (kein Asset-Import), Hilfen in scripts/art/.

## Godot lokal fuer Tests (Cloud-Umgebung)
Godot 4.7.2 Linux liegt (falls noch vorhanden) im Scratchpad unter godot-dl, sonst von
https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip laden.
- Import: godot --headless --path . --import
- Tests: godot --headless --path . res://tests/<name>_test.tscn (smoke, combat, element, progression, wave, movement, director, vending, hexapod, menu, ability, loop, boss, meta, regression, sandbox, stage, gate, items, chest, guardian, contract, difficulty)
- Balance: SIM_CLASSES=roomba,hexapod SIM_SCALE=8 godot --headless --path . res://tests/balance_sim.tscn (Bot spielt schneller als Echtzeit, nur Entwicklerwerkzeug; Ergebnisse streuen stark, mehrere Laeufe vergleichen; SIM_BOSS=1 startet direkt den Bosskampf, SIM_NOOBS=1 ohne Hindernisse, SIM_DEBUG=1 mit Spuren. Der Bot kann den Hindernissen nicht gut ausweichen, sein Ergebnis im Bosskampf sagt wenig)
- Zufallseingaben-Test (Abstuerze, NaN, aus der Arena fallen): CHAOS_CLASSES=roomba,hexapod CHAOS_SECONDS=300 [CHAOS_BOSS=1 CHAOS_GOD=1] godot --headless --path . res://tests/chaos.tscn
- Frame-Zeit mit vielen Gegnern: PERF_ENEMIES=60 godot --headless --path . res://tests/perf.tscn (nur relative Werte vergleichen)
- Screenshots: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 <szene>
- Autoloads (Sfx, InputSetup) gibt es nur in Szenen, nicht im --script Modus.

## Karten
Grosse Karten stehen in scripts/data/stages.gd (Layouts als Daten), gebaut von scripts/game/stage_builder.gd. Tests laufen auf der alten flachen Halle: `main.stage_id = "classic"` vor add_child(main). tests/stage_test.gd prueft jedes Layout auf Erreichbarkeit (Fuss, Sprung, Seil) und Spawnpunkte, neue Layouts muessen ihn bestehen.

## Stolperfallen
- Area2D hat eingebaute Felder wie gravity; _set ist reserviert; Variant braucht explizite Typen (var x: float = ...).
- Tests muessen auf Frames warten (physics_frame) und Eingaben am Frame-Anfang setzen (siehe _tap).
- Spielertreffer nur ueber Player.take_hit, Gegner nur ueber Enemy.take_damage(amount, source, direction, element).

## Architektur
scripts/data (Werte: Klassen, Waffen, Gegner, Perks, Firmware, Elemente, Shop), scripts/game (Spieler, Gegner, Director,
Menues, HUD, Hauptszene), scripts/art (Zeichencode), scripts/autoload (Sfx, Eingabe), tests.
