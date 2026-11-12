@echo off
title AniVocal TorchCodec Fix
color 0E
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo AniVocal TorchCodec Fix
echo Folder: %CD%
echo ============================================================
echo.

set "PY=%~dp0python\python.exe"
if exist "%PY%" goto :install

set "PY=%~dp0.venv\Scripts\python.exe"
if exist "%PY%" goto :install

where py >nul 2>nul
if %ERRORLEVEL%==0 (
  set "PY=py -3"
  goto :install
)

where python >nul 2>nul
if %ERRORLEVEL%==0 (
  set "PY=python"
  goto :install
)

echo Python was not found inside AniVocal.
echo Run setup_anivocal.bat first.
echo.
pause
exit /b 3

:install
echo Installing missing dependency: torchcodec
echo This can take a little while...
echo.
%PY% -m pip install torchcodec --no-warn-script-location

set "EXITCODE=%ERRORLEVEL%"

echo.
echo ============================================================
echo TorchCodec fix finished with code: %EXITCODE%
echo ============================================================
echo.
pause
exit /b %EXITCODE%
