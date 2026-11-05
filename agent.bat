@echo off
rem Launcher for the agent desktop app (see shell\agent.ps1).
rem Extra args are forwarded to the app, e.g. agent.bat --data-dir D:\gai-data
rem Every launch first pulls the latest code and re-imports assets (see shell\agent.ps1),
rem then starts the app.
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0shell\agent.ps1" %*
if errorlevel 1 pause
exit /b %ERRORLEVEL%
