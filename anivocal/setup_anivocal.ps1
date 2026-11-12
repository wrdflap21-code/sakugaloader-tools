$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonDir = Join-Path $Base "python"
$PythonExe = Join-Path $PythonDir "python.exe"
$ScriptsDir = Join-Path $PythonDir "Scripts"
$TempDir = Join-Path $Base "temp"
$LogDir = Join-Path $Base "logs"
$OutputDir = Join-Path $Base "outputs"
$ModelDir = Join-Path $Base "models"
$PythonZip = Join-Path $TempDir "python-3.10.11-embed-amd64.zip"
$GetPip = Join-Path $TempDir "get-pip.py"
$ReadyFile = Join-Path $LogDir "setup_ok.txt"
$TranscriptFile = Join-Path $LogDir "setup_anivocal_latest.txt"
$DebugFile = Join-Path $LogDir "setup_debug_python_path.txt"
$SitePackages = Join-Path $PythonDir "Lib\site-packages"
$TorchLib = Join-Path $SitePackages "torch\lib"

New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $ModelDir | Out-Null

try { Remove-Item -Force $ReadyFile -ErrorAction SilentlyContinue } catch {}
try { Start-Transcript -Path $TranscriptFile -Force | Out-Null } catch {}

function Write-Step($Message) {
  Write-Host "[AniVocal Setup] $Message"
}

function Download-File($Url, $OutFile) {
  Write-Step "Downloading $Url"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
  if (!(Test-Path $OutFile)) {
    throw "Download failed: $Url"
  }
}

function Reset-EmbeddedPythonPaths() {
  New-Item -ItemType Directory -Force -Path $SitePackages | Out-Null
  New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null

  # The embedded Python zip starts isolated. We rewrite the ._pth file so pip packages
  # inside Lib/site-packages are always visible to this exact portable python.exe.
  $pth = Join-Path $PythonDir "python310._pth"
  $pthContent = @(
    "python310.zip",
    ".",
    "Lib/site-packages",
    "Scripts",
    "import site"
  )
  Set-Content -Path $pth -Value $pthContent -Encoding ASCII

  $env:PATH = "$PythonDir;$ScriptsDir;$TorchLib;$env:PATH"
  $env:PYTHONNOUSERSITE = "1"
  $env:PIP_DISABLE_PIP_VERSION_CHECK = "1"
}

function Invoke-PythonChecked {
  param(
    [Parameter(Mandatory=$true)][string]$Label,
    [Parameter(Mandatory=$true)][string[]]$Arguments
  )

  Write-Step $Label
  Write-Host "> `"$PythonExe`" $($Arguments -join ' ')"
  & $PythonExe @Arguments
  $code = $LASTEXITCODE
  Write-Host "[AniVocal Setup] exit code: $code"
  if ($code -ne 0) {
    throw "$Label failed with exit code $code"
  }
}

function Invoke-PythonSoft {
  param([Parameter(Mandatory=$true)][string[]]$Arguments)
  & $PythonExe @Arguments
  return ($LASTEXITCODE -eq 0)
}

function Test-TorchImport() {
  Write-Step "Testing torch import..."
  & $PythonExe -c "import sys; import torch; print('Torch OK', torch.__version__); print(sys.executable)"
  return ($LASTEXITCODE -eq 0)
}

function Test-DemucsImport() {
  Write-Step "Testing demucs import..."
  & $PythonExe -c "import sys; import torch, torchaudio, demucs, demucs.separate, imageio_ffmpeg; print('AniVocal deps OK'); print(sys.executable)"
  return ($LASTEXITCODE -eq 0)
}

function Write-PythonDebugInfo() {
  try {
    & $PythonExe -c "import sys, site, os; print('EXE=' + sys.executable); print('VERSION=' + sys.version); print('PATHS='); [print(p) for p in sys.path]; print('SITE='); print(site.getsitepackages() if hasattr(site, 'getsitepackages') else 'no getsitepackages'); print('PYTHONPATH=' + os.environ.get('PYTHONPATH',''))" | Out-File -FilePath $DebugFile -Encoding UTF8
  } catch {}
}

try {
  Write-Step "Base folder: $Base"

  if (!(Test-Path $PythonExe)) {
    Write-Step "Portable Python not found. Installing Python 3.10.11 embedded..."
    if (Test-Path $PythonDir) {
      Remove-Item -Recurse -Force $PythonDir
    }

    Download-File "https://www.python.org/ftp/python/3.10.11/python-3.10.11-embed-amd64.zip" $PythonZip
    New-Item -ItemType Directory -Force -Path $PythonDir | Out-Null
    Expand-Archive -LiteralPath $PythonZip -DestinationPath $PythonDir -Force
  } else {
    Write-Step "Portable Python already exists. Repairing paths/dependencies..."
  }

  Reset-EmbeddedPythonPaths
  Write-PythonDebugInfo

  $pipOk = $false
  try {
    & $PythonExe -m pip --version | Out-Host
    if ($LASTEXITCODE -eq 0) { $pipOk = $true }
  } catch { $pipOk = $false }

  if (-not $pipOk) {
    Write-Step "pip not found. Installing pip..."
    Download-File "https://bootstrap.pypa.io/get-pip.py" $GetPip
    Invoke-PythonChecked -Label "Installing pip" -Arguments @($GetPip)
  } else {
    Write-Step "pip already exists."
  }

  Reset-EmbeddedPythonPaths

  Invoke-PythonChecked -Label "Upgrading pip/setuptools/wheel" -Arguments @("-m", "pip", "install", "--upgrade", "pip", "setuptools", "wheel", "--no-warn-script-location")

  Write-Step "Installing stable NumPy..."
  Invoke-PythonChecked -Label "Installing NumPy" -Arguments @("-m", "pip", "install", "--no-cache-dir", "--upgrade", "numpy==1.26.4", "--no-warn-script-location")

  if (-not (Test-TorchImport)) {
    Write-Step "Torch missing. Installing CPU PyTorch + Torchaudio..."
    try {
      Invoke-PythonChecked -Label "Installing CPU PyTorch + Torchaudio" -Arguments @("-m", "pip", "install", "--no-cache-dir", "--upgrade", "--index-url", "https://download.pytorch.org/whl/cpu", "--extra-index-url", "https://pypi.org/simple", "torch==2.1.2+cpu", "torchaudio==2.1.2+cpu", "--no-warn-script-location")
    } catch {
      Write-Step "CPU PyTorch install failed. Trying fallback PyPI wheels..."
      Invoke-PythonChecked -Label "Installing fallback PyTorch + Torchaudio" -Arguments @("-m", "pip", "install", "--no-cache-dir", "--upgrade", "torch==2.1.2", "torchaudio==2.1.2", "--no-warn-script-location")
    }
  }

  Reset-EmbeddedPythonPaths

  if (-not (Test-TorchImport)) {
    Write-Step "Torch still not visible. Forcing install directly into portable Lib/site-packages..."
    Invoke-PythonChecked -Label "Force target install CPU PyTorch" -Arguments @("-m", "pip", "install", "--no-cache-dir", "--upgrade", "--target", $SitePackages, "--index-url", "https://download.pytorch.org/whl/cpu", "--extra-index-url", "https://pypi.org/simple", "torch==2.1.2+cpu", "torchaudio==2.1.2+cpu", "--no-warn-script-location")
    Reset-EmbeddedPythonPaths
  }

  if (-not (Test-TorchImport)) {
    throw "Torch was installed but Python still cannot import it. Check setup_debug_python_path.txt."
  }

  Write-Step "Installing Demucs stack..."
  Invoke-PythonChecked -Label "Installing Demucs" -Arguments @("-m", "pip", "install", "--no-cache-dir", "--upgrade", "demucs==4.0.1", "imageio-ffmpeg", "soundfile", "--no-warn-script-location")

  Reset-EmbeddedPythonPaths

  if (-not (Test-DemucsImport)) {
    Write-Step "Demucs still not visible. Forcing install directly into portable Lib/site-packages..."
    Invoke-PythonChecked -Label "Force target install Demucs" -Arguments @("-m", "pip", "install", "--no-cache-dir", "--upgrade", "--target", $SitePackages, "demucs==4.0.1", "imageio-ffmpeg", "soundfile", "--no-warn-script-location")
    Reset-EmbeddedPythonPaths
  }

  if (-not (Test-DemucsImport)) {
    throw "Demucs import smoke check failed after install."
  }

  Write-Step "Installed packages summary:"
  & $PythonExe -m pip show torch torchaudio demucs imageio-ffmpeg soundfile | Out-Host
  Write-PythonDebugInfo

  $stamp = "AniVocal setup OK - " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  Set-Content -Path $ReadyFile -Value $stamp -Encoding UTF8
  Write-Step "Setup completed successfully. Ready marker: $ReadyFile"
  exit 0
} catch {
  Write-Host "[AniVocal Setup] ERROR: $($_.Exception.Message)" -ForegroundColor Red
  try { Remove-Item -Force $ReadyFile -ErrorAction SilentlyContinue } catch {}
  Write-Host "[AniVocal Setup] Log saved at: $TranscriptFile"
  Write-Host "[AniVocal Setup] Debug path log: $DebugFile"
  exit 1
} finally {
  try { Stop-Transcript | Out-Null } catch {}
}
