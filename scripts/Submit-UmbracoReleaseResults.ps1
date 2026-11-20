#Requires -Version 7.0
<#
.SYNOPSIS
Acts on the results of testing new Umbraco releases: commits the releases that passed and starts the package's Release
workflow, and opens an issue for each release that failed.

.DESCRIPTION
Reads the JSON summaries the tests wrote, each a list of objects with Release, Result, Tests and Failures. A release
passed when it passed in every summary; a missing summary, from a step that never ran, fails every release.

For the releases that passed, the script restores Directory.Build.props and the Markdown files from the last commit,
adds the releases with Add-UmbracoRelease.ps1, commits the change to the branch and pushes it. It then starts the
Release workflow with test set to false, because the tests have just run on these releases. A package numbered
MAJOR.MINOR.PATCH gets -Bump auto, which raises the minor number when a release starts a new Umbraco minor version, such
as 18.4.0, and the patch number otherwise. Before the package has a first release tag there is no number to raise, so
the script commits the releases and leaves publishing the first version to a person.

For each release that failed, it opens an issue, or comments on the open issue with the same title. With -DryRun it
prints what it would do and changes nothing. Exits with 1 when any release failed.

.PARAMETER Releases
The releases that were tested. A value can list several, separated by commas.

.PARAMETER Summaries
The JSON summaries to read, such as the tests' and the browser check's.

.PARAMETER RunUrl
The address of the workflow run, whose artifacts hold the logs.

.PARAMETER Bump
Empty for a package whose version follows the Umbraco release, such as 18.3.2.1. Use auto for a package numbered
MAJOR.MINOR.PATCH.

.PARAMETER ReleaseWorkflow
The workflow file that publishes the package. Empty commits the releases without starting it.

.PARAMETER Branch
The branch to commit to and release from.

.PARAMETER Repository
The repository's root folder. Defaults to the current folder.

.PARAMETER DryRun
Prints the commit, the release and the issues instead of creating them.
#>
param(
    [Parameter(Mandatory)][string[]] $Releases,
    [Parameter(Mandatory)][string[]] $Summaries,
    [string] $RunUrl = '',
    [ValidateSet('', 'auto')][string] $Bump = '',
    [string] $ReleaseWorkflow = 'release.yml',
    [string] $Branch = 'main',
    [string] $Repository = (Get-Location).Path,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$split = [StringSplitOptions]::RemoveEmptyEntries -bor [StringSplitOptions]::TrimEntries
$Releases = @($Releases | ForEach-Object { $_.Split(',', $split) })
$Summaries = @($Summaries | ForEach-Object { $_.Split(',', $split) })
$label = 'umbraco-release'

$records = foreach ($path in $Summaries) {
    $name = [IO.Path]::GetFileNameWithoutExtension($path)
    if (Test-Path -LiteralPath $path) {
        foreach ($record in Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) {
            [pscustomobject]@{ Summary = $name; Release = $record.Release; Result = $record.Result; Tests = $record.Tests; Failures = @($record.Failures) }
        }
    }
    else {
        foreach ($release in $Releases) {
            [pscustomobject]@{ Summary = $name; Release = $release; Result = 'not run'; Tests = ''; Failures = @("The $name tests did not run.") }
        }
    }
}
$passed = @($Releases | Where-Object {
    $release = $_
    @($records | Where-Object { $_.Release -eq $release -and $_.Result -eq 'passed' }).Count -eq $Summaries.Count
})
$failed = @($Releases | Where-Object { $_ -notin $passed })
$link = $RunUrl ? "[the test run]($RunUrl)" : 'the test run'

<#
.SYNOPSIS
Returns a Markdown table of the results for <releases>, one row per release and summary.
#>
function Format-Results([string[]] $releases) {
    "| Release | Tests | Result |"
    "|---|---|---|"
    foreach ($record in $records | Where-Object Release -in $releases | Sort-Object { [version] $_.Release }, Summary) {
        "| $($record.Release) | $($record.Summary): $($record.Tests) | $($record.Result) |"
    }
}

<#
.SYNOPSIS
Runs a command and throws when it fails, or on a dry run prints it instead.
#>
function Invoke-Checked([string] $command, [string[]] $arguments) {
    if ($DryRun) { Write-Host "Would run: $command $($arguments -join ' ')"; return }
    & $command @arguments
    if ($LASTEXITCODE -ne 0) { throw "$command $($arguments[0]) failed." }
}

<#
.SYNOPSIS
Opens an issue titled <title>, or comments on the open issue with that title, with <body> as its text.
#>
function Submit-Issue([string] $title, [string] $body) {
    if ($DryRun) { Write-Host "Would open the issue ""$title"":`n$body`n"; return }
    $file = New-TemporaryFile
    Set-Content -LiteralPath $file -Value $body -Encoding utf8
    $existing = gh issue list --state open --search "$title in:title" --json number,title | ConvertFrom-Json |
        Where-Object title -eq $title | Select-Object -First 1
    if ($existing) { Invoke-Checked gh @('issue', 'comment', [string] $existing.number, '--body-file', $file) }
    else { Invoke-Checked gh @('issue', 'create', '--title', $title, '--body-file', $file, '--label', $label) }
    Remove-Item -LiteralPath $file
}

Push-Location $Repository
try {
    if (-not $DryRun) {
        gh label create $label --color 0e8a16 --description 'A new Umbraco release and its test results' --force | Out-Null
    }

    foreach ($release in $failed) {
        $details = foreach ($record in $records | Where-Object { $_.Release -eq $release -and $_.Result -ne 'passed' }) {
            $record.Failures | ForEach-Object { "- $($record.Summary): $_" }
        }
        Submit-Issue "Umbraco $release fails the tests" (@(
                "The tests failed on Umbraco $release, so it stays out of ``UmbracoReleases`` and no package was published for it."
                ''
                Format-Results @($release)
                ''
                $details
                ''
                "The artifacts of $link hold the logs. Close this issue once the cause is fixed; the next weekly run of the"
                'New Umbraco releases workflow tests the release again, or run it now with this release.'
            ) -join "`n")
    }

    if ($passed -and $DryRun) {
        Write-Host "Would add Umbraco $($passed -join ', ') unless listed already, commit to $Branch and start $ReleaseWorkflow."
    }
    elseif ($passed) {
        # The tests ran with every tested release listed. Start again from the commit and add only those that passed.
        Invoke-Checked git @('checkout', '--', '.')
        $added = @(& (Join-Path $PSScriptRoot 'Add-UmbracoRelease.ps1') -Releases $passed -Repository $Repository)
        if (-not $added) {
            # A manual run can retest releases that are listed already, which leaves nothing to add or publish.
            Write-Host "Umbraco $($passed -join ', ') is listed already, so there is nothing to add."
        }
        else {
            $names = $added -join ', '
            Invoke-Checked git @('config', 'user.name', 'github-actions[bot]')
            Invoke-Checked git @('config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
            Invoke-Checked git @('commit', '--all', '-m', "Add Umbraco $names", '-m', "The tests passed on $names. $RunUrl".Trim())
            # Another commit can reach the branch while the tests run. Replay this one on top of it once.
            git push origin "HEAD:$Branch"
            if ($LASTEXITCODE -ne 0) {
                Invoke-Checked git @('pull', '--rebase', 'origin', $Branch)
                Invoke-Checked git @('push', 'origin', "HEAD:$Branch")
            }

            $notes = "Adds Umbraco $names, which passed the tests in $link."
            $inputs = @('-f', 'test=false', '-f', "notes=$notes")
            $start = [bool] $ReleaseWorkflow
            if ($start -and $Bump -eq 'auto') {
                $tags = @(git ls-remote --tags --refs origin 'v*')
                if ($LASTEXITCODE -ne 0) { throw 'Could not list the release tags.' }
                if (-not $tags) {
                    Write-Host "::notice::Umbraco $names is committed. The package has no release yet, so run $ReleaseWorkflow with its first version."
                    $start = $false
                }
                # A release such as 18.4.0 starts a new Umbraco minor version, which can add API surface.
                $inputs += @('-f', "bump=$(@($added | Where-Object { ([version] $_).Build -eq 0 }) ? 'minor' : 'patch')")
            }
            if ($start) {
                Invoke-Checked gh (@('workflow', 'run', $ReleaseWorkflow, '--ref', $Branch) + $inputs)
                Write-Host "Started $ReleaseWorkflow on $Branch for Umbraco $names."
            }
        }
    }
}
finally {
    Pop-Location
}

Write-Host "Passed: $($passed -join ', ')"
Write-Host "Failed: $($failed -join ', ')"
exit ($failed ? 1 : 0)
