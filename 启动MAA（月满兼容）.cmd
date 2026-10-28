@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-MoonTheme.ps1" -Launch
if errorlevel 1 pause
