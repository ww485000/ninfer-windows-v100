param(
    [string]$Prompt = "用三句话解释大语言模型的 prefill 和 decode 阶段，并给出简短结论。",
    [ValidateRange(1, 8192)]
    [int]$MaxNew = 256,
    [ValidateSet("official", "uncensored")]
    [string]$Variant = "official",
    [switch]$NoThinking,
    [string]$ModelPath = "",
    [string]$BinaryPath = "$PSScriptRoot\build-v100\apps\Release\ninfer.exe"
)

$ErrorActionPreference = "Stop"

if (-not $ModelPath) {
    $filename = if ($Variant -eq "uncensored") {
        "qwen3_8_27b_nvfp4_uncensored.ninfer"
    } else {
        "qwen3_8_27b_nvfp4.ninfer"
    }
    $ModelPath = Join-Path $PSScriptRoot "models\$filename"
}

foreach ($required in @($BinaryPath, $ModelPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file not found: $required"
    }
}

& nvidia-smi --query-gpu=name,compute_cap,memory.total,memory.free,driver_version --format=csv,noheader
if ($LASTEXITCODE -ne 0) { throw "nvidia-smi failed with exit code $LASTEXITCODE" }

$messagesPath = Join-Path ([System.IO.Path]::GetTempPath()) "ninfer-qwen38-$PID.json"
try {
    ConvertTo-Json -InputObject @(@{ role = "user"; content = $Prompt }) -Depth 4 |
        Set-Content -LiteralPath $messagesPath -Encoding utf8

    $arguments = @(
        $ModelPath,
        "--messages", $messagesPath,
        "--device", "0",
        "--max-context", "32768",
        "--max-new", "$MaxNew",
        "--kv-dtype", "int8",
        "--spec", "mtp", "--draft-tokens", "3",
        "--lm-head-draft",
        "--greedy",
        "--print-token-ids"
    )
    if ($NoThinking) { $arguments += "--no-thinking" }

    & $BinaryPath @arguments

    if ($LASTEXITCODE -ne 0) { throw "ninfer failed with exit code $LASTEXITCODE" }
} finally {
    Remove-Item -LiteralPath $messagesPath -Force -ErrorAction SilentlyContinue
}
