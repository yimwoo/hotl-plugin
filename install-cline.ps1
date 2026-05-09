# HOTL Plugin Installer for Cline (Windows)
# Requires: PowerShell 5.1+ (ships with Windows 10+)

param(
    [switch]$NativeSkills
)

$ErrorActionPreference = "Stop"

$InstallMode = if ($NativeSkills) { "native-skills" } else { "legacy-rules" }

$HotlDir = Join-Path $env:USERPROFILE ".cline\hotl"
$RulesSrc = Join-Path $HotlDir "cline\rules"
$ScriptsSrc = Join-Path $HotlDir "scripts"
$GlobalRulesDir = Join-Path $env:USERPROFILE "Documents\Cline\Rules"
$GlobalScriptsDir = Join-Path $env:USERPROFILE "Documents\Cline\Scripts"
$ClineSkillsDir = Join-Path $env:USERPROFILE ".cline\skills\hotl"
$ModeFile = Join-Path $HotlDir ".cline-install-mode"

# Windows path values for placeholder replacement
$HotlHomePath = Join-Path $env:USERPROFILE ".cline\hotl"
$ScriptsHomePath = $GlobalScriptsDir

# The 10 native Cline skills (by directory name)
$NativeSkillNames = @("brainstorming", "writing-plans", "document-review", "executing-plans", "subagent-execution", "tdd", "systematic-debugging", "code-review", "pr-reviewing", "loop-execution")

# The 9 legacy workflow rule files (all except hotl-operating-model.md)
$LegacyWorkflowRules = @("hotl-brainstorming.md", "hotl-planning.md", "hotl-execution.md", "hotl-document-review.md", "hotl-subagent-execution.md", "hotl-tdd.md", "hotl-debugging.md", "hotl-code-review.md", "hotl-pr-review.md")

function Replace-Placeholders {
    param([string]$FilePath)
    $Content = Get-Content $FilePath -Raw
    $Content = $Content -replace '__HOTL_HOME__', $HotlHomePath
    $Content = $Content -replace '__SCRIPTS_HOME__', $ScriptsHomePath
    Set-Content -Path $FilePath -Value $Content -NoNewline
}

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

# Persist install mode
Set-Content -Path $ModeFile -Value $InstallMode -NoNewline

# -- Step 2: Install rules and/or skills ------------------------------------------

if (-not (Test-Path $GlobalRulesDir)) {
    New-Item -ItemType Directory -Force -Path $GlobalRulesDir | Out-Null
}

if ($InstallMode -eq "native-skills") {
    # Native skills mode: 1 rule + 10 native skills

    # Install only hotl-operating-model.md as a rule
    $OpModelSrc = Join-Path $RulesSrc "hotl-operating-model.md"
    if (Test-Path $OpModelSrc) {
        Copy-Item -Force -Path $OpModelSrc -Destination $GlobalRulesDir
        Replace-Placeholders (Join-Path $GlobalRulesDir "hotl-operating-model.md")
        Write-Host "  Installed hotl-operating-model.md as global rule."
    } else {
        Write-Host "ERROR: hotl-operating-model.md not found in $RulesSrc" -ForegroundColor Red
        exit 1
    }

    # Remove legacy workflow rules if they exist
    foreach ($RuleName in $LegacyWorkflowRules) {
        $RulePath = Join-Path $GlobalRulesDir $RuleName
        if (Test-Path $RulePath) { Remove-Item -Force $RulePath }
    }

    # Install native skills via copy
    if (-not (Test-Path $ClineSkillsDir)) {
        New-Item -ItemType Directory -Force -Path $ClineSkillsDir | Out-Null
    }
    $SkillCount = 0
    foreach ($SkillName in $NativeSkillNames) {
        $SkillSrc = Join-Path $HotlDir "skills\$SkillName"
        $SkillDst = Join-Path $ClineSkillsDir $SkillName
        if (Test-Path $SkillSrc) {
            if (Test-Path $SkillDst) { Remove-Item -Recurse -Force $SkillDst }
            Copy-Item -Recurse -Force -Path $SkillSrc -Destination $SkillDst
            $SkillCount++
        } else {
            Write-Host "WARNING: Skill directory not found: $SkillSrc" -ForegroundColor Yellow
        }
    }

    $Copied = 1
    Write-Host "  Installed $SkillCount native Cline skills to $ClineSkillsDir."

} else {
    # Legacy rules mode: all 10 rules

    # Remove native skills directory if it exists (cleanup from previous native-skills install)
    if (Test-Path $ClineSkillsDir) {
        Remove-Item -Recurse -Force $ClineSkillsDir
        Write-Host "  Removed previous native skills installation."
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
        Replace-Placeholders $_.FullName
    }
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
Write-Host "HOTL for Cline installed successfully! (mode: $InstallMode)"
Write-Host ""
if ($InstallMode -eq "native-skills") {
    Write-Host "  Global rule:    $GlobalRulesDir\hotl-operating-model.md"
    Write-Host "  Native skills:  $ClineSkillsDir\ ($SkillCount skills)"
} else {
    Write-Host "  Global skills:  $HotlDir\skills\"
    Write-Host "  Global rules:   $GlobalRulesDir\ ($Copied rule files)"
}
Write-Host "  Global scripts: $GlobalScriptsDir\"
Write-Host ""
Write-Host "  Mode persisted to $ModeFile"
Write-Host ""
Write-Host "  Workflows apply to ALL projects in Cline - no per-project setup needed."
Write-Host ""
Write-Host "Available workflows - just tell Cline:"
Write-Host '  "brainstorm this feature"     - design with HOTL contracts before coding'
Write-Host '  "plan the implementation"     - create docs/plans/YYYY-MM-DD-<slug>-workflow.md'
Write-Host '  "execute the plan"            - run the workflow with checkpoints'
Write-Host '  "subagent execute the plan"   - delegate reviewed workflow steps in-session'
Write-Host '  "use TDD"                     - RED-GREEN-REFACTOR cycle'
Write-Host '  "debug this"                  - systematic 4-phase debugging'
Write-Host '  "review the code"             - checklist-based code review'
Write-Host ""
Write-Host "Update: powershell -ExecutionPolicy Bypass -File $HotlDir\update.ps1"
