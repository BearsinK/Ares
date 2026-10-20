# Robros

2D-Coop-Roguelike für zwei Spieler an einem PC, gebaut mit Godot 4.7.
Design-Zusammenfassung: [docs/DESIGN.md](docs/DESIGN.md)

## Projekt öffnen

1. Godot 4.7 starten (Standardversion, nicht .NET).
2. Im Projektmanager auf "Importieren" und `project.godot` aus diesem Ordner wählen.
3. Mit F5 starten.

## Steuerung

Beide Spieler können Controller und Tastatur gleichzeitig nutzen. Spieler 1 bekommt Controller 1, Spieler 2 Controller 2. Das Spiel zeigt oben links, welche Controller erkannt wurden.

| Aktion | Controller (PS5) | Spieler 1 Tastatur | Spieler 2 Tastatur |
|---|---|---|---|
| Bewegen | Linker Stick | A, D | Pfeil links, rechts |
| Zielen | Rechter Stick | Maus | Blickrichtung |
| Sprung | L1 | Leertaste | Pfeil hoch |
| Dash | R1 | Shift | Schrägstrich |
| Schießen | R2 | Linke Maustaste oder F | Punkt |
| Klassenfähigkeit | L2 | E | Komma |
| Waffe wechseln | Dreieck | Q | M |
| Haken (Firmware) | Quadrat | R | N |
| Menüs | Links/Rechts, Kreuz bestätigen, Kreis zurück | A/D, Enter | Pfeile, Num-Enter, Rechts-Shift oder Rechts-Alt |

Interagieren (Kreis / G / L) belebt den Partner (halten). Die Klassenfähigkeit auf L2 (Taste E bzw. Komma) hat eine Abklingzeit, die Leiste im HUD zeigt sie. Escape oder Options öffnet die Pause.

Das Spiel startet im Titelbildschirm: Spielen, dann wählt jeder Spieler seine Klasse (Links/Rechts, Kreuz bestätigt, Kreis nimmt zurück). Im Spiel wechseln F4 (Spieler 1) und F5 (Spieler 2) die Klasse (startet die Szene neu).

Debug: F1 und F2 tauschen die aktuelle Waffe von Spieler 1 bzw. 2 gegen die nächste, F3 gibt beiden das komplette Testset (alle Waffen mit Modulen).

## Aktueller Stand

- Testarena mit Plattformen und Schacht, Kamera hält beide Spieler im Bild
- Laufen mit Beschleunigung, Sprung (variable Höhe, Coyote-Time, Eingabepuffer), Dash mit Aufladungen, Iframes und Momentum
- Platzhalter-Klassen Roomba und Hexapod (Hexapod schießt nur im Stand)
- Sechs Waffen: Dustgun, Rapid, Scatter, Rocket (Explosion), Beam und Sniper (Treffer entlang einer Linie, durchschlägt Gegner). Jeder Spieler hat drei zum Ausprobieren, Wechsel per Dreieck
- Rückmeldung: Mündungsfeuer, Funken, Rückstoß, Kamerawackeln, Explosionen, eigener Sound pro Waffe
- Automat: Dosenwurf im Bogen aus dem Ausgabefach unten. Feuer halten schüttelt die Dose (Ladering, gepunktete Flugbahn), loslassen wirft. Je länger geschüttelt, desto weiter, schneller und größer die Explosion. Ab 20 Prozent Schütteln explodiert die Dose beim Aufprall, kurzes Antippen wirft nur eine ungeschüttelte Dose ohne Explosion. Mit Elementmodul gibt die Dose das Element weiter
- Hexapod: klettert Wände hoch (gegen die Wand drücken, hoch/runter klettern, an der Oberkante hopst er auf den Rand, von der Wand abspringen geht auch). Sein Geschütz schießt schnell (2,8 Schuss pro Sekunde, durchschlägt bis zu 3 Gegner), aber nur im Stand: am Boden oder hängend an der Wand, nach 0,2 Sekunden Aufbauzeit (Beine spreizen sich). Im Gehen, Klettern oder in der Luft schießt er nicht. Waffen aus dem Shop darf er überall nutzen
- Vier Gegnertypen (Läufer, Schütze, Flieger, Brute) ohne Kontaktschaden: Jeder Angriff wird vorher angekündigt (Kegel, Kreis, Schusslinie)
- Director: Gegner erscheinen nach und nach, die Schwierigkeit steigt mit jeder Welle (und stetig innerhalb der Welle), neue Typen schalten sich nach und nach frei. Teure Typen werden vorab gewürfelt und abgewartet, damit sie nicht von billigen verdrängt werden
- XP und Gold fallen aus Gegnern, werden angezogen und eingesammelt. XP gehört beiden, Gold dem Einsammler
- Level-Ups mitten im Kampf: drei Team-Perks, beide Spieler müssen dieselbe Karte bestätigen (Links/Rechts wählen, Kreuz bestätigen, Kreis zurück). Jeder Perk wirkt je nach Klasse anders
- Elemente als Module an Waffen (Feuer, Wasser, Eis, Blitz) mit kurzen Statuseffekten und Kombos: Wasser+Blitz (x1,5, Kettenblitz), Wasser+Eis (eingefroren), Wasser+Feuer (Dampfexplosion), Feuer+Eis (schmilzt). Setzt ein anderer Spieler den Status, ist die Kombo deutlich stärker (Coop-Bonus). Zum Testen tragen die Waffen schon Module (Punkt im HUD zeigt das Element)
- Wellen mit Zeitlimit (Standard 120 s, 10 Wellen), danach räumt sich das Feld, alle stehen auf und der Shop öffnet. Jeder kauft persönlich ein: Buffs, Elementmodule, Waffen, Bewegungs-Firmware, Reroll. Nach der letzten Welle erscheint ein Sieg-Bildschirm (der Endboss fehlt noch)
- Bewegungs-Firmware: Doppelsprung, Wandsprung (rutschen und abspringen), Gleitschirm, Bodenstoß, Greifhaken, mehr Dash-Ladungen. Plattformen sind von unten durchlässig, mit nach unten + Sprung fällt man durch
- Klassenfähigkeiten auf L2: Roomba Sog (zieht Gegner und Beute heran und kaut sie an), Hexapod Overwatch (4 s doppelte Feuerrate, auch in Bewegung), Automat Walze (3 s schneller, halber Schaden, rammt Gegner), Drucker Druck (zwei Drohnen mit Explosivschüssen, übernehmen das Element-Modul der aktiven Waffe; jeder Kill verkürzt die Abklingzeit um 0,3 s)
- Sechs Gegnertypen (Grunt, Gunner, Buzzer, Brute, Ramtank, Mortar): dazu Ramtank (kündigt einen Ansturm an, der Schaden macht, wenn man im Weg steht) und Mortar (Warnkreis am Boden, dann Einschlag). Ab etwa einer Minute erscheinen Elites: größer, zäher, goldene Aura, viel Beute und ein Reparaturkit
- Reparaturkits (grünes Kreuz) heilen den Spieler, der sie braucht. Treffer erzeugen Kamerawackeln, roten Bildschirmrand und einen kurzen Hitstop
- Dreizehn Perks mit Symbolen, darunter Glückschip (Crit), Notstrom (Heilung pro Kill), Durchschlag, Sprengkapsel (Kettenexplosionen) und Kühlkreislauf (Fähigkeit lädt schneller)
- Endboss "Smelter" nach Welle 10 (nach einem letzten Shop): Die Halle wird zum Laufband-Ofen. Das Band zieht alles am Boden nach links in den Verbrennungsofen (Feuer, 30 Schaden). Der Boss rechts schickt Hindernisse aufs Band: Kisten und Stapel (springen, mit Anlauf), rollende Sägen (springen) und hängende Träger (drunter durchlaufen). Plattformen über dem Band sind sicher. Dazu Feuersalven mit Zielstrahl, Ascheregen mit Warnkreisen und ab Phase 3 Schweißdrohnen. Sein Panzer nimmt nur 25 Prozent Schaden, nur im Vent (Kern offen) volle. Hydro +50 Prozent, Cryo +25 Prozent, Pyro -40 Prozent. Bei 66 und 33 Prozent Leben wechselt die Phase, das Band wird schneller
- Garage im Hauptmenü: Am Ende jedes Laufs gibt es Chips (mehr für Wellen, Kills, Stufe und den Boss). Damit kauft man dauerhafte Upgrades (Leben, Schaden, Startgold, Erfahrung, Tempo, gratis Reroll) und schaltet Automat, Drucker und weitere Waffen frei. Der Spielstand liegt in `user://ares_save.json`
- Elites haben eine Art mit eigener Mechanik: Inferno (legt Feuerherde), Bulwark (Schild), Stormer (Blitzfächer), Frostbite (bremst in der Nähe)
- Wellen-Modifikatoren ab Welle 2: Swarm, Elite Rush, Heavy Metal, Air Raid, Overdrive. Der Shop bietet auch Reparaturen, und jeder Kauf macht weitere teurer
- Perk Cable Link: nah beim Partner mehr Schaden und Regeneration
- Musik wird im Code erzeugt und lässt sich im Menü abschalten, F11 schaltet Vollbild um
- Hexapod, Vendor, Drucker und Roomba sind animiert und poliert (der Drucker mit Filament-Pistole, Spule, Fortschrittsanzeige, kippt um wenn er am Boden ist, Drohnen mit Rotoren, Aufpoppen und Blinken vor dem Ablauf): Atmen, Gangwippen, Aufstellen mit Stabilisatoren, Rückstoß, Hitze, Wand- und Deckenklettern (kopfüber, das Geschütz hängt dann nach unten) mit gedrehtem Körper, Landestauchung, Dash mit Nachbildern der echten Figur, Windlinien, Absprungwolken, Wandrutsch-Funken, Haken mit Kralle und schwingender Leine, Bodenschlag mit Druckwelle und Kamerawackeln, Umkippen und Aufstehen (ausgeschaltet liegen Automat und Drucker auf dem Rücken, Roomba und Hexapod auf dem Panzer). Der Hexapod steckt aufgestellt 20 % weniger ein, der Vendor wird kaum zurückgestoßen und lässt den Boden beben. Eine Pose-Tafel (`tests/pose_sheet.tscn`, `POSE_CLASS=vending`) zeigt alle Zustände
- Pausemenü (Weiter, Steuerung, Neustart, Hauptmenü mit Rückfrage) und Ergebnisbildschirm nach Game Over oder Sieg
- Spieler-Leben mit Unverwundbarkeit nach Treffer, Wiederbeleben durch Halten von Interagieren (Kreis), Game Over wenn beide am Boden liegen

Waffenwerte stehen in `scripts/data/weapons.gd`, Das Testset steht in `scripts/game/main.gd` (`TEST_LOADOUTS`, `TEST_MODULES`). Ein normaler Lauf startet nur mit der Klassenwaffe.

Welche Klassen gespielt werden, legt der Titelbildschirm fest (`scripts/game/title_screen.gd`), Standard sind Roomba und Hexapod.

## Optik

Alles wird im Code gezeichnet (kein Asset-Import). `scripts/art/` enthält die Zeichenhilfen (`art.gd`), die Roboter und Gegner (`robot_art.gd`), Level-Blöcke (`block_art.gd`), den Parallax-Hintergrund (`backdrop.gd`), Requisiten und Dampf (`props.gd`) und die Vignette. Mit der Szene `tests/art_gallery.tscn` kannst du alle Figuren nebeneinander ansehen. Die Roboter sind für die Seitenansicht gebaut: Roomba flach (68x26, dunkle Scheibe mit Silberring, Knopf, Stoßstange und Arm), Hexapod mit Beinen, Automat groß (68x108, die Dosen kommen aus dem Ausgabefach unten), Drucker auf zwei selbst gedruckten Beinen ohne eigene Waffe: zwei Begleitdrohnen schweben bei ihm und feuern seine Waffe (Rückstoß gibt es nicht), in der Kammer druckt er Schicht für Schicht eine Quadcopter-Drohne (die Tür öffnet sich, wenn die Fähigkeit sie losschickt).

## Struktur

- `scenes/` Szenen
- `scripts/autoload/` globale Skripte (Eingabe)
- `scripts/data/` Werte und Daten (Klassen)
- `scripts/game/` Spiellogik (Spieler, Gegner, Director, Menüs, HUD, Hauptszene)
- `scripts/art/` Zeichencode für Figuren, Level und Effekte
- `tests/` automatischer Test

## Automatischer Test

```
godot --headless --path . res://tests/smoke_test.tscn
godot --headless --path . res://tests/combat_test.tscn
godot --headless --path . res://tests/director_test.tscn
godot --headless --path . res://tests/progression_test.tscn
godot --headless --path . res://tests/element_test.tscn
godot --headless --path . res://tests/wave_test.tscn
godot --headless --path . res://tests/movement_test.tscn
godot --headless --path . res://tests/vending_test.tscn
godot --headless --path . res://tests/hexapod_test.tscn
godot --headless --path . res://tests/menu_test.tscn
godot --headless --path . res://tests/ability_test.tscn
godot --headless --path . res://tests/loop_test.tscn
godot --headless --path . res://tests/boss_test.tscn
```

Die Tests simulieren Eingaben und prüfen Bewegung, Waffen, Gegnerangriffe, Wiederbeleben, Game Over und den Director.

## Controller wird nicht erkannt

Oben links im Spiel steht, welche Controller Godot sieht und welcher Input zuletzt ankam. Wenn dort "Kein Controller erkannt" steht:

1. Controller per USB-Kabel anschließen (ein Datenkabel, nicht nur Ladekabel) und alle anderen Programme schließen, die Controller übernehmen: Steam, DS4Windows, Playstation-Remote-Play.
2. In Windows "Gamecontroller einrichten" öffnen (Windows-Suche). Dort muss "Wireless Controller" oder "DualSense" auftauchen. Wenn nicht, liegt es an Windows oder dem Kabel.
3. Bei Bluetooth: Controller zuerst in den Windows-Bluetooth-Einstellungen koppeln (PS-Taste und Share-Taste gedrückt halten, bis das Licht blinkt).
4. Godot nach dem Anschließen neu starten.

## Aktualisieren (Windows)

Doppelklick auf `update.bat` holt die neueste Version. Lokale Änderungen (auch die, die Godot automatisch schreibt) werden vorher per `git stash` gesichert. Mit einer Datei `godot_path.txt` (nur der Pfad zur Godot-.exe in einer Zeile) startet danach automatisch der Godot-Editor. Für eine Desktop-Verknüpfung: Rechtsklick auf `update.bat`, "Senden an", "Desktop (Verknüpfung erstellen)".
