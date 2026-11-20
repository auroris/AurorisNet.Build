#Requires -Version 7.0
<#
.SYNOPSIS
Starts the package's Release workflow once for every update that was merged since the last release, or does nothing
when there is none.

.DESCRIPTION
An update that changes what the package ships is recorded in its commit message, with a line for each of:

    Release-Bump: patch
    Release-Note: Updates OpenIddict.Server.

Merge-DependabotUpdate.ps1 writes these lines for a Dependabot update of a shipped package, and
Submit-UmbracoReleaseResults.ps1 writes them for a new Umbraco release that passed the tests. A person can write them in
a commit of their own to have the next weekly release publish it.

The script reads the commits of the checked-out branch that no release tag reaches, where a release tag starts with v
and a digit. When one or more of them has such a line, it starts the Release workflow once:

- bump is minor when any commit asks for minor, and patch otherwise. A package whose version follows the Umbraco
  release gets no bump.
- notes holds each Release-Note once, oldest first, as a list when there are several.
- test keeps its default, so the release tests the updates together before it publishes.

A package with no release tag yet has no version to raise, so the first release is left to a person. The release tag
marks the commit that was published, so a release that failed before it reserved its tag is started again by the next
run.

GH_TOKEN must be set, and the checkout needs the full history and the tags.

.PARAMETER Versioning
semver for a package numbered MAJOR.MINOR.PATCH, or umbraco for a package whose version follows the Umbraco release.

.PARAMETER ReleaseWorkflow
The workflow file that publishes the package.

.PARAMETER Branch
The branch to release from, which must be the one that is checked out.

.PARAMETER Repository
The repository's root folder. Defaults to the current folder.

.PARAMETER DryRun
Prints the GitHub CLI command instead of running it.
#>
param(
    [ValidateSet('semver', 'umbraco')][string] $Versioning = 'semver',
    [string] $ReleaseWorkflow = 'release.yml',
    [string] $Branch = 'main',
    [string] $Repository = (Get-Location).Path,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$releaseTags = 'v[0-9]*'

Push-Location $Repository
try {
    $tags = @(git tag --list $releaseTags)
    if ($LASTEXITCODE -ne 0) { throw 'Could not list the release tags.' }
    if (-not $tags) {
        Write-Host "::notice::The package has no release yet, so run $ReleaseWorkflow with its first version."
        return
    }

    # Each commit that no release tag reaches, oldest first, as its hash and its whole message.
    $log = @(git log --reverse '--format=%H%x1f%B%x1e' HEAD --not "--tags=$releaseTags")
    if ($LASTEXITCODE -ne 0) { throw 'Could not read the commits since the last release.' }

    $pending = @()
    $bump = 'patch'
    $notes = @()
    foreach ($entry in ($log -join "`n").Split([char] 0x1e) | Where-Object { $_.Trim() }) {
        $hash, $message = $entry.Trim().Split([char] 0x1f, 2)
        $asked = @([regex]::Matches($message, '(?im)^[ \t]*Release-Bump:[ \t]*(\S+)[ \t]*\r?$') | ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() })
        $noted = @([regex]::Matches($message, '(?im)^[ \t]*Release-Note:[ \t]*(\S.*?)[ \t]*\r?$') | ForEach-Object { $_.Groups[1].Value })
        if (-not $asked -and -not $noted) { continue }

        $subject = $message.Split("`n")[0].Trim()
        $pending += "$($hash.Substring(0, 7)) $subject"
        foreach ($value in $asked | Where-Object { $_ -notin 'patch', 'minor' }) {
            Write-Host "::warning::$($hash.Substring(0, 7)) has Release-Bump: $value. Use patch or minor. It counts as patch."
        }
        if ('minor' -in $asked) { $bump = 'minor' }
        $notes += $noted | Where-Object { $_ -notin $notes }
    }

    if (-not $pending) {
        Write-Host "No update that ships has been merged since the last release, so there is nothing to publish."
        return
    }

    Write-Host "Updates since the last release:"
    $pending | ForEach-Object { Write-Host "  $_" }

    $inputs = @()
    if ($notes) { $inputs += @('-f', "notes=$($notes.Count -eq 1 ? $notes[0] : (($notes | ForEach-Object { "- $_" }) -join "`n"))") }
    if ($Versioning -eq 'semver') { $inputs += @('-f', "bump=$bump") }
    $arguments = @('workflow', 'run', $ReleaseWorkflow, '--ref', $Branch) + $inputs
    if ($DryRun) { Write-Host "Would run: gh $($arguments -join ' ')"; return }
    gh @arguments
    if ($LASTEXITCODE -ne 0) { throw "Could not start $ReleaseWorkflow." }
    Write-Host "Started $ReleaseWorkflow on $Branch for $($pending.Count) update$($pending.Count -eq 1 ? '' : 's')."
}
finally {
    Pop-Location
}
