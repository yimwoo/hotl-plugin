# HOTL Plugin Update Script (Windows / PowerShell)
# Updates Claude Code, Codex, and Cline installations if present.
# Requires: PowerShell 5.1+, git

param(
    [switch]$ForceCodex,
    [switch]$Check,
    [switch]$NativeSkills,
    [switch]$Status,
    [switch]$CodexPlugin,
    [switch]$ForceCodexPlugin
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

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CodexMarketplaceUser = Join-Path $env:USERPROFILE ".agents\plugins\marketplace.json"
$CodexMarketplaceLocal = Join-Path $ScriptDir ".agents\plugins\marketplace.json"

# ── Helper functions ─────────────────────────────────────────────────────────

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

function Test-HotlInMarketplace {
    param([string]$MktPath)
    if (-not (Test-Path $MktPath)) { return $false }
    try {
        $data = Get-Content $MktPath -Raw | ConvertFrom-Json
        $entry = $data.plugins | Where-Object { $_.name -eq "hotl" }
        return [bool]$entry
    } catch {
        return $false
    }
}

function Get-HotlMarketplaceVersion {
    param([string]$MktPath)
    try {
        $data = Get-Content $MktPath -Raw | ConvertFrom-Json
        $entry = $data.plugins | Where-Object { $_.name -eq "hotl" }
        if ($entry) { return $entry.version }
        return "unknown"
    } catch {
        return "unknown"
    }
}

function Sync-CodexPluginCache {
    param([string]$SourceDir)

    if (-not (Test-Path $SourceDir)) { return }

    $CacheRoot = Join-Path $env:USERPROFILE ".codex\plugins\cache\codex-plugins\hotl"
    $Refreshed = $false

    if (Test-Path $CacheRoot) {
        Get-ChildItem -Path $CacheRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $CacheDir = $_.FullName
            Write-Host "Refreshing Codex plugin cache at $CacheDir..."
            if (-not (Test-Path $CacheDir)) {
                New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
            }
            Get-ChildItem -Force -Path $CacheDir -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
            Get-ChildItem -Force -Path $SourceDir | Where-Object { $_.Name -ne ".git" } | ForEach-Object {
                Copy-Item -Recurse -Force -Path $_.FullName -Destination $CacheDir
            }
            $Refreshed = $true
        }
    }

    if (-not $Refreshed) {
        $SeedDir = Join-Path $CacheRoot "local"
        Write-Host "Seeding Codex plugin cache at $SeedDir..."
        New-Item -ItemType Directory -Force -Path $SeedDir | Out-Null
        Get-ChildItem -Force -Path $SeedDir -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
        Get-ChildItem -Force -Path $SourceDir | Where-Object { $_.Name -ne ".git" } | ForEach-Object {
            Copy-Item -Recurse -Force -Path $_.FullName -Destination $SeedDir
        }
        $Refreshed = $true
    }

    if ($Refreshed) {
        Write-Host "  Codex plugin cache refreshed."
    }
}

# -Status: read-only report of all HOTL install modes, then exit
if ($Status) {
    Write-Host "HOTL Installation Status"
    Write-Host ""

    # Claude Code
    $ClaudeDir = Join-Path $env:USERPROFILE ".claude\plugins\hotl"
    if ((Test-Path $ClaudeDir) -and (Test-GitWorkTree $ClaudeDir)) {
        $ClaudeVerFile = Join-Path $ClaudeDir "VERSION"
        $ClaudeVer = if (Test-Path $ClaudeVerFile) { (Get-Content $ClaudeVerFile -Raw).Trim() } else { "unknown" }
        Write-Host "Claude Code:     installed (v$ClaudeVer) at $ClaudeDir"
    } else {
        Write-Host "Claude Code:     not found"
    }

    # Codex native-skills
    $CodexNativeFound = $false
    $CodexDir = Join-Path $env:USERPROFILE ".codex\hotl"
    if ((Test-Path $CodexDir) -and (Test-GitWorkTree $CodexDir)) {
        $CodexRev = try { (git -C $CodexDir rev-parse --short HEAD 2>$null) } catch { "unknown" }
        Write-Host "Codex native:    installed (rev $CodexRev) at $CodexDir"
        $CodexNativeFound = $true
    } else {
        Write-Host "Codex native:    not found"
    }

    # Codex plugin (check both user-global and repo-local marketplaces)
    $PluginFound = $false
    $PluginReported = $false
    foreach ($CodexMkt in @($CodexMarketplaceUser, $CodexMarketplaceLocal)) {
        if (Test-HotlInMarketplace $CodexMkt) {
            $PluginVer = Get-HotlMarketplaceVersion $CodexMkt
            if (-not $PluginVer) { $PluginVer = "unknown" }
            if (-not $PluginReported) {
                Write-Host "Codex plugin:    registered (v$PluginVer) in $CodexMkt"
                $PluginReported = $true
            } else {
                Write-Host "                 also registered (v$PluginVer) in $CodexMkt"
            }
            $PluginFound = $true
        }
    }
    if (-not $PluginFound) {
        Write-Host "Codex plugin:    not found"
    }

    # Show source checkout health
    $CodexSource = Join-Path $env:USERPROFILE ".codex\plugins\hotl-source"
    if ($PluginFound) {
        if (Test-Path (Join-Path $CodexSource ".git")) {
            $SrcRev = try { (git -C $CodexSource rev-parse --short HEAD 2>$null) } catch { "unknown" }
            Write-Host "                 source checkout (rev $SrcRev) at $CodexSource"
        } else {
            Write-Host "                 WARNING: source checkout not found at $CodexSource"
        }
    } elseif (Test-Path (Join-Path $CodexSource ".git")) {
        $SrcRev = try { (git -C $CodexSource rev-parse --short HEAD 2>$null) } catch { "unknown" }
        Write-Host "Codex plugin:    source checkout (rev $SrcRev) at $CodexSource (no marketplace entry)"
    }

    # Warn if both Codex modes are present
    if ($CodexNativeFound -and $PluginFound) {
        Write-Host ""
        Write-Host "Warning: both Codex install modes are present. HOTL cannot guarantee which"
        Write-Host "source Codex will use when duplicate skill names exist."
        Write-Host "Recommendation: keep only one active Codex install mode at a time."
    }

    # Cline
    Write-Host ""
    $ClineDir = Join-Path $env:USERPROFILE ".cline\hotl"
    if ((Test-Path $ClineDir) -and (Test-GitWorkTree $ClineDir)) {
        $ClineModeF = Join-Path $ClineDir ".cline-install-mode"
        $ClineMode = if (Test-Path $ClineModeF) { (Get-Content $ClineModeF -Raw).Trim() } else { "legacy-rules" }
        Write-Host "Cline:           installed ($ClineMode) at $ClineDir"
    } else {
        Write-Host "Cline:           not found"
    }

    exit 0
}

# -CodexPlugin: update the plugin source checkout, then exit
if ($CodexPlugin) {
    $CodexPluginSource = Join-Path $env:USERPROFILE ".codex\plugins\hotl-source"

    if (-not (Test-Path (Join-Path $CodexPluginSource ".git"))) {
        Write-Host "No HOTL plugin source checkout found at $CodexPluginSource."
        Write-Host "Run install.sh --codex-plugin first."
        $NativeSkillsDir = Join-Path $env:USERPROFILE ".codex\hotl"
        if (Test-Path $NativeSkillsDir) {
            Write-Host ""
            Write-Host "Hint: a native-skills install exists at $NativeSkillsDir."
            Write-Host "Use update.ps1 (without -CodexPlugin) to update that instead."
        }
        exit 1
    }

    Write-Host "Updating Codex plugin source checkout at $CodexPluginSource..."

    if (Test-HasLocalChanges $CodexPluginSource) {
        if ($ForceCodexPlugin) {
            Write-Host "Source checkout has local changes; -ForceCodexPlugin set, skipping backup."
        } else {
            $BackupRoot = Join-Path $env:USERPROFILE ".codex\backups\hotl-plugin"
            $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $BackupDir = Join-Path $BackupRoot $Timestamp
            New-Item -ItemType Directory -Force -Path (Join-Path $BackupDir "worktree") | Out-Null
            git -C $CodexPluginSource status --short --branch > (Join-Path $BackupDir "git-status.txt") 2>$null
            Copy-Item -Recurse -Force -Path (Join-Path $CodexPluginSource "*") -Destination (Join-Path $BackupDir "worktree") -Exclude ".git"
            Write-Host "Source checkout has local changes; backed them up to $BackupDir."
        }
    }

    git -C $CodexPluginSource fetch origin main
    git -C $CodexPluginSource reset --hard origin/main
    git -C $CodexPluginSource clean -fd

    $VerFile = Join-Path $CodexPluginSource "VERSION"
    $Ver = if (Test-Path $VerFile) { (Get-Content $VerFile -Raw).Trim() } else { "unknown" }
    Sync-CodexPluginCache $CodexPluginSource
    Write-Host "  Updated to version $Ver."
    Write-Host ""
    Write-Host "Restart Codex to pick up the updated plugin."
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
$Skipped = 0

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

# Update Codex plugin source checkout if it exists
$CodexPluginSource = Join-Path $env:USERPROFILE ".codex\plugins\hotl-source"
if (Test-Path (Join-Path $CodexPluginSource ".git")) {
    $Found++
    Write-Host "Updating Codex plugin source checkout at $CodexPluginSource..."

    if (Test-HasLocalChanges $CodexPluginSource) {
        if ($ForceCodexPlugin) {
            Write-Host "  Source checkout has local changes; -ForceCodexPlugin set, skipping backup."
        } else {
            $BackupRoot = Join-Path $env:USERPROFILE ".codex\backups\hotl-plugin"
            $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $BackupDir = Join-Path $BackupRoot $Timestamp
            New-Item -ItemType Directory -Force -Path (Join-Path $BackupDir "worktree") | Out-Null
            git -C $CodexPluginSource status --short --branch > (Join-Path $BackupDir "git-status.txt") 2>$null
            Copy-Item -Recurse -Force -Path (Join-Path $CodexPluginSource "*") -Destination (Join-Path $BackupDir "worktree") -Exclude ".git"
            Write-Host "  Source checkout has local changes; backed them up to $BackupDir."
        }
    }

    git -C $CodexPluginSource fetch origin main
    git -C $CodexPluginSource reset --hard origin/main
    git -C $CodexPluginSource clean -fd

    $VerFile = Join-Path $CodexPluginSource "VERSION"
    $Ver = if (Test-Path $VerFile) { (Get-Content $VerFile -Raw).Trim() } else { "unknown" }
    Sync-CodexPluginCache $CodexPluginSource
    $Updated++
    Write-Host "  Codex plugin source updated (v$Ver)."
    Write-Host ""
} elseif ((Test-Path (Join-Path $env:USERPROFILE ".codex\plugins\hotl")) -and -not (Test-Path (Join-Path $CodexPluginSource ".git"))) {
    # Old copied-bundle install detected, no source checkout yet
    Write-Host "Note: HOTL is installed as a Codex plugin via copied bundle at ~/.codex/plugins/hotl."
    Write-Host "This install is reported but skipped by update.ps1."
    Write-Host "The updater can refresh multiple HOTL installs in one run, but it does not"
    Write-Host "update this copied bundle from GitHub directly."
    Write-Host "To enable Codex plugin updates, migrate to the"
    Write-Host "source checkout model by running:"
    Write-Host ""
    Write-Host "  bash install.sh --codex-plugin"
    Write-Host ""
    Write-Host "This will clone to ~/.codex/plugins/hotl-source/ and remove the old bundle."
    Write-Host ""
    $Skipped++
}

if (Test-GitWorkTree $CodexHotlDir) {
    $Found++
    $CodexBranch = Get-CurrentBranch $CodexHotlDir
    if ([string]::IsNullOrEmpty($CodexBranch)) { $CodexBranch = "detached HEAD" }
    $CodexDirty = Test-HasLocalChanges $CodexHotlDir

    Write-Host "Updating Codex native-skills install at $CodexHotlDir..."

    if ($CodexDirty -and -not $ForceCodex) {
        # Backup local changes
        $BackupRoot = Join-Path $env:USERPROFILE ".codex\backups\hotl"
        $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $BackupDir = Join-Path $BackupRoot $Timestamp
        New-Item -ItemType Directory -Force -Path (Join-Path $BackupDir "worktree") | Out-Null
        git -C $CodexHotlDir status --short --branch > (Join-Path $BackupDir "git-status.txt") 2>$null
        Copy-Item -Recurse -Force -Path (Join-Path $CodexHotlDir "*") -Destination (Join-Path $BackupDir "worktree") -Exclude ".git"
        Write-Host "Codex native-skills install has local changes; backed them up to $BackupDir before updating."
        Write-Host ""
    } elseif ($CodexDirty) {
        Write-Host "Codex native-skills install has local changes; --ForceCodex set, skipping backup and resetting to origin/main."
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
    Write-Host "  Codex native-skills install updated."
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
    Write-Host "Install for Codex:        see docs/README.codex.md"
    Write-Host "Install for Cline:        powershell -ExecutionPolicy Bypass -File install-cline.ps1"
    exit 1
}

Write-Host "Done. $Updated installation(s) updated in this run."
if ($Skipped -gt 0) {
    Write-Host "$Skipped installation(s) skipped."
}
Write-Host "Restart your Claude Code session or start a new Cline task to use the latest version."
