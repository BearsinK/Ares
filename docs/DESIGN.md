# Ares: Design-Zusammenfassung

Stand: Planungsphase, noch kein Code. Alles hier ist ein Entwurf und kann sich ändern.
Markiert mit (Vorschlag) ist, was noch nicht bestätigt wurde.

## Eckdaten

- 2 Spieler lokal an einem PC, beide mit Controller (PS5 DualSense), Windows
- Engine: Godot 4 (GDScript), läuft lokal, kein Browser
- Erst 2D Seitenansicht (Action-Plattformer). 3D wäre später reizvoll, Spiellogik soll deshalb getrennt von Darstellung und Steuerung bleiben
- Roguelike mit Runs und Perma-Progression zwischen den Runs
- Fokus: Upgrades, Elemente, Synergien, Chaos durch Stacking (Risk of Rain 2 als Vorbild)

## Setting

- Roboter, die sich Upgrades kaufen und per Firmware neue Skills lernen
- Humor und lustige Details kommen später
- Optik: Platzhalter aus Formen und Farben. Wer was ist, zeigt Form und Spielerfarbe
- Keine echten Marken oder Logos, nur erfundene

## Run-Struktur

- Wellen im Wechsel mit Shop-Pause
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
- Bezeichnung des Golds im Setting: z.B. Schrott oder Chips (Vorschlag)

**Perma-Progression**
- Freischaltungen zwischen Runs (Klassen, Items, Firmware). Umfang offen

## Elemente und Synergien

Vier Elemente: Feuer, Wasser, Eis, Blitz. Status liegen auf dem Gegner, egal welcher Spieler sie gesetzt hat (Vorschlag):

| Kombination | Wirkung |
|---|---|
| Wasser + Blitz | nasse Gegner nehmen doppelten Blitzschaden, Blitz springt auf weitere nasse Gegner |
| Wasser + Eis | gefroren, Gegner steht still |
| Wasser + Feuer | Dampfexplosion |
| Feuer + Eis | schmilzt, hebt beides auf |

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
- Geschütz oben drauf, schießt nur im Stand
- Dafür schneller laufen und Wände hochklettern
- Muss gegen Massen Durchschlag und Fläche bekommen

### Getränkeautomat auf Panzerketten
- Archetyp: tanky, Flächenschaden (AoE), langsam
- Wirft Dosen im Bogen, geschüttelte Dosen explodieren

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

## Coop

- Synergien zwischen Spielern über Elemente auf Gegnern
- Wiederbeleben durch Halten in der Nähe des gefallenen Partners, beide down ist Game Over
- Team-Items und Team-Perks mit spielerspezifischen Effekten

## Karte

- Hybrid aus mehreren handgebauten Arenen mit Variationen (Vorschlag)
- Prototyp: eine Arena, etwa 2 Bildschirme breit und 1,5 hoch, Kamera zeigt beide Spieler
- Geometrie für jede Bewegungsoption: versetzte Plattformen, hohe Schächte, Lücken, Decken-Anker
- Jede Karte muss ohne Bewegungs-Firmware spielbar sein, Firmware gibt Abkürzungen und Belohnungen

## Prototyp-Umfang (Vorschlag)

- 1 Arena, 2 Klassen (Roomba und Hexapod), etwa 15 Items, 4 Gegnertypen, 1 Boss
- Director-Spawning, Level-Up-System, Shop, Wiederbeleben
- Ziel: Spielgefühl und Synergien prüfen, danach ausbauen

## Offene Fragen

- Steuerungsbelegung auf dem PS5-Controller (Saugen, Dash, Klassenfähigkeit)
- Dauer der Kopie beim Roomba: Zeit oder Ladungen
- Wie groß ist die Perma-Progression
- Name und Optik des Golds im Setting
- Wie genau Bodengegner auf Plattformen navigieren
- Welche zwei Klassen im Prototyp: Vorschlag Roomba und Hexapod, noch nicht bestätigt
