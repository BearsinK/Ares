class_name Achievements
extends RefCounted
## Erfolge: kleine Ziele fuer jeden Lauf. Wer eins schafft, bekommt einmalig Chips fuer die Garage.
## Welche freigeschaltet sind, steht wie das Archiv im Spielstand (Art "achievements").

const DATA := {
	"first_blood": {"name": "Erstes Blech", "text": "Besiege deinen ersten Gegner.", "chips": 10},
	"kills_100": {"name": "Hundertschaft", "text": "Besiege 100 Gegner in einem Lauf.", "chips": 30},
	"wave_5": {"name": "Durchhalter", "text": "Schaffe 5 Wellen in einem Lauf.", "chips": 20},
	"no_hit": {"name": "Unberührbar", "text": "Schaffe eine Welle ab Welle 2, ohne dass ein Spieler getroffen wird.", "chips": 40},
	"contract": {"name": "Vertragstreu", "text": "Schaffe eine Welle mit einem selbst gewählten Vertrag.", "chips": 20},
	"chests_5": {"name": "Schatzsucher", "text": "Öffne 5 Kisten in einem Lauf.", "chips": 30},
	"rich": {"name": "Goldrausch", "text": "Halte 500 Gold gleichzeitig.", "chips": 30},
	"rare_find": {"name": "Seltener Fund", "text": "Besitze ein seltenes Item.", "chips": 20},
	"stack_5": {"name": "Sammelwut", "text": "Besitze dasselbe Item fünfmal.", "chips": 40},
	"gambler": {"name": "Glücksritter", "text": "Gewinne dreimal am Glücksaltar in einem Lauf.", "chips": 30},
	"blood": {"name": "Blutpakt", "text": "Nutze den Blutaltar dreimal in einem Lauf.", "chips": 30},
	"revive_3": {"name": "Teamgeist", "text": "Belebe deinen Partner dreimal in einem Lauf.", "chips": 30},
	"elite_10": {"name": "Elitejäger", "text": "Besiege insgesamt 10 Elite-Gegner.", "chips": 40},
	"guardian": {"name": "Wächterfall", "text": "Besiege einen Wächter.", "chips": 30},
	"archive_half": {"name": "Archivar", "text": "Entdecke die Hälfte aller Items, Gegner und Waffen.", "chips": 50},
	"boss": {"name": "Ofen aus", "text": "Besiege den Smelter.", "chips": 100},
	"speedrun": {"name": "Schnellschmelze", "text": "Besiege den Smelter in unter 15 Minuten.", "chips": 60},
	"boss_hard": {"name": "Hardcore-Held", "text": "Besiege den Smelter auf Hardcore.", "chips": 200},
	"endless_15": {"name": "Immer weiter", "text": "Schaffe im Endlosmodus Welle 15.", "chips": 100},
	"endless_20": {"name": "Unaufhaltsam", "text": "Schaffe im Endlosmodus Welle 20.", "chips": 250},
}

const SPEEDRUN_SECONDS := 900.0
