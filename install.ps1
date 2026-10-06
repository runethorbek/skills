<#
.SYNOPSIS
    Installs the Claude Code skills and agents in this repository into a
    personal Claude Code configuration directory.

.DESCRIPTION
    Copies every file under claude/skills/<name>/ (for each directory that
    contains a SKILL.md) and every *.md file under claude/agents/ into the
    matching location under the destination root.

    Files are copied one at a time. Identical files are skipped. A destination
    file that differs from the repository copy is reported as a conflict and
    left untouched unless -Force is given. Nothing is ever deleted.

.PARAMETER DestinationRoot
    Claude Code configuration directory to install into.
    Defaults to $env:USERPROFILE\.claude.

.PARAMETER Force
    Replace destination files that differ from the repository copy.

.EXAMPLE
    .\install.ps1 -WhatIf
    Preview what would be installed or updated.

.EXAMPLE
    .\install.ps1 -DestinationRoot $env:TEMP\claude-test
    Install into a scratch directory instead of the real configuration.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$DestinationRoot = (Join-Path $env:USERPROFILE '.claude'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Absolute path, so .NET file APIs and messages do not depend on the current directory.
$DestinationRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationRoot)

$sourceRoot = Join-Path $PSScriptRoot 'claude'
$skillsSource = Join-Path $sourceRoot 'skills'
$agentsSource = Join-Path $sourceRoot 'agents'

# Each item: source file, destination file, and a short display path.
$items = New-Object System.Collections.Generic.List[object]

function Add-Tree {
    param([string]$SourceDir, [string]$DestDir, [string]$Label, [string]$Filter = '*')
    Get-ChildItem -LiteralPath $SourceDir -Recurse -File -Filter $Filter | ForEach-Object {
        $relative = $_.FullName.Substring($SourceDir.Length).TrimStart('\', '/')
        $items.Add([pscustomobject]@{
            Source  = $_.FullName
            Dest    = Join-Path $DestDir $relative
            Display = Join-Path $Label $relative
        })
    }
}

# Skills: every directory under claude/skills that contains a SKILL.md.
$skillDirs = @()
if (Test-Path -LiteralPath $skillsSource -PathType Container) {
    $skillDirs = @(Get-ChildItem -LiteralPath $skillsSource -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf })
    Get-ChildItem -LiteralPath $skillsSource -Directory |
        Where-Object { $skillDirs.FullName -notcontains $_.FullName } |
        ForEach-Object { Write-Warning "Skipping claude\skills\$($_.Name): no SKILL.md." }
}
if ($skillDirs.Count -eq 0) {
    Write-Error "No installable skills found: expected claude\skills\<name>\SKILL.md under $PSScriptRoot." -ErrorAction Continue
    exit 1
}
foreach ($dir in $skillDirs) {
    $label = Join-Path 'skills' $dir.Name
    Add-Tree -SourceDir $dir.FullName -DestDir (Join-Path $DestinationRoot $label) -Label $label
}

# Agents: optional.
if (Test-Path -LiteralPath $agentsSource -PathType Container) {
    Add-Tree -SourceDir $agentsSource -DestDir (Join-Path $DestinationRoot 'agents') -Label 'agents' -Filter '*.md'
} else {
    Write-Host 'No claude\agents directory found; installing skills only.'
}

Write-Host "Installing $($skillDirs.Count) skill(s) from $sourceRoot"
Write-Host "Destination: $DestinationRoot"

# Hashes with .NET rather than Get-FileHash, which in Windows PowerShell 5.1
# prints spurious "What if" lines under -WhatIf.
function Get-Sha256 {
    param([string]$Path)
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return [System.BitConverter]::ToString($sha.ComputeHash($stream)) } finally { $sha.Dispose() }
    } finally {
        $stream.Dispose()
    }
}

# Returns Installed, Updated, Unchanged, Conflict, or Skipped (declined at a
# -Confirm prompt). Under -WhatIf, returns what would happen without copying.
function Install-File {
    param($Item)
    if (Test-Path -LiteralPath $Item.Dest -PathType Container) {
        throw 'a directory exists at that path'
    }
    $exists = Test-Path -LiteralPath $Item.Dest -PathType Leaf
    if ($exists) {
        $same = (Get-Item -LiteralPath $Item.Source).Length -eq (Get-Item -LiteralPath $Item.Dest).Length -and
            (Get-Sha256 $Item.Source) -eq (Get-Sha256 $Item.Dest)
        if ($same) { return 'Unchanged' }
        if (-not $Force) { return 'Conflict' }
        $status = 'Updated'; $action = 'Update (replace differing file)'
    } else {
        $status = 'Installed'; $action = 'Install (new file)'
    }

    if (-not $PSCmdlet.ShouldProcess($Item.Dest, $action)) {
        if ($WhatIfPreference) { return $status }
        return 'Skipped'
    }
    $parent = Split-Path -Parent $Item.Dest
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Item.Source -Destination $Item.Dest -Force:$exists
    return $status
}

$installed = 0; $updated = 0; $unchanged = 0; $conflicts = 0; $failed = 0
$verb = if ($WhatIfPreference) { 'would be ' } else { '' }

foreach ($item in $items) {
    try {
        $status = Install-File $item
    } catch {
        $failed++
        Write-Warning "Failed to install $($item.Display): $($_.Exception.Message)"
        continue
    }
    switch ($status) {
        'Installed' { $installed++ }
        'Updated'   { $updated++ }
        'Unchanged' { $unchanged++; Write-Verbose "Unchanged: $($item.Display)" }
        'Conflict'  { $conflicts++; Write-Warning "Conflict (destination differs, left untouched): $($item.Display)" }
    }
    if (($status -eq 'Installed' -or $status -eq 'Updated') -and -not $WhatIfPreference) {
        Write-Host ("{0,-10} {1}" -f "${status}:", $item.Display)
    }
}

Write-Host ''
Write-Host "Summary: $installed ${verb}installed, $updated ${verb}updated, $unchanged unchanged, $conflicts conflicting, $failed failed."
if ($conflicts -gt 0 -and -not $Force) {
    Write-Host 'Conflicting files were left untouched. Move any personal edits into this repository, then rerun with -Force.'
}

if ($failed -gt 0) { exit 1 }
exit 0
