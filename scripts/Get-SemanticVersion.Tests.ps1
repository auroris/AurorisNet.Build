BeforeAll {
    $script = Join-Path $PSScriptRoot 'Get-SemanticVersion.ps1'
    $commit = 'a' * 40
    $other = 'b' * 40
    <#
    .SYNOPSIS
    Returns tag lines as git ls-remote prints them, each tag on the other commit unless it is in <onCommit>.
    #>
    function Get-TagLines([string[]] $tags, [string[]] $onCommit = @()) {
        @($tags | ForEach-Object { "$($_ -in $onCommit ? $commit : $other)`trefs/tags/$_" })
    }
}

Describe 'Choosing a semantic version' {
    It 'raises the patch number of the newest stable tag' {
        $release = & $script -Commit $commit -Tags (Get-TagLines 'v1.0.9', 'v1.0.10', 'v0.9.0')
        $release.Version | Should -Be '1.0.11'
        $release.Tag | Should -Be 'v1.0.11'
        $release.Tagged | Should -BeFalse
        $release.Prerelease | Should -BeFalse
    }

    It 'raises the minor number and resets the patch number' {
        (& $script -Bump minor -Commit $commit -Tags (Get-TagLines 'v1.2.3')).Version | Should -Be '1.3.0'
    }

    It 'ignores prereleases older than the newest stable tag and tags that are not versions' {
        (& $script -Commit $commit -Tags (Get-TagLines 'v1.2.3', 'v1.2.3-rc.2', 'nightly', 'v2', 'v18.3.1.2')).Version | Should -Be '1.2.4'
    }

    It 'continues a prerelease series while its newest tag is a prerelease' {
        $release = & $script -Bump minor -Commit $commit -Tags (Get-TagLines 'v0.1.0-alpha.9', 'v0.1.0-alpha.10', 'v0.0.5')
        $release.Version | Should -Be '0.1.0-alpha.11'
        $release.Prerelease | Should -BeTrue
    }

    It 'orders a stable release after its own prereleases' {
        (& $script -Commit $commit -Tags (Get-TagLines 'v1.0.0-rc.3', 'v1.0.0')).Version | Should -Be '1.0.1'
    }

    It 'asks for a version when a prerelease does not end in a number' {
        { & $script -Commit $commit -Tags (Get-TagLines 'v1.0.0-beta') } | Should -Throw '*does not end in a number*'
    }

    It 'asks for a version when there is no tag to raise' {
        { & $script -Commit $commit -Tags @() } | Should -Throw '*No release tag exists*'
    }

    It 'accepts a given version, with or without a v prefix' {
        (& $script -Version ' v2.0.0-rc.1 ' -Commit $commit -Tags @()).Version | Should -Be '2.0.0-rc.1'
        (& $script -Version '2.0.0' -Commit $commit -Tags @()).Tag | Should -Be 'v2.0.0'
    }

    It 'finishes a release whose tag already marks the commit' {
        (& $script -Version '1.2.3' -Commit $commit -Tags (Get-TagLines 'v1.2.3' -onCommit 'v1.2.3')).Tagged | Should -BeTrue
    }

    It 'refuses a version whose tag marks another commit' {
        { & $script -Version '1.2.3' -Commit $commit -Tags (Get-TagLines 'v1.2.3') } | Should -Throw '*already marks commit*'
    }

    It 'refuses a value that is not a version: <Value>' -TestCases @(
        @{ Value = '1.2' }, @{ Value = '1.2.3.4' }, @{ Value = '1.02.3' }, @{ Value = '1.2.3+build' }, @{ Value = '1.2.3-' }
    ) {
        param($Value)
        { & $script -Version $Value -Commit $commit -Tags @() } | Should -Throw '*MAJOR.MINOR.PATCH*'
    }

    It 'refuses a number beyond the assembly version limit' {
        { & $script -Version '1.65535.0' -Commit $commit -Tags @() } | Should -Throw '*between 0 and 65534*'
    }
}
