# ninfer-windows-v100

Native Windows + Tesla V100 (Volta, sm_70) port of NInfer.

Porting bases:
- natpate/ninfer-windows (Windows/MSVC base)
- geoffwatts/ninfer-v100 (Volta/V100 CUDA base)

Target stack:
- Windows 10 x64
- Tesla V100 32GB, TCC mode
- CUDA Toolkit 12.8
- Visual Studio 2022
- CMake 3.28+
- Qwen3.8-27B NVFP4
- INT8 KV cache
- MTP speculative decoding
- OpenAI-compatible server

Work is being staged incrementally: Windows build first, then Volta kernels and runtime integration.
