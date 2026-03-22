param(
    [Parameter(Mandatory = $true)]
    [string]$Game,
    [string]$JsonPath,
    [string]$ManifestPath,
    [switch]$SkipRemoteUrlCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

function Get-StringValues {
    param([Parameter(Mandatory = $true)]$Node)

    $values = New-Object System.Collections.Generic.List[string]

    function Visit {
        param($Current)

        if ($null -eq $Current) { return }

        if ($Current -is [string]) {
            $values.Add($Current) | Out-Null
            return
        }

        if ($Current -is [System.Collections.IList]) {
            foreach ($item in $Current) { Visit $item }
            return
        }

        if ($Current -is [pscustomobject]) {
            foreach ($prop in $Current.PSObject.Properties) { Visit $prop.Value }
            return
        }
    }

    Visit $Node
    return $values
}

function Test-RemoteUrl {
    param([Parameter(Mandatory = $true)][string]$Url)
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec 15 -ErrorAction Stop
        return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400)
    } catch {
        try {
            $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 15 -ErrorAction Stop
            return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400)
        } catch {
            return $false
        }
    }
}

$repoRoot = Get-RepoRoot
$defaults = Get-GameDefaultPaths -Game $Game
$jsonFile = if ($PSBoundParameters.ContainsKey("JsonPath")) { Resolve-RepoPath -Path $JsonPath -RepoRoot $repoRoot } else { $defaults.OutputPath }
$manifestFile = if ($PSBoundParameters.ContainsKey("ManifestPath")) { Resolve-RepoPath -Path $ManifestPath -RepoRoot $repoRoot } else { $defaults.ManifestPath }
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$manifest = $null
if (Test-Path -LiteralPath $manifestFile) {
    try {
        $manifest = Get-Content -Raw -Path $manifestFile | ConvertFrom-Json
    } catch {
        $errors.Add("Malformed JSON in assets manifest: $manifestFile") | Out-Null
    }
}

if ($manifest -and $manifest.assets) {
    foreach ($prop in $manifest.assets.PSObject.Properties) {
        $assetName = $prop.Name
        $asset = $prop.Value
        if (-not $asset.url) {
            $errors.Add("Manifest asset '$assetName' is missing 'url'.") | Out-Null
            continue
        }
        $url = [string]$asset.url
        if (-not (Test-IsHttpUrl -Value $url)) {
            $errors.Add("Manifest asset '$assetName' must use http/https URL: $url") | Out-Null
            continue
        }
        if (-not $SkipRemoteUrlCheck) {
            if (-not (Test-RemoteUrl -Url $url)) {
                $errors.Add("Manifest asset '$assetName' URL is not reachable: $url") | Out-Null
            }
        }
    }
}

if (-not (Test-Path -LiteralPath $jsonFile)) {
    $warnings.Add("Target JSON not found at $jsonFile. Skipping mod JSON validation.") | Out-Null
} else {
    $jsonObj = $null
    try {
        $jsonObj = Get-Content -Raw -Path $jsonFile | ConvertFrom-Json
    } catch {
        $errors.Add("Malformed JSON in target file: $jsonFile") | Out-Null
    }

    if ($jsonObj) {
        if (-not $jsonObj.PSObject.Properties["ObjectStates"]) {
            $errors.Add("Missing required top-level field 'ObjectStates' in $jsonFile") | Out-Null
        }

        $stringValues = Get-StringValues -Node $jsonObj
        foreach ($value in $stringValues) {
            if ($value -match '^[a-zA-Z]:\\' -or $value -match '^file://') {
                $errors.Add("Local-only file reference detected: $value") | Out-Null
            }
            if ($value -match 'Documents\\My Games\\Tabletop Simulator' -or $value -match '^/Users/.+/Documents/My Games/Tabletop Simulator') {
                $errors.Add("Local TTS path detected in JSON: $value") | Out-Null
            }
        }
    }
}

foreach ($warning in $warnings) {
    Write-Warning $warning
}

if ($errors.Count -gt 0) {
    foreach ($errorMessage in $errors) {
        Write-Error $errorMessage
    }
    throw "Validation failed with $($errors.Count) error(s)."
}

Write-Host "Validation passed."
