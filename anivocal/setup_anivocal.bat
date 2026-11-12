@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title AniVocal Setup

echo ============================================================
echo AniVocal Setup / Repair
echo Folder: %CD%
echo ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_anivocal.ps1"
set "EXITCODE=%ERRORLEVEL%"

echo.
echo ============================================================
echo Setup finished with code: %EXITCODE%
echo ============================================================
exit /b %EXITCODE%
