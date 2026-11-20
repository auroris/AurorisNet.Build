BeforeAll {
    $script = Join-Path $PSScriptRoot 'Start-PendingRelease.ps1'
    <#
    .SYNOPSIS
    Runs git with the given arguments, discards its output, and throws when git fails.
    #>
    function Invoke-Git {
        & git @args 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Git failed: $args" }
    }
    <#
    .SYNOPSIS
    Creates an empty commit in the fixture repository with <subject> and, when given, <body> as its message.
    #>
    function New-Commit([string] $subject, [string] $body = '') {
        if ($body) { Invoke-Git commit --allow-empty -m $subject -m $body } else { Invoke-Git commit --allow-empty -m $subject }
    }
    <#
    .SYNOPSIS
    Runs the script on a dry run in the fixture repository and returns what it printed as one string.
    #>
    function Invoke-Release([hashtable] $arguments = @{}) {
        (& $script -DryRun @arguments 6>&1) -join "`n"
    }
}

Describe 'Starting the weekly release' {
    BeforeEach {
        $fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $fixture -Force | Out-Null
        Push-Location $fixture
        Invoke-Git init -b main
        Invoke-Git config user.name 'Release fixture'
        Invoke-Git config user.email 'fixture@example.test'
        Invoke-Git config commit.gpgsign false
        New-Commit 'First commit'
        Invoke-Git tag v1.2.3
    }

    AfterEach { Pop-Location }

    It 'does nothing when no commit since the last release ships an update' {
        New-Commit 'Bump the github-actions group with 2 updates (#4)'
        $output = Invoke-Release
        $output | Should -BeLike '*nothing to publish*'
        $output | Should -Not -BeLike '*workflow run*'
    }

    It 'starts one patch release for one recorded update' {
        New-Commit 'Bump Serilog from 4.3.0 to 4.3.1 (#5)' "Release-Bump: patch`nRelease-Note: Updates Serilog."
        Invoke-Release | Should -BeLike '*Would run: gh workflow run release.yml --ref main -f notes=Updates Serilog. -f bump=patch'
    }

    It 'combines several updates into one release, with the highest bump and every note' {
        New-Commit 'Bump the openiddict group with 3 updates (#6)' "Release-Bump: minor`nRelease-Note: Updates OpenIddict.Server."
        New-Commit 'Fix a typo'
        New-Commit 'Bump Serilog from 4.3.0 to 4.3.1 (#7)' "Release-Bump: patch`nRelease-Note: Updates Serilog."
        $output = Invoke-Release
        ([regex]::Matches($output, 'workflow run')).Count | Should -Be 1
        $output | Should -BeLike "*-f notes=- Updates OpenIddict.Server.`n- Updates Serilog. -f bump=minor"
        $output | Should -BeLike '*Bump the openiddict group with 3 updates (#6)*'
        $output | Should -Not -BeLike '*Fix a typo*'
    }

    It 'reads the lines anywhere in the message, and repeats no note' {
        New-Commit 'Add Umbraco 18.4.0' "The tests passed on 18.4.0.`n`nRelease-Bump: minor`nRelease-Note: Adds Umbraco 18.4.0."
        New-Commit 'Merge the update again' "release-note:   Adds Umbraco 18.4.0.  `n`nCo-authored-by: Someone <someone@example.test>"
        Invoke-Release | Should -BeLike '*-f notes=Adds Umbraco 18.4.0. -f bump=minor'
    }

    It 'leaves out the updates that a release tag already reaches' {
        New-Commit 'Bump Serilog from 4.3.0 to 4.3.1 (#5)' "Release-Bump: minor`nRelease-Note: Updates Serilog."
        Invoke-Git tag v1.3.0
        Invoke-Release | Should -BeLike '*nothing to publish*'

        New-Commit 'Bump Serilog from 4.3.1 to 4.3.2 (#8)' "Release-Bump: patch`nRelease-Note: Updates Serilog again."
        Invoke-Release | Should -BeLike '*-f notes=Updates Serilog again. -f bump=patch'
    }

    It 'counts only release tags, which start with v and a digit' {
        New-Commit 'Bump Serilog from 4.3.0 to 4.3.1 (#5)' "Release-Bump: patch`nRelease-Note: Updates Serilog."
        Invoke-Git tag nightly
        Invoke-Release | Should -BeLike '*workflow run*'
    }

    It 'sends no bump to a package whose version follows the Umbraco release' {
        New-Commit 'Add Umbraco 18.3.3' "Release-Bump: patch`nRelease-Note: Adds Umbraco 18.3.3."
        $output = Invoke-Release @{ Versioning = 'umbraco' }
        $output | Should -BeLike '*gh workflow run release.yml --ref main -f notes=Adds Umbraco 18.3.3.'
        $output | Should -Not -BeLike '*bump=*'
    }

    It 'counts an unknown bump as patch and warns' {
        New-Commit 'Change the defaults' "Release-Bump: major`nRelease-Note: Changes the defaults."
        $output = Invoke-Release
        $output | Should -BeLike '*::warning::*Release-Bump: major*'
        $output | Should -BeLike '*-f bump=patch'
    }

    It 'leaves the first release to a person' {
        Invoke-Git tag -d v1.2.3
        New-Commit 'Bump Serilog from 4.3.0 to 4.3.1 (#5)' "Release-Bump: patch`nRelease-Note: Updates Serilog."
        $output = Invoke-Release
        $output | Should -BeLike '*::notice::The package has no release yet*'
        $output | Should -Not -BeLike '*workflow run*'
    }
}
