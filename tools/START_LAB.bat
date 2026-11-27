@echo off
setlocal
cd /d "%~dp0"
set "PROJECT=%~dp0godot"
set "CACHE=%PROJECT%\.godot"
set "LOG=%~dp0LAB_STARTUP.log"
if not exist "%PROJECT%\project.godot" goto fail
if not exist "%PROJECT%\addons\pixelfx\bin\pixelfx.windows.x86_64.dll" goto fail
if not exist "%PROJECT%\addons\motionphysics\bin\motionphysics_099d.windows.x86_64.dll" goto fail
if not exist "%CACHE%" mkdir "%CACHE%"
if not exist "%CACHE%\extension_list.cfg" goto prepare
if not exist "%CACHE%\imported" goto prepare
if not exist "%CACHE%\lab_bootstrap_ok" goto prepare
goto ready
:prepare
echo Preparing Lab resources and native extensions...
(
echo res://addons/pixelfx/pixelfx.gdextension
echo res://addons/motionphysics/motionphysics_099d.gdextension
)>"%CACHE%\extension_list.cfg"
"%~dp0Godot_console.exe" --headless --path "%PROJECT%" --editor --import >"%LOG%" 2>&1
if errorlevel 1 goto fail
"%~dp0Godot_console.exe" --headless --path "%PROJECT%" --audio-driver Dummy --script res://tests/lab_rc2_smoke.gd >>"%LOG%" 2>&1
if errorlevel 1 goto fail
findstr /C:"RC2_SMOKE_OK" "%LOG%" >nul
if errorlevel 1 goto fail
echo OK>"%CACHE%\lab_bootstrap_ok"
:ready
if /I "%~1"=="--check" goto check
start "" "%~dp0Godot.exe" --path "%PROJECT%" --log-file "%~dp0LAB_RUNTIME.log"
exit /b 0
:check
"%~dp0Godot_console.exe" --headless --path "%PROJECT%" --audio-driver Dummy --script res://tests/lab_rc2_smoke.gd
exit /b %errorlevel%
:fail
echo Lab startup failed. Check LAB_STARTUP.log and extract the complete archive.
if /I not "%~1"=="--check" pause
exit /b 1
