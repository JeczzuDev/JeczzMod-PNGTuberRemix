@echo off
rem Removes JeczzMod (Mouse X / Mouse Y) from the folder this file is in.
cd /d "%~dp0"
if not exist "PNGTube Remix.exe" (
	echo Este archivo debe estar en la carpeta de "PNGTube Remix.exe".
	pause
	exit /b 1
)

if exist "mods\follow_mouse_axis" rmdir /s /q "mods\follow_mouse_axis"
if exist "mods\jeczz_mod_loader.gd" del /q "mods\jeczz_mod_loader.gd"
if exist "mods\SANDBOX" del /q "mods\SANDBOX"
rmdir "mods" 2>nul

if exist "override.cfg" (
	rem Only delete override.cfg when the mod's line is its only setting.
	findstr /c:"=" "override.cfg" | findstr /v /c:"JeczzModLoader" >nul
	if errorlevel 1 (
		del /q "override.cfg"
	) else (
		echo override.cfg tiene otros ajustes: quita a mano la linea JeczzModLoader.
	)
)

echo JeczzMod desinstalado.
pause
