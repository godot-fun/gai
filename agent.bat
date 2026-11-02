@echo off
rem Launcher for the agent desktop app (see agent.ps1).
rem Extra args are forwarded to the app, e.g. agent.bat --data-dir D:\gai-data
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0agent.ps1" %*
if errorlevel 1 pause
exit /b %ERRORLEVEL%
