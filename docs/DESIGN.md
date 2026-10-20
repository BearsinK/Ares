# Ares: Design-Zusammenfassung

Stand: Prototyp läuft (siehe Abschnitt Umsetzungsstand am Ende). Alles hier ist ein Entwurf und kann sich ändern.
Markiert mit (Vorschlag) ist, was noch nicht bestätigt wurde.

## Eckdaten

- 2 Spieler lokal an einem PC, beide mit Controller (PS5 DualSense), Windows
- Engine: Godot 4 (GDScript), läuft lokal, kein Browser
- Erst 2D Seitenansicht (Action-Plattformer). 3D wäre später reizvoll, Spiellogik soll deshalb getrennt von Darstellung und Steuerung bleiben
- Roguelike mit Runs und Perma-Progression zwischen den Runs
- Nur 2 Spieler, kein Solo-Modus
- Privates Projekt nur zum Spaß, keine Veröffentlichung geplant (Lizenzen und Marken weniger kritisch, trotzdem keine echten Logos)
- Zielen mit dem rechten Stick, frei in 360 Grad
- Kein Friendly Fire, Spieler laufen durcheinander
- Eine feste Schwierigkeit, Balancing später
- Fokus: Upgrades, Elemente, Synergien, Chaos durch Stacking (Risk of Rain 2 als Vorbild)

## Setting

- Roboter, die sich Upgrades kaufen und per Firmware neue Skills lernen
- Humor und lustige Details kommen später
- Story-Rahmen: Die Roboter (Haushaltsgeräte und Maschinen) werden lebendig. Wie, ist offen: Wackelaugen oder LCD-Gesichter (Referenz: Roboter mit Display-Gesichtern aus leuchtenden Augen und Lächeln). Der Rest der Fabrik versucht, sie auszuschalten
- Gegner: Sicherheitsbots, Förderband-Roboter, Drohnen, Qualitätskontrolle (Vorschlag)
- Bosse: Fabrikbereiche und ihre Wächter, z.B. Presse, Schweißarm, Kühlanlage, Serverraum, am Ende die Fabrik-KI oder der Chef (Vorschlag)
- Item-Idee: Firmware-Updates, Perma-Währung (Name offen, z.B. Gesichts-Chips oder Wackelaugen)
- Ton: bunt und humorvoll
- Optik: im Code gezeichnete Sprites in Seitenansicht (kein Asset-Import). Wer was ist, zeigt Form, Farbe, LCD-Gesicht und Spielermarke über dem Kopf. Roomba flach, Automat groß
- Keine echten Marken oder Logos, nur erfundene

## Gegner

Erste Gegnertypen für den Prototyp (Namen im Fabrikthema sind Vorschlag):

1. **Läufer:** läuft auf die Spieler zu und greift im Nahkampf an. Die Masse
2. **Schütze:** hält Abstand, zielt und schießt Projektile. Kurz vor dem Schuss zeigt er die Schusslinie an (Telegraph), damit man ausweichen kann
3. **Flieger:** wie der Schütze, aber fliegt frei und ist beweglicher
4. **Brute:** tanky Nahkämpfer mit hohem Schaden und wenigen starken Angriffen, denen man ausweichen muss (klares Vorzeichen vor dem Schlag)
5. **Bosse:** siehe Boss-Typen

- Der Brute ist für den Roomba nicht saugbar
- Elites sind keine reinen Stat-Boosts, sondern bekommen ein Element und eine Mechanik (z.B. brennend, geladen, schildtragend)
- Offen: Haben Gegner Elementschwächen, sind Elites saugbar

## Kampfkollision

- Kein Kontaktschaden: Gegner verletzen nur über Angriffs-Hitboxen (Schlag, Projektil), nicht durch Berühren
- Kein Gegner blockiert die Spieler, auch nicht Brutes, Elites und Bosse. Man bewegt sich frei durch alle Gegner
- Der Dash (Iframes) dient dazu, große Angriffsbereiche und Projektile zu durchqueren. Bei großen Gegnern muss man ab und zu durch ihren Angriffsbereich hindurch
- Nach einem Treffer hat der Spieler kurz Unverwundbarkeit (Iframes, Startwert Vorschlag 0,6 bis 1 Sekunde, mit Blinken). Zusätzlich hat der Dash eigene Iframes
- Folge: Nahkampf-Gegner brauchen echte Angriffsanimationen mit Vorwarnung, nicht nur Berührung
- Gefahr: Hunderte Nahkämpfer in einem Haufen greifen gleichzeitig an. Lösung (Vorschlag): Angriffs-Cooldowns und begrenzte Zahl gleichzeitiger Angreifer

## Run-Struktur

- Ein Run dauert etwa 40 bis 60 Minuten
- Etwa 10 Wellen à 3 bis 5 Minuten im Wechsel mit Shop-Pause, Boss alle paar Wellen
- Der Run endet mit einem Endboss nach der letzten Welle (Sieg). Optionaler Endlos-Modus später
- Bosse: Bullet-Hell mit eindeutigen Mustern
- Jeder Boss hat eine Elementschwäche und zusätzlich Schwachpunkte, die den Schaden vervielfachen (etwa x1,5)
- Schwachpunkte sind nur in bestimmten Phasen oder Mustern erreichbar (Vorschlag)
- Gegner spawnen nach und nach über einen Director (Punktesystem wie in Risk of Rain), nicht alle auf einmal
- Schwierigkeit steigt kontinuierlich mit der Zeit
- Viele Gegner, wenig Typen: 4 bis 6 Typen plus Elites und Boss
- Obergrenze gleichzeitiger Gegner: etwa 200 bis 400 (1000 ist zu viel)
- Bodengegner patrouillieren oder springen auf Plattformen, Flieger jagen frei und stellen die Masse (Vorschlag)

## Progression

Zwei getrennte Systeme, beide liefern Skills und Buffs.

**Level-Up (XP, gemeinsam)**
- XP kommt von Gegnern, Level-Ups passieren mitten in der Runde
- Team-Perks: gelten für beide, wirken aber je nach Klasse und Element unterschiedlich und geben spielerspezifische Interaktionen
- Gemeinsame Wahl: ihr einigt euch auf eine Karte

**Gold (pro Spieler)**
- Gold gehört dem Spieler, der es einsammelt
- Einkauf im Shop zwischen den Wellen, jeder wählt seine eigenen Skills und Buffs
- Jeder Spieler bekommt 4 bis 5 Angebote, Reroll gegen Gold, Preise steigen mit der Welle
- Bezeichnung des Golds im Setting: z.B. Schrott oder Chips (Vorschlag)

**Perma-Progression**
- Ausgabe der Perma-Währung in einem einfachen Menü zwischen den Runs (Hub später möglich)
- Neue Items und Firmware werden freigeschaltet (Pool wächst durch Erfolge)
- Passive Dauer-Buffs
- Manche Upgrades sind schon am Start eines Runs vorhanden. Damit Klassen weiter gleich anfangen, bleibt das klein (Vorschlag: ein Item aus drei zur Wahl)
- Alle vier Klassen sind von Anfang an spielbar

## Elemente und Synergien

Elemente kommen über Module in Waffen (siehe Waffen und Waffenrad), nicht über Klassen oder ein Rad.

- Statuseffekte halten nur kurz (Startwert Vorschlag: etwa 2 bis 3 Sekunden, später tunen)
- Coop-Bonus: Wird ein Gegner von zwei verschiedenen Spielern mit zwei Elementen behandelt, ist die Kombo deutlich stärker als wenn ein Spieler beide selbst setzt
- Ziel: Zusammenarbeit lohnt sich, Solo-Kombos durch Waffenwechsel bleiben möglich, aber schwächer

Vier Elemente: Feuer, Wasser, Eis, Blitz. Status liegen auf dem Gegner, egal welcher Spieler sie gesetzt hat (Vorschlag):

| Kombination | Wirkung |
|---|---|
| Wasser + Blitz | nasse Gegner nehmen doppelten Blitzschaden, Blitz springt auf weitere nasse Gegner |
| Wasser + Eis | gefroren, Gegner steht still |
| Wasser + Feuer | Dampfexplosion |
| Feuer + Eis | schmilzt, hebt beides auf |

## Waffen und Waffenrad

- Jeder Spieler hat bis zu 3 Waffen
- Statt eines Waffenrads gibt es einen Rotate-Button: Waffe 1, dann 2, dann 3, dann wieder 1
- Das Klassenwerkzeug (Geschütz, Dosenwerfer, Drohnendrucker, Saugkegel) bleibt die Basis jeder Klasse
- Weitere Waffen werden im Shop gekauft und liegen im Rad
- Waffentypen: Schnellfeuer, Schrot, Raketen und Granaten, Strahlwaffen (Laser, Flammenwerfer), Präzisionswaffe (Sniper)
- Elemente werden nicht im Rad gewechselt. Waffen sind neutral, Elementmodule werden im Shop in eine Waffe eingebaut
- Im Kampf wechselt man nur die Waffe, der Elementbuild bleibt eine bewusste Shop-Entscheidung
- Maximal ein Modul pro Waffe (Tendenz, damit Coop-Synergien zwischen den Spielern wichtiger bleiben als Solo-Kombos). Zweiter Modul-Slot höchstens als seltene Belohnung (Vorschlag)
- Risiko: Mit mehreren Waffen im Rad kann ein Spieler Elemente selbst kombinieren, indem er die Waffe wechselt. Gegenmittel (beschlossen): Maximal 3 Waffen, Statuseffekte halten nur kurz, und Coop-Kombos bekommen einen Bonus (siehe Elemente und Synergien)
- Steuerung: eine Taste für Rotate, genaue Belegung offen (Schultertaste ist naheliegend, da der rechte Stick zum Zielen belegt ist)
- Items: Allgemeine Stats (Schaden, Tempo) gelten global, Element-Items hängen am Modul (Vorschlag)

## Items und Stacking

- Items stapeln sich, Treffer-, Kill-, Dash- und Zeit-Effekte lösen weitere Effekte aus
- Bewusst extrem: Bildschirm voller Effekte am Ende eines Runs
- Tiefenbegrenzung bei Proc-Ketten, damit nichts endlos läuft und die Leistung stabil bleibt
- Items haben Tags (Element, Bewegung, Team) und Seltenheiten

## Bewegung

- Alle starten gleich: Laufen und ein einfacher Sprung
- Weitere Optionen kommen als Firmware im Run: Doppelsprung, Wandsprung, Dash (mit Aufladungen und Iframes), Greifhaken, Gleiten, Bodenstoß, Wandabprallen
- Dash ist eine der häufigsten frühen Firmware (Vorschlag), mit Momentum nach dem Dash
- Bewegungs-Firmware ist persönlich und wird im Shop gekauft, erhöhte Chance in den ersten Wellen (Vorschlag)

## Klassen

Alle starten mit demselben Grundkit, unterscheiden sich in Hauptangriff, Klassenfähigkeit und Werten. Jede Klasse hat einen eigenen Spielstil.

### Hexapod
- Archetyp: Sniper oder Turret-Modus, Mobilität, Positionierung ist entscheidend
- Geschütz oben drauf, schießt nur im Stand (umgesetzt: am Boden oder hängend an der Wand, 0,2 s Aufbauzeit, 2,8 Schuss pro Sekunde, durchschlägt bis 3 Gegner)
- Dafür schneller laufen und Wände hochklettern (umgesetzt)
- Muss gegen Massen Durchschlag und Fläche bekommen

### Getränkeautomat auf Panzerketten
- Archetyp: tanky, Flächenschaden (AoE), langsam
- Wirft Dosen im Bogen, geschüttelte Dosen explodieren (umgesetzt: Feuer halten schüttelt und lädt auf, Loslassen wirft, Aufladung bestimmt Wurfweite, Tempo, Explosionsradius und Schaden)
- Walze: Mit genug Beschleunigung wird er zur Walze. Dann verursacht er Schaden durch Kontakt (er ist die Ausnahme vom Kein-Kontaktschaden-Prinzip, aber nur gegen Gegner) und hat etwas Rüstung gegen Nahkampftreffer
- Walze baut Tempo über Anlauf auf, Richtungswechsel kostet Tempo (Vorschlag, damit er trotz Walze langsam bleibt)
- Raupenboost-Firmware ist der Startknopf der Walze (Vorschlag)

### 3D-Drucker
- Archetyp: Schwarm, viele Pfade, Utility
- Zwei Drohnen schweben über ihm als versetzte Waffen
- Druckt explodierende Drohnen, die sich selbst zerstören
- Pfade: Blitzdrohnen, Bomber, Feuer
- Gut für Item-Procs, weil Drohnen zusätzliche Quellen sind

### Roomba mit Arm
- Archetyp: Sauger mit Fähigkeitskopie (Kirby-Prinzip)
- Saugkegel in Blickrichtung: Gegner, Projektile und Gold einsaugen, im Behälter speichern
- Ausspucken: gespeicherter Gegner wird zum Geschoss, Element wird übernommen
- Schlucken: kopiert die Fähigkeit des Gegners für kurze Zeit oder Ladungen
- Basisangriff: kleine Staubkugeln, kein Nahkampf
- Langsamer beim Saugen. Bosse sind nicht saugbar
- Kein Teilen von Kopien an den Partner
- Upgrade-Pfade (Firmware): Konter (Projektile als Salve zurück), Medic (Eingesaugtes heilt den Partner), Wirtschaft (Magnet, Beute-Boost, Gold klauen), mehr Behälter-Slots
- Risiko: braucht viele gute Kopien, Basisangriff muss stark genug sein

## Controller-Belegung (PS5 DualSense, Vorschlag bestätigt)

Beide Daumen liegen auf den Sticks, deshalb liegen zeitkritische Aktionen auf den Schultertasten.

| Taste | Aktion |
|---|---|
| Linker Stick | Bewegen. Stick nach unten plus Sprung in der Luft: Bodenstoß (Firmware) |
| Rechter Stick | Zielen, 360 Grad |
| L1 | Sprung (Doppelsprung, Wandsprung per erneutem Druck) |
| R1 | Dash |
| R2 | Hauptangriff halten (Dauerfeuer) |
| L2 | Klassenfähigkeit (Saugen, Geschütz-Modus, Dose, Drucker) |
| Quadrat | Greifhaken (Firmware) |
| Dreieck | Waffe rotieren |
| Kreis | Interagieren, Wiederbeleben halten |
| Kreuz | Bestätigen im Menü, im Spiel frei |
| D-Pad | Ping und Emotes |
| Options | Pause |
| Touchpad | Item- und Build-Übersicht |

- Aim-Gedächtnis: Die letzte Zielrichtung bleibt etwa 0,25 Sekunden erhalten, wenn der Daumen für eine Face-Taste den Zielstick verlässt
- Alle Belegungen frei umstellbar, Sprung auf Kreuz als Alternative

## Coop

- Synergien zwischen Spielern über Elemente auf Gegnern
- Gefallener Spieler liegt am Boden, der Partner belebt ihn durch Halten in der Nähe wieder
- Beide gleichzeitig am Boden ist Game Over
- Am Wellenende steht jeder automatisch wieder auf (Vorschlag)
- Team-Items und Team-Perks mit spielerspezifischen Effekten

## Karte

- Hybrid aus mehreren handgebauten Arenen mit Variationen (Vorschlag)
- Prototyp: eine Arena, etwa 2 Bildschirme breit und 1,5 hoch, Kamera zeigt beide Spieler
- Kamera folgt beiden mit Zoom, harte Maximaldistanz zwischen den Spielern
- Boss-Arenen können davon abweichen (z.B. scrollender Laufband-Boss)
- Geometrie für jede Bewegungsoption: versetzte Plattformen, hohe Schächte, Lücken, Decken-Anker
- Jede Karte muss ohne Bewegungs-Firmware spielbar sein, Firmware gibt Abkürzungen und Belohnungen

## Prototyp-Umfang (Vorschlag)

- 1 Arena, 2 Klassen (Roomba und Hexapod), etwa 15 Items, 4 Gegnertypen, 1 Boss
- Director-Spawning, Level-Up-System, Shop, Wiederbeleben
- Ziel: Spielgefühl und Synergien prüfen, danach ausbauen

## Boss-Typen

Bosse sind nicht alle gleich. Neben Bullet-Hell-Musterbossen gibt es Umwelt-Bosse mit Verfolgungs-Charakter.

**Beispiel: Laufband-Verbrennungsofen**
- Laufband schiebt die Spieler Richtung Ofen, man muss springen, Wände zerschießen und wegrennen, während man Schaden macht
- Elementschwäche (Vorschlag): Wasser oder Eis. Schwachpunkte: Ofentür, Heizelement
- Fordert Bewegungs-Firmware (Doppelsprung, Dash, Wandsprung)
- Braucht eigene Boss-Arena mit speziellem Layout und gegebenenfalls scrollender Kamera
- Hexapod und Automat brauchen Ruhezonen oder sichere Plattformen, auf denen Stehen und Schießen möglich ist
- Pro Boss entsteht fast ein eigenes Mini-Level, also hoher Aufwand: im Prototyp nur ein Boss

## Auswirkungen der Bullet-Hell-Bosse (Notiz)

- Dash mit Iframes und gute Bewegung sind für Bosskämpfe zentral
- Hexapod (nur im Stand schießen) und Automat (langsam) brauchen Wege, Mustern auszuweichen, z.B. Schutzschild, Teleport oder große Sicherheitszonen im Muster
- Hitboxen der Spieler klein halten, Muster lesbar halten, auch bei viel Effektchaos
- Elementschwäche belohnt Elementkombos der beiden Spieler, Schwachpunkte belohnen präzises Zielen (gut für Hexapod)
- Elementschwäche und Schwachpunkt-Multiplikator stapeln sich. Obergrenze nötig, damit Bosse nicht in Sekunden fallen
- Offen: Treffen Flächenschaden und Drohnen die Schwachpunkte automatisch, oder müssen Spieler zielen?

## Offene Fragen

- Genauer Wert für Statusdauer und Coop-Bonus, später beim Testen
- Wie fügt sich das Klassenwerkzeug (z.B. Saugkegel) in das Waffenrad ein

- Steuerungsbelegung auf dem PS5-Controller (Saugen, Dash, Klassenfähigkeit)
- Dauer der Kopie beim Roomba: Zeit oder Ladungen
- Umfang der Perma-Progression und was genau Freischaltungen auslöst
- Name und Optik des Golds im Setting
- Wie genau Bodengegner auf Plattformen navigieren
- Welche zwei Klassen im Prototyp: Vorschlag Roomba und Hexapod, noch nicht bestätigt

## Umsetzungsstand (Prototyp)

Umgesetzt und automatisch getestet:
- Bewegung (Laufen, variabler Sprung, Dash mit Iframes und Momentum), 2 Spieler, Controller und Tastatur
- Sechs Waffentypen mit Rückstoß, Screenshake, Sounds; Waffenwechsel per Taste (bis 3 Waffen)
- Elementmodule und Status (nass, brennend, verlangsamt, eingefroren) mit den vier Kombos; Coop-Bonus bei Status von einem und Auslöser von anderem Spieler
- Vier Gegnertypen ohne Kontaktschaden, Angriffe mit Vorwarnung; Director mit steigender Menge und Stärke
- Spieler-Leben, Iframes nach Treffer, Wiederbeleben durch Halten, Game Over
- XP und Gold als Pickups, Level-Ups mit gemeinsamer Team-Perk-Wahl (klassenabhängige Wirkung)
- Wellen mit Zeitlimit und Shop (Buffs, Module, Waffen, Firmware, Reroll), Sieg-Bildschirm
- Bewegungs-Firmware: Doppelsprung, Wandsprung, Gleiten, Bodenstoß, Greifhaken, Dash-Ladungen; durchlässige Plattformen

Noch offen:
- Klassenfähigkeiten (L2) und die Klassenmechaniken von Roomba (Müll saugen), Automat (Walze), Drucker (Drohnen), Hexapod (Geschützmodus)
- Bosse (Bullet-Hell, Elementschwäche, Schwachpunkte, Laufband-Ofen), Elites mit Element und Mechanik
- Item-System mit Procs und Stacking, Team-Items (Kabelbaum u.a.)
- Perma-Progression und Meta-Menü, Klassenauswahl, Optik (LCD-Gesichter, Assets)
- Balancing durch Spieltests
