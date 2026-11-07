@echo off
title Add a game
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0add-game.ps1" %*
echo.
pause
