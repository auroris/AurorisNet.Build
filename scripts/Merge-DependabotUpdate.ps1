#Requires -Version 7.0
<#
.SYNOPSIS
Merges a Dependabot pull request that passed its checks, and starts the package's Release workflow when the update
changes what the package ships.

.DESCRIPTION
A major version update of a NuGet or npm package gets a comment and stays open for a person to review. Major updates of
workflow actions merge, because the run that calls this script already used them.

Every other update is squash-merged. It ships, and starts the Release workflow, when:

- it is a NuGet update of a package that a project under -ShippedProjects references, or
- it is an npm update, -NpmShips is set, and the package is outside -NpmDevelopmentOnly.

Updates of test packages, samples and workflow actions change nothing a consumer installs, so they merge without a
release. The Release workflow starts with test set to false, because the pull request's checks have just run. With
-Versioning semver it also gets bump: minor for a minor NuGet update, which can add API surface, and patch otherwise.

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

.PARAMETER Versioning
semver for a package numbered MAJOR.MINOR.PATCH, or umbraco for a package whose version follows the Umbraco release.

.PARAMETER ReleaseWorkflow
The workflow file that publishes the package.

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
    [ValidateSet('semver', 'umbraco')][string] $Versioning = 'semver',
    [string] $ReleaseWorkflow = 'release.yml',
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

Invoke-GitHub @('pr', 'merge', $PullRequest, '--squash', '--delete-branch')
if (-not $shipped) {
    Write-Host "Merged the $Ecosystem update of $($updated -join ', '). The package ships none of it, so there is no release."
    return
}

$inputs = @('-f', 'test=false', '-f', "notes=Updates $($shipped -join ', ').")
if ($Versioning -eq 'semver') {
    $inputs += @('-f', "bump=$($Ecosystem -eq 'nuget' -and $UpdateType -eq 'version-update:semver-minor' ? 'minor' : 'patch')")
}
Invoke-GitHub (@('workflow', 'run', $ReleaseWorkflow, '--ref', 'main') + $inputs)
Write-Host "Merged the update of $($shipped -join ', ') and started $ReleaseWorkflow on main."
