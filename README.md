# Ares

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
| Waffe wechseln | Dreieck | Q | M |
| Haken (Firmware) | Quadrat | R | N |
| Menüs | Links/Rechts, Kreuz bestätigen, Kreis zurück | A/D, Enter | Pfeile, Rechts-Alt oder \ |

Interagieren (Kreis / G / L) belebt den Partner (halten). Die Klassenfähigkeit (L2) hat noch keine Funktion.

Klassen wechseln: F4 (Spieler 1) und F5 (Spieler 2) schalten durch Roomba, Hexapod, Automat und Drucker (startet die Szene neu). Der Drucker ist noch ein Platzhalter.

Debug: F1 und F2 tauschen die aktuelle Waffe von Spieler 1 bzw. 2 gegen die nächste, F3 gibt beiden das komplette Testset (alle Waffen mit Modulen).

## Aktueller Stand

- Testarena mit Plattformen und Schacht, Kamera hält beide Spieler im Bild
- Laufen mit Beschleunigung, Sprung (variable Höhe, Coyote-Time, Eingabepuffer), Dash mit Aufladungen, Iframes und Momentum
- Platzhalter-Klassen Roomba und Hexapod (Hexapod schießt nur im Stand)
- Sechs Waffen: Staubkugeln, Schnellfeuer, Schrot, Rakete (Explosion), Strahl und Sniper (Treffer entlang einer Linie, durchschlägt Gegner). Jeder Spieler hat drei zum Ausprobieren, Wechsel per Dreieck
- Rückmeldung: Mündungsfeuer, Funken, Rückstoß, Kamerawackeln, Explosionen, eigener Sound pro Waffe
- Automat: Dosenwurf im Bogen. Feuer halten schüttelt die Dose (Ladering, gepunktete Flugbahn), loslassen wirft. Je länger geschüttelt, desto weiter, schneller und größer die Explosion. Ab 20 Prozent Schütteln explodiert die Dose beim Aufprall, kurzes Antippen wirft nur eine ungeschüttelte Dose ohne Explosion. Mit Elementmodul gibt die Dose das Element weiter
- Hexapod: klettert Wände hoch (gegen die Wand drücken, hoch/runter klettern, an der Oberkante hopst er auf den Rand, von der Wand abspringen geht auch). Sein Geschütz schießt schnell (2,8 Schuss pro Sekunde, durchschlägt bis zu 3 Gegner), aber nur im Stand: am Boden oder hängend an der Wand, nach 0,2 Sekunden Aufbauzeit (Beine spreizen sich). Im Gehen, Klettern oder in der Luft schießt er nicht. Waffen aus dem Shop darf er überall nutzen
- Vier Gegnertypen (Läufer, Schütze, Flieger, Brute) ohne Kontaktschaden: Jeder Angriff wird vorher angekündigt (Kegel, Kreis, Schusslinie)
- Director: Gegner erscheinen nach und nach, die Menge und Stärke steigen mit der Zeit
- XP und Gold fallen aus Gegnern, werden angezogen und eingesammelt. XP gehört beiden, Gold dem Einsammler
- Level-Ups mitten im Kampf: drei Team-Perks, beide Spieler müssen dieselbe Karte bestätigen (Links/Rechts wählen, Kreuz bestätigen, Kreis zurück). Jeder Perk wirkt je nach Klasse anders
- Elemente als Module an Waffen (Feuer, Wasser, Eis, Blitz) mit kurzen Statuseffekten und Kombos: Wasser+Blitz (x1,5, Kettenblitz), Wasser+Eis (eingefroren), Wasser+Feuer (Dampfexplosion), Feuer+Eis (schmilzt). Setzt ein anderer Spieler den Status, ist die Kombo deutlich stärker (Coop-Bonus). Zum Testen tragen die Waffen schon Module (Punkt im HUD zeigt das Element)
- Wellen mit Zeitlimit (Standard 120 s, 10 Wellen), danach räumt sich das Feld, alle stehen auf und der Shop öffnet. Jeder kauft persönlich ein: Buffs, Elementmodule, Waffen, Bewegungs-Firmware, Reroll. Nach der letzten Welle erscheint ein Sieg-Bildschirm (der Endboss fehlt noch)
- Bewegungs-Firmware: Doppelsprung, Wandsprung (rutschen und abspringen), Gleitschirm, Bodenstoß, Greifhaken, mehr Dash-Ladungen. Plattformen sind von unten durchlässig, mit nach unten + Sprung fällt man durch
- Spieler-Leben mit Unverwundbarkeit nach Treffer, Wiederbeleben durch Halten von Interagieren (Kreis), Game Over wenn beide am Boden liegen

Waffenwerte stehen in `scripts/data/weapons.gd`, Das Testset steht in `scripts/game/main.gd` (`TEST_LOADOUTS`, `TEST_MODULES`). Ein normaler Lauf startet nur mit der Klassenwaffe.

Welche Klassen gespielt werden, steht in `scripts/game/main.gd` (`PLAYER_CLASSES`).

## Struktur

- `scenes/` Szenen
- `scripts/autoload/` globale Skripte (Eingabe)
- `scripts/data/` Werte und Daten (Klassen)
- `scripts/game/` Spiellogik (Spieler, Projektile, Kamera, Hauptszene)
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
