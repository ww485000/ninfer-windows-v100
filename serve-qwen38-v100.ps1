param(
    [ValidateRange(1, 65535)]
    [int]$Port = 7105,
    [string]$ModelPath = "$PSScriptRoot\models\qwen3_8_27b_nvfp4.ninfer",
    [string]$BinaryPath = "$PSScriptRoot\build-v100\apps\Release\ninfer-serve.exe"
)

$ErrorActionPreference = "Stop"

foreach ($required in @($BinaryPath, $ModelPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file not found: $required"
    }
}

& nvidia-smi --query-gpu=name,compute_cap,memory.total,memory.free,driver_version --format=csv,noheader
if ($LASTEXITCODE -ne 0) { throw "nvidia-smi failed with exit code $LASTEXITCODE" }

& $BinaryPath $ModelPath `
    --host 127.0.0.1 `
    --port $Port `
    --device 0 `
    --model-id qwen3.8-27b `
    --max-context 131072 `
    --kv-capacity auto `
    --max-concurrency 1 `
    --kv-dtype int8 `
    --device-state-slots 1 `
    --host-state-slots 8 `
    --host-kv-mib 8192 `
    --spec mtp --draft-tokens 3 `
    --lm-head-draft `
    --preserve-thinking `
    --pending-timeout-ms 600000

if ($LASTEXITCODE -ne 0) { throw "ninfer-serve failed with exit code $LASTEXITCODE" }
