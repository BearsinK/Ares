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

Die übrigen Aktionen (Klassenfähigkeit, Haken, Interagieren) sind schon belegt, haben aber noch keine Funktion.

Debug: F1 und F2 tauschen die aktuelle Waffe von Spieler 1 bzw. 2 gegen die nächste.

## Aktueller Stand

- Testarena mit Plattformen und Schacht, Kamera hält beide Spieler im Bild
- Laufen mit Beschleunigung, Sprung (variable Höhe, Coyote-Time, Eingabepuffer), Dash mit Aufladungen, Iframes und Momentum
- Platzhalter-Klassen Roomba und Hexapod (Hexapod schießt nur im Stand)
- Sechs Waffen: Staubkugeln, Schnellfeuer, Schrot, Rakete (Explosion), Strahl und Sniper (Treffer entlang einer Linie, durchschlägt Gegner). Jeder Spieler hat drei zum Ausprobieren, Wechsel per Dreieck
- Rückmeldung: Mündungsfeuer, Funken, Rückstoß, Kamerawackeln, Explosionen, eigener Sound pro Waffe
- Vier Gegnertypen (Läufer, Schütze, Flieger, Brute) ohne Kontaktschaden: Jeder Angriff wird vorher angekündigt (Kegel, Kreis, Schusslinie)
- Director: Gegner erscheinen nach und nach, die Menge und Stärke steigen mit der Zeit
- Spieler-Leben mit Unverwundbarkeit nach Treffer, Wiederbeleben durch Halten von Interagieren (Kreis), Game Over wenn beide am Boden liegen

Waffenwerte stehen in `scripts/data/weapons.gd`, Welche Waffen ein Spieler zum Testen hat, in `scripts/game/main.gd` (`TEST_LOADOUTS`).

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
