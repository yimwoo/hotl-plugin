# HOTL Session-Start Hook for Claude Code (Windows / PowerShell)
# Reads using-hotl SKILL.md, escapes for JSON, and outputs the hook response.

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginRoot = Split-Path -Parent $ScriptDir

# Best-effort update check — output to stderr so it doesn't contaminate JSON response
try {
    $CheckScript = Join-Path $PluginRoot "scripts\check-update.ps1"
    if (Test-Path $CheckScript) {
        & powershell -ExecutionPolicy Bypass -File $CheckScript 2>&1 | Write-Host
    } else {
        # Fall back to bash check-update if .ps1 doesn't exist yet
        $CheckScriptSh = Join-Path $PluginRoot "scripts\check-update.sh"
        if (Test-Path $CheckScriptSh) {
            bash $CheckScriptSh 2>$null
        }
    }
} catch {
    # Silently continue — update check is best-effort
}

$SkillFile = Join-Path $PluginRoot "skills\using-hotl\SKILL.md"
if (-not (Test-Path $SkillFile)) {
    Write-Error "HOTL session-start hook: using-hotl skill file not found at $SkillFile"
    exit 1
}

$UsingHotlContent = Get-Content $SkillFile -Raw

# Escape for JSON embedding
function ConvertTo-JsonSafeString {
    param([string]$Text)
    $Text = $Text -replace '\\', '\\'
    $Text = $Text -replace '"', '\"'
    $Text = $Text -replace "`r`n", '\n'
    $Text = $Text -replace "`n", '\n'
    $Text = $Text -replace "`r", '\r'
    $Text = $Text -replace "`t", '\t'
    return $Text
}

$EscapedContent = ConvertTo-JsonSafeString $UsingHotlContent
$EscapedPluginPath = ConvertTo-JsonSafeString $PluginRoot

$SessionContext = "<EXTREMELY_IMPORTANT>\nYou have HOTL superpowers.\n\n**Below is the full content of your 'hotl:using-hotl' skill - your introduction to using HOTL skills. For all other skills, use the 'Skill' tool:**\n\n$EscapedContent\n\n**HOTL Plugin Base Path:**\nWhen running hotl-rt or HOTL scripts (document-lint.sh, render-execution-summary.sh, finalize-codex-summary.sh, show-codex-current-step.sh), use this base path: $EscapedPluginPath\n\nExamples:\n  bash $EscapedPluginPath/runtime/hotl-rt init <workflow-file>\n  bash $EscapedPluginPath/scripts/render-execution-summary.sh --platform claude <json-file>\n  bash $EscapedPluginPath/scripts/document-lint.sh <workflow-file>\n</EXTREMELY_IMPORTANT>"

$JsonOutput = @"
{
  "additional_context": "$SessionContext",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$SessionContext"
  }
}
"@

Write-Output $JsonOutput
exit 0
