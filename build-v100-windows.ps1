param(
  [string]$VcpkgRoot = $env:VCPKG_ROOT,
  [string]$BuildDir = "build-v100",
  [ValidateRange(1, 64)] [int]$BuildJobs = 4,
  [switch]$Clean
)

$ErrorActionPreference = "Stop"

function Initialize-MsvcEnvironment {
  if (Get-Command cl.exe -ErrorAction SilentlyContinue) { return }
  $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (-not (Test-Path $vswhere)) {
    throw "Visual Studio 2022 with the Desktop development with C++ workload is required."
  }
  $installation = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if ($LASTEXITCODE -ne 0 -or -not $installation) {
    throw "Visual Studio 2022 C++ x64 build tools were not found."
  }
  $vsDevCmd = Join-Path ($installation | Select-Object -First 1) "Common7\Tools\VsDevCmd.bat"
  $lines = & $env:ComSpec /d /s /c "`"$vsDevCmd`" -no_logo -arch=x64 -host_arch=x64 >nul && set"
  if ($LASTEXITCODE -ne 0) { throw "VsDevCmd.bat failed with exit code $LASTEXITCODE" }
  foreach ($line in $lines) {
    $separator = $line.IndexOf("=")
    if ($separator -gt 0) {
      Set-Item -Path ("Env:" + $line.Substring(0, $separator)) `
        -Value $line.Substring($separator + 1)
    }
  }
}

function Invoke-Native([string]$File, [object[]]$Arguments) {
  $saved = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    & $File @Arguments 2>&1 | ForEach-Object { Write-Output $_ }
    $script:NativeExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $saved
  }
  if ($script:NativeExitCode -ne 0) {
    throw "Native command failed with exit code $script:NativeExitCode: $File"
  }
}

Write-Output "[NInfer V100] Native Windows build"
if (-not $VcpkgRoot) {
  if (Test-Path "C:\src\vcpkg\scripts\buildsystems\vcpkg.cmake") {
    $VcpkgRoot = "C:\src\vcpkg"
  } else {
    throw "Set VCPKG_ROOT or pass -VcpkgRoot."
  }
}
$toolchain = Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"
if (-not (Test-Path $toolchain)) { throw "vcpkg toolchain not found: $toolchain" }

Initialize-MsvcEnvironment
$cmake = (Get-Command cmake.exe -ErrorAction Stop).Source
$null = Get-Command cl.exe -ErrorAction Stop
$null = Get-Command nvidia-smi.exe -ErrorAction Stop

$cudaRoot = @($env:CUDA_PATH_V12_9, $env:CUDA_PATH_V12_8,
  "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9",
  "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8") |
  Where-Object { $_ -and (Test-Path (Join-Path $_ "bin\nvcc.exe")) } |
  Select-Object -First 1
if (-not $cudaRoot) { throw "CUDA Toolkit 12.8 or 12.9 was not found." }
$nvcc = Join-Path $cudaRoot "bin\nvcc.exe"
$nvccVersion = & $nvcc --version | Out-String
if ($nvccVersion -notmatch "release\s+12\.(8|9)") {
  throw "CUDA Toolkit 12.8 or 12.9 is required."
}

$gpuNames = & nvidia-smi.exe --query-gpu=name --format=csv,noheader 2>$null
$computeCaps = & nvidia-smi.exe --query-gpu=compute_cap --format=csv,noheader 2>$null
if (-not (($computeCaps -match "^7\.0$") -or ($gpuNames -match "V100|PG503-216"))) {
  throw "No Tesla V100 / sm_70 GPU was detected. Found: $gpuNames ($computeCaps)"
}
Write-Output "[OK] CUDA: $cudaRoot"
Write-Output "[OK] GPU: $gpuNames (compute capability $computeCaps)"

if ($Clean -and (Test-Path $BuildDir)) {
  $resolved = (Resolve-Path -LiteralPath $BuildDir).Path
  $root = (Resolve-Path -LiteralPath .).Path
  if (-not $resolved.StartsWith($root + [IO.Path]::DirectorySeparatorChar,
                                [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove build directory outside the repository: $resolved"
  }
  Write-Output "[Clean] $resolved"
  Remove-Item -LiteralPath $resolved -Recurse -Force
}

$configure = @("-S", ".", "-B", $BuildDir, "-G", "Visual Studio 17 2022", "-A", "x64",
  "-DCMAKE_CUDA_ARCHITECTURES=70", "-DCMAKE_CUDA_COMPILER=$nvcc",
  "-DCMAKE_TOOLCHAIN_FILE=$toolchain", "-DVCPKG_TARGET_TRIPLET=x64-windows",
  "-DNINFER_BUILD_APPS=ON", "-DBUILD_TESTING=OFF", "-DNINFER_BUILD_BENCHMARKS=OFF")
Invoke-Native $cmake $configure
Invoke-Native $cmake @("--build", $BuildDir, "--config", "Release", "--parallel", $BuildJobs)

$release = Join-Path $BuildDir "apps\Release"
foreach ($name in @("ninfer.exe", "ninfer-serve.exe", "ninfer-perplexity.exe")) {
  $path = Join-Path $release $name
  if (-not (Test-Path $path)) { throw "Expected executable was not produced: $path" }
  Write-Output "[OK] $path"
}
