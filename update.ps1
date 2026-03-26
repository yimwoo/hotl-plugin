# HOTL Plugin Update Script (Windows / PowerShell)
# Updates Claude Code, Codex, and Cline installations if present.
# Requires: PowerShell 5.1+, git

param(
    [switch]$ForceCodex,
    [switch]$Check,
    [switch]$NativeSkills
)

$ErrorActionPreference = "Stop"

# --check: just report whether an update is available, then exit
if ($Check) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $CheckScript = Join-Path $ScriptDir "scripts\check-update.ps1"
    if (Test-Path $CheckScript) {
        & powershell -ExecutionPolicy Bypass -File $CheckScript
    } else {
        $CheckScriptSh = Join-Path $ScriptDir "scripts\check-update.sh"
        if (Test-Path $CheckScriptSh) {
            bash $CheckScriptSh 2>$null
        } else {
            Write-Host "check-update script not found."
        }
    }
    exit 0
}

$ClaudePluginDir = Join-Path $env:USERPROFILE ".claude\plugins\hotl"
$ClaudeCacheDir = Join-Path $env:USERPROFILE ".claude\plugins\cache\hotl-plugin\hotl"
$CodexHotlDir = Join-Path $env:USERPROFILE ".codex\hotl"
$ClineHotlDir = Join-Path $env:USERPROFILE ".cline\hotl"
$ClineRulesDir = Join-Path $env:USERPROFILE "Documents\Cline\Rules"
$ClineScriptsDir = Join-Path $env:USERPROFILE "Documents\Cline\Scripts"
$ClineSkillsDir = Join-Path $env:USERPROFILE ".cline\skills\hotl"
$ClineModeFile = Join-Path $ClineHotlDir ".cline-install-mode"

$Found = 0
$Updated = 0

function Test-GitWorkTree {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    try {
        $result = git -C $Path rev-parse --is-inside-work-tree 2>$null
        return $result -eq "true"
    } catch {
        return $false
    }
}

function Get-CurrentBranch {
    param([string]$Path)
    try {
        return (git -C $Path branch --show-current 2>$null)
    } catch {
        return ""
    }
}

function Test-HasLocalChanges {
    param([string]$Path)
    $status = git -C $Path status --short --untracked-files=all 2>$null
    return -not [string]::IsNullOrWhiteSpace($status)
}

function Sync-Directory {
    param([string]$Source, [string]$Destination)
    if (Test-Path $Destination) {
        Remove-Item -Recurse -Force $Destination
    }
    Copy-Item -Recurse -Force -Path $Source -Destination $Destination
}

# -- Claude Code -------------------------------------------------------------------

if (Test-GitWorkTree $ClaudePluginDir) {
    $Found++
    Write-Host "Updating Claude Code plugin at $ClaudePluginDir..."
    git -C $ClaudePluginDir pull

    # Refresh plugin cache if it exists
    if (Test-Path $ClaudeCacheDir) {
        Get-ChildItem -Path $ClaudeCacheDir -Directory | ForEach-Object {
            $CacheVerDir = $_.FullName
            Write-Host "Refreshing plugin cache at $CacheVerDir..."

            $Dirs = @("skills", "commands", "hooks", "scripts", "runtime")
            foreach ($Dir in $Dirs) {
                $SrcDir = Join-Path $ClaudePluginDir $Dir
                $DstDir = Join-Path $CacheVerDir $Dir
                if (Test-Path $SrcDir) {
                    if (Test-Path $DstDir) {
                        Remove-Item -Recurse -Force $DstDir
                    }
                    Copy-Item -Recurse -Force -Path $SrcDir -Destination $DstDir
                }
            }
        }
        Write-Host "  Cache refreshed."
    }

    $Updated++
    Write-Host "  Claude Code plugin updated."
    Write-Host ""
}

# -- Codex -------------------------------------------------------------------------

if (Test-GitWorkTree $CodexHotlDir) {
    $Found++
    $CodexBranch = Get-CurrentBranch $CodexHotlDir
    if ([string]::IsNullOrEmpty($CodexBranch)) { $CodexBranch = "detached HEAD" }
    $CodexDirty = Test-HasLocalChanges $CodexHotlDir

    Write-Host "Updating Codex plugin at $CodexHotlDir..."

    if ($CodexDirty -and -not $ForceCodex) {
        # Backup local changes
        $BackupRoot = Join-Path $env:USERPROFILE ".codex\backups\hotl"
        $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $BackupDir = Join-Path $BackupRoot $Timestamp
        New-Item -ItemType Directory -Force -Path (Join-Path $BackupDir "worktree") | Out-Null
        git -C $CodexHotlDir status --short --branch > (Join-Path $BackupDir "git-status.txt") 2>$null
        Copy-Item -Recurse -Force -Path (Join-Path $CodexHotlDir "*") -Destination (Join-Path $BackupDir "worktree") -Exclude ".git"
        Write-Host "Codex install has local changes; backed them up to $BackupDir before updating."
        Write-Host ""
    } elseif ($CodexDirty) {
        Write-Host "Codex install has local changes; --ForceCodex set, skipping backup and resetting to origin/main."
        Write-Host ""
    }

    if ($CodexBranch -ne "main") {
        Write-Host "Codex install is on branch $CodexBranch; switching back to stable branch main."
        git -C $CodexHotlDir switch main
        Write-Host ""
    }

    git -C $CodexHotlDir fetch origin main
    git -C $CodexHotlDir reset --hard origin/main
    git -C $CodexHotlDir clean -fd

    $SkillsLink = Join-Path $env:USERPROFILE ".agents\skills\hotl"
    if (Test-Path $SkillsLink) {
        Write-Host "  Skills symlink/junction intact at $SkillsLink"
    }

    $Updated++
    Write-Host "  Codex plugin updated."
    Write-Host ""
}

# -- Cline -------------------------------------------------------------------------

if (Test-GitWorkTree $ClineHotlDir) {
    $Found++
    Write-Host "Updating Cline plugin at $ClineHotlDir..."
    git -C $ClineHotlDir pull

    # Determine Cline install mode
    $ClineMode = "legacy-rules"
    if ($NativeSkills) {
        $ClineMode = "native-skills"
        Set-Content -Path $ClineModeFile -Value $ClineMode -NoNewline
        Write-Host "  Switching Cline install mode to native-skills."
    } elseif (Test-Path $ClineModeFile) {
        $ClineMode = (Get-Content $ClineModeFile -Raw).Trim()
    }

    # Skill and rule name lists
    $NativeSkillNames = @("brainstorming", "writing-plans", "document-review", "executing-plans", "subagent-execution", "tdd", "systematic-debugging", "code-review", "pr-reviewing", "loop-execution")
    $LegacyWorkflowRules = @("hotl-brainstorming.md", "hotl-planning.md", "hotl-execution.md", "hotl-document-review.md", "hotl-subagent-execution.md", "hotl-tdd.md", "hotl-debugging.md", "hotl-code-review.md", "hotl-pr-review.md")

    $HotlHomePath = Join-Path $env:USERPROFILE ".cline\hotl"

    function Replace-ClinePlaceholders {
        param([string]$FilePath)
        $Content = Get-Content $FilePath -Raw
        $Content = $Content -replace '__HOTL_HOME__', $HotlHomePath
        $Content = $Content -replace '__SCRIPTS_HOME__', $ClineScriptsDir
        Set-Content -Path $FilePath -Value $Content -NoNewline
    }

    if (-not (Test-Path $ClineRulesDir)) {
        New-Item -ItemType Directory -Force -Path $ClineRulesDir | Out-Null
    }

    $ClineRulesSrc = Join-Path $ClineHotlDir "cline\rules"

    if ($ClineMode -eq "native-skills") {
        Write-Host "  Refreshing Cline in native-skills mode..."

        # Refresh operating model rule only
        $OpModelSrc = Join-Path $ClineRulesSrc "hotl-operating-model.md"
        if (Test-Path $OpModelSrc) {
            Copy-Item -Force -Path $OpModelSrc -Destination $ClineRulesDir
            Replace-ClinePlaceholders (Join-Path $ClineRulesDir "hotl-operating-model.md")
        }

        # Remove legacy workflow rules
        foreach ($RuleName in $LegacyWorkflowRules) {
            $RulePath = Join-Path $ClineRulesDir $RuleName
            if (Test-Path $RulePath) { Remove-Item -Force $RulePath }
        }

        # Refresh native skills via copy
        if (-not (Test-Path $ClineSkillsDir)) {
            New-Item -ItemType Directory -Force -Path $ClineSkillsDir | Out-Null
        }
        foreach ($SkillName in $NativeSkillNames) {
            $SkillSrc = Join-Path $ClineHotlDir "skills\$SkillName"
            $SkillDst = Join-Path $ClineSkillsDir $SkillName
            if (Test-Path $SkillSrc) {
                if (Test-Path $SkillDst) { Remove-Item -Recurse -Force $SkillDst }
                Copy-Item -Recurse -Force -Path $SkillSrc -Destination $SkillDst
            }
        }
        Write-Host "  1 rule + 10 native skills refreshed."
    } else {
        Write-Host "  Refreshing Cline in legacy-rules mode..."

        # Remove native skills if they exist
        if (Test-Path $ClineSkillsDir) {
            Remove-Item -Recurse -Force $ClineSkillsDir
        }

        # Refresh all rules
        if (Test-Path $ClineRulesSrc) {
            $RuleCount = 0
            Get-ChildItem -Path $ClineRulesSrc -Filter "hotl-*.md" | ForEach-Object {
                Copy-Item -Force -Path $_.FullName -Destination $ClineRulesDir
                $RuleCount++
            }
            Get-ChildItem -Path $ClineRulesDir -Filter "hotl-*.md" | ForEach-Object {
                Replace-ClinePlaceholders $_.FullName
            }
            Write-Host "  $RuleCount rule files updated."
        }
    }

    # Refresh global scripts
    $ClineScriptsSrc = Join-Path $ClineHotlDir "scripts"
    if (Test-Path $ClineScriptsSrc) {
        if (-not (Test-Path $ClineScriptsDir)) {
            New-Item -ItemType Directory -Force -Path $ClineScriptsDir | Out-Null
        }
        Get-ChildItem -Path $ClineScriptsSrc -Filter "*.sh" -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -Force -Path $_.FullName -Destination $ClineScriptsDir
        }
        Write-Host "  Scripts refreshed at $ClineScriptsDir."
    }

    # Refresh runtime (hotl-rt)
    $RuntimeSrc = Join-Path $ClineHotlDir "runtime\hotl-rt"
    if (Test-Path $RuntimeSrc) {
        if (-not (Test-Path $ClineScriptsDir)) {
            New-Item -ItemType Directory -Force -Path $ClineScriptsDir | Out-Null
        }
        Copy-Item -Force -Path $RuntimeSrc -Destination (Join-Path $ClineScriptsDir "hotl-rt")
        Write-Host "  Runtime (hotl-rt) refreshed."
    }

    $Updated++
    Write-Host "  Cline plugin updated (mode: $ClineMode)."
    Write-Host ""
}

# -- Result ------------------------------------------------------------------------

if ($Found -eq 0) {
    Write-Host "No HOTL installations found."
    Write-Host ""
    Write-Host "Install for Claude Code:  powershell -ExecutionPolicy Bypass -File install.ps1"
    Write-Host "Install for Codex:        see .codex/INSTALL.md"
    Write-Host "Install for Cline:        powershell -ExecutionPolicy Bypass -File install-cline.ps1"
    exit 1
}

Write-Host "Done. $Updated installation(s) updated."
Write-Host "Restart Codex to re-discover updated HOTL skills."
Write-Host "Restart your Claude Code session or start a new Cline task to use the latest version."
