@echo off
rem Holt die neueste Version des Projekts und startet optional den Godot-Editor.
rem Optional: Lege eine Datei "godot_path.txt" in diesen Ordner und schreibe den
rem kompletten Pfad zu deiner Godot-.exe hinein, dann startet das Skript Godot danach.
cd /d "%~dp0"

echo Hole neueste Version...
git checkout claude/2-player-coop-game-upgrades-5s2a48
git pull
if errorlevel 1 (
    echo.
    echo FEHLER beim Aktualisieren. Siehe Meldung oben.
    pause
    exit /b 1
)

echo.
echo Fertig, Projekt ist aktuell.

if exist godot_path.txt (
    set /p GODOT=<godot_path.txt
    echo Starte Godot...
    start "" "%GODOT%" --editor --path "%~dp0"
) else (
    pause
)
