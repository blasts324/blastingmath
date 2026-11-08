@echo off
title Push to GitHub
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0push-repo.ps1"
echo.
pause
