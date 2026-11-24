@echo off
cd /d "%~dp0"
node tools/bootstrap.mjs
if errorlevel 1 (
 echo Setup failed. Install Git and Node.js 18+ and check internet.
 pause
 exit /b 1
)
echo Ready. Import godot/project.godot in Godot 4.
pause
