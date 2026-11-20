#Requires -Version 7.0
<#
.SYNOPSIS
Merges a Dependabot pull request that passed its checks, and records the update for the weekly release when it
changes what the package ships.

.DESCRIPTION
A major version update of a NuGet or npm package gets a comment and stays open for a person to review. Major updates of
workflow actions merge, because the run that calls this script already used them.

Every other update is squash-merged. It ships when:

- it is a NuGet update of a package that a project under -ShippedProjects references, or
- it is an npm update, -NpmShips is set, and the package is outside -NpmDevelopmentOnly.

The merge commit of an update that ships ends with two lines, which Start-PendingRelease.ps1 reads when the weekly
release runs:

    Release-Bump: patch
    Release-Note: Updates OpenIddict.Server.

Release-Bump is minor for a minor NuGet update, which can add API surface, and patch otherwise. One release then
publishes every update merged since the last one. Updates of test packages, samples and workflow actions change nothing
a consumer installs, so their merge commits carry no such lines.

GH_TOKEN and GH_REPO must be set.

.PARAMETER PullRequest
The number of the pull request.

.PARAMETER UpdateType
The update type from dependabot/fetch-metadata, such as version-update:semver-minor.

.PARAMETER Ecosystem
The package ecosystem from dependabot/fetch-metadata: nuget, npm_and_yarn or github_actions.

.PARAMETER Dependencies
The names of the updated packages, separated by commas.

.PARAMETER ShippedProjects
Project files, or folders searched for project files, whose package references reach consumers.

.PARAMETER NpmShips
Set when the package embeds files built from npm packages.

.PARAMETER NpmDevelopmentOnly
The npm packages that only build, test or demonstrate, and are never embedded.

.PARAMETER DryRun
Prints the GitHub CLI commands instead of running them.
#>
param(
    [Parameter(Mandatory)][string] $PullRequest,
    [string] $UpdateType = '',
    [string] $Ecosystem = '',
    [string] $Dependencies = '',
    [string[]] $ShippedProjects = @('src'),
    [switch] $NpmShips,
    [string[]] $NpmDevelopmentOnly = @(),
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$split = [StringSplitOptions]::RemoveEmptyEntries -bor [StringSplitOptions]::TrimEntries
$updated = @($Dependencies.Split(',', $split))
$ShippedProjects = @($ShippedProjects | ForEach-Object { $_.Split([string[]] @(',', "`n"), $split) })
$NpmDevelopmentOnly = @($NpmDevelopmentOnly | ForEach-Object { $_.Split([string[]] @(',', "`n"), $split) })

<#
.SYNOPSIS
Runs the GitHub CLI and throws when it fails, or on a dry run prints the command instead.
#>
function Invoke-GitHub([string[]] $arguments) {
    if ($DryRun) { Write-Host "Would run: gh $($arguments -join ' ')"; return }
    gh @arguments
    if ($LASTEXITCODE -ne 0) { throw "gh $($arguments[0]) $($arguments[1]) failed." }
}

if ($UpdateType -eq 'version-update:semver-major' -and $Ecosystem -ne 'github_actions') {
    Invoke-GitHub @('pr', 'comment', $PullRequest, '--body',
        "The checks passed, but a major version update waits for a person to review it. After merging, run the Release workflow if the change should ship.")
    Write-Host 'Left a major version update for review.'
    return
}

$shipped = @()
if ($Ecosystem -eq 'nuget') {
    $projects = @($ShippedProjects | ForEach-Object {
        if (Test-Path -LiteralPath $_ -PathType Leaf) { Get-Item -LiteralPath $_ }
        elseif (Test-Path -LiteralPath $_) { Get-ChildItem -LiteralPath $_ -Recurse -Filter *.csproj }
    })
    if (-not $projects) { throw "No project file is under $($ShippedProjects -join ', '). Is the checkout complete?" }
    $references = @($projects | ForEach-Object {
        ([xml] (Get-Content -LiteralPath $_.FullName -Raw)).SelectNodes('//PackageReference/@Include') | ForEach-Object Value
    })
    $shipped = @($updated | Where-Object { $_ -in $references })
}
elseif ($Ecosystem -in 'npm', 'npm_and_yarn' -and $NpmShips) {
    $shipped = @($updated | Where-Object { $_ -notin $NpmDevelopmentOnly })
}

if (-not $shipped) {
    Invoke-GitHub @('pr', 'merge', $PullRequest, '--squash', '--delete-branch')
    Write-Host "Merged the $Ecosystem update of $($updated -join ', '). The package ships none of it, so there is nothing to release."
    return
}

# The body of the squash commit. Start-PendingRelease.ps1 finds these lines in the commits since the last release tag.
$bump = $Ecosystem -eq 'nuget' -and $UpdateType -eq 'version-update:semver-minor' ? 'minor' : 'patch'
$record = "Release-Bump: $bump`nRelease-Note: Updates $($shipped -join ', ')."
Invoke-GitHub @('pr', 'merge', $PullRequest, '--squash', '--delete-branch', '--body', $record)
Write-Host "Merged the update of $($shipped -join ', '). The weekly release publishes it."
