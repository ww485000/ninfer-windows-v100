param(
  [string]$VcpkgRoot = $env:VCPKG_ROOT,
  [string]$BuildDir = "build-v100",
  [switch]$Clean
)

$ErrorActionPreference = "Stop"

function Require-Command([string]$Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) { throw "Required command '$Name' was not found in PATH." }
  return $cmd.Source
}

# Windows PowerShell 5.1 turns native-process stderr into PowerShell ErrorRecord
# objects. With $ErrorActionPreference='Stop', harmless MSBuild/CMake banners on
# stderr can abort the script before we can inspect the native exit code. Run
# native build commands with non-terminating stderr handling, then fail only on
# their real process exit code.
function Invoke-NativeCommand([string]$FilePath, [object[]]$Arguments) {
  $oldPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    & $FilePath @Arguments 2>&1 | ForEach-Object { Write-Host $_ }
    return $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $oldPreference
  }
}

Write-Host "[NInfer V100] Native Windows/TCC build bootstrap"

if (-not $VcpkgRoot) {
  if (Test-Path "C:\src\vcpkg\scripts\buildsystems\vcpkg.cmake") {
    $VcpkgRoot = "C:\src\vcpkg"
  } else {
    throw "Set VCPKG_ROOT or pass -VcpkgRoot. Example: -VcpkgRoot C:\src\vcpkg"
  }
}

$vcpkgToolchain = Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"
if (-not (Test-Path $vcpkgToolchain)) { throw "vcpkg toolchain not found: $vcpkgToolchain" }

$cmake = Require-Command "cmake.exe"
$null = Require-Command "cl.exe"
$null = Require-Command "nvidia-smi.exe"

$cudaRoot = $null
if ($env:CUDA_PATH_V12_9 -and (Test-Path (Join-Path $env:CUDA_PATH_V12_9 "bin\nvcc.exe"))) {
  $cudaRoot = $env:CUDA_PATH_V12_9
} elseif ($env:CUDA_PATH_V12_8 -and (Test-Path (Join-Path $env:CUDA_PATH_V12_8 "bin\nvcc.exe"))) {
  $cudaRoot = $env:CUDA_PATH_V12_8
} else {
  $candidates = @(
    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9",
    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"
  )
  foreach ($candidate in $candidates) {
    if (Test-Path (Join-Path $candidate "bin\nvcc.exe")) {
      $cudaRoot = $candidate
      break
    }
  }
}

if (-not $cudaRoot) { throw "CUDA Toolkit 12.8 or 12.9 was not found. Install one of them." }

$nvcc = Join-Path $cudaRoot "bin\nvcc.exe"
$nvccVersion = & $nvcc --version | Out-String
if ($nvccVersion -notmatch "release\s+12\.(8|9)") {
  throw "This V100 port requires CUDA Toolkit 12.8 or 12.9. nvcc reported: $nvccVersion"
}

Write-Host "[OK] Using CUDA Toolkit: $cudaRoot"
Write-Host ($nvccVersion.Trim())

$gpuNames = & nvidia-smi.exe --query-gpu=name --format=csv,noheader 2>$null
$computeCaps = & nvidia-smi.exe --query-gpu=compute_cap --format=csv,noheader 2>$null
$hasVolta70 = $false
if ($LASTEXITCODE -eq 0 -and $computeCaps) {
  $hasVolta70 = ($computeCaps -match "^7\.0$")
}
$knownV100Name = ($gpuNames -match "V100") -or ($gpuNames -match "PG503-216")
if (-not ($knownV100Name -or $hasVolta70)) {
  throw "No Volta sm_70 / Tesla V100-class GPU was detected by Windows nvidia-smi. Name: $gpuNames Compute capability: $computeCaps"
}
Write-Host "[OK] Volta sm_70 GPU detected: $gpuNames"
if ($computeCaps) { Write-Host "[OK] Compute capability: $computeCaps" }

$driverInfo = & nvidia-smi.exe -q | Out-String
if ($driverInfo -match "Driver Model[\s\S]*?Current\s*:\s*TCC") {
  Write-Host "[OK] Tesla V100 detected in TCC mode."
} else {
  Write-Warning "Tesla V100 detected, but TCC mode was not confirmed from nvidia-smi -q."
}

if ($Clean -and (Test-Path $BuildDir)) {
  Write-Host "[Clean] Removing $BuildDir"
  Remove-Item -Recurse -Force $BuildDir
}

$env:CL = "/Zc:preprocessor /utf-8"

Write-Host "[Configure] CUDA 12.8/12.9, sm_70, VS2022 x64"
$configureArgs = @(
  "-S", ".",
  "-B", $BuildDir,
  "-G", "Visual Studio 17 2022",
  "-A", "x64",
  "-DCMAKE_CUDA_ARCHITECTURES=70",
  "-DCMAKE_CUDA_COMPILER=$nvcc",
  "-DCMAKE_TOOLCHAIN_FILE=$vcpkgToolchain",
  "-DVCPKG_TARGET_TRIPLET=x64-windows",
  "-DNINFER_BUILD_APPS=ON",
  "-DNINFER_BUILD_PRODUCT_SUPPORT=ON",
  "-DBUILD_TESTING=OFF",
  "-DNINFER_BUILD_BENCHMARKS=OFF"
)
$configureExit = Invoke-NativeCommand $cmake $configureArgs
if ($configureExit -ne 0) { throw "CMake configure failed with exit code $configureExit" }

Write-Host "[Build] Release"
$buildArgs = @("--build", $BuildDir, "--config", "Release", "--parallel")
$buildExit = Invoke-NativeCommand $cmake $buildArgs
if ($buildExit -ne 0) { throw "Build failed with exit code $buildExit" }

$cli = Join-Path $BuildDir "apps\Release\ninfer.exe"
$serve = Join-Path $BuildDir "apps\Release\ninfer-serve.exe"

Write-Host ""
if (Test-Path $cli) { Write-Host "[OK] $cli" } else { Write-Warning "Build completed but ninfer.exe was not found at the expected path." }
if (Test-Path $serve) { Write-Host "[OK] $serve" }
