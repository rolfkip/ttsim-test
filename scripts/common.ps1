Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Resolve-TTSModManager {
    param(
        [string]$TTSModManagerPath
    )

    $candidates = @()
    if ($TTSModManagerPath) {
        $candidates += $TTSModManagerPath
    }
    if ($env:TTSMODMANAGER_PATH) {
        $candidates += $env:TTSMODMANAGER_PATH
    }
    $candidates += (Join-Path (Get-RepoRoot) "tools/TTSModManager.exe")

    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction SilentlyContinue
        if ($resolved) {
            return $resolved.Path
        }
    }

    throw "TTSModManager.exe not found. Run: pwsh ./scripts/install-ttsmodmanager.ps1 or pass -TTSModManagerPath."
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Test-IsHttpUrl {
    param([string]$Value)
    if (-not $Value) { return $false }
    return $Value -match '^https?://'
}

