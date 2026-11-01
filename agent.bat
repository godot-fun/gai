@echo off
rem Launcher for the agent desktop app (see agent.ps1).
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0agent.ps1"
if errorlevel 1 pause
exit /b %ERRORLEVEL%
