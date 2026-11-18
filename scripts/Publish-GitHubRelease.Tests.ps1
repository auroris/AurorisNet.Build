BeforeAll {
    $script = Join-Path $PSScriptRoot 'Publish-GitHubRelease.ps1'
    $env:GITHUB_REPOSITORY = 'auroris/Example'
}

Describe 'Publishing GitHub releases' {
    BeforeEach {
        $packages = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $packages | Out-Null
        foreach ($name in 'Example.1.2.3.nupkg', 'Example.1.2.3.snupkg', 'Example.Extra.1.2.3.nupkg', 'Example.18.3.2.1.nupkg', 'Example.17.8.2.1.nupkg', 'Example.2.0.0-rc.1.nupkg') {
            Set-Content -LiteralPath (Join-Path $packages $name) 'package'
        }
        Set-Content -LiteralPath (Join-Path $packages 'SHA256SUMS.txt') 'sums'
    }

    It 'creates one release with every package of the version, the assets, the notes and the latest mark' {
        $output = (& $script -Versions '1.2.3' -Packages $packages -Assets (Join-Path $packages '*.txt') -Notes 'Fixes sign-in.' -DryRun 6>&1) -join "`n"
        $output | Should -BeLike '*gh release create v1.2.3 *Example.1.2.3.nupkg*Example.1.2.3.snupkg*Example.Extra.1.2.3.nupkg*SHA256SUMS.txt --verify-tag --title 1.2.3 --generate-notes --latest --notes Fixes sign-in.'
        $output | Should -Not -BeLike '*18.3.2.1*'
    }

    It 'marks a version with a suffix as a prerelease' {
        $output = (& $script -Versions '2.0.0-rc.1' -Packages $packages -DryRun 6>&1) -join "`n"
        $output | Should -BeLike '*gh release create v2.0.0-rc.1 *--prerelease'
        $output | Should -Not -BeLike '*--latest*'
    }

    It 'points each further version of an Umbraco-numbered package to the first' {
        $output = @(& $script -Versions '18.3.2.1,17.8.2.1' -Packages $packages -DryRun 6>&1)
        $output[0] | Should -BeLike '*gh release create v18.3.2.1 *Example.18.3.2.1.nupkg --verify-tag --title 18.3.2.1 --generate-notes --latest'
        $output[1] | Should -BeLike '*gh release create v17.8.2.1 *Example.17.8.2.1.nupkg --verify-tag --title 17.8.2.1 --notes The same package as `[18.3.2.1`](https://github.com/auroris/Example/releases/tag/v18.3.2.1)*Umbraco 17*--latest=false'
    }

    It 'stops when a version has no package' {
        { & $script -Versions '9.9.9' -Packages $packages -DryRun } | Should -Throw '*No package for 9.9.9*'
    }

    It 'releases the assets alone when an application ships no package' {
        $output = (& $script -Versions '9.9.9' -Packages (Join-Path $packages 'none') -Assets (Join-Path $packages '*.txt') -DryRun 6>&1) -join "`n"
        $output | Should -BeLike '*gh release create v9.9.9 *SHA256SUMS.txt --verify-tag --title 9.9.9 --generate-notes --latest'
        $output | Should -Not -BeLike '*.nupkg*'
    }

    It 'stops when an asset is missing' {
        { & $script -Versions '1.2.3' -Packages $packages -Assets (Join-Path $packages 'missing.zip') -DryRun } | Should -Throw '*No file matches*'
    }
}
