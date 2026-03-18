param(
    [string]$Version = "latest",
    [string]$OutputPath = "tools/TTSModManager.exe"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

$repoRoot = Get-RepoRoot
$output = Join-Path $repoRoot $OutputPath
Ensure-Directory -Path (Split-Path -Parent $output)

$releaseUrl = if ($Version -eq "latest") {
    "https://api.github.com/repos/argonui/TTSModManager/releases/latest"
} else {
    "https://api.github.com/repos/argonui/TTSModManager/releases/tags/$Version"
}

Write-Host "Fetching release metadata from $releaseUrl"
$release = Invoke-RestMethod -Uri $releaseUrl -Headers @{ "User-Agent" = "tts-mod-repo-bootstrap" }
$asset = $release.assets | Where-Object { $_.name -match 'TTSModManager.*\.exe$' } | Select-Object -First 1

if (-not $asset) {
    throw "Unable to find Windows executable asset in release '$Version'."
}

Write-Host "Downloading $($asset.name) to $output"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $output
Write-Host "Installed TTSModManager to $output"
