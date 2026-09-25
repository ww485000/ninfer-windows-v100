param(
    [ValidateSet("official", "uncensored", "all")]
    [string]$Variant = "all"
)

$ErrorActionPreference = "Stop"
$modelsDir = Join-Path $PSScriptRoot "models"
New-Item -ItemType Directory -Force -Path $modelsDir | Out-Null

$artifacts = @(
    @{
        Variant = "official"
        Repo = "neroued/Qwen3.8-27B-nvfp4-NInfer"
        File = "qwen3_8_27b_nvfp4.ninfer"
        Bytes = 23719715844L
        Sha256 = "74d2c57145e6ff11d1d2faa79594477f9bc903a611af1fb20218189fbbb77d82"
    },
    @{
        Variant = "uncensored"
        Repo = "JMVRoill/Qwen3.8-27B-Uncensored-nvfp4-NInfer"
        File = "qwen3_8_27b_nvfp4_uncensored.ninfer"
        Bytes = 23719496192L
        Sha256 = "43025bb64f2cb558d9ede6269f8a3c2ed8ebfa4619344fe1ba8e955ba4979218"
    }
)

foreach ($artifact in $artifacts) {
    if ($Variant -ne "all" -and $Variant -ne $artifact.Variant) { continue }

    $destination = Join-Path $modelsDir $artifact.File
    if (-not (Test-Path -LiteralPath $destination) -or
        (Get-Item -LiteralPath $destination).Length -ne $artifact.Bytes) {
        $url = "https://huggingface.co/$($artifact.Repo)/resolve/main/$($artifact.File)"
        & curl.exe -L --fail --retry 10 --retry-delay 5 -C - --output $destination $url
        if ($LASTEXITCODE -ne 0) { throw "Download failed for $($artifact.Variant)" }
    }

    $item = Get-Item -LiteralPath $destination
    if ($item.Length -ne $artifact.Bytes) {
        throw "Unexpected size for $($artifact.Variant): $($item.Length)"
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destination).Hash.ToLowerInvariant()
    if ($actualHash -ne $artifact.Sha256) {
        throw "SHA-256 mismatch for $($artifact.Variant): $actualHash"
    }
    Write-Output "$($artifact.Variant) ready: $destination"
}
