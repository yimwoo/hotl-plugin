# HOTL Plugin Installer for Cline (Windows)
# Requires: PowerShell 5.1+ (ships with Windows 10+)

$ErrorActionPreference = "Stop"

$HotlDir = Join-Path $env:USERPROFILE ".cline\hotl"
$RulesSrc = Join-Path $HotlDir "cline\rules"
$ScriptsSrc = Join-Path $HotlDir "scripts"
$GlobalRulesDir = Join-Path $env:USERPROFILE "Documents\Cline\Rules"
$GlobalScriptsDir = Join-Path $env:USERPROFILE "Documents\Cline\Scripts"

# Windows path values for placeholder replacement
$HotlHomePath = Join-Path $env:USERPROFILE ".cline\hotl"
$ScriptsHomePath = $GlobalScriptsDir

# -- Step 1: Install HOTL globally ------------------------------------------------

if (Test-Path (Join-Path $HotlDir ".git")) {
    Write-Host "Updating HOTL plugin at $HotlDir..."
    git -C $HotlDir pull
} else {
    Write-Host "Installing HOTL plugin to $HotlDir..."
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $TestFile = Join-Path $ScriptDir "cline\rules\hotl-operating-model.md"
    if (Test-Path $TestFile) {
        if (-not (Test-Path $HotlDir)) {
            New-Item -ItemType Directory -Force -Path $HotlDir | Out-Null
        }
        Copy-Item -Recurse -Force -Path (Join-Path $ScriptDir "*") -Destination $HotlDir
    } else {
        git clone https://github.com/yimwoo/hotl-plugin.git $HotlDir
    }
}

# -- Step 2: Install rules globally to ~/Documents/Cline/Rules/ -------------------

if (-not (Test-Path $GlobalRulesDir)) {
    New-Item -ItemType Directory -Force -Path $GlobalRulesDir | Out-Null
}

$Copied = 0
Get-ChildItem -Path $RulesSrc -Filter "hotl-*.md" -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item -Force -Path $_.FullName -Destination $GlobalRulesDir
    $Copied++
}

if ($Copied -eq 0) {
    Write-Host "ERROR: No rule files found in $RulesSrc" -ForegroundColor Red
    Write-Host "Try re-running: git clone https://github.com/yimwoo/hotl-plugin.git $HotlDir"
    exit 1
}

# Replace path placeholders with Windows paths in installed rule copies
Get-ChildItem -Path $GlobalRulesDir -Filter "hotl-*.md" | ForEach-Object {
    $Content = Get-Content $_.FullName -Raw
    $Content = $Content -replace '__HOTL_HOME__', $HotlHomePath
    $Content = $Content -replace '__SCRIPTS_HOME__', $ScriptsHomePath
    Set-Content -Path $_.FullName -Value $Content -NoNewline
}

# -- Step 3: Install scripts globally to ~/Documents/Cline/Scripts/ ---------------

if (-not (Test-Path $GlobalScriptsDir)) {
    New-Item -ItemType Directory -Force -Path $GlobalScriptsDir | Out-Null
}

if (Test-Path $ScriptsSrc) {
    Get-ChildItem -Path $ScriptsSrc -Filter "*.sh" -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Force -Path $_.FullName -Destination $GlobalScriptsDir
    }
}

# -- Step 4: Install runtime (hotl-rt) to Scripts directory ------------------------

$RuntimeSrc = Join-Path $HotlDir "runtime\hotl-rt"
if (Test-Path $RuntimeSrc) {
    Copy-Item -Force -Path $RuntimeSrc -Destination (Join-Path $GlobalScriptsDir "hotl-rt")
}

# -- Done --------------------------------------------------------------------------

Write-Host ""
Write-Host "HOTL for Cline installed successfully!"
Write-Host ""
Write-Host "  Global skills:  $HotlDir\skills\"
Write-Host "  Global rules:   $GlobalRulesDir\ ($Copied rule files)"
Write-Host "  Global scripts: $GlobalScriptsDir\"
Write-Host ""
Write-Host "  Rules apply to ALL projects in Cline - no per-project setup needed."
Write-Host ""
Write-Host "Available workflows - just tell Cline:"
Write-Host '  "brainstorm this feature"     - design with HOTL contracts before coding'
Write-Host '  "plan the implementation"     - create a hotl-workflow-<slug>.md'
Write-Host '  "execute the plan"            - run the workflow with checkpoints'
Write-Host '  "subagent execute the plan"   - delegate reviewed workflow steps in-session'
Write-Host '  "use TDD"                     - RED-GREEN-REFACTOR cycle'
Write-Host '  "debug this"                  - systematic 4-phase debugging'
Write-Host '  "review the code"             - checklist-based code review'
Write-Host ""
Write-Host "Update: powershell -ExecutionPolicy Bypass -File $HotlDir\update.ps1"
