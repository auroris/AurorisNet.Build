BeforeAll {
    $script = Join-Path $PSScriptRoot 'Test-UmbracoReleases.ps1'
}

Describe 'Testing a package on Umbraco releases' {
    BeforeEach {
        $folder = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $summary = Join-Path $folder 'tests.json'
    }

    It 'passes each release whose command exits with 0 and records the test counts' {
        $command = 'Write-Output "  total: 3"; Write-Output "  succeeded: 3"; Write-Output "release $env:UMBRACO_RELEASE"'
        pwsh -NoProfile -File $script -Releases '17.8.2,18.3.2' -Command $command -ArtifactsPath $folder -SummaryPath $summary | Out-Null
        $LASTEXITCODE | Should -Be 0
        $records = Get-Content $summary -Raw | ConvertFrom-Json
        $records.Release | Should -Be @('17.8.2', '18.3.2')
        $records.Result | Should -Be @('passed', 'passed')
        $records[0].Tests | Should -Be 'total: 3, succeeded: 3'
        Get-Content (Join-Path $folder '18.3.2/test.log') | Should -Contain 'release 18.3.2'
    }

    It 'fails a release whose command exits with another code, lists its failed tests, and exits with 1' {
        $command = 'if ($env:UMBRACO_RELEASE -eq "18.3.2") { Write-Output "failed Site_starts (2s 10ms)"; cmd /c exit 2 }'
        if (-not $IsWindows) { $command = $command.Replace('cmd /c exit 2', 'sh -c "exit 2"') }
        pwsh -NoProfile -File $script -Releases '17.8.2,18.3.2' -Command $command -ArtifactsPath $folder -SummaryPath $summary | Out-Null
        $LASTEXITCODE | Should -Be 1
        $records = Get-Content $summary -Raw | ConvertFrom-Json
        $records.Result | Should -Be @('passed', 'failed')
        $records[1].Failures | Should -Be @('Site_starts')
    }

    It 'fails a release whose command throws' {
        pwsh -NoProfile -File $script -Releases '18.3.2' -Command 'throw "no build"' -ArtifactsPath $folder -SummaryPath $summary | Out-Null
        $LASTEXITCODE | Should -Be 1
        (Get-Content $summary -Raw | ConvertFrom-Json).Failures | Should -BeLike 'The test command exited with*'
    }

    It 'refuses a value that is not a release number' {
        { & $script -Releases '18.3' -Command 'exit 0' -ArtifactsPath $folder -SummaryPath $summary } | Should -Throw '*not a release number*'
    }
}
