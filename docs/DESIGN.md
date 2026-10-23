# Robros: Design-Zusammenfassung

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

Elemente kommen über Module in Waffen (siehe Waffen und Waffenrad), nicht über Klassen oder ein Rad. Jedes Element ist an Geschoss, Treffer und Ziel sichtbar, jedes Elementpaar hat genau eine Kombo (siehe Elements.COMBOS und Kombos weiter unten).

- Statuseffekte halten nur kurz (Startwert Vorschlag: etwa 2 bis 3 Sekunden, später tunen)
- Sechs Kombos (je Paar eine): Dampf (Wasser+Feuer), Einfrieren (Wasser+Eis, spröde und Zersplittern), Stromschlag (Wasser+Blitz), Schmelze (Feuer+Eis), Überlast (Feuer+Blitz, Explosion), Kurzschluss (Eis+Blitz, Lähmung). Alle melden sich mit Namen, Ring und Teilchen am Ziel, bei Koop mit goldener Zeile
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
- Jede Klasse hat fünf eigene Waffen (Klassenset), die nur sie benutzen darf, dazu vier allgemeine (Rapid, Scatter, Rocket, Beam). Die Sets betonen die Rolle: Roomba nah und schnell (Schwung, Scheibe, Sog, Blitz), Hexapod Position und Fallen (Geschütz, Sniper, Salve, Minen, Gespinst), Vendor Wucht (Flammen, Dosen, Münzen, Turm), Printer Unterstützung und Drohnen (Sprengdrohnen, Tonerwolke, Markierung, Betäubung)
- Magazin und Nachladen: pro Waffe Magazin und Nachladezeit, automatisches Nachladen bei leerem Magazin, Teil-Nachladen nach Pause, Feuer unterbricht es. Alle Waffenwerte sind über Upgrade-Items steigerbar (Projektile, Tempo, Reichweite, Präzision, Explosion, Crit-Schaden, Wucht, Abpraller, Zielsuche, Munition, Magazin, Nachladen). Ein Zusatzprojektil zählt zu 60 Prozent zum Gesamtschaden, damit +1 nicht verdoppelt
- Waffen mit festem Standard-Element (Zapper Volt, Flamer Pyro) bekommen Wasser-Kombos mit dem Partner; ein Modul ersetzt das feste Element
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
- Archetyp: Beschwörer (Schwarm, Utility)
- Schuss kommt aus dem Druckkopf in der Mitte (früher aus zwei seitlichen Begleitdrohnen, das machte Zielen schwer)
- Diener (scripts/data/minions.gd): Printling (druckt sich alle 6 s nach, bis 3, schießt), Gnat (Beißer, 7 s, von der Waffe Gnat Swarm), Warbot (Kampfdrohne, 13 s, von der Fähigkeit). Alle haben Leben und eine Lebensdauer und sterben durch Gegnertreffer oder Ablauf
- Diener lenken Gegner ab: ein naher Diener wird bevorzugt angegriffen, Bodengegner aber nur, wenn sie ihn erreichen können (sonst stünden sie darunter und warteten)
- Pfade: Blitzdrohnen, Bomber, Feuer. Drohnen übernehmen das Element-Modul und zählen als zusätzliche Quellen für Item-Procs

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
- 24 Waffen (vier allgemeine, je fünf pro Klasse) mit Rückstoß, Screenshake, Sounds; Waffenwechsel per Taste (bis 3 Waffen); Magazin und Nachladen; zwölf Waffen-Upgrade-Items
- Elementmodule und Status (nass, brennend, verlangsamt, eingefroren) mit sechs Kombos; Coop-Bonus bei Status von einem und Auslöser von anderem Spieler
- Vier Gegnertypen ohne Kontaktschaden, Angriffe mit Vorwarnung; Director mit steigender Menge und Stärke
- Spieler-Leben, Iframes nach Treffer, Wiederbeleben durch Halten, Game Over
- XP und Gold als Pickups, Level-Ups mit gemeinsamer Team-Perk-Wahl (klassenabhängige Wirkung)
- Wellen mit Zeitlimit und Shop (Buffs, Module, Waffen, Firmware, Reroll), Sieg-Bildschirm
- Bewegungs-Firmware: Doppelsprung, Wandsprung, Gleiten, Bodenstoß, Greifhaken, Dash-Ladungen, Jet Boots, Turbo Legs, Spring Legs, Blade Dash, Long Dash; durchlässige Plattformen
- Titelbildschirm mit Klassenauswahl, Pausemenü, Ergebnisbildschirm
- Klassenfähigkeiten auf L2: Sog, Overwatch, Walze, Druck (Drohnen)
- Gegner: Rammbock (Ansturm) und Mörser (Flächenschlag) zusätzlich, Elites (größer, zäher, mehr Beute), Reparaturkits
- Perks mit Procs: Crit, Heilung pro Kill, Durchschlag, Kettenexplosion, Fähigkeits-Ladezeit
- Treffer-Rückmeldung: Wackeln, roter Rand, Hitstop
- Endboss "Smelter" mit Laufband-Ofen, Hindernissen (Kiste, Stapel, Säge, Träger), Panzer/Kern-Mechanik, drei Phasen, Elementschwäche (Wasser, Eis)

Noch offen:
- Roomba saugt noch keine Beute-Kategorien (Müll als Munition)
- Weitere Bosse für die Zwischenbereiche, Boss-Balance durch echte Spieltests, Elites mit Element und Mechanik (aktuell nur größer und zäher)
- Item-System mit Procs und Stacking, Team-Items (Kabelbaum u.a.)
- Perma-Progression und Meta-Menü, Musik
- Balancing durch Spieltests

## Designregeln und Entscheidungen (Runde Risk of Rain und Roguelike-Regeln)

Grundlage: Risk of Rain 1 (Karten erkunden, Kisten und Altäre gegen Gold, steigende Schwierigkeit mit der Zeit, stapelbare Items) und allgemeine Roguelike-Regeln (bedeutsame Entscheidungen ohne dominante Antwort, Risiko gegen Belohnung, Synergien, Niederlagen nachvollziehbar, Schwierigkeit als Kurve statt Zahl).

Was wir daraus gemacht haben:
- Bedeutsame Entscheidungen: Vertragswahl vor jeder Welle (sicherer Standard gegen zwei riskante Modifikatoren mit Gold-Prämie), Slot-Wahl im Shop, Items mit Verhalten statt nur Prozentwerten
- Risiko gegen Belohnung: Verträge, die große Goldkiste am entlegensten Punkt der Karte, der Wächter am Ende jeder Karte (Brute, Rammtank, Mörser), Schwierigkeitsstufen mit Chips-Faktor (Rookie x0,6, Hardcore x1,7)
- Erkunden lohnt sich: Altäre (Blut gegen Gold, Glück gegen Item mit Risiko) und Kisten auf den großen Karten (Gold gegen Item, Preis steigt mit Welle und geöffneten Kisten), Randmarker mit Preis, Lichtsäule als Orientierung
- Synergien und Build-Identität: zehn Verhaltens-Perks (Frenzy, Arc Coil, Dash Blast, Thorns, Last Stand, Shield Cell, Recycler, Executioner, Close Quarters, Long Shot). Sie stapeln, wirken je nach Klasse unterschiedlich und greifen ineinander (Close Quarters mit Thorns, Executioner mit Arc Coil, Recycler mit Fähigkeiten)
- Spannungskurve: Pro Karte ein Höhepunkt (Wächter in Welle 3, 6, 9), danach Kartenwechsel hinter den Toren, am Ende der Smelter. Wellen mit Modifikatoren bringen Abwechslung dazwischen
- Niederlagen nachvollziehbar: Gegnergeschosse haben eine eigene Form und Farbe, Zielstrahl und Warndreieck vor jedem Angriff, langsamere Geschosse, Medic und Sprengi sind erkennbare Prioritätsziele
- Wiederspielwert: Kartenreihenfolge und Spiegelung zufällig, jede Karte bevorzugt eigene Gegnertypen, Schwierigkeitsstufen, Sandbox zum Ausprobieren
- Coop: Items und Kisten sind persönlich, Verträge und Level-Up-Perks gemeinsam. Wiederbeleben hat Vorrang vor Kisten öffnen. Die Wächterbeute bekommt, wer sie holt, sonst der Nächste

Offene Punkte nach dieser Runde:
- Balance ist geschätzt, nur der Bot (der Hindernissen kaum ausweicht) und Tests sind Maßstab. Echte Spieltests entscheiden über Preise, Prämien und Gegnerwerte
- Items nach Seltenheit stufen und im Shop sichtbar machen
- Freischaltungen über Herausforderungen statt nur über Chips

## Runde Politur und Tiefe (Optionen, Hinweise, Archiv, Erfolge, neue Gegner)

Grundlage: Was ein Spiel von einem Prototyp trennt, ist selten ein Feature, sondern Lesbarkeit, Einstieg, Rückmeldung und Gründe wiederzukommen.

- Optionen für alles, was Spieler verschieden wollen: Lautstärke (Gesamt, Musik, Effekte) in Stufen mit der alten Mischung als Standard, Bildschirmwackeln in vier Stufen, Schadenszahlen, Controller-Vibration, Hinweise, Vollbild. Gemeinsame Seite für Titel und Pause, Werte im Spielstand, nur Lautstärke wiederholt sich beim Halten
- Einstieg ohne Tutorial-Level: Einmalige Hinweise (Kiste, Altäre, Wiederbeleben, erster Treffer ohne Dash, Medic, Sprengi, Aegis, Nest, Elite) erscheinen erst, wenn das Thema auftaucht, nacheinander, nie über der Steuerungsübersicht oder in Menüs
- Rückmeldung über Klang: Jede neue Mechanik hat einen eigenen Klang (Kiste, Ablehnen statt Schadens-Sound, Altäre, Wächter-Horn, Medic, Zündschnur, Vertrag, Tore, Countdown, Fanfare, Abpraller am Schild). Ein Test prüft, dass jeder Klang im Code existiert und nicht übersteuert
- Gründe wiederzukommen: Archiv (Items, Gegner, Waffen entdecken, Zähler besiegter Gegner, Meldung bei Neuem) und 22 Erfolge mit einmaliger Chips-Belohnung. Erfolge belohnen Spielweise statt Grind (Welle ohne Treffer, Zangengriff, Boss auf Hardcore, Speedrun, Kisten und Altäre)
- Gegnervielfalt über Konter statt Zahlen: Aegis zwingt zu Position und Zusammenspiel (Zangengriff, Sprengungen, von oben, durchdashen), Nest zwingt zur Priorität (Quelle zerstören statt Nachschub bekämpfen)
- Wiederspielwert über das Ende hinaus: Endlosmodus nach dem Boss mit Rekord, Chips je Welle und zwei Erfolgen
- Feinschliff: Überblendungen zwischen Szenen, Versionsnummer, Credits mit Godot-Lizenzhinweis, Icon

Messung statt Bauchgefühl bei Leistung: Das Gegner-Skript kostet bei 60 Gegnern rund 1,5 ms pro Frame, der Rest ist Engine-Grundlast, daher keine Umbauten.

Offene Punkte:
- Balance der neuen Gegner und der Erfolgs-Belohnungen ist geschätzt
- Englische Texte fehlen (alle Texte stehen im Code, ein Übersetzungs-Layer wäre eine eigene Aufgabe)
- Endlosmodus nutzt dieselbe Gegnerkurve weiter (kein eigener Schwierigkeitsdeckel), ein Gegnerlimit von 200 und die Leistung dort sind ungeprüft über Welle 20

## Runde Waffen, Elemente und Boden (Klassensets, Magazin, Kombos, Neigung)

Grundlage: Klassen sollen sich nicht nur über Werte, sondern über die Art zu kämpfen unterscheiden, und jedes Element muss man sehen, nicht nur im Text lesen.

- Klassensets: Jede Klasse hat genau fünf eigene Waffen, die sonst niemand benutzen darf. Die Sets folgen der Rolle: Roomba nah und schnell (Schwung, Scheibe, Sog, Blitz), Hexapod Position und Fallen (Geschütz, Sniper, Salve, Minen, Gespinst), Vendor Wucht (Flammen, Dosen, Münzen, Turm), Printbot Unterstützung (Sprengdrohnen, Tonerwolke, Markierung, Betäubung). Vier allgemeine Waffen bleiben für alle, damit ein Wechsel der Rolle möglich ist
- Neue Waffenarten statt neuer Zahlen: Schwung, Sog, Kettenblitz, Boomerang, Salve, ablegbare Minen und Türme, Wolken. Jede Art hat eigene Lesbarkeit (Bogen, Kegel, Blitzlinie, Kontrollring) und mindestens einen Konter-Gedanken (Sweeper gegen Aegis, Sog gegen Gruppen, Labeler für Teamschaden)
- Magazin statt Dauerfeuer: Jede Waffe hat Magazin und Nachladezeit, damit Waffenwechsel und Upgrades (Magazin, Nachladen, Eco Chip) Entscheidungen werden. Nachladen ist automatisch (leer, oder nach kurzer Pause) und von Hand möglich, Feuer unterbricht ein Teil-Nachladen
- Upgrades für alles: Jede Waffeneigenschaft hat ein Item. Zusatzprojektile zählen zu 60 Prozent zum Gesamtschaden (beim Printbot geben sie mehr Diener). Die Wirkung ist je Waffenart sinnvoll übersetzt (Sweeper: breiterer Bogen, Zapper: mehr Sprünge, Mine: mehr Minen, Strahlen: Fächer und Zielhilfe)
- Elemente sichtbar: Spur am Geschoss, Treffer-Teilchen, Zustand am Gegner mit kurzer Meldung. Sechs Kombos, jedes Paar hat genau eine, jede mit Name, Ring, Teilchen und Klang, bei Koop mit goldener Zeile
- Boden: Spieler und Bodengegner stellen sich auf Rampen parallel zur Fläche, Flieger bleiben frei. Nur die Zeichnung neigt sich, die Kollisionsform bleibt gleich (Physik unverändert)
- Statuswirkungen aus Waffen sind begrenzt: Betäubung hat danach eine Immunitätszeit, Bosse nehmen nur die Markierung an, gefrorene Ziele sind spröde, damit Kontrolle nie zur Dauerlähmung wird
- Balance per Messung: tests/weapon_bench.tscn misst den Schaden pro Sekunde je Waffe gegen ein Ziel und acht Ziele (Echtzeit, ohne Klassenfaktor). Erste Runde: Sweeper 22 Schaden, Sixpack-Explosion 20, Toner 14 pro Sekunde in der Wolke, Paperjam 5, Mine 60 Schaden bei Radius 120, Dispenser und Mine mit eigener Wurfkraft (Schlüssel lift). Streuung ist hoch, Werte nur zum Vergleichen


## Runde Solo, Beschwörer und Beweglichkeit

- Solo: Ein Eintrag in der Klassenliste heißt Solo, zwei heißen Koop. Alles, was zwei Spieler voraussetzte, arbeitet mit der Zahl der Spieler (HUD, Shop, Level-Up mit gespiegeltem Zeiger, Ergebnis, Kamera). Ausgleich ohne Partner: 50 Leben mehr, 55 Prozent der Gegner-Punkte und 75 Prozent des Gegnerlimits im Director. Allein am Boden ist sofort Game Over
- Kamera und Gefallene: Die Kamera folgt nur Stehenden und lässt Gefallene los. Ein Pfeil am Bildrand in der Farbe des Gefallenen zeigt, wohin man zum Wiederbeleben laufen muss, mit dem Fortschrittsring
- Die Spielzeit friert bei Game Over ein, damit das Ergebnis den Moment des Ausfalls zeigt
- Mobilität: Neue Firmware Jet Boots, Turbo Legs, Spring Legs, Blade Dash, Long Dash, dazu drei Stufen für Double Jump und Dash Cell. Jede hat eine eigene Wirkung statt eines reinen Zahlenbonus (Schub mit Tank, Schaden im Dash, weitere Sprünge). Firmware erscheint im Shop häufiger (35 Prozent in den ersten drei Wellen, danach 18)

## Runde Endboss, Rand-Pfeile, Zielstrahl

- Endboss: Das Band läuft zum Boss statt vom Boss weg, die Plattformen sind weg. Der Boss ist der Fresser: Der Schredder vor ihm gibt fetten Schaden mit Rückstoß statt Instakill. Hindernisse rollen von links ein (1000 px vor dem linken Spieler, außerhalb des Bildes) und sind etwas schneller als das Band, Lasten fallen mit Warnstreifen von der Decke, der Boss ruft in jeder Phase Verstärkung. Das Band zieht von selbst bis plus 25 an, damit der Druck steigt, ohne die langsamste Klasse (Vendor, 220) abzuhängen
- Unsichtbare Begrenzungen (Ebene 8) zählen nicht als Wand: Klettern und Wandsprung gehen nur an sichtbaren Wänden
- Rote Pfeile am Bildrand zeigen Gegner außerhalb des Bildes (bis 1700 px, höchstens zehn, nahe Gegner in einer Richtung teilen sich einen größeren Pfeil, Elites golden umrandet)
- Zielstrahl der Spieler ist deutlich blasser und wird beim Schießen noch blasser, damit man die Schüsse sieht
- Karten kompakter: Die Entwürfe (6400 x 2200) werden beim Bau mit STAGE_SCALE 0,55 verkleinert, Stege behalten ihre Dicke und Seile ihre Breite. Abstände für Kisten, Altäre, Bodenpunkte und Startabstand folgen dem Maßstab, ein paar Stege mehr füllen die langen leeren Strecken (Rostbecken über den Rampen, Zickzack im unteren Gang). Zum Nachstellen genügt die eine Zahl
- Boss-Kisten blocken nur: 112 px breit statt 72, kein Kontaktschaden, eigene Kollisionsebene 9 (nur Spieler stoßen daran, Geschosse und Gegner nicht). Sie schieben Spieler vor sich her, wer oben steht, fährt mit. Schaden machen im Bosskampf nur Sägen, Träger, der Einschlag einer fallenden Last und der Schredder. Gefressen werden Hindernisse schon vor dem Schredder, damit keine Kiste jemanden an die Wand quetscht

## Runde Eine Karte, langsamer, lesbarer

- Es gibt nur noch eine Karte (Werkhalle): durchgehender Boden, zwei sanfte Hügel statt Wänden, Stege auf drei Ebenen und ein langer oberer Steg mit drei Seilen. Nichts trennt die Halle in Abschnitte. Die alten Entwürfe (Rostbecken, Kavernen, Zickzack) bleiben im Code, sind aber nicht in IDS
- Tempo rund 20 Prozent niedriger (Spieler, Gegner, Gegnergeschosse, Dash, Band), Kamera zoomt höchstens 1,0 statt 1,3, damit alles kleiner wirkt und man ausweichen muss
- Schützen zeigen den Schussweg bis zur ersten Wand mit Endmarke
