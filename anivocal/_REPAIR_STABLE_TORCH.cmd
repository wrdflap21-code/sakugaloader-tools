@echo off
title AniVocal Stable Torch Repair
color 0E
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo AniVocal Stable Torch Repair
echo Folder: %CD%
echo ============================================================
echo.
echo This will remove the broken TorchCodec path and install stable
echo CPU versions of torch/torchaudio for Demucs.
echo.
echo This can take a while because PyTorch is large.
echo.
pause

set "PY=%~dp0python\python.exe"

if not exist "%PY%" (
  echo Portable Python was not found:
  echo %PY%
  echo.
  echo Run setup_anivocal.bat first.
  echo.
  pause
  exit /b 3
)

echo.
echo Using portable Python:
echo %PY%
echo.

echo [1/6] Upgrading pip tools...
"%PY%" -m pip install --upgrade pip setuptools wheel --no-warn-script-location

echo.
echo [2/6] Removing broken/new torch stack...
"%PY%" -m pip uninstall -y torch torchaudio torchcodec torchvision torchtext

echo.
echo [3/6] Installing stable NumPy...
"%PY%" -m pip install "numpy==1.26.4" --no-warn-script-location

echo.
echo [4/6] Installing stable CPU PyTorch + Torchaudio...
"%PY%" -m pip install torch==2.1.2 torchaudio==2.1.2 --index-url https://download.pytorch.org/whl/cpu --no-warn-script-location

echo.
echo [5/6] Installing Demucs stack...
"%PY%" -m pip install demucs==4.0.1 imageio-ffmpeg soundfile --no-warn-script-location

echo.
echo [6/6] Smoke check...
"%PY%" -c "import torch, torchaudio, demucs, imageio_ffmpeg; print('OK torch=', torch.__version__, 'torchaudio=', torchaudio.__version__)"

set "EXITCODE=%ERRORLEVEL%"

echo.
echo ============================================================
echo Stable Torch repair finished with code: %EXITCODE%
echo ============================================================
echo.
pause
exit /b %EXITCODE%
