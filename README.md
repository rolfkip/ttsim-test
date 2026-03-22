# Tabletop Simulator Mod Repository

This repository is structured to manage multiple Tabletop Simulator (TTS) games in one codebase. Each game is self-contained under its own folder and is built/validated through shared scripts.

## Repository Layout

- `uno/`: UNO game root.
- `uno/mod-source/`: source-controlled UNO mod project directory.
- `uno/dist/`: UNO build outputs (`workshop.json`), never hand-edited.
- `uno/assets-manifest.json`: UNO hosted asset URL manifest.
- `assets-src/`: source assets you own/edit before publishing to hosted URLs.
- `releases/`: release notes and metadata snapshots.
- `scripts/`: shared PowerShell automation (`-Game` is required for bootstrap/build/validate).
- `tools/`: local utility binaries (for example `TTSModManager.exe`).
- `.github/workflows/`: CI and release artifact workflows.

## Prerequisites

- Windows + PowerShell 7+ recommended.
- Tabletop Simulator installed.
- A local TTS save JSON to bootstrap from.
- Optional: VS Code with Tabletop Simulator Lua extension for rapid script iteration.

## Quick Start

1. Install TTSModManager:

```powershell
pwsh ./scripts/install-ttsmodmanager.ps1
```

2. Bootstrap from a local TTS save JSON:

```powershell
pwsh ./scripts/bootstrap.ps1 -Game uno -SourceJsonPath "C:\Users\<you>\Documents\My Games\Tabletop Simulator\Mods\Workshop\123456789.json"
```

3. Build a distributable Workshop JSON:

```powershell
pwsh ./scripts/build.ps1 -Game uno
```

4. Validate output and URLs:

```powershell
pwsh ./scripts/validate.ps1 -Game uno
```

## Build Contract

- Input: `<game>/mod-source/` + `<game>/assets-manifest.json`
- Output: `<game>/dist/workshop.json`
- URL replacement tokens supported in source JSON/text:
- `asset://<key>`
- `{{asset:<key>}}`

The key must exist in the selected game's `assets-manifest.json` and map to a valid hosted URL.

## Bootstrap Contract

`scripts/bootstrap.ps1` performs a reverse conversion with:

```text
TTSModManager --reverse --moddir=<repo>\<game>\mod-source --modfile=<local-save-json> --writesrc
```

This initializes source structure from a real save and creates `<game>/mod-source/.bootstrap-complete`.

## Validation Contract

`scripts/validate.ps1` returns non-zero on:

- malformed JSON in `<game>/dist/workshop.json` (or selected file),
- missing expected TTS fields for a save root,
- local-only file references (`C:\...`, `file://...`, local docs paths),
- broken hosted URLs in `<game>/assets-manifest.json` (unless `-SkipRemoteUrlCheck`).

## Development Loop

1. Edit code/data in `uno/mod-source/` and `assets-src/`.
2. If assets changed, publish assets externally and update `uno/assets-manifest.json`.
3. Run build + validate for UNO.
4. Load/test in TTS.
5. Upload/update manually via `UPLOAD -> WORKSHOP UPLOAD` in TTS.

## Release Workflow

1. Build and validate locally.
2. Add release note under `releases/<version>.md`.
3. Tag and push.
4. GitHub release workflow attaches:
- generated `uno/dist/workshop.json`,
- `uno/assets-manifest.json`.

Steam Workshop publish/update remains manual by design.
