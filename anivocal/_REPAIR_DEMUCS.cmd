@echo off
title AniVocal Demucs Repair
color 0E
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo AniVocal Demucs Repair
echo Folder: %CD%
echo ============================================================
echo.
echo This will install/repair Demucs inside AniVocal portable Python.
echo.
call setup_anivocal.bat
set "EXITCODE=%ERRORLEVEL%"
echo.
echo Repair finished with code: %EXITCODE%
echo.
pause
exit /b %EXITCODE%
