Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Resolve-RepoPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$RepoRoot = (Get-RepoRoot)
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return (Join-Path $RepoRoot $Path)
}

function Resolve-GameRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Game
    )

    $repoRoot = Get-RepoRoot
    $gameRoot = Join-Path $repoRoot $Game
    if (-not (Test-Path -LiteralPath $gameRoot -PathType Container)) {
        throw "Game directory '$Game' does not exist at $gameRoot."
    }
    return (Resolve-Path -LiteralPath $gameRoot).Path
}

function Get-GameDefaultPaths {
    param(
        [Parameter(Mandatory = $true)][string]$Game
    )

    $gameRoot = Resolve-GameRoot -Game $Game
    return [pscustomobject]@{
        GameRoot     = $gameRoot
        ModDir       = Join-Path $gameRoot "mod-source"
        ManifestPath = Join-Path $gameRoot "assets-manifest.json"
        OutputPath   = Join-Path $gameRoot "dist/workshop.json"
    }
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

