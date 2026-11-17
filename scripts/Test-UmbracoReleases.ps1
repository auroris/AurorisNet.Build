#Requires -Version 7.0
<#
.SYNOPSIS
Runs a package's test command once for each Umbraco release and writes a summary of the results.

.DESCRIPTION
Runs -Command in a new PowerShell process for each release, one at a time, with the release in the environment
variable UMBRACO_RELEASE. A release passes when the command exits with 0. The output of each run goes to
<ArtifactsPath>/<release>/test.log. Prints one line per release, writes a JSON summary and exits with 1 when any
release fails.

A package with a matrix of its own, such as browser cases, keeps its own script and writes the same summary format.

.PARAMETER Releases
The Umbraco releases to test, such as 18.3.2. A value can list several, separated by commas.

.PARAMETER Command
The PowerShell command that tests one release, such as
dotnet test --project tests/Package.Tests -c Release "-p:UmbracoVersion=$env:UMBRACO_RELEASE".

.PARAMETER ArtifactsPath
Where the logs go. Defaults to artifacts/umbraco-releases in the current folder.

.PARAMETER SummaryPath
The JSON summary to write: one object per release with Release, Result, Tests and Failures. Defaults to
artifacts/tests.json in the current folder.
#>
param(
    [Parameter(Mandatory)][string[]] $Releases,
    [Parameter(Mandatory)][string] $Command,
    [string] $ArtifactsPath = 'artifacts/umbraco-releases',
    [string] $SummaryPath = 'artifacts/tests.json'
)

$ErrorActionPreference = 'Stop'
$split = [StringSplitOptions]::RemoveEmptyEntries -bor [StringSplitOptions]::TrimEntries
$Releases = @($Releases | ForEach-Object { $_.Split(',', $split) })
foreach ($release in $Releases) {
    if ($release -notmatch '^\d+\.\d+\.\d+$') { throw "$release is not a release number such as 18.3.2." }
}

$records = foreach ($release in $Releases) {
    $folder = Join-Path $ArtifactsPath $release
    New-Item -ItemType Directory -Force $folder | Out-Null
    $log = Join-Path $folder 'test.log'
    Write-Host "Testing Umbraco $release"
    $env:UMBRACO_RELEASE = $release
    # The command sets the exit code of the process, whether it ends with a native command or throws.
    pwsh -NoProfile -NonInteractive -Command "`$ErrorActionPreference = 'Stop'; $Command; exit `$LASTEXITCODE" *> $log
    $exitCode = $LASTEXITCODE
    # The test platform colors its output on a CI runner even when it goes to a file, so strip the codes before reading.
    $lines = @(Get-Content -LiteralPath $log) -replace '\e\[[0-9;?]*[A-Za-z]', ''
    $counts = @($lines | Select-String -Pattern '^\s+(total|failed|succeeded|skipped): (\d+)' | ForEach-Object { $_.Line.Trim() })
    $failures = @($lines | Select-String -Pattern '^failed (.+?)( \(\d.*\))?$' | ForEach-Object { $_.Matches[0].Groups[1].Value })
    if ($exitCode -ne 0 -and -not $failures) { $failures = @("The test command exited with $exitCode. See test.log.") }
    [pscustomobject]@{
        Release = $release
        Result = $exitCode -eq 0 ? 'passed' : 'failed'
        Tests = $counts -join ', '
        Failures = $failures
    }
}
Remove-Item Env:UMBRACO_RELEASE

$records | Format-Table Release, Result, Tests -AutoSize | Out-String -Width 200 | Write-Host
foreach ($record in $records | Where-Object Result -ne 'passed') {
    Write-Host "Umbraco $($record.Release) failed: $(Join-Path $ArtifactsPath $record.Release 'test.log')"
    $record.Failures | ForEach-Object { Write-Host "  $_" }
}
New-Item -ItemType Directory -Force (Split-Path -Parent ([IO.Path]::GetFullPath($SummaryPath))) | Out-Null
ConvertTo-Json -InputObject @($records) -Depth 4 | Set-Content -LiteralPath $SummaryPath -Encoding utf8
exit (@($records | Where-Object Result -ne 'passed').Count -eq 0 ? 0 : 1)
