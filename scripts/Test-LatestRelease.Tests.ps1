BeforeAll {
    $script = Join-Path $PSScriptRoot 'Test-LatestRelease.ps1'
}

Describe 'Marking a GitHub release as the latest' {
    It 'marks the first release' {
        & $script -Version '18.3.1.1' -Published @() | Should -BeTrue
        & $script -Version '1.0.0' -Published @() | Should -BeTrue
    }

    It 'marks a release that is newer than every published release' {
        & $script -Version '18.3.2.1' -Published @('v18.3.1.2', 'v17.8.1.1') | Should -BeTrue
        & $script -Version '1.2.0' -Published @('v1.1.9', 'v1.0.0') | Should -BeTrue
    }

    It 'leaves the mark on a newer release when an older release is published after it' {
        & $script -Version '18.3.1.2' -Published @('v18.3.1.3', 'v17.8.1.2') | Should -BeFalse
        & $script -Version '1.1.2' -Published @('v1.2.0') | Should -BeFalse
    }

    It 'leaves the mark on a newer major version''s release' {
        & $script -Version '18.3.1.4' -Published @('v19.0.0.1', 'v18.3.1.3') | Should -BeFalse
    }

    It 'compares the numbers in a version rather than its text' {
        & $script -Version '18.3.1.10' -Published @('v18.3.1.9') | Should -BeTrue
        & $script -Version '18.3.1.9' -Published @('v18.3.1.10') | Should -BeFalse
        & $script -Version '1.10.0' -Published @('v1.9.0') | Should -BeTrue
    }

    It 'marks a release again when it is the newest published one' {
        & $script -Version '18.3.1.2' -Published @('v18.3.1.2', 'v17.8.1.1') | Should -BeTrue
    }

    It 'ignores prerelease tags and tags that are not release tags' {
        & $script -Version '18.3.1.2' -Published @('nightly', 'v19.0.0.1-rc1', '19.0.0.1', 'v18.3.1.011', 'v2.0.0-rc.1') | Should -BeTrue
    }

    It 'refuses a value that is not a package version: <Value>' -TestCases @(
        @{ Value = '18.3' }, @{ Value = 'v18.3.1.2' }, @{ Value = '18.3.1.2-rc1' }, @{ Value = '1.02.3' }
    ) {
        param($Value)
        { & $script -Version $Value -Published @() } | Should -Throw '*not a package version*'
    }
}
