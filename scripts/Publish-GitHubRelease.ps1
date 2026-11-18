#Requires -Version 7.0
<#
.SYNOPSIS
Publishes the GitHub release of each package version, with its packages attached.

.DESCRIPTION
Most releases have one version. A package whose version follows the Umbraco release publishes one version for each
supported Umbraco major version, such as 18.3.2.1 and 17.8.2.1, and lists the newest first.

Each release gets the files in -Packages whose names end in its version: <id>.<version>.nupkg and .snupkg. The first
release also gets the files in -Assets, the notes in -Notes and GitHub's generated list of changes. A repository that
ships an application and no package releases its assets alone. A version with a prerelease suffix is marked as a
prerelease. Otherwise the first release becomes the latest release unless a newer one is published already, as when a
run retries an older commit's release. Each other release points to the first, since it publishes the same package
under another version number.

A release that exists already belongs to an earlier attempt of the same run, so its files are uploaded again.
The tags must exist, and GH_TOKEN and GITHUB_REPOSITORY must be set.

.PARAMETER Versions
The versions to release, newest first. A value can list several, separated by commas.

.PARAMETER Packages
The folder that holds the packages.

.PARAMETER Assets
Other files to attach to the first release, such as archives and a checksum file. Wildcards are allowed.

.PARAMETER Notes
Notes in Markdown for the first release, shown above the generated list of changes.

.PARAMETER DryRun
Prints each GitHub CLI command instead of running it.
#>
param(
    [Parameter(Mandatory)][string[]] $Versions,
    [Parameter(Mandatory)][string] $Packages,
    [string[]] $Assets = @(),
    [string] $Notes = '',
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
# A release job that only downloads artifacts has no checkout, so the GitHub CLI cannot read the repository from git.
if (-not $env:GH_REPO -and $env:GITHUB_REPOSITORY) { $env:GH_REPO = $env:GITHUB_REPOSITORY }
$split =[StringSplitOptions]::RemoveEmptyEntries -bor [StringSplitOptions]::TrimEntries
$Versions = @($Versions | ForEach-Object { $_.Split(',', $split) })
$extra = @($Assets | ForEach-Object { $_.Split([string[]] @("`n"), $split) } | ForEach-Object {
    $found = @(Get-Item -Path $_ -ErrorAction SilentlyContinue | ForEach-Object FullName)
    if (-not $found) { throw "No file matches the asset $_." }
    $found
})

<#
.SYNOPSIS
Runs the GitHub CLI and throws when it fails, or on a dry run prints the command instead.
#>
function Invoke-GitHub([string[]] $arguments) {
    if ($DryRun) { Write-Host "Would run: gh $($arguments -join ' ')"; return }
    gh @arguments
    if ($LASTEXITCODE -ne 0) { throw "gh $($arguments[0]) $($arguments[1]) failed for $($arguments[2])." }
}

for ($i = 0; $i -lt $Versions.Count; $i++) {
    $version = $Versions[$i]
    $tag = "v$version"
    $files = @()
    if (Test-Path -LiteralPath $Packages) {
        $files = @(Get-ChildItem -LiteralPath $Packages -File | Where-Object { $_.Name -like "*.$version.nupkg" -or $_.Name -like "*.$version.snupkg" } |
            ForEach-Object FullName)
    }
    if ($i -eq 0) { $files += $extra }
    # An application that ships no NuGet package releases its assets alone.
    if (-not $files) { throw "No package for $version is in $Packages, and the release has no other asset." }

    $exists = $false
    if (-not $DryRun) {
        gh release view $tag --json id 2>$null | Out-Null
        $exists = $LASTEXITCODE -eq 0
    }
    if ($exists) {
        Invoke-GitHub (@('release', 'upload', $tag) + $files + '--clobber')
    }
    elseif ($i -eq 0) {
        $create = @('release', 'create', $tag) + $files + @('--verify-tag', '--title', $version, '--generate-notes')
        if ($version.Contains('-')) { $create += '--prerelease' }
        else {
            $latest = $DryRun ? $true : (& (Join-Path $PSScriptRoot 'Test-LatestRelease.ps1') -Version $version)
            $create += $latest ? '--latest' : '--latest=false'
        }
        # gh places these notes above the generated ones.
        if ($Notes) { $create += @('--notes', $Notes) }
        Invoke-GitHub $create
    }
    else {
        $major = $version.Split('.')[0]
        $pointer = "The same package as [$($Versions[0])](https://github.com/$env:GITHUB_REPOSITORY/releases/tag/v$($Versions[0])), " +
            "numbered for sites on Umbraco $major, which can float on ``$major.*``."
        Invoke-GitHub (@('release', 'create', $tag) + $files + @('--verify-tag', '--title', $version, '--notes', $pointer, '--latest=false'))
    }
}
