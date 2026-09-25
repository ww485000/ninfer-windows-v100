[English](V100-BUILD.md) | **简体中文**

# Windows V100 编译与运行指南

本指南只面向本仓库唯一支持的部署目标：64 位 Windows、单张 Tesla V100 32GB、TCC 模式。
本项目不支持 Linux、WSL、Docker、RTX 或 Blackwell 构建。

## 已验证配置

| 组件 | 已验证配置 |
|---|---|
| GPU | Tesla PG503-216 32GB，Volta 计算能力 7.0 |
| 驱动 | 576.57，TCC |
| 系统 | Windows 10 64 位 |
| CUDA | 12.9；脚本也接受 12.8 |
| 编译器 | Visual Studio 2022 Community，MSVC 14.44 |
| CMake | 4.4.3 |
| 依赖 | vcpkg x64-windows manifest |

## 前置条件

1. 安装 NVIDIA 数据中心驱动，确认 `nvidia-smi` 显示 V100/PG503-216、32GB、计算能力 7.0、TCC。
2. 安装 CUDA Toolkit 12.8 或 12.9。
3. 安装 Visual Studio 2022，勾选 Desktop development with C++ 和 Windows SDK。
4. 安装 Git、CMake、vcpkg。下文假设 vcpkg 位于 `C:\src\vcpkg`。
5. 单模型至少预留 50GB；同时保留官方与 uncensored 模型建议至少 75GB。

## 编译

在仓库根目录的普通 PowerShell 中执行：

```powershell
powershell -ExecutionPolicy Bypass -Command `
  ".\build-v100-windows.ps1 -VcpkgRoot C:\src\vcpkg -Clean 2>&1 | Tee-Object build-v100.log"
```

脚本会查找 Visual Studio 和 CUDA、验证 GPU、配置 `sm_70`、恢复 vcpkg manifest，并编译三个
Release 应用。成功后生成：

```text
build-v100\apps\Release\ninfer.exe
build-v100\apps\Release\ninfer-serve.exe
build-v100\apps\Release\ninfer-perplexity.exe
```

之后修改源码可用增量编译：

```powershell
cmake --build build-v100 --config Release -j
```

## 模型

请使用仓库下载脚本，以获得断点续传、精确文件大小检查和 SHA-256 校验：

```powershell
.\download-qwen38-v100.ps1 -Variant official
.\download-qwen38-v100.ps1 -Variant uncensored
.\download-qwen38-v100.ps1 -Variant all
```

| 版本 | 发布 SHA-256 |
|---|---|
| 官方 v3 | `74d2c57145e6ff11d1d2faa79594477f9bc903a611af1fb20218189fbbb77d82` |
| Uncensored v2 | `43025bb64f2cb558d9ede6269f8a3c2ed8ebfa4619344fe1ba8e955ba4979218` |

uncensored artifact 来自第三方，已降低安全对齐，且没有完整能力或安全评测。

## CLI

```powershell
.\run-qwen38-v100.ps1 `
  -Variant official `
  -NoThinking `
  -Prompt "计算 37 乘以 43。" `
  -MaxNew 128
```

脚本会把 prompt 写入临时 UTF-8 messages 文件，使中文和其他 Unicode 文本绕过 Windows 窄字符
命令行编码问题。

## 服务

```powershell
.\serve-qwen38-v100.ps1 -Variant official -Port 7105
```

验证配置使用 `--prefill-chunk 2048`、INT8 group-64 KV、MTP K=3、优化 proposal head、
131,072 逻辑上下文、单活跃请求、一个 Device 检查点、八个 Host State 槽和 8GiB Host KV。
使用 `-Variant uncensored` 时，服务模型 ID 为 `qwen3.8-27b-uncensored`。

模型加载完成后通过 HTTP 判断就绪：

```powershell
Invoke-RestMethod http://127.0.0.1:7105/v1/models
```

## Windows 实测

在上述验证系统上，使用 INT8 KV、CUDA Graph、MTP K=3、优化 proposal head、prefill chunk
2048、一次丢弃预热和三次测量：

| Artifact | pp2048 | pp2048+tg256 | MTP 接受率 |
|---|---:|---:|---:|
| 官方 Qwen3.8-27B NVFP4 v3 | 1,135.88 tok/s | 228.14 tok/s | 99.17% |
| Uncensored Qwen3.8-27B NVFP4 v2 | 1,130.50 tok/s | 228.08 tok/s | 99.17% |

完整复现命令见根目录 README。该结果使用高接受率固定语料，不代表任意自然语言提示的固定速度。

## 常见问题

- artifact 加载出现 `ERROR_IO_PENDING`：可执行文件早于 Windows overlapped I/O 修复，请重新编译。
- 退出码 `0xC0000135`：EXE 旁缺少 vcpkg DLL；请直接使用构建脚本生成的 Release 目录。
- CUDA Graph OOM：上下文/KV 分配过大；先降低上下文，再考虑禁用 graph。
- 只有 reasoning、最终答案为空：thinking 用完了 `max_tokens`；CLI 使用 `-NoThinking`，HTTP 使用
  `reasoning_effort: "none"`。
- 首次启动包含权重上传、Volta 权重重排、缓存分配与 graph 捕获。请探测 `/v1/models`，不要把
  进程已经创建当作服务就绪。

## 支持边界

只有原生 Windows 加单张 V100 32GB 经过验证。Linux、WSL、Docker、V100 16GB、其他 GPU、
多 GPU、修改后的 artifact 或未支持 CUDA 版本不属于本项目的支持配置。
