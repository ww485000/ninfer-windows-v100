[English](README.md) | **简体中文**

# NInfer Windows V100

这是 NInfer 面向 **单张 NVIDIA Tesla V100 32GB（`sm_70`）** 的原生 Windows 移植。
本仓库仅支持 Windows：Linux、WSL、Docker、Blackwell、消费级 RTX、多 GPU 和其他 CUDA 架构
均不属于本项目的支持范围。

本移植以 [geoffwatts/ninfer-v100](https://github.com/geoffwatts/ninfer-v100) 为性能基线，后者源自
[Neroued/ninfer](https://github.com/Neroued/ninfer)。本仓库增加 MSVC/vcpkg 构建、Windows artifact
I/O、启动工具和真实模型验证，与上游作者无隶属或背书关系。

## 最新成果

Qwen3.8-27B NVFP4 已通过公开 `ninfer_bench` Engine 路线在 Windows 上实测：

| Artifact | pp2048 | pp2048+tg256 | MTP 接受率 |
|---|---:|---:|---:|
| 官方 Qwen3.8-27B NVFP4 v3 | **1,135.88 tok/s** | **228.14 tok/s** | 99.17% |
| Uncensored Qwen3.8-27B NVFP4 v2 | 1,130.50 tok/s | 228.08 tok/s | 99.17% |

测试环境：Tesla PG503-216 32GB（Volta 7.0，V100 OEM 标识）、驱动 576.57、CUDA 12.9、
Windows 10、INT8 group-64 KV、CUDA Graph、MTP K=3、优化 proposal head、prefill chunk 2048，
一次预热、三次测量。固定测试语料的投机接受率很高；普通提示的速度取决于上下文和接受率。

真实生成与服务验证也已通过：

- 官方 artifact SHA-256 校验通过，识别为 `qwen3.8-27b/nvfp4`；
- uncensored artifact SHA-256 校验通过，以 `qwen3.8-27b-uncensored` 独立发布；
- greedy 输出和 token IDs 两次逐字节一致；
- 中文 CLI、OpenAI `/v1/models` 和 `/v1/chat/completions` 验证通过；
- 131,072-token INT8 KV 服务配置可启用 CUDA Graph 正常启动。

## 支持平台

| 组件 | 支持配置 |
|---|---|
| 操作系统 | 64 位 Windows 10/11 |
| GPU | 单张 Tesla V100 32GB，包括 OEM `PG503-216` |
| GPU 模式 | TCC |
| CUDA | Toolkit 12.8 或 12.9 |
| 编译器 | Visual Studio 2022，Desktop development with C++ |
| 依赖 | vcpkg manifest（`ffmpeg`、`curl`、`zlib`） |
| 编译架构 | 仅 `sm_70` |

构建脚本会拒绝非 Volta GPU。V100 16GB 不是经过验证的 Qwen3.8-27B NVFP4 目标。

## 模型

推荐使用 Qwen3.8-27B NVFP4。模型文件被 Git 忽略，只保存在本机。

| 版本 | 文件 | 大小 | 来源 |
|---|---|---:|---|
| 官方 | `qwen3_8_27b_nvfp4.ninfer` | 22.09 GiB | [neroued](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer) |
| Uncensored | `qwen3_8_27b_nvfp4_uncensored.ninfer` | 22.09 GiB | [JMVRoill](https://huggingface.co/JMVRoill/Qwen3.8-27B-Uncensored-nvfp4-NInfer) |

uncensored artifact 来自第三方，大幅移除了安全对齐，尚未完成系统能力和安全评测。没有身份认证、
内容审核及适用法律控制时，请勿向不受信任用户开放。

## 编译

安装 CUDA 12.8/12.9、Visual Studio 2022 C++、Git、CMake 和 vcpkg，然后运行：

```powershell
powershell -ExecutionPolicy Bypass -Command `
  ".\build-v100-windows.ps1 -VcpkgRoot C:\src\vcpkg -Clean 2>&1 | Tee-Object build-v100.log"
```

输出位于 `build-v100\apps\Release`：`ninfer.exe`、`ninfer-serve.exe` 和
`ninfer-perplexity.exe`。

## 下载与运行

下载支持断点续传，并强制检查文件大小和 SHA-256：

```powershell
.\download-qwen38-v100.ps1 -Variant official
.\download-qwen38-v100.ps1 -Variant uncensored
# 或同时下载：
.\download-qwen38-v100.ps1 -Variant all
```

执行单次推理；`-NoThinking` 可把输出预算留给最终答案：

```powershell
.\run-qwen38-v100.ps1 `
  -Variant official `
  -NoThinking `
  -Prompt "用三句话解释 prefill 和 decode。" `
  -MaxNew 256
```

将 `official` 替换为 `uncensored` 即可切换模型。

## 启动服务

启动推荐的 V100 本机服务配置：

```powershell
.\serve-qwen38-v100.ps1 -Variant official -Port 7105
```

也可以在资源管理器中双击 `start-qwen38-official.bat` 或
`start-qwen38-uncensored.bat`。服务运行期间请保持窗口打开，按 `Ctrl+C` 停止。两个脚本都使用
7105 端口，因此同一时间只能启动一个。双击 `stop-qwen38-server.bat` 可安全停止监听进程；如果
7105 端口属于其他程序，停止脚本会拒绝结束它。

脚本使用 INT8 KV、MTP K=3、prefill chunk 2048、单活跃请求、131,072-token 逻辑上下文、
Device/Host 续写缓存和 CUDA Graph。切换到 uncensored：

```powershell
.\serve-qwen38-v100.ps1 -Variant uncensored -Port 7105
```

检查服务：

```powershell
Invoke-RestMethod http://127.0.0.1:7105/v1/models

$body = @{
  model = "qwen3.8-27b"
  messages = @(@{ role = "user"; content = "计算 29 乘以 31。" })
  max_tokens = 64
  reasoning_effort = "none"
} | ConvertTo-Json -Depth 5

Invoke-RestMethod http://127.0.0.1:7105/v1/chat/completions `
  -Method Post -ContentType "application/json; charset=utf-8" -Body $body
```

uncensored 服务对应的模型 ID 是 `qwen3.8-27b-uncensored`。

## 性能测试

benchmark 默认不编译，需要显式启用：

```powershell
cmake -S . -B build-v100 -DNINFER_BUILD_BENCHMARKS=ON
cmake --build build-v100 --config Release --target ninfer_bench -j

.\build-v100\bench\Release\ninfer_bench.exe `
  --weights models\qwen3_8_27b_nvfp4.ninfer `
  -p 2048 -pg "2048,256" -r 3 --warmup 1 `
  --max-ctx 4096 --prefill-chunk 2048 --kv-dtype int8 `
  --spec mtp --draft-tokens 3 --lm-head-draft
```

## 项目边界

- 单张 V100、一个常驻模型、启动时固定 1–8 个活跃请求。
- 不支持多 GPU、分布式服务、权重卸载、请求抢占或运行时模型发现。
- CLI、OpenAI 兼容和 Anthropic 兼容 API；可选图像/视频输入。
- 支持官方 `.ninfer` v2/v3；不直接加载任意 GGUF 或 Safetensors。
- NVFP4 通过 Volta 软件解码及优化的 FP16 Tensor Core/SIMT kernel 执行。
- 模型、日志、构建输出和 benchmark 报告不提交到 Git。

## 文档

- [Windows V100 编译与运行指南](docs/V100-BUILD.zh-CN.md)
- [English Windows V100 guide](docs/V100-BUILD.md)
- [CLI 参考](docs/cli.md)
- [HTTP 服务参考](docs/serving.md)
- [V100 kernel 验证与上游性能笔记](docs/v100.md)
- [Benchmark 参考](bench/README.md)

## 许可证

代码采用 [Apache License 2.0](LICENSE)。模型 artifact 保留各自许可证与来源；用户自行负责模型许可、
使用方式和生成内容。
