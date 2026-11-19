@echo off
setlocal
set "PROJECT=%~dp0"
set "GODOT="
for %%G in (Godot_v4.7.2-stable_win64_console.exe godot4.exe godot.exe) do (
    if not defined GODOT for /f "delims=" %%P in ('where.exe %%G 2^>nul') do if not defined GODOT set "GODOT=%%P"
)
if not defined GODOT (
    echo Godot 4.7 wurde im PATH nicht gefunden.
    echo Oeffne project.godot im Godot-Projektmanager und druecke nach dem Import F5.
    pause
    exit /b 1
)
echo Stahlfront bereitet Modelle und Texturen vor. Der erste Import dauert etwas.
"%GODOT%" --headless --path "%PROJECT%." --editor --import
if errorlevel 1 (
    pause
    exit /b 1
)
"%GODOT%" --path "%PROJECT%."
exit /b %errorlevel%
