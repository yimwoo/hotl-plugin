# HOTL Plugin Installer for Claude Code (Windows)
# Requires: PowerShell 5.1+ (ships with Windows 10+)

$ErrorActionPreference = "Stop"

$PluginName = "hotl"
$InstallDir = Join-Path $env:USERPROFILE ".claude\plugins\$PluginName"

Write-Host "Installing HOTL plugin to $InstallDir..."

if (Test-Path $InstallDir) {
    Write-Host "Existing installation found. Running unified updater..."
    $UpdateScript = Join-Path $InstallDir "update.ps1"
    if (Test-Path $UpdateScript) {
        & powershell -ExecutionPolicy Bypass -File $UpdateScript
    } else {
        Write-Host "WARNING: update.ps1 not found at $UpdateScript. Re-installing from scratch."
        Remove-Item -Recurse -Force $InstallDir
    }
}

if (-not (Test-Path $InstallDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ParentDir = Split-Path -Parent $InstallDir
    if (-not (Test-Path $ParentDir)) {
        New-Item -ItemType Directory -Force -Path $ParentDir | Out-Null
    }
    Copy-Item -Recurse -Path $ScriptDir -Destination $InstallDir
}

# Guide user to configure Claude Code settings
$SettingsFile = Join-Path $env:USERPROFILE ".claude\settings.json"
if (Test-Path $SettingsFile) {
    $SettingsContent = Get-Content $SettingsFile -Raw
    if ($SettingsContent -match [regex]::Escape($PluginName)) {
        Write-Host "Plugin already configured in $SettingsFile"
    } else {
        Write-Host ""
        Write-Host "Add the following to $SettingsFile under 'plugins':"
        Write-Host "  `"$PluginName`": `"$InstallDir`""
    }
} else {
    Write-Host ""
    Write-Host "Claude Code settings not found at $SettingsFile"
    Write-Host "Manually add plugin path to your Claude Code settings: $InstallDir"
}

Write-Host ""
Write-Host "HOTL plugin installed. Start a new Claude Code session to activate."
Write-Host ""
Write-Host "Available commands:"
Write-Host "  /hotl:brainstorm   - Design a feature with HOTL contracts"
Write-Host "  /hotl:write-plan   - Create docs/plans/YYYY-MM-DD-<slug>-workflow.md"
Write-Host "  /hotl:loop         - Execute workflow file with auto-approve"
Write-Host "  /hotl:execute-plan - Linear execution with checkpoints"
Write-Host "  /hotl:subagent-execute - Same-session delegated execution with controller-owned verification"
Write-Host "  /hotl:setup        - Generate adapter files for your team's tools"
Write-Host ""
Write-Host "For Codex setup: see docs/README.codex.md"
Write-Host "For Cline setup:  see docs/README.cline.md"
