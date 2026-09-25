**English** | [简体中文](README.zh-CN.md)

# NInfer Windows V100

Native Windows port of NInfer for **one NVIDIA Tesla V100 32GB (`sm_70`)**. This repository is
Windows-only: Linux, WSL, Docker, Blackwell, consumer RTX GPUs, multi-GPU, and other CUDA
architectures are outside its supported platform contract.

The port follows [geoffwatts/ninfer-v100](https://github.com/geoffwatts/ninfer-v100), itself based
on [Neroued/ninfer](https://github.com/Neroued/ninfer), and adds the MSVC/vcpkg build, Windows
artifact I/O, launch tooling, and real-model qualification. It is not affiliated with the upstream
authors.

## Latest verified result

Qwen3.8-27B NVFP4 was measured through the public `ninfer_bench` Engine route on Windows:

| Artifact | pp2048 | pp2048+tg256 | MTP acceptance |
|---|---:|---:|---:|
| Official Qwen3.8-27B NVFP4 v3 | **1,135.88 tok/s** | **228.14 tok/s** | 99.17% |
| Uncensored Qwen3.8-27B NVFP4 v2 | 1,130.50 tok/s | 228.08 tok/s | 99.17% |

Test system: Tesla PG503-216 32GB (Volta 7.0, V100 OEM identifier), driver 576.57, CUDA 12.9,
Windows 10, INT8 group-64 KV, CUDA Graphs, MTP K=3, optimized proposal head, prefill chunk 2048,
one warmup and three measured repetitions. The committed corpus has unusually high speculative
acceptance; ordinary prompts vary with context and acceptance rate.

Real generation and serving checks also pass:

- official artifact SHA-256 verified, loaded as `qwen3.8-27b/nvfp4`;
- uncensored artifact SHA-256 verified, loaded and served as `qwen3.8-27b-uncensored`;
- deterministic greedy output and token IDs repeated exactly;
- Chinese CLI generation, OpenAI `/v1/models`, and `/v1/chat/completions` verified;
- 131,072-token INT8 KV service profile starts with CUDA Graphs enabled.

## Supported platform

| Component | Supported configuration |
|---|---|
| OS | 64-bit Windows 10/11 |
| GPU | One Tesla V100 32GB, including OEM `PG503-216` |
| GPU mode | TCC |
| CUDA | Toolkit 12.8 or 12.9 |
| Compiler | Visual Studio 2022, Desktop development with C++ |
| Dependencies | vcpkg manifest (`ffmpeg`, `curl`, `zlib`) |
| Build architecture | `sm_70` only |

The build script rejects non-Volta GPUs. V100 16GB is not a qualified Qwen3.8-27B NVFP4 target.

## Models

The recommended profile is Qwen3.8-27B NVFP4. Both files are ignored by Git and remain local.

| Variant | File | Size | Source |
|---|---|---:|---|
| Official | `qwen3_8_27b_nvfp4.ninfer` | 22.09 GiB | [neroued](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer) |
| Uncensored | `qwen3_8_27b_nvfp4_uncensored.ninfer` | 22.09 GiB | [JMVRoill](https://huggingface.co/JMVRoill/Qwen3.8-27B-Uncensored-nvfp4-NInfer) |

The uncensored artifact is third-party and has substantially reduced safety alignment. It has not
received a complete capability or safety evaluation. Do not expose it to untrusted users without
authentication, moderation, and applicable legal controls.

## Build

Install CUDA 12.8/12.9, Visual Studio 2022 C++, Git, CMake, and vcpkg, then run from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -Command `
  ".\build-v100-windows.ps1 -VcpkgRoot C:\src\vcpkg -Clean 2>&1 | Tee-Object build-v100.log"
```

Outputs are under `build-v100\apps\Release`: `ninfer.exe`, `ninfer-serve.exe`, and
`ninfer-perplexity.exe`.

## Download and run

Download one or both artifacts with resumable transfer, exact size checks, and SHA-256 validation:

```powershell
.\download-qwen38-v100.ps1 -Variant official
.\download-qwen38-v100.ps1 -Variant uncensored
# Or download both:
.\download-qwen38-v100.ps1 -Variant all
```

Run one request. `-NoThinking` leaves the output budget for the final answer:

```powershell
.\run-qwen38-v100.ps1 `
  -Variant official `
  -NoThinking `
  -Prompt "Explain prefill and decode in three sentences." `
  -MaxNew 256
```

Replace `official` with `uncensored` to select the alternate artifact.

## Serve

Start the recommended V100 profile on localhost:

```powershell
.\serve-qwen38-v100.ps1 -Variant official -Port 7105
```

Windows Explorer shortcuts are also provided: double-click `start-qwen38-official.bat` or
`start-qwen38-uncensored.bat`. Keep the console open while serving and press `Ctrl+C` to stop.
Both launchers use port 7105, so run only one at a time.

The script selects INT8 KV, MTP K=3, prefill chunk 2048, one active request, 131,072-token logical
context, Device/Host continuation retention, and CUDA Graphs. For the alternate model:

```powershell
.\serve-qwen38-v100.ps1 -Variant uncensored -Port 7105
```

Check the service:

```powershell
Invoke-RestMethod http://127.0.0.1:7105/v1/models

$body = @{
  model = "qwen3.8-27b"
  messages = @(@{ role = "user"; content = "Calculate 29 times 31." })
  max_tokens = 64
  reasoning_effort = "none"
} | ConvertTo-Json -Depth 5

Invoke-RestMethod http://127.0.0.1:7105/v1/chat/completions `
  -Method Post -ContentType "application/json; charset=utf-8" -Body $body
```

Use model ID `qwen3.8-27b-uncensored` when serving the uncensored variant.

## Benchmark

Benchmarks are optional and excluded from the default build:

```powershell
cmake -S . -B build-v100 -DNINFER_BUILD_BENCHMARKS=ON
cmake --build build-v100 --config Release --target ninfer_bench -j

.\build-v100\bench\Release\ninfer_bench.exe `
  --weights models\qwen3_8_27b_nvfp4.ninfer `
  -p 2048 -pg "2048,256" -r 3 --warmup 1 `
  --max-ctx 4096 --prefill-chunk 2048 --kv-dtype int8 `
  --spec mtp --draft-tokens 3 --lm-head-draft
```

## Scope and limits

- One V100, one resident model, and one to eight startup-fixed active requests.
- No multi-GPU, distributed serving, weight offload, request preemption, or runtime model discovery.
- Text and optional image/video input through CLI, OpenAI-compatible, and Anthropic-compatible APIs.
- Official `.ninfer` v2 and v3 containers are supported; arbitrary GGUF/Safetensors files are not.
- NVFP4 executes through Volta-specific software decode and tuned FP16 tensor-core/SIMT kernels.
- Model files, logs, build outputs, and benchmark reports are deliberately excluded from Git.

## Documentation

- [Windows V100 build and operating guide](docs/V100-BUILD.md)
- [中文 Windows V100 指南](docs/V100-BUILD.zh-CN.md)
- [CLI reference](docs/cli.md)
- [HTTP serving reference](docs/serving.md)
- [V100 kernel qualification and upstream performance notes](docs/v100.md)
- [Benchmark reference](bench/README.md)

## License

Code is distributed under the [Apache License 2.0](LICENSE). Model artifacts retain their own
licenses and provenance. Users are responsible for model-license compliance and generated output.
