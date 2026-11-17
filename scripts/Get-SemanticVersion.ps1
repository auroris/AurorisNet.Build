#Requires -Version 7.0
<#
.SYNOPSIS
Chooses the package version and release tag for a release numbered MAJOR.MINOR.PATCH.

.DESCRIPTION
With -Version, checks the version and uses it. Without it, raises the newest release tag:

- When the newest tag is a stable release such as v1.2.3, -Bump patch gives 1.2.4 and -Bump minor gives 1.3.0.
- When the newest tag is a prerelease that ends in a number, such as v0.1.0-alpha.1, either bump gives the next
  prerelease, 0.1.0-alpha.2. A package leaves its prerelease series only through -Version.

A tag that already marks the commit being released belongs to an earlier attempt at the same release, which the run
finishes. A tag on another commit means the version is taken.

.PARAMETER Version
The version to publish, such as 1.2.3 or 1.2.3-rc.1, with or without a v prefix. Leave empty to raise the newest tag.

.PARAMETER Bump
Which part of the newest stable tag to raise when -Version is empty: patch or minor.

.PARAMETER Commit
The full hash of the commit being released.

.PARAMETER Tags
The release tags to compare with, as lines of "<commit> refs/tags/<tag>", for tests. Defaults to the tags of the
repository in -RepositoryUrl, read with git ls-remote, which works in a shallow checkout.

.PARAMETER RepositoryUrl
The repository whose tags to read. Defaults to the origin remote of the current folder.

.OUTPUTS
An object with Version, such as 1.2.4, Tag, such as v1.2.4, Tagged, true when the tag already marks the commit, and
Prerelease, true when the version has a prerelease suffix.
#>
param(
    [string] $Version = '',
    [ValidateSet('patch', 'minor')][string] $Bump = 'patch',
    [Parameter(Mandatory)][string] $Commit,
    [string[]] $Tags,
    [string] $RepositoryUrl = 'origin'
)

$ErrorActionPreference = 'Stop'
$number = '(0|[1-9][0-9]*)'
$identifier = '(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)'
$semantic = "\A$number\.$number\.$number(-$identifier(\.$identifier)*)?\z"

if (-not $PSBoundParameters.ContainsKey('Tags')) {
    $Tags = @(git ls-remote --tags --refs $RepositoryUrl 'v*')
    if ($LASTEXITCODE -ne 0) { throw 'Could not list the release tags.' }
}
$commitOf = @{}
foreach ($line in $Tags | Where-Object { $_ }) {
    $sha, $ref = $line -split '\s+'
    $commitOf[$ref.Substring('refs/tags/'.Length)] = $sha
}

<#
.SYNOPSIS
Returns a sort key for a semantic version, which orders versions by their numbers, a stable release after its own
prereleases, and prereleases by their identifiers, numeric ones as numbers.
#>
function Get-SortKey([string] $version) {
    $core, $suffix = $version.Split('-', 2)
    $key = ($core.Split('.') | ForEach-Object { '{0:D10}' -f [long] $_ }) -join '.'
    if (-not $suffix) { return "$key|1" }
    $key + '|0|' + (($suffix.Split('.') | ForEach-Object { $_ -match '^\d+$' ? ('0{0:D10}' -f [long] $_) : "1$_" }) -join '.')
}

$Version = $Version.Trim()
if (-not $Version) {
    $released = @($commitOf.Keys | Where-Object { $_ -cmatch ('\Av' + $semantic.Substring(2)) } | ForEach-Object { $_.Substring(1) } |
        Sort-Object { Get-SortKey $_ })
    if (-not $released) { throw 'No release tag exists to raise. Enter a version, such as 1.0.0.' }
    $newest = $released[-1]
    if ($newest.Contains('-')) {
        if ($newest -notmatch '\A(.+\.)(\d+)\z') { throw "The newest tag, v$newest, is a prerelease that does not end in a number. Enter a version." }
        $Version = $Matches[1] + ([long] $Matches[2] + 1)
    }
    else {
        $parts = [version] $newest
        $Version = $Bump -eq 'minor' ? "$($parts.Major).$($parts.Minor + 1).0" : "$($parts.Major).$($parts.Minor).$($parts.Build + 1)"
    }
    Write-Host "Raising v$newest to v$Version."
}
if ($Version.StartsWith('v')) { $Version = $Version.Substring(1) }
if ($Version -cnotmatch $semantic) {
    throw 'Use MAJOR.MINOR.PATCH, optionally followed by a prerelease such as -rc.1. Build metadata is not supported.'
}
foreach ($component in $Version.Split('-', 2)[0].Split('.')) {
    if ($component.Length -gt 5 -or [int] $component -gt 65534) { throw '.NET assembly version components must be between 0 and 65534.' }
}

$tag = "v$Version"
if ($commitOf.ContainsKey($tag) -and $commitOf[$tag] -cne $Commit) {
    throw "Tag $tag already marks commit $($commitOf[$tag]). Choose a new version."
}
[pscustomobject]@{
    Version = $Version
    Tag = $tag
    Tagged = $commitOf.ContainsKey($tag)
    Prerelease = $Version.Contains('-')
}
