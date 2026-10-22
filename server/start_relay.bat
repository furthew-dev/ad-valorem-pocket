@echo off
REM Double-click to start the Ad Valorem multiplayer relay on this PC.
cd /d "%~dp0"
if not exist node_modules (
  echo Installing relay dependencies, first run only...
  call npm install
)
echo.
echo Relay starting. Leave this window open while you play. Close it to stop.
echo.
call npm start
pause
