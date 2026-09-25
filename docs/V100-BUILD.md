**English** | [简体中文](V100-BUILD.zh-CN.md)

# Windows V100 build and operating guide

This guide is for the only supported deployment target of this repository: 64-bit Windows with
one Tesla V100 32GB in TCC mode. It does not describe or support Linux, WSL, Docker, RTX, or
Blackwell builds.

## Verified configuration

| Component | Verified value |
|---|---|
| GPU | Tesla PG503-216 32GB, Volta compute capability 7.0 |
| Driver | 576.57, TCC |
| OS | Windows 10 64-bit |
| CUDA | 12.9; the script also accepts 12.8 |
| Compiler | Visual Studio 2022 Community, MSVC 14.44 |
| CMake | 4.4.3 |
| Dependencies | vcpkg x64-windows manifest |

## Prerequisites

1. Install the NVIDIA data-center driver and confirm that `nvidia-smi` reports a V100/PG503-216,
   32GB memory, compute capability 7.0, and TCC mode.
2. Install CUDA Toolkit 12.8 or 12.9.
3. Install Visual Studio 2022 with Desktop development with C++ and a Windows SDK.
4. Install Git, CMake, and vcpkg. The examples assume `C:\src\vcpkg`.
5. Keep at least 50GB free for one model plus the build, or about 75GB for both model variants.

## Build

Run from a normal PowerShell session at the repository root:

```powershell
powershell -ExecutionPolicy Bypass -Command `
  ".\build-v100-windows.ps1 -VcpkgRoot C:\src\vcpkg -Clean 2>&1 | Tee-Object build-v100.log"
```

The script locates Visual Studio and CUDA, verifies the GPU, configures `sm_70`, restores the vcpkg
manifest, and builds the three Release applications. A successful build produces:

```text
build-v100\apps\Release\ninfer.exe
build-v100\apps\Release\ninfer-serve.exe
build-v100\apps\Release\ninfer-perplexity.exe
```

For later source changes, use the incremental build:

```powershell
cmake --build build-v100 --config Release -j
```

## Models

Use the repository downloader so interrupted transfers resume and the exact published size and
SHA-256 are verified:

```powershell
.\download-qwen38-v100.ps1 -Variant official
.\download-qwen38-v100.ps1 -Variant uncensored
.\download-qwen38-v100.ps1 -Variant all
```

| Variant | Published SHA-256 |
|---|---|
| Official v3 | `74d2c57145e6ff11d1d2faa79594477f9bc903a611af1fb20218189fbbb77d82` |
| Uncensored v2 | `43025bb64f2cb558d9ede6269f8a3c2ed8ebfa4619344fe1ba8e955ba4979218` |

The uncensored artifact is third-party, has reduced safety alignment, and has not received a full
capability or safety evaluation.

## CLI

```powershell
.\run-qwen38-v100.ps1 `
  -Variant official `
  -NoThinking `
  -Prompt "Calculate 37 times 43." `
  -MaxNew 128
```

Prompts are written to a temporary UTF-8 messages file so Chinese and other Unicode text bypass
the Windows narrow-command-line encoding path.

## Server

```powershell
.\serve-qwen38-v100.ps1 -Variant official -Port 7105
```

The qualified profile uses `--prefill-chunk 2048`, INT8 group-64 KV, MTP K=3, the optimized
proposal head, 131,072 logical context tokens, one active request, one Device checkpoint, eight
Host State slots, and 8GiB Host KV. Select `-Variant uncensored` to publish
`qwen3.8-27b-uncensored` instead.

Readiness must be checked through HTTP after the model is loaded:

```powershell
Invoke-RestMethod http://127.0.0.1:7105/v1/models
```

## Windows benchmark result

Measured on the verified system with INT8 KV, CUDA Graphs, MTP K=3, optimized proposal head,
prefill chunk 2048, one discarded warmup, and three repetitions:

| Artifact | pp2048 | pp2048+tg256 | MTP acceptance |
|---|---:|---:|---:|
| Official Qwen3.8-27B NVFP4 v3 | 1,135.88 tok/s | 228.14 tok/s | 99.17% |
| Uncensored Qwen3.8-27B NVFP4 v2 | 1,130.50 tok/s | 228.08 tok/s | 99.17% |

Build and reproduce the benchmark with the command in the root README. These numbers use a fixed
high-acceptance corpus and are not a promise for arbitrary natural-language prompts.

## Troubleshooting

- `ERROR_IO_PENDING` during artifact loading means the executable predates the Windows overlapped
  I/O fix; rebuild from the current branch.
- `0xC0000135` means required vcpkg DLLs are missing beside the executable; use the build script's
  Release output directory rather than copying only the EXE.
- CUDA Graph OOM means the selected context/KV allocation is too aggressive; reduce context before
  disabling graphs.
- A blank final answer with only reasoning usually means `max_tokens` was exhausted by thinking;
  use `-NoThinking` in the CLI or `reasoning_effort: "none"` in an HTTP request.
- First startup includes artifact upload, Volta weight permutation, cache allocation, and graph
  capture. Probe `/v1/models` instead of assuming that process creation means readiness.

## Support boundary

Only native Windows plus one V100 32GB is qualified. Reports from Linux, WSL, Docker, V100 16GB,
other GPU architectures, multi-GPU setups, modified artifacts, or unsupported CUDA releases do not
describe this project's supported configuration.
