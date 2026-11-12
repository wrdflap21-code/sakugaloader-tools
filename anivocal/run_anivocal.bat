@echo off
title AniVocal Runner
setlocal EnableExtensions EnableDelayedExpansion

set "BASE=%~dp0"
set "INPUT=%~1"
set "OUTPUT=%~2"
set "MODE=%~3"
set "OUTMODE=%~4"
set "CUTSTART=%~5"
set "CUTEND=%~6"

if "%INPUT%"=="" (
  echo [AniVocal] Missing input path.
  exit /b 2
)

if "%OUTPUT%"=="" set "OUTPUT=%BASE%outputs"
if "%MODE%"=="" set "MODE=balanced"
if "%OUTMODE%"=="" set "OUTMODE=vocals_instrumental"

set "PY=%BASE%python\python.exe"
set "PATH=%BASE%python;%BASE%python\Scripts;%BASE%python\Lib\site-packages\torch\lib;%PATH%"

if exist "%PY%" goto :run

echo [AniVocal] Portable Python was not found:
echo %PY%
echo.
echo [AniVocal] Run setup_anivocal.bat first.
echo [AniVocal] Do NOT use global Python 3.14 because Demucs/PyTorch may not work there.
exit /b 3

:run
echo [AniVocal] Using portable Python:
echo %PY%
echo [AniVocal] Checking AniVocal dependencies...
"%PY%" -c "import torch, torchaudio, demucs, demucs.separate; print('AniVocal deps OK')" >nul 2>nul
if not "%ERRORLEVEL%"=="0" (
  echo [AniVocal] Demucs is missing or broken. Running setup/repair now...
  echo [AniVocal] This can take a while on the first run.
  if exist "%BASE%setup_anivocal.bat" (
    call "%BASE%setup_anivocal.bat"
    set "SETUPCODE=!ERRORLEVEL!"
    if not "!SETUPCODE!"=="0" (
      echo [AniVocal] Setup/repair failed with code !SETUPCODE!.
      exit /b !SETUPCODE!
    )
  ) else (
    echo [AniVocal] setup_anivocal.bat was not found.
    exit /b 4
  )

  "%PY%" -c "import torch, torchaudio, demucs, demucs.separate; print('AniVocal deps OK')" >nul 2>nul
  if not "!ERRORLEVEL!"=="0" (
    echo [AniVocal] AniVocal dependencies are still missing after setup/repair.
    echo [AniVocal] Open logs\setup_anivocal_latest.txt for details.
    exit /b 8
  )
)

echo [AniVocal] Starting...
"%PY%" "%BASE%engine\anivocal_runner.py" --input "%INPUT%" --output "%OUTPUT%" --mode "%MODE%" --output-mode "%OUTMODE%" --cut-start "%CUTSTART%" --cut-end "%CUTEND%"
exit /b %ERRORLEVEL%
