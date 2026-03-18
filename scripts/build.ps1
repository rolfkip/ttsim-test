param(
    [string]$ModDir = "mod-source",
    [string]$ManifestPath = "assets-manifest.json",
    [string]$OutputPath = "dist/workshop.json",
    [string]$TTSModManagerPath,
    [switch]$AllowUnbootstrapped
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

function Replace-AssetTokens {
    param(
        [Parameter(Mandatory = $true)]$Node,
        [Parameter(Mandatory = $true)][hashtable]$AssetMap
    )

    if ($Node -is [string]) {
        $updated = $Node
        $updated = [regex]::Replace($updated, '\{\{asset:([^}]+)\}\}', {
                param($m)
                $key = $m.Groups[1].Value
                if ($AssetMap.ContainsKey($key)) { return $AssetMap[$key] }
                return $m.Value
            })
        $updated = [regex]::Replace($updated, 'asset://([a-zA-Z0-9._-]+)', {
                param($m)
                $key = $m.Groups[1].Value
                if ($AssetMap.ContainsKey($key)) { return $AssetMap[$key] }
                return $m.Value
            })
        return $updated
    }

    if ($Node -is [System.Collections.IList]) {
        for ($i = 0; $i -lt $Node.Count; $i++) {
            $Node[$i] = Replace-AssetTokens -Node $Node[$i] -AssetMap $AssetMap
        }
        return $Node
    }

    if ($Node -is [pscustomobject]) {
        foreach ($prop in $Node.PSObject.Properties) {
            $prop.Value = Replace-AssetTokens -Node $prop.Value -AssetMap $AssetMap
        }
        return $Node
    }

    return $Node
}

$repoRoot = Get-RepoRoot
$modDirPath = Join-Path $repoRoot $ModDir
$manifestFile = Join-Path $repoRoot $ManifestPath
$outputFile = Join-Path $repoRoot $OutputPath
$bootstrapMarker = Join-Path $modDirPath ".bootstrap-complete"

if (-not $AllowUnbootstrapped -and -not (Test-Path -LiteralPath $bootstrapMarker)) {
    throw "mod-source is not bootstrapped yet. Run scripts/bootstrap.ps1 first (or use -AllowUnbootstrapped)."
}

if (-not (Test-Path -LiteralPath $modDirPath)) {
    throw "Missing mod directory: $modDirPath"
}

Ensure-Directory -Path (Split-Path -Parent $outputFile)

$ttsmm = Resolve-TTSModManager -TTSModManagerPath $TTSModManagerPath

Write-Host "Building workshop JSON from $modDirPath"
& $ttsmm --moddir="$modDirPath" --modfile="$outputFile"
if ($LASTEXITCODE -ne 0) {
    throw "TTSModManager build failed with exit code $LASTEXITCODE"
}

if (Test-Path -LiteralPath $manifestFile) {
    $manifest = Get-Content -Raw -Path $manifestFile | ConvertFrom-Json
    $map = @{}
    if ($manifest.assets) {
        foreach ($prop in $manifest.assets.PSObject.Properties) {
            $asset = $prop.Value
            if ($asset.url) {
                $map[$prop.Name] = [string]$asset.url
            }
        }
    }

    if ($map.Count -gt 0) {
        Write-Host "Applying asset URL tokens from $manifestFile"
        $workshopJson = Get-Content -Raw -Path $outputFile | ConvertFrom-Json
        $workshopJson = Replace-AssetTokens -Node $workshopJson -AssetMap $map
        $normalized = $workshopJson | ConvertTo-Json -Depth 100 -Compress
        Set-Content -Path $outputFile -Value $normalized -NoNewline
    }
}

Write-Host "Build complete: $outputFile"
