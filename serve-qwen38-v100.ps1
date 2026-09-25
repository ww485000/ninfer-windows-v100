param(
    [ValidateRange(1, 65535)]
    [int]$Port = 7105,
    [ValidateSet("official", "uncensored")]
    [string]$Variant = "official",
    [string]$ModelPath = "",
    [string]$BinaryPath = "$PSScriptRoot\build-v100\apps\Release\ninfer-serve.exe"
)

$ErrorActionPreference = "Stop"

if (-not $ModelPath) {
    if ($Variant -eq "uncensored") {
        $ModelPath = Join-Path $PSScriptRoot "models\qwen3_8_27b_nvfp4_uncensored.ninfer"
        $ModelId = "qwen3.8-27b-uncensored"
    } else {
        $ModelPath = Join-Path $PSScriptRoot "models\qwen3_8_27b_nvfp4.ninfer"
        $ModelId = "qwen3.8-27b"
    }
} else {
    $ModelId = if ($Variant -eq "uncensored") { "qwen3.8-27b-uncensored" } else { "qwen3.8-27b" }
}

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
    --model-id $ModelId `
    --max-context 131072 `
    --prefill-chunk 2048 `
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
