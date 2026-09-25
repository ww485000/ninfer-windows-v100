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

$cudaRoot = $env:CUDA_PATH_V12_8
if (-not $cudaRoot) {
  $candidate = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"
  if (Test-Path (Join-Path $candidate "bin\nvcc.exe")) { $cudaRoot = $candidate }
}
if (-not $cudaRoot) { throw "CUDA Toolkit 12.8 was not found. Install CUDA 12.8 or set CUDA_PATH_V12_8." }

$nvcc = Join-Path $cudaRoot "bin\nvcc.exe"
if (-not (Test-Path $nvcc)) { throw "nvcc.exe not found at $nvcc" }

$nvccVersion = & $nvcc --version | Out-String
if ($nvccVersion -notmatch "release\s+12\.8") {
  throw "This V100 port requires CUDA Toolkit 12.8 exactly. nvcc reported: $nvccVersion"
}

$gpuNames = & nvidia-smi.exe --query-gpu=name --format=csv,noheader 2>$null
if (-not ($gpuNames -match "V100")) { throw "No Tesla V100 was detected by Windows nvidia-smi. Detected: $gpuNames" }

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

# Required by the native Windows port. cl.exe and the host compiler launched by nvcc both inherit CL.
$env:CL = "/Zc:preprocessor /utf-8"

Write-Host "[Configure] CUDA 12.8, sm_70, VS2022 x64"
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
& $cmake @configureArgs
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed with exit code $LASTEXITCODE" }

Write-Host "[Build] Release"
& $cmake --build $BuildDir --config Release --parallel
if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }

$cli = Join-Path $BuildDir "apps\Release\ninfer.exe"
$serve = Join-Path $BuildDir "apps\Release\ninfer-serve.exe"

Write-Host ""
if (Test-Path $cli) { Write-Host "[OK] $cli" } else { Write-Warning "Build completed but ninfer.exe was not found at the expected path." }
if (Test-Path $serve) { Write-Host "[OK] $serve" }
