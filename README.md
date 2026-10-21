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
| Klassenfähigkeit | Quadrat | E | Komma |
| Waffe wechseln | Dreieck | Q | M |
| Haken (Firmware) | L2 | R | N |
| Menüs | Links/Rechts, Kreuz bestätigen, Kreis zurück | A/D, Enter | Pfeile, Num-Enter, Rechts-Shift oder Rechts-Alt |

Interagieren (Kreis / G / L) belebt den Partner (halten). Die Klassenfähigkeit auf Quadrat (Taste E bzw. Komma) hat eine Abklingzeit, die Leiste im HUD zeigt sie. Escape oder Options öffnet die Pause.

Das Spiel startet im Titelbildschirm: Spielen, dann wählt jeder Spieler seine Klasse (Links/Rechts, Kreuz bestätigt, Kreis nimmt zurück). Im Spiel wechseln F4 (Spieler 1) und F5 (Spieler 2) die Klasse (startet die Szene neu).

Debug: F1 und F2 tauschen die aktuelle Waffe von Spieler 1 bzw. 2 gegen die nächste, F3 gibt beiden das komplette Testset (alle Waffen mit Modulen).

## Aktueller Stand

- Testarena mit Plattformen und Schacht, Kamera hält beide Spieler im Bild
- Laufen mit Beschleunigung, Sprung (variable Höhe, Coyote-Time, Eingabepuffer), Dash mit Aufladungen, Iframes und Momentum
- Platzhalter-Klassen Roomba und Hexapod (Hexapod geht beim Schießen nur halb so schnell)
- Sechs Waffen, die sich verschieden anfühlen: Dustgun (sauber, Allrounder), Rapid (sehr schnell, streut mit der Hitze), Scatter (kurze Reichweite, starker Rückstoß), Rocket (lenkende Rakete, beschleunigt, Explosion), Beam (Dauerstrahl, wird mit der Zeit stärker, bremst den Träger beim Halten) und Sniper (Treffer entlang einer Linie, durchschlägt Gegner). Jeder Spieler hat drei zum Ausprobieren, Wechsel per Dreieck. Jeder Spieler hat einen Zielstrahl in seiner Farbe (P1 Cyan, P2 Limette, nie rot)
- Rückmeldung: Mündungsfeuer, Funken, Rückstoß, Kamerawackeln, Explosionen, eigener Sound pro Waffe
- Automat: Dosenwurf im Bogen aus dem Ausgabefach unten. Feuer halten schüttelt die Dose (Ladering, gepunktete Flugbahn), loslassen wirft. Je länger geschüttelt, desto weiter, schneller und größer die Explosion. Ab 20 Prozent Schütteln explodiert die Dose beim Aufprall, kurzes Antippen wirft nur eine ungeschüttelte Dose ohne Explosion. Mit Elementmodul gibt die Dose das Element weiter
- Hexapod: klettert Wände hoch (gegen die Wand drücken, hoch/runter klettern, an der Oberkante hopst er auf den Rand, von der Wand abspringen geht auch). Sein Geschütz schießt schnell (2,8 Schuss pro Sekunde, durchschlägt bis zu 3 Gegner) und überall (Boden, Wand, Decke, Luft), aber solange er mit dem Geschütz feuert, geht und klettert er nur mit halbem Tempo, die Beine spreizen sich (Schiesshaltung, 20 Prozent weniger Schaden). Overwatch hebt die Bremse auf. Waffen aus dem Shop darf er überall nutzen
- Vier Gegnertypen (Läufer, Schütze, Flieger, Brute) ohne Kontaktschaden: Jeder Angriff wird vorher angekündigt (Kegel, Kreis, Schusslinie)
- Director: Gegner erscheinen nach und nach, die Schwierigkeit steigt mit jeder Welle (und stetig innerhalb der Welle), neue Typen schalten sich nach und nach frei. Teure Typen werden vorab gewürfelt und abgewartet, damit sie nicht von billigen verdrängt werden
- XP und Gold fallen aus Gegnern, werden angezogen und eingesammelt. XP gehört beiden, Gold dem Einsammler
- Level-Ups mitten im Kampf: drei Team-Perks, beide Spieler müssen dieselbe Karte bestätigen (Links/Rechts wählen, Kreuz bestätigen, Kreis zurück). Jeder Perk wirkt je nach Klasse anders
- Elemente als Module an Waffen (Feuer, Wasser, Eis, Blitz) mit kurzen Statuseffekten und Kombos: Wasser+Blitz (x1,5, Kettenblitz), Wasser+Eis (eingefroren), Wasser+Feuer (Dampfexplosion), Feuer+Eis (schmilzt). Setzt ein anderer Spieler den Status, ist die Kombo deutlich stärker (Coop-Bonus). Zum Testen tragen die Waffen schon Module (Punkt im HUD zeigt das Element)
- Wellen mit Zeitlimit (Standard 120 s, 10 Wellen), danach räumt sich das Feld, alle stehen auf und der Shop öffnet. Davor schließen sich zwei Metalltore und der Shop öffnet dahinter, beim Weiterspielen öffnen sie sich wieder. Jeder kauft persönlich ein: Buffs, Elementmodule, Waffen, Bewegungs-Firmware, Reroll. Bei Waffen und Modulen wählt man den Slot selbst (welche Waffe ersetzt wird, welche Waffe das Modul bekommt), und jedes Modul zeigt, was es macht. Nach der letzten Welle erscheint ein Sieg-Bildschirm (der Endboss fehlt noch)
- Bewegungs-Firmware: Doppelsprung, Wandsprung (rutschen und abspringen), Gleitschirm, Bodenstoß, Greifhaken, mehr Dash-Ladungen. Plattformen sind von unten durchlässig, mit nach unten + Sprung fällt man durch
- Klassenfähigkeiten auf Quadrat: Roomba Vortex (zieht Gegner und Beute zu einem Brennpunkt vor ihm, betäubt sie, und sprengt sie am Ende weg, sie kommen ihm nie ins Gesicht), Hexapod Overwatch (4 s doppelte Feuerrate, auch in Bewegung), Automat Walze (3 s schneller, halber Schaden, rammt Gegner), Drucker Druck (zwei Drohnen mit Explosivschüssen, übernehmen das Element-Modul der aktiven Waffe; jeder Kill verkürzt die Abklingzeit um 0,3 s)
- Sechs Gegnertypen (Grunt, Gunner, Buzzer, Brute, Ramtank, Mortar): dazu Ramtank (kündigt einen Ansturm an, der Schaden macht, wenn man im Weg steht) und Mortar (Warnkreis am Boden, dann Einschlag). Ab etwa einer Minute erscheinen Elites: größer, zäher, goldene Aura, viel Beute und ein Reparaturkit
- Reparaturkits (grünes Kreuz) heilen den Spieler, der sie braucht. Treffer erzeugen Kamerawackeln, roten Bildschirmrand und einen kurzen Hitstop
- Dreizehn Perks mit Symbolen, darunter Glückschip (Crit), Notstrom (Heilung pro Kill), Durchschlag, Sprengkapsel (Kettenexplosionen) und Kühlkreislauf (Fähigkeit lädt schneller)
- Endboss "Smelter" nach Welle 10 (nach einem letzten Shop): Die Halle wird zum Laufband-Ofen. Das Band zieht alles am Boden nach links in den Verbrennungsofen (Feuer, 30 Schaden). Der Boss rechts schickt Hindernisse aufs Band: Kisten und Stapel (springen, mit Anlauf), rollende Sägen (springen) und hängende Träger (drunter durchlaufen). Plattformen über dem Band sind sicher. Dazu Feuersalven mit Zielstrahl, Ascheregen mit Warnkreisen und ab Phase 3 Schweißdrohnen. Sein Panzer nimmt nur 25 Prozent Schaden, nur im Vent (Kern offen) volle. Hydro +50 Prozent, Cryo +25 Prozent, Pyro -40 Prozent. Bei 66 und 33 Prozent Leben wechselt die Phase, das Band wird schneller
- Garage im Hauptmenü: Am Ende jedes Laufs gibt es Chips (mehr für Wellen, Kills, Stufe und den Boss). Damit kauft man dauerhafte Upgrades (Leben, Schaden, Startgold, Erfahrung, Tempo, gratis Reroll) und schaltet Automat, Drucker und weitere Waffen frei. Der Spielstand liegt in `user://ares_save.json`
- Elites haben eine Art mit eigener Mechanik: Inferno (legt Feuerherde), Bulwark (Schild), Stormer (Blitzfächer), Frostbite (bremst in der Nähe)
- Wellen-Modifikatoren ab Welle 2: Swarm, Elite Rush, Heavy Metal, Air Raid, Overdrive. Der Shop bietet auch Reparaturen, und jeder Kauf macht weitere teurer
- Perk Cable Link: nah beim Partner mehr Schaden und Regeneration
- Musik wird im Code erzeugt. Optionen (Titel- und Pausemenü): Lautstärke für Gesamt, Musik und Effekte in Stufen, Bildschirmwackeln (Aus bis Stark), Schadenszahlen, Controller-Vibration und Vollbild (auch per F11). Alles wird im Spielstand gemerkt. Im eingebetteten Spiel-Fenster des Godot-Editors geht das nicht (Fenster bleibt 1600x900): dort "Spiel einbetten" ausschalten oder das Spiel eigenständig starten (update.bat)
- Karten im Stil von Risk of Rain 1: große, mehrstöckige Hallen (6400 x 2200) mit dicken Felsmassen, Rampen, Durchsprung-Stegen, schwebenden Inseln und Kletterseilen. Drei Karten (Rostbecken, Kavernen, Zickzack), pro Lauf zufällige Reihenfolge und Spiegelung, alle drei Wellen wechselt die Karte. Seile: Hoch oder Runter in der Nähe greift zu, Sprung löst sich seitlich, oben hopst man auf den Rand. Bodengegner laufen über Rampen, Flieger kommen aus den Luftbereichen. Die Kamera hält beide Spieler im Bild (Abstandsleine 3000 x 1500). Die alte flache Halle bleibt als Karte "classic" für die Tests (`main.stage_id = "classic"`)
- Wellenübergang: Beim Start fliegt der Wellentitel ein (mit Modifikator), ein Countdown 3, 2, 1 und LOS läuft, erst dann kommen Gegner. Am Ende erscheint WELLE GESCHAFFT mit Besiegt-Zähler und Gold-Bonus
- Schrott: Zerstörte Gegner lassen Mutter, Schraube, Zahnrad oder Blech fallen (höchstens 22 liegen gleichzeitig). Nur der Roomba saugt ihn auf (Nähe, im Vortex weiter weg): 1 XP, 1 Leben und 0,4 s weniger Fähigkeits-Abklingzeit
- Schacht rechts: unten ein Durchgang, im Schacht trägt ein Aufwind nach oben zur Plattform. Hexapod klettert Wände und hält sich auch ohne Richtungseingabe fest
- Soda Bomb (Automat) und Turret (Hexapod) werden nur ihrer Klasse im Shop angeboten. Alle Klassen und Waffen sind in der Testphase freigeschaltet
- Items mit Verhalten (Perks, die das Spiel verändern, nicht nur Zahlen): Frenzy (Kills geben Feuerrate), Arc Coil (Treffer springen weiter), Dash Blast (Dash sprengt), Thorns (Schockwelle bei Treffer), Last Stand (stark bei wenig Leben), Shield Cell (Schild, lädt wieder auf), Recycler (Kills verkürzen die Fähigkeits-Ladezeit), Executioner (mehr Schaden auf Schwache), Close Quarters und Long Shot (Schaden je nach Distanz). Sie erscheinen im Level-Up, im Shop und in Kisten. Was man persönlich gekauft hat, steht als Symbole mit Zähler unter dem Spielerpanel
- Kisten auf den großen Karten (wie in Risk of Rain): Mit Gold und Interagieren (Kreis, G, L) aufmachen, drin steckt ein zufälliges Item für den, der sie öffnet. Zwei bis vier liegen verteilt, dazu pro Karte eine große Goldkiste am entlegensten Punkt, die mehr kostet und immer ein Verhaltens-Item enthält. Preise steigen mit der Welle und mit jeder geöffneten Kiste. Außerhalb des Bildes zeigt ein Pfeil am Rand mit Preis, wo eine liegt. Wiederbeleben hat Vorrang vor Öffnen
- Altäre auf den Karten (wie die Schreine in Risk of Rain, je dreimal nutzbar): Blutaltar tauscht 30 Prozent der maximalen Leben gegen Gold (nur mit genug Leben, passt zu Last Stand), Glücksaltar kostet Gold und gibt mit 55 Prozent Chance ein Item, sonst eine Niete, jede Nutzung macht ihn teurer. Einer pro Karte, ab Welle 4 zwei
- Neue Gegner: Sprengi (rennt schnell los und sprengt sich nach kurzer Warnung selbst, gibt nur Beute und zählt nur, wenn man ihn vorher abschießt) und Medic (hält Abstand, läuft zu verwundeten Gegnern und heilt bis zu fünf davon um 30 Prozent, Wächter nur schwach; grüner Ring und Linien zeigen, wen er heilt, zuerst ausschalten). Sie erscheinen ab etwa der dritten (Sprengi) und vierten Welle (Medic)
- Schwierigkeit (Titelmenü, wird gespeichert): Rookie (Gegner 25 % weniger Leben, 30 % weniger Schaden, Chips x0,6), Normal, Hardcore (35 % mehr Leben, 30 % mehr Schaden, schnellere Spawns, Chips x1,7)
- Vertragswahl: Vor jeder Welle ab Welle 2 (nicht vor der letzten und dem Boss) wählen beide Spieler wie beim Level-Up einen von drei Verträgen: der sichere Standard oder zwei riskante Modifikatoren (Swarm, Elite Rush, Heavy Metal, Air Raid, Overdrive) mit Gold-Prämie (Swarm +30 %, Elite Rush +50 %, Air Raid +25 %, Overdrive +35 %, Heavy Metal doppeltes Gold). Die Tore bleiben währenddessen zu, die Karte baut sich dahinter auf. Die Prämie gilt nur für gewählte Verträge. Auch der Endboss folgt der Schwierigkeitsstufe
- Karten haben ihren Charakter: Rostbecken (viele Bodengegner), Kavernen (viele Flieger und Sprengis), Zickzack (Schützen, Mörser, Medics). Ein Banner nennt Karte und Eigenart beim Wechsel. Der Ergebnisbildschirm zeigt die gesammelten Items
- Wächter: In der letzten Welle jeder Karte (Welle 3 Brute, Welle 6 Rammtank, Welle 9 Mörser) erscheint nach etwa einem Drittel der Zeit ein Mini-Boss, eine übergroße Elite mit eigener Lebensleiste oben, Banner und Pfeil am Rand. Wer ihn besiegt, bekommt an seiner Stelle eine Gratis-Goldkiste mit Verhaltens-Item, beide Roboter werden repariert und es regnet Gold. Ist die Wellenzeit um und er lebt noch, geht der Kampf in die Verlängerung (keine neuen Gegner, höchstens 90 s), danach entkommt er und es gibt nichts
- Lesbarkeit: Gegnergeschosse sind magentafarbene Stachelbälle mit weißem Kern, dunkler Kontur und Schweif, langsamer als früher (Shooter 360, Flyer 340, Boss 400 bis 480). Schützen zeigen vor dem Schuss eine Zielstrahl-Linie in derselben Farbe, die kurz vor dem Schuss weiß wird, und alle Gegner ein Warndreieck über dem Kopf. Der Hintergrund ist gedämpft, Spieler haben einen weichen Schein in ihrer Farbe, der Hexapod ist heller, Zahlen und Texte haben eine dunkle Kontur
- Druckbot: Begleitdrohnen schießen "Drone Pulse" (langsam, schwach), stark wird er über Waffen, Module und Perks
- Treffer zeigen sich am getroffenen Roboter (roter Ring, Zahl, Aufleuchten) und an seinem HUD-Panel, nicht auf dem ganzen Bild. Das HUD ist größer, mit Fähigkeits-Symbol und XP-Anzeige
- Team-Perks: nach der Wahl Banner, Ring und Wirkungs-Text an beiden Robotern, Perk-Leiste unter der Wellenanzeige. Wählen die Spieler verschiedene Karten, laufen nach 2,5 s alle Karten wie ein Roulette durch (blinkend, wird langsamer), die Gewinnerkarte stoppt, blinkt weiter und trägt "GEWONNEN!"
- Sandbox (Titelmenü): erst Klassen wählen, dann pro Spieler Waffen (bis 3), Module, Firmware und Team-Perks einstellen, dazu Startwelle (bis Endboss), Startgold und Unverwundbarkeit. Sandbox-Läufe geben keine Chips
- Gegner sind ebenfalls poliert: Aufpoppen beim Spawn, Gangwippen, Neigung mit der Fahrt, Zurückzucken bei Treffern, Landestauchung, Mündungsblitz und Rückstoß bei Schüssen, Schlagbogen des Grunts, Rauch und Funken bei wenig Leben, Staub beim Abbremsen des Ramtanks und Trümmerteile (Platten, Räder, Schrauben) beim Tod. Alle Zustände zeigt `tests/pose_sheet.tscn` mit `POSE_CLASS=enemies`
- Hexapod, Vendor, Drucker und Roomba sind animiert und poliert (der Drucker mit Filament-Pistole, Spule, Fortschrittsanzeige, kippt um wenn er am Boden ist, Drohnen mit Rotoren, Aufpoppen und Blinken vor dem Ablauf): Atmen, Gangwippen, Schiesshaltung mit Stabilisatoren, Rückstoß, Hitze, Wand- und Deckenklettern (kopfüber, das Geschütz hängt dann nach unten) mit gedrehtem Körper, Landestauchung, Dash mit Nachbildern der echten Figur, Windlinien, Absprungwolken, Wandrutsch-Funken, Haken mit Kralle und schwingender Leine, Bodenschlag mit Druckwelle und Kamerawackeln, Umkippen und Aufstehen (ausgeschaltet liegen Automat und Drucker auf dem Rücken, Roomba und Hexapod auf dem Panzer). Der Hexapod steckt beim Schießen 20 % weniger ein, der Vendor wird kaum zurückgestoßen und lässt den Boden beben. Eine Pose-Tafel (`tests/pose_sheet.tscn`, `POSE_CLASS=vending`) zeigt alle Zustände
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
