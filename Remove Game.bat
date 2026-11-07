@echo off
title Remove a game
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0add-game.ps1" -Remove
echo.
pause
