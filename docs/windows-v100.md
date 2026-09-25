# Windows Tesla V100 port

This branch combines the native Windows/MSVC work from `natpate/ninfer-windows`
with the Volta execution work from `geoffwatts/ninfer-v100`.

## Target platform

- Windows 10/11 x64
- NVIDIA Tesla V100 32GB
- TCC driver mode
- CUDA Toolkit 12.8
- Visual Studio 2022, Desktop development with C++
- CMake 3.28+
- vcpkg
- CUDA architecture `sm_70`

CUDA 13.x is intentionally rejected for the V100 target because offline Volta
compilation was removed. The Blackwell `sm_120a` path remains available and
keeps its CUDA 13.1+ requirement.

## Current porting stage

The Windows build system now accepts `sm_70`, pins the V100 path to CUDA 12.8,
defines `NINFER_VOLTA_BUILD`, and fetches the same CUTLASS 4.4.2 headers used
by the Linux V100 port.

The next stage is source integration: Volta-specific kernels and dispatch paths
must be brought across without regressing the newer Windows refactor. Until that
work lands, an sm_70 build is expected to expose the remaining Blackwell-only
translation units as compiler errors. Those failures are useful porting targets.

## First build probe

Run from **x64 Native Tools Command Prompt for VS 2022** or a PowerShell session
where `cl.exe` is available:

```powershell
git checkout v100-sm70
.\build-v100-windows.ps1 -VcpkgRoot C:\src\vcpkg -Clean
```

The script checks for:

- a Windows-visible Tesla V100;
- CUDA Toolkit 12.8;
- MSVC;
- CMake;
- vcpkg;
- TCC mode when it can be identified from `nvidia-smi -q`.

Do not install CUDA 13 for this branch.

## Porting order

1. Make the native Windows build configure for CUDA 12.8 / sm_70.
2. Replace or exclude Blackwell-only CUDA translation units.
3. Integrate Volta FP16/CUTLASS and QPN kernels.
4. Integrate INT8 KV and Volta attention.
5. Restore MTP and CUDA Graph generation.
6. Validate Qwen3.8-27B NVFP4 artifact loading.
7. Benchmark single-request decode and prefill.

The first functional milestone is a native `ninfer.exe --help` binary; model
loading and optimized inference come after the CUDA source tree builds cleanly.
