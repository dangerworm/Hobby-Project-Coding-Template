#!/usr/bin/env pwsh
<#
.SYNOPSIS
    VS Code extension bootstrapper for PowerShell

.DESCRIPTION
    - Installs extensions from the allowlist defined in vscode-extensions.yaml
    - Optionally uninstalls extensions not in the allowlist
    - Optionally confirms installation per group or per extension

.PARAMETER Remove
    Remove extensions not in allowlist

.PARAMETER ConfirmGroups
    Prompt before installing each extension group

.PARAMETER ConfirmEach
    Prompt before installing each individual extension

.PARAMETER CodeBin
    VS Code binary to use (default: 'code')
    e.g., 'code-insiders'

.EXAMPLE
    .\vscode-extensions-master.ps1

.EXAMPLE
    .\vscode-extensions-master.ps1 -Remove -ConfirmGroups

.EXAMPLE
    .\vscode-extensions-master.ps1 -ConfirmEach

.EXAMPLE
    $env:CODE_BIN = 'code-insiders'
    .\vscode-extensions-master.ps1 -Remove
#>

[CmdletBinding()]
# Parameters set to false by default
param(
    [switch]$Remove,
    [switch]$ConfirmGroups,
    [switch]$ConfirmEach,
    [string]$CodeBin = $env:CODE_BIN
)

# Use default if not specified
if ([string]::IsNullOrEmpty($CodeBin)) {
    $CodeBin = 'code'
}

# Check if VS Code CLI is available
if (-not (Get-Command $CodeBin -ErrorAction SilentlyContinue)) {
    Write-Error "Error: '$CodeBin' not found on PATH."
    Write-Host "Set `$env:CODE_BIN or use -CodeBin parameter and ensure the VS Code CLI is installed."
    exit 1
}

function Get-CanonicalExtensionId {
    param([string]$ExtensionId)
    return $ExtensionId.ToLower()
}

function Confirm-Action {
    param([string]$Prompt)

    while ($true) {
        $response = Read-Host "$Prompt [y/n]"
        switch ($response.ToLower()) {
            'y' { return $true }
            'n' { return $false }
            default { Write-Host "Please answer y or n." }
        }
    }
}

# Load extensions from YAML file
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$yamlFile = Join-Path $scriptDir "vscode-extensions.yaml"

if (-not (Test-Path $yamlFile)) {
    Write-Error "Error: Extensions configuration file not found at: $yamlFile"
    exit 1
}

Write-Host "Loading extensions from: $yamlFile"

# Simple YAML parser for our specific format
$groups = @()
$allExtensions = @()
$currentGroup = $null

Get-Content $yamlFile | ForEach-Object {
    $line = $_.Trim()

    # Skip empty lines and comments
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        return
    }

    # Parse group name (- name: "...")
    if ($line -match '^-\s*name:\s*["''](.+)["'']$') {
        $currentGroup = @{
            Name = $matches[1]
            Extensions = @()
        }
        $groups += $currentGroup
        return
    }

    # Parse extension (- extension.id)
    if ($line -match '^-\s*(.+)$') {
        $ext = $matches[1].Trim()
        if ($null -ne $currentGroup) {
            $currentGroup.Extensions += $ext
            $allExtensions += $ext
        }
    }
}

# Build allowlist lookup
$allowlist = $allExtensions | Select-Object -Unique | Sort-Object
$allowlistSet = @{}
foreach ($ext in $allowlist) {
    $allowlistSet[(Get-CanonicalExtensionId $ext)] = $true
}

# Read currently installed extensions
Write-Host "`nReading currently installed extensions using: $CodeBin"
$installedRaw = & $CodeBin --list-extensions 2>$null
$installed = $installedRaw | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique

Write-Host ""
Write-Host "Allowlist: $($allowlist.Count) extensions"
Write-Host "Installed: $($installed.Count) extensions"

# ---------------------------------------------------------------------------
# Uninstall anything not on the allowlist
# ---------------------------------------------------------------------------

if ($Remove) {
    $toRemove = @()
    foreach ($ext in $installed) {
        if (-not $allowlistSet.ContainsKey((Get-CanonicalExtensionId $ext))) {
            $toRemove += $ext
        }
    }

    Write-Host ""
    if ($toRemove.Count -gt 0) {
        Write-Host "Uninstalling $($toRemove.Count) extension(s) not in allowlist:"
        foreach ($ext in $toRemove) {
            Write-Host "× $ext"
            & $CodeBin --uninstall-extension $ext 2>&1 | Out-Null
        }
    } else {
        Write-Host "No extensions to uninstall."
    }

    # Re-read installed extensions after uninstall
    $installedRaw = & $CodeBin --list-extensions 2>$null
    $installed = $installedRaw | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique
} else {
    Write-Host ""
    Write-Host "Skipping removal of non-allowlisted extensions (default behavior, use -Remove to enable)."
}

# ---------------------------------------------------------------------------
# Install missing allowlisted extensions
# ---------------------------------------------------------------------------

$installedSet = @{}
foreach ($ext in $installed) {
    $installedSet[(Get-CanonicalExtensionId $ext)] = $true
}

$toInstall = @()
foreach ($ext in $allowlist) {
    if (-not $installedSet.ContainsKey((Get-CanonicalExtensionId $ext))) {
        $toInstall += $ext
    }
}

Write-Host ""
if ($toInstall.Count -gt 0) {
    if ($ConfirmGroups) {
        # Install by groups with confirmation
        Write-Host "Installing missing extensions by group..."
        Write-Host ""

        foreach ($group in $groups) {
            $groupToInstall = @()
            foreach ($ext in $group.Extensions) {
                if (-not $installedSet.ContainsKey((Get-CanonicalExtensionId $ext))) {
                    $groupToInstall += $ext
                }
            }

            if ($groupToInstall.Count -gt 0) {
                Write-Host "$($group.Name): $($groupToInstall.Count) extension(s) to install"
                if (Confirm-Action "Install $($group.Name) extensions?") {
                    foreach ($ext in $groupToInstall) {
                        if ($ConfirmEach) {
                            if (Confirm-Action "  Install $ext?") {
                                Write-Host "  → $ext"
                                & $CodeBin --install-extension $ext 2>&1 | Out-Null
                            } else {
                                Write-Host "  ⊘ Skipped $ext"
                            }
                        } else {
                            Write-Host "  → $ext"
                            & $CodeBin --install-extension $ext 2>&1 | Out-Null
                        }
                    }
                } else {
                    Write-Host "  ⊘ Skipped $($group.Name) group"
                }
                Write-Host ""
            }
        }
    } elseif ($ConfirmEach) {
        # Install all with per-extension confirmation
        Write-Host "Installing $($toInstall.Count) missing extension(s) with confirmation:"
        foreach ($ext in $toInstall) {
            if (Confirm-Action "Install $ext?") {
                Write-Host "→ $ext"
                & $CodeBin --install-extension $ext 2>&1 | Out-Null
            } else {
                Write-Host "⊘ Skipped $ext"
            }
        }
    } else {
        # Install all without confirmation
        Write-Host "Installing $($toInstall.Count) missing extension(s):"
        foreach ($ext in $toInstall) {
            Write-Host "→ $ext"
            & $CodeBin --install-extension $ext 2>&1 | Out-Null
        }
    }
} else {
    Write-Host "All allowlisted extensions already installed."
}

Write-Host ""
Write-Host "Done."
