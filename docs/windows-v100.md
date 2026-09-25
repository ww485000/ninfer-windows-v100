# Windows Tesla V100 port

This branch combines the native Windows/MSVC work from `natpate/ninfer-windows`
with the Volta execution work from `geoffwatts/ninfer-v100`.

## Target platform

- Windows 10/11 x64
- NVIDIA Tesla V100 32GB
- TCC driver mode
- CUDA Toolkit 12.8 or 12.9
- Visual Studio 2022, Desktop development with C++
- CMake 3.28+
- vcpkg
- CUDA architecture `sm_70`

CUDA 13.x is intentionally rejected for the V100 target because offline Volta
compilation was removed.

## First build probe

Run from x64 Native Tools Command Prompt for VS 2022:

```powershell
git checkout v100-sm70
.\build-v100-windows.ps1 -VcpkgRoot C:\src\vcpkg -Clean
```

The first functional milestone is a native `ninfer.exe --help` binary.
