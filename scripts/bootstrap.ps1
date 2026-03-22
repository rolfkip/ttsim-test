param(
    [Parameter(Mandatory = $true)]
    [string]$Game,
    [Parameter(Mandatory = $true)]
    [string]$SourceJsonPath,
    [string]$ModDir,
    [string]$TTSModManagerPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

$repoRoot = Get-RepoRoot
$sourceJson = Resolve-Path -LiteralPath $SourceJsonPath -ErrorAction Stop
$defaults = Get-GameDefaultPaths -Game $Game
$modDirPath = if ($PSBoundParameters.ContainsKey("ModDir")) { Resolve-RepoPath -Path $ModDir -RepoRoot $repoRoot } else { $defaults.ModDir }
Ensure-Directory -Path $modDirPath

$ttsmm = Resolve-TTSModManager -TTSModManagerPath $TTSModManagerPath

Write-Host "Bootstrapping source from $($sourceJson.Path)"
& $ttsmm --reverse --moddir="$modDirPath" --modfile="$($sourceJson.Path)" --writesrc
if ($LASTEXITCODE -ne 0) {
    throw "TTSModManager reverse failed with exit code $LASTEXITCODE"
}

$markerPath = Join-Path $modDirPath ".bootstrap-complete"
Set-Content -Path $markerPath -Value "true" -NoNewline
Write-Host "Bootstrap complete. Marker written to $markerPath"
